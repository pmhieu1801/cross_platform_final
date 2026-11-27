import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../theme/theme.dart';
import '../../../utils/validators.dart';
import '../../../widgets/widgets.dart';
import '../application/auth_providers.dart';
import '../application/change_password_controller.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authenticatedUidProvider) != widget.uid ||
        ref.read(changePasswordProvider).busy ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(changePasswordProvider.notifier)
          .submit(_current.text, _newPassword.text);
    } finally {
      // Keep credentials only in this form while needed by the current request.
      if (mounted) {
        _current.clear();
        _newPassword.clear();
        _confirmation.clear();
      }
    }
  }

  Widget _passwordField({
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    required bool enabled,
    bool confirmation = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      key: Key(fieldKey),
      controller: controller,
      enabled: enabled,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: confirmation ? (_) => _submit() : null,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authenticatedUidProvider) != widget.uid) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final state = ref.watch(changePasswordProvider);
    final enabled = !state.busy && !state.passwordChanged;
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: GlassPanel(
                    glowColor: context.colors.primary,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Change password',
                            style: context.text.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'After changing your password, sign in again with the new password.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (!state.passwordChanged) ...[
                            _passwordField(
                              fieldKey: 'change-current',
                              label: 'Current password',
                              controller: _current,
                              validator: Validators.requiredPassword,
                              enabled: enabled,
                            ),
                            _passwordField(
                              fieldKey: 'change-new',
                              label: 'New password',
                              controller: _newPassword,
                              validator: Validators.newPassword,
                              enabled: enabled,
                            ),
                            _passwordField(
                              fieldKey: 'change-confirm',
                              label: 'Confirm new password',
                              controller: _confirmation,
                              validator: Validators.confirmPassword(
                                () => _newPassword.text,
                              ),
                              enabled: enabled,
                              confirmation: true,
                            ),
                          ],
                          if (state.error != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(state.error!),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (state.phase == PasswordChangePhase.signOutFailed)
                            GradientButton(
                              key: const Key('change-retry-signout'),
                              label: 'Try signing out again',
                              onPressed: ref
                                  .read(changePasswordProvider.notifier)
                                  .retrySignOut,
                            )
                          else
                            GradientButton(
                              key: const Key('change-submit'),
                              label: state.passwordChanged
                                  ? 'Signing out…'
                                  : 'Change password',
                              loading: state.busy,
                              onPressed: enabled ? _submit : null,
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            key: const Key('change-back'),
                            onPressed: state.busy
                                ? null
                                : () => context.go(AppRoutes.home),
                            child: const Text('Back to notes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
