class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
  });
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
}

abstract interface class AuthRepository {
  /// First event resolves persisted session; null means signed out.
  Stream<AuthUser?> watchSession();
  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  });
  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

String authErrorMessage(String code) => switch (code) {
  'invalid-email' => 'Email không hợp lệ.',
  'email-already-in-use' => 'Email này đã được đăng ký. Hãy đăng nhập.',
  'weak-password' || 'password-does-not-meet-requirements' =>
    'Mật khẩu chưa đáp ứng chính sách bảo mật của Firebase.',
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' => 'Email hoặc mật khẩu không đúng.',
  'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
  'network-request-failed' => 'Không kết nối được mạng. Hãy thử lại.',
  'too-many-requests' => 'Quá nhiều yêu cầu. Vui lòng thử lại sau.',
  'operation-not-allowed' =>
    'Email/Password chưa được bật trên Firebase. Liên hệ M1.',
  _ => 'Không thể hoàn tất xác thực. Vui lòng thử lại.',
};
