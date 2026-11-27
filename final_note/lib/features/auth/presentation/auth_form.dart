import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/register_screen.dart';
import '../../../theme/theme.dart';
import '../application/auth_providers.dart';
import '../application/change_password_controller.dart';

/// Connects the shared auth forms to Auth; always renders in crisp White/Light theme.
class AuthForm extends ConsumerWidget {
  const AuthForm({super.key, required this.register});
  final bool register;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionsProvider);
    final actions = ref.read(authActionsProvider.notifier);
    void navigate(String path) {
      if (ref.read(authActionsProvider).busy) return;
      actions.clearError();
      ref.read(changePasswordProvider.notifier).clearCompleted();
      context.go(path);
    }

    final screen = register
        ? RegisterScreen(
            isLoading: action.busy,
            error: action.error,
            onSubmit: actions.register,
            onSignIn: () => navigate(AppRoutes.login),
          )
        : LoginScreen(
            isLoading: action.busy,
            error: action.error,
            onSubmit: (email, password) {
              ref.read(changePasswordProvider.notifier).clearCompleted();
              return actions.signIn(email, password);
            },
            notice:
                ref.watch(changePasswordProvider).phase ==
                    PasswordChangePhase.completed
                ? 'Password changed. Sign in with your new password.'
                : null,
            onCreateAccount: () => navigate(AppRoutes.register),
            onForgotPassword: () => navigate(AppRoutes.forgotPassword),
          );

    return Theme(data: AppTheme.light, child: screen);
  }
}
