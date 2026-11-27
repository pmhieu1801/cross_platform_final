import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../theme/theme.dart';
import '../../../utils/validators.dart';
import '../../../widgets/widgets.dart';
import '../application/password_reset_controller.dart';
import '../domain/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(passwordResetProvider.notifier).submit(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(passwordResetProvider);
    final busy = request?.isLoading ?? false;
    final error = request?.error as AuthFailure?;
    return Theme(
      data: AppTheme.light,
      child: Builder(
        builder: (context) => Scaffold(
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
                            const Center(child: BrandBadge()),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Reset your password',
                              style: context.text.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Enter your email to request a password reset link.',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.tokens.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              key: const Key('forgot-email'),
                              controller: _email,
                              enabled: !busy,
                              validator: Validators.email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              onChanged: (_) => ref
                                  .read(passwordResetProvider.notifier)
                                  .clearResult(),
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                hintText: 'you@example.com',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (error != null || request?.hasValue == true) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  error?.message ?? 'If an account exists for this email, check your inbox or spam for the link. After setting a new password, return here to sign in.',
                                  style: error == null
                                      ? context.text.bodyMedium
                                      : TextStyle(color: context.colors.error),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            GradientButton(
                              key: const Key('forgot-submit'),
                              label: 'Request reset link',
                              loading: busy,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              onPressed: () => context.go(AppRoutes.login),
                              child: const Text('Back to sign in'),
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
      ),
    );
  }
}
