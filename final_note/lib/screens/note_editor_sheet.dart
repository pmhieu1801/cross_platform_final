import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../features/notes/application/note_ai_service.dart';
import '../features/notes/application/note_attachment_service.dart';
import '../features/notes/application/note_providers.dart';
import '../features/notes/domain/note_repository.dart';
import '../models/note.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// Shows a confirmation dialog before deleting a note (R13).
///
/// Returns `true` only if the user explicitly confirms deletion.
Future<bool> confirmDeleteNote(
  BuildContext context, {
  required String title,
}) async {
  final displayTitle = title.trim().isEmpty ? 'Untitled note' : title.trim();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          'Are you sure you want to delete "$displayTitle"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-delete-note'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-note'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Unified Create / Update note editor with debounced auto-save,
/// [AppLifecycleListener] flush support, and label attachment (R11-R14, R21).
class NoteEditorPanel extends StatefulWidget {
  const NoteEditorPanel({
    super.key,
    this.initialNote,
    this.availableLabels = const <String>[],
    required this.onSave,
    this.onDelete,
    this.onClose,
    this.attachmentPicker,
    this.onEnablePassword,
    this.onChangePassword,
    this.onDisablePassword,
    this.onLockSession,
    this.onShareNote,
    this.onUpdateSharePermission,
    this.onRevokeShare,
    this.readOnly = false,
    this.sharedByEmail,
    this.sharedAt,
    this.debounceDuration = const Duration(milliseconds: 400),
    this.embedded = false,
    this.noteFontScale = 1,
  });

  /// `null` when creating a new note; non-null when editing an existing note.
  final Note? initialNote;
  final double noteFontScale;

  /// All known labels for this account so the user can toggle them on/off.
  final List<String> availableLabels;

  /// Persists the note and returns the saved [Note] (or throws / returns `null`
  /// on failure).
  final Future<Note?> Function(Note draft, {required bool isAutosave}) onSave;

  /// Optional delete callback for existing notes.
  final Future<bool> Function(Note note)? onDelete;

  /// Called when the user closes the editor.
  final VoidCallback? onClose;

  /// Optional custom attachment picker for R15 (images/videos) and R16 (files).
  /// When omitted, opens the interactive NoteFlow attachment selector dialog.
  final Future<AttachmentPickOutcome> Function(NoteAttachmentKind kind)?
  attachmentPicker;

  /// Optional callbacks for enabling, changing, or disabling note password
  /// protection (R23, R24).
  final Future<({Note? note, String? error})> Function(
    Note draft,
    String password,
    String confirmPassword,
  )?
  onEnablePassword;

  final Future<({Note? note, String? error})> Function(
    Note draft,
    String currentPassword,
    String newPassword,
    String confirmNewPassword,
  )?
  onChangePassword;

  final Future<({Note? note, String? error})> Function(
    Note draft,
    String currentPassword,
  )?
  onDisablePassword;

  final VoidCallback? onLockSession;

  /// Optional sharing callbacks for the note owner (R25, R26).
  final Future<({Note? note, String? error})> Function(
    Note draft,
    String recipientEmail,
    NoteSharePermission permission,
  )?
  onShareNote;

  final Future<({Note? note, String? error})> Function(
    Note draft,
    String recipientEmail,
    NoteSharePermission permission,
  )?
  onUpdateSharePermission;

  final Future<({Note? note, String? error})> Function(
    Note draft,
    String recipientEmail,
  )?
  onRevokeShare;

  /// Whether this editor is opened by a recipient with Read-only permission (R25, R26).
  final bool readOnly;
  final String? sharedByEmail;
  final DateTime? sharedAt;

  /// Debounce window before auto-saving after the user stops typing.
  final Duration debounceDuration;

  /// Whether this editor is embedded side-by-side on desktop.
  final bool embedded;

  @override
  State<NoteEditorPanel> createState() => _NoteEditorPanelState();
}

class _NoteEditorPanelState extends State<NoteEditorPanel> {
  late final String _noteId;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final _newLabelController = TextEditingController();
  late final AppLifecycleListener _lifecycleListener;

  late int _colorIndex;
  late bool _isPinned;
  late DateTime? _pinnedAt;
  late NoteStatus _status;
  late NoteSyncStatus _syncStatus;
  late List<String> _labels;
  late List<NoteAttachment> _attachments;
  late List<NoteShareEntry> _shares;
  late List<String> _catalogLabels;
  String? _passwordHash;
  String? _passwordSalt;

  bool get _isPasswordProtected =>
      _passwordHash != null &&
      _passwordHash!.isNotEmpty &&
      _passwordSalt != null &&
      _passwordSalt!.isNotEmpty;

  Timer? _debounceTimer;
  bool _dirty = false;
  bool _hasEverSaved = false;
  NoteAutosavePhase _phase = NoteAutosavePhase.idle;
  String? _errorMessage;
  String? _attachmentError;
  Note? _lastSavedSnapshot;
  NoteAiSummaryResult? _aiSummary;
  String? _aiSummaryError;
  bool _generatingSummary = false;
  int _summaryVariationIndex = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialNote;
    _noteId = initial?.id ?? 'note-${DateTime.now().microsecondsSinceEpoch}';
    _titleController = TextEditingController(text: initial?.title ?? '');
    _contentController = TextEditingController(text: initial?.content ?? '');
    _colorIndex = initial?.colorIndex ?? 0;
    _isPinned = initial?.isPinned ?? false;
    _pinnedAt = initial?.pinnedAt;
    _status = initial?.status ?? NoteStatus.normal;
    _syncStatus = initial?.syncStatus ?? NoteSyncStatus.pending;
    _labels = List<String>.of(initial?.labels ?? const <String>[]);
    _attachments = List<NoteAttachment>.of(
      initial?.attachments ?? const <NoteAttachment>[],
    );
    _shares = List<NoteShareEntry>.of(
      initial?.shares ?? const <NoteShareEntry>[],
    );
    _passwordHash = initial?.passwordHash;
    _passwordSalt = initial?.passwordSalt;
    _catalogLabels = {...widget.availableLabels, ..._labels}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _hasEverSaved = initial != null;
    _lastSavedSnapshot = initial;

    _titleController.addListener(_onFieldEdited);
    _contentController.addListener(_onFieldEdited);

    _lifecycleListener = AppLifecycleListener(
      onInactive: _flushPendingSave,
      onHide: _flushPendingSave,
      onPause: _flushPendingSave,
      onDetach: _flushPendingSave,
    );
  }

  @override
  void didUpdateWidget(covariant NoteEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableLabels != widget.availableLabels) {
      _catalogLabels = {...widget.availableLabels, ..._labels}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    final next = widget.initialNote;
    if (next != null) {
      _shares = List<NoteShareEntry>.of(next.shares);
      _passwordHash = next.passwordHash;
      _passwordSalt = next.passwordSalt;
      if (!_dirty && oldWidget.initialNote?.syncStatus != next.syncStatus) {
        _syncStatus = next.syncStatus;
      }
      // Real-time collaboration update from another authorized editor (R26).
      if (!_dirty &&
          (oldWidget.initialNote?.title != next.title ||
              oldWidget.initialNote?.content != next.content ||
              oldWidget.initialNote?.updatedAt != next.updatedAt)) {
        _titleController.removeListener(_onFieldEdited);
        _contentController.removeListener(_onFieldEdited);
        if (_titleController.text != next.title) {
          _titleController.text = next.title;
        }
        if (_contentController.text != next.content) {
          _contentController.text = next.content;
        }
        _titleController.addListener(_onFieldEdited);
        _contentController.addListener(_onFieldEdited);
        _colorIndex = next.colorIndex;
        _isPinned = next.isPinned;
        _pinnedAt = next.pinnedAt;
        _status = next.status;
        _labels = List<String>.of(next.labels);
        _attachments = List<NoteAttachment>.of(next.attachments);
        _lastSavedSnapshot = next;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _lifecycleListener.dispose();
    _titleController.removeListener(_onFieldEdited);
    _contentController.removeListener(_onFieldEdited);
    _titleController.dispose();
    _contentController.dispose();
    _newLabelController.dispose();
    super.dispose();
  }

  bool get _hasMeaningfulContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _attachments.isNotEmpty;

  Note _buildDraft() {
    final now = DateTime.now();
    final rawTitle = _titleController.text.trim();
    return Note(
      id: _noteId,
      title: rawTitle.isEmpty ? 'Untitled note' : rawTitle,
      content: _contentController.text,
      labels: List<String>.unmodifiable(_labels),
      colorIndex: _colorIndex,
      updatedAt: now,
      isPinned: _isPinned,
      pinnedAt: _isPinned ? (_pinnedAt ?? now) : null,
      ownerUid: widget.initialNote?.ownerUid,
      ownerEmail: widget.initialNote?.ownerEmail,
      status: _status,
      syncStatus: _syncStatus,
      attachments: List<NoteAttachment>.unmodifiable(_attachments),
      passwordHash: _passwordHash,
      passwordSalt: _passwordSalt,
      shares: List<NoteShareEntry>.unmodifiable(_shares),
    );
  }

  bool _differsFromLastSaved() {
    final previous = _lastSavedSnapshot;
    if (previous == null) return _hasMeaningfulContent;
    final currentTitle = _titleController.text.trim().isEmpty
        ? 'Untitled note'
        : _titleController.text.trim();
    if (previous.title != currentTitle) return true;
    if (previous.content != _contentController.text) return true;
    if (previous.colorIndex != _colorIndex) return true;
    if (previous.isPinned != _isPinned) return true;
    if (previous.status != _status) return true;
    if (previous.labels.length != _labels.length) return true;
    for (var i = 0; i < _labels.length; i++) {
      if (previous.labels[i] != _labels[i]) return true;
    }
    if (previous.attachments.length != _attachments.length) return true;
    for (var i = 0; i < _attachments.length; i++) {
      if (previous.attachments[i] != _attachments[i]) return true;
    }
    return false;
  }

  Future<void> _addAttachment(NoteAttachmentKind kind) async {
    final outcome = widget.attachmentPicker != null
        ? await widget.attachmentPicker!(kind)
        : await _pickFromDeviceFileSystem(kind);
    if (!mounted) return;

    if (outcome.cancelled) {
      return;
    }
    if (outcome.permissionDenied || outcome.errorMessage != null) {
      setState(() {
        _attachmentError =
            outcome.errorMessage ??
            'Permission to access files or media was denied.';
      });
      return;
    }

    final added = <NoteAttachment>[];
    String? firstValidationError;
    for (final candidate in outcome.candidates) {
      final result = NoteAttachmentValidator.validate(
        candidate,
        ownerUid: widget.initialNote?.ownerUid,
      );
      if (result.isValid) {
        added.add(result.attachment!);
      } else {
        firstValidationError ??= result.error;
      }
    }

    setState(() {
      _attachmentError = firstValidationError;
      if (added.isNotEmpty) {
        _attachments.addAll(added);
      }
    });
    if (added.isNotEmpty) {
      _markPendingAndScheduleAutosave();
    }
  }

  Future<AttachmentPickOutcome> _pickFromDeviceFileSystem(
    NoteAttachmentKind kind,
  ) async {
    try {
      final allowedExtensions = switch (kind) {
        NoteAttachmentKind.image =>
          NoteAttachmentValidator.allowedImageExtensions.toList(),
        NoteAttachmentKind.video =>
          NoteAttachmentValidator.allowedVideoExtensions.toList(),
        NoteAttachmentKind.file =>
          NoteAttachmentValidator.allowedFileExtensions.toList(),
      };
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (files.isEmpty) {
        return const AttachmentPickOutcome.cancelled();
      }
      final candidates = <PickedAttachmentCandidate>[];
      for (final file in files) {
        final safePath = kIsWeb
            ? 'device://${file.name}'
            : (file.path ?? 'device://${file.name}');
        final sizeBytes = file.lengthSync() ?? (await file.length()) ?? 0;
        Uint8List? bytes;
        if (sizeBytes > 0 && sizeBytes <= kMaxInlinePreviewBytes) {
          try {
            bytes = await file.readAsBytes();
          } catch (_) {}
        }
        candidates.add(
          PickedAttachmentCandidate(
            name: file.name,
            kind: kind,
            sizeBytes: bytes?.length ?? sizeBytes,
            localPath: safePath,
            bytes: bytes,
          ),
        );
      }
      return AttachmentPickOutcome.picked(candidates);
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('permission') || code.contains('denied')) {
        return AttachmentPickOutcome.permissionDenied(
          error.message ?? 'Permission to access files or media was denied. Please grant access and try again.',
        );
      }
      return AttachmentPickOutcome.failure(
        error.message ?? 'Could not open device file picker.',
      );
    } catch (_) {
      return _showAttachmentPickerDialog(kind);
    }
  }

  Future<AttachmentPickOutcome> _showAttachmentPickerDialog(
    NoteAttachmentKind kind,
  ) async {
    final defaultName = switch (kind) {
      NoteAttachmentKind.image => 'photo_${_attachments.length + 1}.png',
      NoteAttachmentKind.video => 'clip_${_attachments.length + 1}.mp4',
      NoteAttachmentKind.file => 'document_${_attachments.length + 1}.pdf',
    };
    final defaultSizeKb = switch (kind) {
      NoteAttachmentKind.image => '240',
      NoteAttachmentKind.video => '2048',
      NoteAttachmentKind.file => '512',
    };
    final nameController = TextEditingController(text: defaultName);
    final sizeKbController = TextEditingController(text: defaultSizeKb);

    final result = await showDialog<AttachmentPickOutcome>(
      context: context,
      builder: (dialogContext) {
        final text = dialogContext.text;
        final presets = switch (kind) {
          NoteAttachmentKind.image => const [
            ('whiteboard.png', 180 * 1024),
            ('wireframe.jpg', 420 * 1024),
            ('diagram.webp', 95 * 1024),
          ],
          NoteAttachmentKind.video => const [
            ('demo_walkthrough.mp4', 3 * 1024 * 1024),
            ('lecture_clip.webm', 5 * 1024 * 1024),
          ],
          NoteAttachmentKind.file => const [
            ('project_spec.pdf', 380 * 1024),
            ('meeting_notes.md', 24 * 1024),
            ('budget_2026.csv', 64 * 1024),
          ],
        };

        return AlertDialog(
          title: Text('Attach ${kind.label.toLowerCase()}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(switch (kind) {
                  NoteAttachmentKind.image =>
                    'Supported: PNG, JPG, GIF, WEBP, BMP (max 5 MB).',
                  NoteAttachmentKind.video =>
                    'Supported: MP4, WEBM, MOV, M4V, AVI (max 15 MB).',
                  NoteAttachmentKind.file => 'Supported: PDF, TXT, MD, CSV, JSON, Office, ZIP (max 5 MB).',
                }, style: text.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: presets.map((preset) {
                    return ActionChip(
                      key: Key('attachment-preset-${preset.$1}'),
                      label: Text(
                        '${preset.$1} (${NoteAttachmentValidator.formatBytes(preset.$2)})',
                      ),
                      onPressed: () {
                        nameController.text = preset.$1;
                        sizeKbController.text = '${preset.$2 ~/ 1024}';
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('attachment-picker-name-input'),
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'File name',
                    hintText: 'e.g. screenshot.png',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('attachment-picker-size-kb-input'),
                  controller: sizeKbController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'File size (KB)',
                    hintText: '240',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('attachment-picker-cancel'),
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(const AttachmentPickOutcome.cancelled()),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('attachment-picker-confirm'),
              onPressed: () {
                final rawName = nameController.text.trim();
                final parsedKb = int.tryParse(sizeKbController.text.trim());
                final sizeBytes = parsedKb == null ? 0 : parsedKb * 1024;
                Navigator.of(dialogContext).pop(
                  AttachmentPickOutcome.picked([
                    PickedAttachmentCandidate(
                      name: rawName,
                      kind: kind,
                      sizeBytes: sizeBytes,
                    ),
                  ]),
                );
              },
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Attach'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    sizeKbController.dispose();
    return result ?? const AttachmentPickOutcome.cancelled();
  }

  void _openAttachmentPreview(NoteAttachment attachment) {
    final authorized = NoteAttachmentValidator.canAccessAttachment(
      note: _buildDraft(),
      attachment: attachment,
      viewerUid: widget.initialNote?.ownerUid,
    );
    if (!authorized) {
      setState(() {
        _attachmentError = 'You are not authorized to open this attachment from the current account.';
      });
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text = dialogContext.text;
        final previewBytes = attachment.previewBase64 != null
            ? base64Decode(attachment.previewBase64!)
            : null;
        final ext = NoteAttachmentValidator.extractExtension(attachment.name);
        final isTextFile = const {'txt', 'md', 'csv', 'json'}.contains(ext);
        String? textPreview;
        if (previewBytes != null && isTextFile) {
          try {
            textPreview = utf8.decode(previewBytes, allowMalformed: true);
          } catch (_) {}
        }

        return AlertDialog(
          key: const Key('attachment-preview-dialog'),
          title: Row(
            children: [
              Icon(switch (attachment.kind) {
                NoteAttachmentKind.image => Icons.image_rounded,
                NoteAttachmentKind.video => Icons.videocam_rounded,
                NoteAttachmentKind.file => Icons.insert_drive_file_rounded,
              }),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(attachment.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (previewBytes != null &&
                      attachment.kind == NoteAttachmentKind.image) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: Image.memory(
                          previewBytes,
                          key: const Key('attachment-image-memory-preview'),
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else if (textPreview != null &&
                      textPreview.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: dialogContext.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          textPreview,
                          style: text.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    'Type: ${attachment.kind.label} (${attachment.mimeType})',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${NoteAttachmentValidator.formatBytes(attachment.sizeBytes)}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Location: ${attachment.localPath}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('attachment-preview-close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _removeAttachment(NoteAttachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.id == attachment.id);
    });
    _markPendingAndScheduleAutosave();
  }

  void _onFieldEdited() {
    if (widget.readOnly) return;
    if (!_differsFromLastSaved()) return;
    _markPendingAndScheduleAutosave();
  }

  void _toggleLabel(String label) {
    setState(() {
      if (_labels.contains(label)) {
        _labels.remove(label);
      } else {
        _labels.add(label);
      }
    });
    _markPendingAndScheduleAutosave();
  }

  void _commitPendingLabelInput({bool scheduleSave = true}) {
    final raw = _newLabelController.text.trim();
    if (raw.isEmpty) return;
    final parts = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;

    setState(() {
      for (final part in parts) {
        final existingMatch = _catalogLabels.cast<String?>().firstWhere(
          (item) => item!.toLowerCase() == part.toLowerCase(),
          orElse: () => null,
        );
        final resolved = existingMatch ?? part;
        if (!_catalogLabels.contains(resolved)) {
          _catalogLabels = [..._catalogLabels, resolved]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
        if (!_labels.contains(resolved)) {
          _labels.add(resolved);
        }
      }
      _newLabelController.clear();
    });
    if (scheduleSave) {
      _markPendingAndScheduleAutosave();
    } else {
      _dirty = true;
      if (_syncStatus != NoteSyncStatus.pending) {
        _syncStatus = NoteSyncStatus.pending;
      }
    }
  }

  void _addCustomLabel() {
    _commitPendingLabelInput(scheduleSave: true);
  }

  void _markPendingAndScheduleAutosave() {
    _dirty = true;
    if (_syncStatus != NoteSyncStatus.pending) {
      setState(() => _syncStatus = NoteSyncStatus.pending);
    }
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _debounceTimer?.cancel();
    if (!_hasMeaningfulContent && !_hasEverSaved) {
      if (_phase != NoteAutosavePhase.idle) {
        setState(() => _phase = NoteAutosavePhase.idle);
      }
      return;
    }
    setState(() {
      _phase = NoteAutosavePhase.saving;
      _errorMessage = null;
    });
    _debounceTimer = Timer(widget.debounceDuration, () {
      _persistNow(isAutosave: true);
    });
  }

  void _flushPendingSave() {
    _debounceTimer?.cancel();
    if (_newLabelController.text.trim().isNotEmpty) {
      _commitPendingLabelInput(scheduleSave: false);
    }
    if (_dirty && (_hasMeaningfulContent || _hasEverSaved)) {
      unawaited(_persistNow(isAutosave: true));
    }
  }

  Future<bool> _persistNow({required bool isAutosave}) async {
    _debounceTimer?.cancel();
    if (widget.readOnly) return true;
    if (_newLabelController.text.trim().isNotEmpty) {
      _commitPendingLabelInput(scheduleSave: false);
    }
    if (!_hasMeaningfulContent && !_hasEverSaved) {
      return true;
    }
    final draft = _buildDraft();
    if (mounted) {
      setState(() {
        _phase = NoteAutosavePhase.saving;
        _errorMessage = null;
      });
    }
    try {
      final saved = await widget.onSave(draft, isAutosave: isAutosave);
      if (saved == null) {
        if (mounted) {
          setState(() {
            _phase = NoteAutosavePhase.error;
            _errorMessage = 'Could not save locally. Tap retry.';
          });
        }
        return false;
      }
      _hasEverSaved = true;
      _lastSavedSnapshot = saved;
      _passwordHash = saved.passwordHash ?? _passwordHash;
      _passwordSalt = saved.passwordSalt ?? _passwordSalt;
      if (saved.shares.isNotEmpty) {
        _shares = List<NoteShareEntry>.of(saved.shares);
      }
      _dirty = _differsFromLastSaved();
      if (mounted) {
        setState(() {
          _syncStatus = saved.syncStatus;
          _phase = NoteAutosavePhase.saved;
          _errorMessage = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = NoteAutosavePhase.error;
          _errorMessage = 'Could not save locally. Tap retry.';
        });
      }
      return false;
    }
  }

  Future<void> _handleSaveAndClose() async {
    _debounceTimer?.cancel();
    if (_newLabelController.text.trim().isNotEmpty) {
      _commitPendingLabelInput(scheduleSave: false);
    }
    if (_hasMeaningfulContent || _hasEverSaved) {
      final ok = await _persistNow(isAutosave: false);
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _handleClose() async {
    _debounceTimer?.cancel();
    if (_newLabelController.text.trim().isNotEmpty) {
      _commitPendingLabelInput(scheduleSave: false);
    }
    if ((_dirty || _differsFromLastSaved()) &&
        (_hasMeaningfulContent || _hasEverSaved)) {
      await _persistNow(isAutosave: false);
    }
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _handleDelete() async {
    final target = _lastSavedSnapshot ?? widget.initialNote;
    if (target == null || widget.onDelete == null) return;
    final confirmed = await confirmDeleteNote(
      context,
      title: _titleController.text,
    );
    if (!confirmed || !mounted) return;
    _debounceTimer?.cancel();
    _dirty = false;
    final deleted = await widget.onDelete!(target);
    if (!deleted || !mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _handlePasswordProtectionButton() async {
    // Ensure the note exists in storage before enabling/changing its password.
    if (!_hasEverSaved || _dirty) {
      final savedOk = await _persistNow(isAutosave: false);
      if (!savedOk || !mounted) return;
    }
    final currentDraft = _lastSavedSnapshot ?? _buildDraft();

    if (!_isPasswordProtected) {
      if (widget.onEnablePassword == null) return;
      await showEnableNotePasswordDialog(
        context,
        onEnable: (password, confirmPassword) async {
          final res = await widget.onEnablePassword!(
            currentDraft,
            password,
            confirmPassword,
          );
          if (res.note != null && mounted) {
            setState(() {
              _lastSavedSnapshot = res.note;
              _passwordHash = res.note!.passwordHash;
              _passwordSalt = res.note!.passwordSalt;
              _syncStatus = res.note!.syncStatus;
            });
          }
          return res.error;
        },
      );
      return;
    }

    if (widget.onChangePassword == null || widget.onDisablePassword == null) {
      return;
    }
    await showManageNotePasswordDialog(
      context,
      onChangePassword:
          (currentPassword, newPassword, confirmNewPassword) async {
            final res = await widget.onChangePassword!(
              currentDraft,
              currentPassword,
              newPassword,
              confirmNewPassword,
            );
            if (res.note != null && mounted) {
              setState(() {
                _lastSavedSnapshot = res.note;
                _passwordHash = res.note!.passwordHash;
                _passwordSalt = res.note!.passwordSalt;
                _syncStatus = res.note!.syncStatus;
              });
            }
            return res.error;
          },
      onDisablePassword: (currentPassword) async {
        final res = await widget.onDisablePassword!(
          currentDraft,
          currentPassword,
        );
        if (res.note != null && mounted) {
          setState(() {
            _lastSavedSnapshot = res.note;
            _passwordHash = null;
            _passwordSalt = null;
            _syncStatus = res.note!.syncStatus;
          });
        }
        return res.error;
      },
      onLockNow: widget.onLockSession == null
          ? null
          : () {
              widget.onLockSession!();
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
    );
  }

  Future<void> _handleShareButton() async {
    if (widget.readOnly || widget.onShareNote == null) return;
    if (!_hasEverSaved || _dirty) {
      final savedOk = await _persistNow(isAutosave: false);
      if (!savedOk || !mounted) return;
    }
    final currentDraft = _lastSavedSnapshot ?? _buildDraft();
    await showNoteShareDialog(
      context,
      note: currentDraft.copyWith(shares: _shares),
      onAddShare: (recipientEmail, permission) async {
        final res = await widget.onShareNote!(
          currentDraft,
          recipientEmail,
          permission,
        );
        if (res.note != null && mounted) {
          setState(() {
            _lastSavedSnapshot = res.note;
            _shares = List<NoteShareEntry>.of(res.note!.shares);
          });
        }
        return res;
      },
      onUpdatePermission: (recipientEmail, permission) async {
        if (widget.onUpdateSharePermission == null) {
          return (note: null, error: 'Updating permission is not configured.');
        }
        final res = await widget.onUpdateSharePermission!(
          currentDraft,
          recipientEmail,
          permission,
        );
        if (res.note != null && mounted) {
          setState(() {
            _lastSavedSnapshot = res.note;
            _shares = List<NoteShareEntry>.of(res.note!.shares);
          });
        }
        return res;
      },
      onRevokeShare: (recipientEmail) async {
        if (widget.onRevokeShare == null) {
          return (note: null, error: 'Revoking access is not configured.');
        }
        final res = await widget.onRevokeShare!(currentDraft, recipientEmail);
        if (res.note != null && mounted) {
          setState(() {
            _lastSavedSnapshot = res.note;
            _shares = List<NoteShareEntry>.of(res.note!.shares);
          });
        }
        return res;
      },
    );
  }

  Future<void> _generateAiSummary({bool regenerate = false}) async {
    if (_generatingSummary) return;
    final nextVariation = regenerate ? _summaryVariationIndex + 1 : 0;
    setState(() {
      _generatingSummary = true;
      _aiSummaryError = null;
    });
    try {
      final result = await const NoteAiService().summarizeNote(
        _buildDraft(),
        isUnlocked: true,
        variationIndex: nextVariation,
      );
      if (!mounted) return;
      setState(() {
        _generatingSummary = false;
        _summaryVariationIndex = nextVariation;
        _aiSummary = result;
      });
    } on NoteFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _generatingSummary = false;
        _aiSummaryError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generatingSummary = false;
        _aiSummaryError = 'Could not generate AI summary.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;
    final accent = tokens.noteAccent(_colorIndex);
    final pastelFill = tokens.noteCardFill(_colorIndex);
    final isEditing = widget.initialNote != null || _hasEverSaved;
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.65);

    return GlassPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: pastelFill,
      borderColor: inkColor.withValues(alpha: 0.12),
      borderRadius: widget.embedded
          ? AppRadius.xlAll
          : const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('note-editor-close'),
                tooltip: 'Close editor',
                onPressed: _handleClose,
                icon: Icon(
                  widget.embedded
                      ? Icons.close_rounded
                      : Icons.arrow_back_rounded,
                  color: inkColor,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAutosaveBadge(context),
                    NoteSyncStatusIndicator(
                      status: _syncStatus,
                      showLabel: true,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('note-editor-ai-summary-button'),
                tooltip: 'AI Summary',
                visualDensity: VisualDensity.compact,
                onPressed: _generatingSummary
                    ? null
                    : () => _generateAiSummary(regenerate: false),
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  color: _aiSummary != null ? inkColor : subInkColor,
                ),
              ),
              if (!widget.readOnly)
                IconButton(
                  key: const Key('note-editor-pin'),
                  tooltip: _isPinned ? 'Unpin note' : 'Pin note',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _isPinned = !_isPinned;
                      _pinnedAt = _isPinned ? DateTime.now() : null;
                    });
                    _markPendingAndScheduleAutosave();
                  },
                  icon: Icon(
                    _isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: _isPinned ? inkColor : subInkColor,
                  ),
                ),
              if (!widget.readOnly && widget.onShareNote != null)
                IconButton(
                  key: const Key('note-editor-share-button'),
                  tooltip: 'Share note',
                  visualDensity: VisualDensity.compact,
                  onPressed: _handleShareButton,
                  icon: Icon(
                    _shares.isNotEmpty
                        ? Icons.people_alt_rounded
                        : Icons.person_add_alt_outlined,
                    color: _shares.isNotEmpty ? inkColor : subInkColor,
                  ),
                ),
              if (!widget.readOnly && widget.onEnablePassword != null)
                IconButton(
                  key: const Key('note-editor-lock-button'),
                  tooltip: _isPasswordProtected
                      ? 'Password protection settings'
                      : 'Protect note with password',
                  visualDensity: VisualDensity.compact,
                  onPressed: _handlePasswordProtectionButton,
                  icon: Icon(
                    _isPasswordProtected
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    color: _isPasswordProtected ? inkColor : subInkColor,
                  ),
                ),
              if (!widget.readOnly &&
                  (_hasEverSaved || widget.initialNote != null) &&
                  widget.onDelete != null)
                IconButton(
                  key: const Key('note-editor-delete'),
                  tooltip: 'Delete note',
                  visualDensity: VisualDensity.compact,
                  onPressed: _handleDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                ),
            ],
          ),
          if (widget.readOnly) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              key: const Key('note-editor-readonly-banner'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: inkColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: inkColor.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: inkColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.sharedByEmail != null
                          ? 'Read-only shared note from ${widget.sharedByEmail}'
                          : 'Read-only shared note — editing is disabled',
                      style: text.labelSmall?.copyWith(
                        color: inkColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('note-title-input'),
            controller: _titleController,
            readOnly: widget.readOnly,
            textInputAction: TextInputAction.next,
            style: text.headlineSmall?.copyWith(
              fontSize:
                  (text.headlineSmall?.fontSize ?? 22) * widget.noteFontScale,
              fontFamily: AppTypography.display,
              fontWeight: FontWeight.w700,
              color: inkColor,
            ),
            decoration: InputDecoration(
              labelText: 'Title',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              hintText: 'Note title...',
              hintStyle: text.headlineSmall?.copyWith(
                fontFamily: AppTypography.display,
                fontWeight: FontWeight.w600,
                color: subInkColor,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
              ),
            ),
          ),
          Divider(color: inkColor.withValues(alpha: 0.12), height: 20),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140, maxHeight: 300),
              child: TextField(
                key: const Key('note-content-input'),
                controller: _contentController,
                readOnly: widget.readOnly,
                maxLines: null,
                minLines: 5,
                keyboardType: TextInputType.multiline,
                style: text.bodyLarge?.copyWith(
                  color: inkColor,
                  height: 1.55,
                  fontSize:
                      (text.bodyLarge?.fontSize ?? 16) * widget.noteFontScale,
                ),
                decoration: InputDecoration(
                  labelText: 'Content',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: 'Start writing your thoughts...',
                  hintStyle: text.bodyLarge?.copyWith(color: subInkColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
          ),
          if (_aiSummary != null || _aiSummaryError != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildAiSummaryCard(context),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildStatusPicker(context),
          const SizedBox(height: AppSpacing.md),
          _buildLabelsSection(context, accent),
          const SizedBox(height: AppSpacing.md),
          _buildAttachmentsSection(context, accent),
          const SizedBox(height: AppSpacing.md),
          _buildColorPicker(context, accent),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _handleClose,
                style: TextButton.styleFrom(foregroundColor: inkColor),
                child: Text(widget.readOnly ? 'Close' : 'Done'),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  key: const Key('note-editor-save-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _handleSaveAndClose,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(isEditing ? 'Save changes' : 'Create note'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.68);

    return Container(
      key: const Key('note-ai-summary-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.80),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: inkColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: inkColor),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _aiSummary != null
                      ? 'AI Summary (${_aiSummary!.styleLabel})'
                      : 'AI Summary',
                  style: text.labelMedium?.copyWith(
                    color: inkColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_aiSummary != null)
                TextButton.icon(
                  key: const Key('note-ai-summary-regenerate'),
                  onPressed: _generatingSummary
                      ? null
                      : () => _generateAiSummary(regenerate: true),
                  style: TextButton.styleFrom(
                    foregroundColor: inkColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Regenerate'),
                ),
              IconButton(
                key: const Key('note-ai-summary-dismiss'),
                tooltip: 'Dismiss AI summary',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  _aiSummary = null;
                  _aiSummaryError = null;
                }),
                icon: Icon(Icons.close_rounded, size: 16, color: subInkColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_aiSummaryError != null)
            Text(
              _aiSummaryError!,
              key: const Key('note-ai-summary-error'),
              style: text.bodySmall?.copyWith(color: tokens.danger),
            )
          else if (_aiSummary != null)
            SelectableText(
              _aiSummary!.summary,
              key: const Key('note-ai-summary-text'),
              style: text.bodySmall?.copyWith(color: inkColor, height: 1.5),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPicker(BuildContext context) {
    final text = context.text;
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Status',
          style: text.labelSmall?.copyWith(
            color: subInkColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<NoteStatus>(
          initialValue: _status,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(18),
          menuMaxHeight: 360,
          elevation: 6,
          iconEnabledColor: inkColor,
          iconDisabledColor: subInkColor,
          style: text.bodyMedium?.copyWith(
            color: inkColor,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.78),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(color: inkColor.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(color: inkColor.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: const BorderSide(color: inkColor, width: 1.5),
            ),
          ),
          items: NoteStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(
                    status.label,
                    style: text.bodyMedium?.copyWith(
                      color: inkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: widget.readOnly
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                  _markPendingAndScheduleAutosave();
                },
        ),
      ],
    );
  }

  Widget _buildLabelsSection(BuildContext context, Color accent) {
    final text = context.text;
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.label_outline_rounded, size: 16, color: subInkColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Labels',
              style: text.labelSmall?.copyWith(
                color: subInkColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_catalogLabels.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _catalogLabels.map((label) {
              final selected = _labels.contains(label);
              return FilterChip(
                key: Key('editor-label-chip-$label'),
                label: Text(label),
                selected: selected,
                onSelected: (_) => _toggleLabel(label),
                backgroundColor: Colors.white.withValues(alpha: 0.65),
                selectedColor: inkColor,
                side: BorderSide(
                  color: selected ? inkColor : inkColor.withValues(alpha: 0.18),
                ),
                labelStyle: text.labelSmall?.copyWith(
                  color: selected ? Colors.white : inkColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('editor-new-label-input'),
                controller: _newLabelController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addCustomLabel(),
                style: text.bodySmall?.copyWith(color: inkColor),
                decoration: InputDecoration(
                  labelText: 'Labels (comma separated)',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: 'Attach a label...',
                  hintStyle: text.bodySmall?.copyWith(color: subInkColor),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.72),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide(
                      color: inkColor.withValues(alpha: 0.16),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide(
                      color: inkColor.withValues(alpha: 0.16),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: const BorderSide(color: inkColor, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const Key('editor-add-label-button'),
              tooltip: 'Attach label',
              onPressed: _addCustomLabel,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: inkColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(BuildContext context, Color accent) {
    final tokens = context.tokens;
    final text = context.text;
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file_rounded, size: 16, color: subInkColor),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Attachments (${_attachments.length})',
                style: text.labelSmall?.copyWith(
                  color: subInkColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<NoteAttachmentKind>(
              key: const Key('editor-add-attachment-menu'),
              tooltip: 'Add attachment',
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: inkColor,
              ),
              onSelected: _addAttachment,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  key: Key('attach-menu-image'),
                  value: NoteAttachmentKind.image,
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Image'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  key: Key('attach-menu-file'),
                  value: NoteAttachmentKind.file,
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('File'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_attachmentError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('note-attachment-error'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: tokens.danger,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _attachmentError!,
                      style: text.labelSmall?.copyWith(
                        color: tokens.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('dismiss-attachment-error'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _attachmentError = null),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: tokens.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        if (_attachments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inkColor.withValues(alpha: 0.14)),
            ),
            child: Text(
              'No attachments yet. Add an image or file.',
              style: text.bodySmall?.copyWith(color: subInkColor),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _attachments.map((attachment) {
              final icon = switch (attachment.kind) {
                NoteAttachmentKind.image => Icons.image_rounded,
                NoteAttachmentKind.video => Icons.videocam_rounded,
                NoteAttachmentKind.file => Icons.insert_drive_file_rounded,
              };

              return Material(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: Key('note-attachment-chip-${attachment.name}'),
                  onTap: () => _openAttachmentPreview(attachment),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: inkColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (attachment.kind == NoteAttachmentKind.image &&
                            attachment.previewBase64 != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              base64Decode(attachment.previewBase64!),
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Icon(icon, size: 16, color: inkColor),
                            ),
                          ),
                        ] else
                          Icon(icon, size: 16, color: inkColor),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          attachment.name,
                          style: text.labelSmall?.copyWith(
                            color: inkColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${attachment.kind.label} • ${NoteAttachmentValidator.formatBytes(attachment.sizeBytes)}',
                          style: text.labelSmall?.copyWith(color: subInkColor),
                        ),
                        IconButton(
                          key: Key('remove-attachment-${attachment.name}'),
                          tooltip: 'Remove attachment',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeAttachment(attachment),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: tokens.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAutosaveBadge(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.7);

    return Semantics(
      liveRegion: true,
      child: switch (_phase) {
        NoteAutosavePhase.idle => Text(
          widget.initialNote == null ? 'New note' : 'Saved locally',
          key: const Key('note-autosave-status'),
          style: text.labelMedium?.copyWith(
            color: subInkColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        NoteAutosavePhase.saving => Row(
          key: const Key('note-autosave-status'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Saving locally…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(color: subInkColor),
              ),
            ),
          ],
        ),
        NoteAutosavePhase.saved => Row(
          key: const Key('note-autosave-status'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_outlined, size: 16, color: tokens.success),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'Saved locally',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                  color: tokens.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        NoteAutosavePhase.error => Row(
          key: const Key('note-autosave-status'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: tokens.danger),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                _errorMessage ?? 'Save failed',
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: tokens.danger),
              ),
            ),
            TextButton(
              key: const Key('note-autosave-retry'),
              onPressed: () => _persistNow(isAutosave: false),
              child: const Text('Retry'),
            ),
          ],
        ),
      },
    );
  }

  Widget _buildColorPicker(BuildContext context, Color activeAccent) {
    final tokens = context.tokens;
    final text = context.text;
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.65);

    return Row(
      children: [
        Text(
          'Color',
          style: text.labelSmall?.copyWith(
            color: subInkColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: List<Widget>.generate(tokens.noteAccents.length, (index) {
              final pastelFill = tokens.noteCardFill(index);
              final selected = _colorIndex % tokens.noteAccents.length == index;
              final name = index < AppColors.noteAccentNames.length
                  ? AppColors.noteAccentNames[index]
                  : 'Color ${index + 1}';

              return Tooltip(
                message: name,
                child: InkWell(
                  key: Key('note-color-$index'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (_colorIndex == index) return;
                    setState(() => _colorIndex = index);
                    _markPendingAndScheduleAutosave();
                  },
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: pastelFill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? inkColor
                            : inkColor.withValues(alpha: 0.25),
                        width: selected ? 2.2 : 1,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: inkColor,
                          )
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
