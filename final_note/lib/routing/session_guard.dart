import '../features/auth/application/auth_providers.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const session = '/session';
  static const home = '/home';
}

/// Explicit public allowlist; new feature routes are protected by default.
String? sessionRedirect(SessionPhase phase, String path) {
  if (phase == SessionPhase.checking || phase == SessionPhase.unavailable) {
    return path == AppRoutes.session ? null : AppRoutes.session;
  }
  final public = path == AppRoutes.login || path == AppRoutes.register;
  if (phase == SessionPhase.signedOut) return public ? null : AppRoutes.login;
  if (public || path == AppRoutes.session || path == '/') return AppRoutes.home;
  return null;
}
