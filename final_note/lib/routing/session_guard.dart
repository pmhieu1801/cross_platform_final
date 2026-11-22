import '../features/auth/application/auth_providers.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const changePassword = '/change-password';
  static const profile = '/profile';
  static const session = '/session';
  static const home = '/home';
}

/// Explicit public allowlist; new feature routes are protected by default.
String? sessionRedirect(SessionPhase phase, String path) {
  if (phase == SessionPhase.checking || phase == SessionPhase.unavailable) {
    // The forgot route renders SessionScreen while resolving the SDK session.
    // Keeping its URL here preserves a direct link opened on a cold start.
    return path == AppRoutes.session || path == AppRoutes.forgotPassword
        ? null
        : AppRoutes.session;
  }
  final public =
      path == AppRoutes.login ||
      path == AppRoutes.register ||
      path == AppRoutes.forgotPassword;
  if (phase == SessionPhase.signedOut) return public ? null : AppRoutes.login;
  if (public || path == AppRoutes.session || path == '/') return AppRoutes.home;
  return null;
}
