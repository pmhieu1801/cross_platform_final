import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/register_screen.dart';
import '../application/auth_providers.dart';

/// Connects the shared Midnight Glow forms to Auth; widgets own only input/UI.
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
      context.go(path);
    }

    if (register) {
      return RegisterScreen(
        isLoading: action.busy,
        error: action.error,
        onSubmit: actions.register,
        onSignIn: () => navigate(AppRoutes.login),
      );
    }
    return LoginScreen(
      isLoading: action.busy,
      error: action.error,
      onSubmit: actions.signIn,
      onCreateAccount: () => navigate(AppRoutes.register),
    );
  }
}
