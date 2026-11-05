import 'dart:async';

import 'package:flutter/material.dart';

import '../features/notes/application/note_providers.dart';
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
    this.debounceDuration = const Duration(milliseconds: 400),
    this.embedded = false,
  });

  /// `null` when creating a new note; non-null when editing an existing note.
  final Note? initialNote;

  /// All known labels for this account so the user can toggle them on/off.
  final List<String> availableLabels;

  /// Persists the note and returns the saved [Note] (or throws / returns `null`
  /// on failure).
  final Future<Note?> Function(Note draft, {required bool isAutosave}) onSave;

  /// Optional delete callback for existing notes.
  final Future<bool> Function(Note note)? onDelete;

  /// Called when the user closes the editor.
  final VoidCallback? onClose;

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
  late List<String> _labels;
  late List<String> _catalogLabels;

  Timer? _debounceTimer;
  bool _dirty = false;
  bool _hasEverSaved = false;
  NoteAutosavePhase _phase = NoteAutosavePhase.idle;
  String? _errorMessage;
  Note? _lastSavedSnapshot;

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
    _labels = List<String>.of(initial?.labels ?? const <String>[]);
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
      _contentController.text.trim().isNotEmpty;

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
    if (previous.labels.length != _labels.length) return true;
    for (var i = 0; i < _labels.length; i++) {
      if (previous.labels[i] != _labels[i]) return true;
    }
    return false;
  }

  void _onFieldEdited() {
    if (!_differsFromLastSaved()) return;
    _dirty = true;
    _scheduleAutosave();
  }

  void _toggleLabel(String label) {
    setState(() {
      if (_labels.contains(label)) {
        _labels.remove(label);
      } else {
        _labels.add(label);
      }
    });
    _dirty = true;
    _scheduleAutosave();
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
    _dirty = true;
    if (scheduleSave) {
      _scheduleAutosave();
    }
  }

  void _addCustomLabel() {
    _commitPendingLabelInput(scheduleSave: true);
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
            _errorMessage = 'Could not save changes. Tap retry.';
          });
        }
        return false;
      }
      _hasEverSaved = true;
      _lastSavedSnapshot = saved;
      _dirty = _differsFromLastSaved();
      if (mounted) {
        setState(() {
          _phase = NoteAutosavePhase.saved;
          _errorMessage = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = NoteAutosavePhase.error;
          _errorMessage = 'Could not save changes. Tap retry.';
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
              Expanded(child: _buildAutosaveBadge(context)),
              IconButton(
                key: const Key('note-editor-pin'),
                tooltip: _isPinned ? 'Unpin note' : 'Pin note',
                onPressed: () {
                  setState(() {
                    _isPinned = !_isPinned;
                    _pinnedAt = _isPinned ? DateTime.now() : null;
                  });
                  _dirty = true;
                  _scheduleAutosave();
                },
                icon: Icon(
                  _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: _isPinned ? inkColor : subInkColor,
                ),
              ),
              if ((_hasEverSaved || widget.initialNote != null) &&
                  widget.onDelete != null)
                IconButton(
                  key: const Key('note-editor-delete'),
                  tooltip: 'Delete note',
                  onPressed: _handleDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('note-title-input'),
            controller: _titleController,
            textInputAction: TextInputAction.next,
            style: text.headlineSmall?.copyWith(
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
                maxLines: null,
                minLines: 5,
                keyboardType: TextInputType.multiline,
                style: text.bodyLarge?.copyWith(color: inkColor, height: 1.55),
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
          const SizedBox(height: AppSpacing.md),
          _buildLabelsSection(context, accent),
          const SizedBox(height: AppSpacing.md),
          _buildColorPicker(context, accent),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _handleClose,
                style: TextButton.styleFrom(foregroundColor: inkColor),
                child: const Text('Done'),
              ),
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
          ),
        ],
      ),
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

  Widget _buildAutosaveBadge(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.7);

    return Semantics(
      liveRegion: true,
      child: switch (_phase) {
        NoteAutosavePhase.idle => Text(
          widget.initialNote == null ? 'New note' : 'Saved',
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
            Text(
              'Saving…',
              style: text.labelMedium?.copyWith(color: subInkColor),
            ),
          ],
        ),
        NoteAutosavePhase.saved => Row(
          key: const Key('note-autosave-status'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined, size: 16, color: tokens.success),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Saved',
              style: text.labelMedium?.copyWith(
                color: tokens.success,
                fontWeight: FontWeight.w700,
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
                    _dirty = true;
                    _scheduleAutosave();
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
