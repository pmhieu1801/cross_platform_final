import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/auth_form.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/session_screen.dart';
import '../features/home/home_screen.dart';
import '../features/preferences/presentation/preferences_screen.dart';
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
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => _smoothPage(state, const SessionScreen()),
      ),
      GoRoute(
        path: AppRoutes.session,
        pageBuilder: (_, state) => _smoothPage(state, const SessionScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) =>
            _smoothPage(state, const AuthForm(register: false)),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (_, state) =>
            _smoothPage(state, const AuthForm(register: true)),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (_, state) => _smoothPage(
          state,
          Consumer(
            builder: (context, ref, child) =>
                sessionPhase(ref.watch(authSessionProvider)) ==
                    SessionPhase.signedOut
                ? const ForgotPasswordScreen()
                : const SessionScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (_, state) => _smoothPage(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.preferences,
        pageBuilder: (_, state) => _smoothPage(
          state,
          Consumer(
            builder: (context, ref, child) {
              final uid = ref.watch(authenticatedUidProvider);
              return uid == null
                  ? const SessionScreen()
                  : PreferencesScreen(key: ValueKey(uid), uid: uid);
            },
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, state) => _smoothPage(
          state,
          Consumer(
            builder: (context, ref, child) {
              final uid = ref.watch(authenticatedUidProvider);
              return uid == null
                  ? const SessionScreen()
                  : ProfileScreen(key: ValueKey(uid), uid: uid);
            },
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        pageBuilder: (_, state) => _smoothPage(
          state,
          Consumer(
            builder: (context, ref, child) {
              final uid = ref.watch(authenticatedUidProvider);
              return uid == null
                  ? const SessionScreen()
                  : ChangePasswordScreen(key: ValueKey(uid), uid: uid);
            },
          ),
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

CustomTransitionPage<void> _smoothPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0.015, 0),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
