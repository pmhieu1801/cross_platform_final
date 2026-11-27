import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/theme.dart';

/// Dialog allowing the note owner to share a note with one or more registered
/// accounts by email address, assign or modify Read-only / Editable permissions,
/// and revoke access at any time (R25, R26).
Future<void> showNoteShareDialog(
  BuildContext context, {
  required Note note,
  required Future<({Note? note, String? error})> Function(
    String recipientEmail,
    NoteSharePermission permission,
  )
  onAddShare,
  required Future<({Note? note, String? error})> Function(
    String recipientEmail,
    NoteSharePermission permission,
  )
  onUpdatePermission,
  required Future<({Note? note, String? error})> Function(String recipientEmail)
  onRevokeShare,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _NoteShareDialog(
      initialNote: note,
      onAddShare: onAddShare,
      onUpdatePermission: onUpdatePermission,
      onRevokeShare: onRevokeShare,
    ),
  );
}

class _NoteShareDialog extends StatefulWidget {
  const _NoteShareDialog({
    required this.initialNote,
    required this.onAddShare,
    required this.onUpdatePermission,
    required this.onRevokeShare,
  });

  final Note initialNote;
  final Future<({Note? note, String? error})> Function(
    String recipientEmail,
    NoteSharePermission permission,
  )
  onAddShare;
  final Future<({Note? note, String? error})> Function(
    String recipientEmail,
    NoteSharePermission permission,
  )
  onUpdatePermission;
  final Future<({Note? note, String? error})> Function(String recipientEmail)
  onRevokeShare;

  @override
  State<_NoteShareDialog> createState() => _NoteShareDialogState();
}

class _NoteShareDialogState extends State<_NoteShareDialog> {
  final _emailController = TextEditingController();
  NoteSharePermission _newPermission = NoteSharePermission.readOnly;
  late List<NoteShareEntry> _shares;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shares = List<NoteShareEntry>.of(widget.initialNote.shares);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (_busy) return;
    final rawEmail = _emailController.text.trim();
    if (rawEmail.isEmpty) {
      setState(() => _error = 'Recipient email address cannot be empty.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.onAddShare(rawEmail, _newPermission);
    if (!mounted) return;
    if (res.error != null || res.note == null) {
      setState(() {
        _busy = false;
        _error = res.error ?? 'Could not share note.';
      });
      return;
    }
    setState(() {
      _busy = false;
      _error = null;
      _shares = List<NoteShareEntry>.of(res.note!.shares);
      _emailController.clear();
    });
  }

  Future<void> _handleUpdatePermission(
    NoteShareEntry entry,
    NoteSharePermission nextPermission,
  ) async {
    if (_busy || entry.permission == nextPermission) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.onUpdatePermission(
      entry.normalizedRecipientEmail,
      nextPermission,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.note != null) {
        _shares = List<NoteShareEntry>.of(res.note!.shares);
      } else {
        _error = res.error ?? 'Could not update share permission.';
      }
    });
  }

  Future<void> _handleRevoke(NoteShareEntry entry) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.onRevokeShare(entry.normalizedRecipientEmail);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.note != null) {
        _shares = List<NoteShareEntry>.of(res.note!.shares);
      } else {
        _error = res.error ?? 'Could not revoke share access.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final colors = context.colors;

    return AlertDialog(
      key: const Key('note-share-dialog'),
      title: Row(
        children: [
          const Icon(Icons.people_alt_outlined, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Share "${widget.initialNote.title}"',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite registered accounts by email and assign Read-only or Editable access.',
                style: text.bodySmall?.copyWith(color: tokens.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('share-recipient-email-input'),
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleAdd(),
                decoration: const InputDecoration(
                  labelText: 'Recipient email address',
                  hintText: 'teammate@example.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<NoteSharePermission>(
                    segments: const [
                      ButtonSegment(
                        value: NoteSharePermission.readOnly,
                        label: Text('Read-only'),
                        icon: Icon(Icons.visibility_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: NoteSharePermission.edit,
                        label: Text('Editable'),
                        icon: Icon(Icons.edit_outlined, size: 16),
                      ),
                    ],
                    selected: {_newPermission},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) {
                            setState(() => _newPermission = selection.first);
                          },
                  ),
                  FilledButton.icon(
                    key: const Key('share-note-add-button'),
                    onPressed: _busy ? null : _handleAdd,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: const Text('Share'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('share-note-error'),
                    style: text.bodySmall?.copyWith(color: tokens.danger),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'SHARED WITH (${_shares.length})',
                style: text.labelSmall?.copyWith(
                  color: tokens.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_shares.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: tokens.glassBorder),
                  ),
                  child: Text(
                    'Not shared with anyone yet.',
                    style: text.bodySmall?.copyWith(color: tokens.textMuted),
                  ),
                )
              else
                for (final entry in _shares)
                  Container(
                    key: Key('share-entry-${entry.normalizedRecipientEmail}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: tokens.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.normalizedRecipientEmail,
                                style: text.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Shared ${_formatShareTimestamp(entry.sharedAt)}',
                                style: text.labelSmall?.copyWith(
                                  color: tokens.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<NoteSharePermission>(
                          key: Key(
                            'share-permission-dropdown-${entry.normalizedRecipientEmail}',
                          ),
                          value: entry.permission,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: NoteSharePermission.values
                              .map(
                                (perm) => DropdownMenuItem(
                                  value: perm,
                                  child: Text(
                                    perm.label,
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (next) {
                                  if (next != null) {
                                    _handleUpdatePermission(entry, next);
                                  }
                                },
                        ),
                        IconButton(
                          key: Key(
                            'share-revoke-button-${entry.normalizedRecipientEmail}',
                          ),
                          tooltip: 'Revoke access',
                          visualDensity: VisualDensity.compact,
                          onPressed: _busy ? null : () => _handleRevoke(entry),
                          icon: Icon(
                            Icons.person_remove_outlined,
                            size: 18,
                            color: tokens.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('share-dialog-close'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

String _formatShareTimestamp(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
