import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> watchSession() => _auth.userChanges().map(
    (user) => user == null
        ? null
        : AuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            emailVerified: user.emailVerified,
          ),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _translate(
      () => _auth.signInWithEmailAndPassword(email: email, password: password),
    );
  }

  @override
  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final credential = await _translate(
      () => _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthFailure('Firebase chưa trả về phiên tài khoản mới.');
    }
    // Account creation already signs in. Do not imply it failed if profile update fails.
    try {
      await _translate(() => user.updateDisplayName(displayName));
    } on AuthFailure {
      throw const AuthFailure(
        'Tài khoản đã được tạo và đăng nhập, nhưng chưa cập nhật được tên. '
        'Không đăng ký lại; kiểm tra mạng và liên hệ M1.',
      );
    }
    // Activation sending/handling is W2; W1 exposes emailVerified and a banner.
  }

  @override
  Future<void> signOut() => _translate(_auth.signOut);

  Future<T> _translate<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(authErrorMessage(error.code));
    }
  }
}
