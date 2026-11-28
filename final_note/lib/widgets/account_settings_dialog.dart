import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../theme/theme.dart';
import '../utils/validators.dart';
import 'password_strength_bar.dart';

/// Formal account settings dialog opened from the sidebar profile section.
/// Allows viewing account identity, updating profile/email/avatar, changing password,
/// and signing out.
class AccountSettingsDialog extends StatefulWidget {
  const AccountSettingsDialog({
    super.key,
    required this.user,
    this.avatarBytes,
    this.onPickAvatar,
    this.onRemoveAvatar,
    this.authBusy = false,
    this.onLogout,
    this.onUpdateProfile,
    this.onChangePassword,
  });

  final AuthUser? user;
  final Uint8List? avatarBytes;
  final Future<String?> Function(Uint8List bytes)? onPickAvatar;
  final Future<String?> Function()? onRemoveAvatar;
  final bool authBusy;
  final VoidCallback? onLogout;
  final Future<String?> Function(String displayName, String email)?
  onUpdateProfile;
  final Future<String?> Function(String currentPassword, String newPassword)?
  onChangePassword;

  @override
  State<AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<AccountSettingsDialog> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _selectedTab = 0; // 0: Profile & Email, 1: Security / Password
  bool _saving = false;
  bool _avatarBusy = false;
  String? _statusMessage;
  bool _isError = false;
  PasswordStrength _strength = PasswordStrength.empty;
  late Uint8List? _localAvatarBytes = widget.avatarBytes;

  Future<void> _handlePickAvatar() async {
    if (widget.onPickAvatar == null || _avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
      );
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      final error = await widget.onPickAvatar!(bytes);
      if (!mounted) return;
      setState(() {
        _isError = error != null;
        if (error == null) {
          _localAvatarBytes = bytes;
        }
        _statusMessage = error ?? 'Đã cập nhật ảnh đại diện.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _statusMessage = 'Không thể mở tệp ảnh. Hãy thử lại.';
      });
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _handleRemoveAvatar() async {
    final remove = widget.onRemoveAvatar;
    if (remove == null || _avatarBusy) return;
    setState(() => _avatarBusy = true);
    String? error;
    try {
      error = await remove();
    } catch (_) {
      error = 'Không thể xóa ảnh đại diện. Hãy thử lại.';
    }
    if (!mounted) return;
    setState(() {
      _avatarBusy = false;
      _isError = error != null;
      if (error == null) _localAvatarBytes = null;
      _statusMessage = error ?? 'Đã khôi phục ảnh đại diện mặc định.';
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user?.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _newPasswordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _strength = evaluatePasswordStrength(_newPasswordController.text);
    });
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (_saving || !_profileFormKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _statusMessage = null;
      _isError = false;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (widget.onUpdateProfile != null) {
      final error = await widget.onUpdateProfile!(name, email);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _isError = error != null;
        _statusMessage = error ?? 'Đã cập nhật thông tin hồ sơ.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _isError = false;
      _statusMessage = 'Đã lưu yêu cầu cập nhật hồ sơ ($name • $email).';
    });
  }

  Future<void> _submitPassword() async {
    if (_saving || !_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _statusMessage = null;
      _isError = false;
    });

    final currentPwd = _currentPasswordController.text;
    final newPwd = _newPasswordController.text;

    if (widget.onChangePassword != null) {
      final error = await widget.onChangePassword!(currentPwd, newPwd);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _isError = error != null;
        _statusMessage = error ?? 'Đã đổi mật khẩu thành công.';
      });
      if (error == null) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _isError = false;
      _statusMessage = 'Đã ghi nhận yêu cầu đổi mật khẩu.';
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tokens = context.tokens;
    final user = widget.user;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colors.primaryContainer,
                    backgroundImage: _localAvatarBytes != null
                        ? MemoryImage(_localAvatarBytes!)
                        : null,
                    child: _localAvatarBytes == null
                        ? Icon(
                            Icons.person_outline_rounded,
                            color: colors.onPrimaryContainer,
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? user?.email ?? 'Tài khoản',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (user != null)
                          SelectableText(
                            'UID: ${user.uid}',
                            style: text.labelSmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        if (widget.onPickAvatar != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              TextButton.icon(
                                key: const Key('account-dialog-change-avatar'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(0, 28),
                                ),
                                onPressed: _avatarBusy ? null : _handlePickAvatar,
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 15,
                                ),
                                label: const Text('Đổi ảnh đại diện'),
                              ),
                              if (_localAvatarBytes != null &&
                                  widget.onRemoveAvatar != null)
                                TextButton(
                                  key: const Key('account-dialog-reset-avatar'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    minimumSize: const Size(0, 28),
                                  ),
                                  onPressed: _avatarBusy
                                      ? null
                                      : _handleRemoveAvatar,
                                  child: const Text('Xoá ảnh'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('account-dialog-close'),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.badge_outlined, size: 18),
                    label: Text('Hồ sơ & Email'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.lock_outline_rounded, size: 18),
                    label: Text('Đổi mật khẩu'),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedTab = selection.first;
                    _statusMessage = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: (_isError ? tokens.danger : tokens.success)
                        .withValues(alpha: 0.1),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: (_isError ? tokens.danger : tokens.success)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: text.bodySmall?.copyWith(
                      color: _isError ? tokens.danger : tokens.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_selectedTab == 0)
                _buildProfileForm(context)
              else
                _buildPasswordForm(context),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Phiên đăng nhập hiện tại',
                    style: text.bodySmall?.copyWith(color: tokens.textMuted),
                  ),
                  if (widget.onLogout != null)
                    OutlinedButton.icon(
                      key: const Key('account-dialog-logout-button'),
                      onPressed: widget.authBusy
                          ? null
                          : () {
                              Navigator.of(context).maybePop();
                              widget.onLogout!();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(
                          color: colors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: Text(
                        widget.authBusy ? 'Đang xử lý…' : 'Đăng xuất',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context) {
    final text = context.text;

    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tên hiển thị',
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: const Key('account-display-name-input'),
            controller: _nameController,
            enabled: !_saving,
            decoration: const InputDecoration(
              hintText: 'Nhập tên hiển thị',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: Validators.displayName,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Địa chỉ Email',
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: const Key('account-email-input'),
            controller: _emailController,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('account-save-profile-button'),
            onPressed: _saving ? null : _submitProfile,
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm(BuildContext context) {
    final text = context.text;

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mật khẩu hiện tại',
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: const Key('account-current-password-input'),
            controller: _currentPasswordController,
            enabled: !_saving,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Nhập mật khẩu hiện tại',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: Validators.requiredPassword,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Mật khẩu mới',
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: const Key('account-new-password-input'),
            controller: _newPasswordController,
            enabled: !_saving,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Tối thiểu 8 ký tự',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            validator: Validators.newPassword,
          ),
          PasswordStrengthBar(strength: _strength),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Xác nhận mật khẩu mới',
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: const Key('account-confirm-password-input'),
            controller: _confirmPasswordController,
            enabled: !_saving,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Nhập lại mật khẩu mới',
              prefixIcon: Icon(Icons.check_circle_outline_rounded),
            ),
            validator: Validators.confirmPassword(
              () => _newPasswordController.text,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('account-update-password-button'),
            onPressed: _saving ? null : _submitPassword,
            child: const Text('Cập nhật mật khẩu'),
          ),
        ],
      ),
    );
  }
}
