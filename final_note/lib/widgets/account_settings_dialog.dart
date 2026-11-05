import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../theme/theme.dart';
import '../utils/validators.dart';
import 'password_strength_bar.dart';

/// Formal account settings dialog opened from the sidebar profile section.
/// Allows viewing account identity, updating profile/email, changing password,
/// and signing out.
class AccountSettingsDialog extends StatefulWidget {
  const AccountSettingsDialog({
    super.key,
    required this.user,
    this.authBusy = false,
    this.onLogout,
    this.onUpdateProfile,
    this.onChangePassword,
  });

  final AuthUser? user;
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
  String? _statusMessage;
  bool _isError = false;
  PasswordStrength _strength = PasswordStrength.empty;

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
                    radius: 22,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: colors.onPrimaryContainer,
                      size: 22,
                    ),
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
