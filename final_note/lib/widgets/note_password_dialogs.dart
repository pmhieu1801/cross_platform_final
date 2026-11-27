import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/theme.dart';

/// Prompts the user to unlock a password-protected note before viewing,
/// editing, deleting, sharing, or summarizing it (R23, R24).
///
/// Returns `true` if the user entered the correct password.
Future<bool> showUnlockNoteDialog(
  BuildContext context, {
  required Note note,
  required Future<String?> Function(String password) onVerify,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _UnlockNoteDialog(note: note, onVerify: onVerify),
  );
  return result ?? false;
}

class _UnlockNoteDialog extends StatefulWidget {
  const _UnlockNoteDialog({required this.note, required this.onVerify});

  final Note note;
  final Future<String?> Function(String password) onVerify;

  @override
  State<_UnlockNoteDialog> createState() => _UnlockNoteDialogState();
}

class _UnlockNoteDialogState extends State<_UnlockNoteDialog> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final raw = _passwordController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter the note password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onVerify(raw);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return AlertDialog(
      key: const Key('unlock-note-dialog'),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Unlock protected note')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the password for "${widget.note.title}" to access its content.',
              style: text.bodySmall?.copyWith(color: tokens.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('unlock-note-password-input'),
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Note password',
                hintText: 'Enter password...',
                errorText: _error,
                prefixIcon: const Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('unlock-note-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('unlock-note-confirm'),
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: const Text('Unlock'),
        ),
      ],
    );
  }
}

/// Dialog to enable password protection on a note by entering the new password
/// twice for confirmation (R23).
Future<bool> showEnableNotePasswordDialog(
  BuildContext context, {
  required Future<String?> Function(String password, String confirmPassword)
  onEnable,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _EnableNotePasswordDialog(onEnable: onEnable),
  );
  return result ?? false;
}

class _EnableNotePasswordDialog extends StatefulWidget {
  const _EnableNotePasswordDialog({required this.onEnable});

  final Future<String?> Function(String password, String confirmPassword)
  onEnable;

  @override
  State<_EnableNotePasswordDialog> createState() =>
      _EnableNotePasswordDialogState();
}

class _EnableNotePasswordDialogState extends State<_EnableNotePasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onEnable(
      _passwordController.text,
      _confirmController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return AlertDialog(
      key: const Key('enable-note-password-dialog'),
      title: const Row(
        children: [
          Icon(Icons.enhanced_encryption_outlined, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Protect note with password')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set a dedicated password for this note. You will need it to view, edit, delete, share, or summarize this note.',
              style: text.bodySmall?.copyWith(color: tokens.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('enable-note-password-input'),
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'New note password',
                hintText: 'At least 4 characters',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('enable-note-password-confirm-input'),
              controller: _confirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm note password',
                hintText: 'Re-enter password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('enable-note-password-error'),
                  style: text.bodySmall?.copyWith(color: tokens.danger),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('enable-note-password-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('enable-note-password-submit'),
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: const Text('Enable protection'),
        ),
      ],
    );
  }
}

/// Dialog to manage an already password-protected note: change its password
/// (verifying current password + new password twice), disable protection
/// (verifying current password), or lock the note session immediately (R23, R24).
Future<void> showManageNotePasswordDialog(
  BuildContext context, {
  required Future<String?> Function(
    String currentPassword,
    String newPassword,
    String confirmNewPassword,
  )
  onChangePassword,
  required Future<String?> Function(String currentPassword) onDisablePassword,
  VoidCallback? onLockNow,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ManageNotePasswordDialog(
      onChangePassword: onChangePassword,
      onDisablePassword: onDisablePassword,
      onLockNow: onLockNow,
    ),
  );
}

enum _ManagePasswordMode { change, disable }

class _ManageNotePasswordDialog extends StatefulWidget {
  const _ManageNotePasswordDialog({
    required this.onChangePassword,
    required this.onDisablePassword,
    this.onLockNow,
  });

  final Future<String?> Function(
    String currentPassword,
    String newPassword,
    String confirmNewPassword,
  )
  onChangePassword;
  final Future<String?> Function(String currentPassword) onDisablePassword;
  final VoidCallback? onLockNow;

  @override
  State<_ManageNotePasswordDialog> createState() =>
      _ManageNotePasswordDialogState();
}

class _ManageNotePasswordDialogState extends State<_ManageNotePasswordDialog> {
  _ManagePasswordMode _mode = _ManagePasswordMode.change;
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final current = _currentController.text.trim();
    if (current.isEmpty) {
      setState(() => _error = 'Enter the current note password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = _mode == _ManagePasswordMode.change
        ? await widget.onChangePassword(
            current,
            _newController.text,
            _confirmController.text,
          )
        : await widget.onDisablePassword(current);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return AlertDialog(
      key: const Key('manage-note-password-dialog'),
      title: const Row(
        children: [
          Icon(Icons.lock_rounded, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Note password settings')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_ManagePasswordMode>(
                segments: const [
                  ButtonSegment(
                    value: _ManagePasswordMode.change,
                    label: Text('Change password'),
                    icon: Icon(Icons.password_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: _ManagePasswordMode.disable,
                    label: Text('Disable lock'),
                    icon: Icon(Icons.lock_open_rounded, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.first;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('manage-note-current-password-input'),
                controller: _currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current note password',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              if (_mode == _ManagePasswordMode.change) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('manage-note-new-password-input'),
                  controller: _newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New note password',
                    hintText: 'At least 4 characters',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('manage-note-confirm-password-input'),
                  controller: _confirmController,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('manage-note-password-error'),
                    style: text.bodySmall?.copyWith(color: tokens.danger),
                  ),
                ),
              ],
              if (widget.onLockNow != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('manage-note-lock-now-button'),
                  onPressed: _busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onLockNow!();
                        },
                  icon: const Icon(Icons.lock_clock_outlined, size: 18),
                  label: const Text('Lock note now'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('manage-note-password-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('manage-note-password-submit'),
          onPressed: _busy ? null : _submit,
          child: Text(
            _mode == _ManagePasswordMode.change
                ? 'Update password'
                : 'Disable protection',
          ),
        ),
      ],
    );
  }
}
