import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/auth_form.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/session_screen.dart';
import '../features/home/home_screen.dart';
import 'session_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authSessionProvider, (_, _) => refresh.notify());
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (_, state) => sessionRedirect(
      sessionPhase(ref.read(authSessionProvider)),
      state.uri.path,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SessionScreen()),
      GoRoute(
        path: AppRoutes.session,
        builder: (_, _) => const SessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const AuthForm(register: false),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const AuthForm(register: true),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => Consumer(
          builder: (context, ref, child) =>
              sessionPhase(ref.watch(authSessionProvider)) ==
                  SessionPhase.signedOut
              ? const ForgotPasswordScreen()
              : const SessionScreen(),
        ),
      ),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, _) => Consumer(
          builder: (context, ref, child) {
            final uid = ref.watch(authenticatedUidProvider);
            return uid == null
                ? const SessionScreen()
                : ChangePasswordScreen(key: ValueKey(uid), uid: uid);
          },
        ),
      ),
    ],
    errorBuilder: (_, _) =>
        const Scaffold(body: Center(child: Text('Không tìm thấy trang.'))),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
