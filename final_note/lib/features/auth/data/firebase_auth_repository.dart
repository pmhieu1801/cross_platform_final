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
            photoUrl: user.photoURL,
          ),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _translate(
      () => _auth.signInWithEmailAndPassword(email: email, password: password),
    );
  }

  @override
  Future<RegistrationResult> register({
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
    final warnings = <String>[];
    var verificationSent = false;
    // These steps are not a transaction. Still attempt email if updating the name fails.
    try {
      _requireUser(user.uid);
      await _translate(() => user.updateDisplayName(displayName));
    } catch (_) {
      warnings.add('Chưa cập nhật được tên.');
    }
    try {
      await sendVerificationEmail(user.uid);
      verificationSent = true;
    } on AuthFailure catch (error) {
      warnings.add(
        'Chưa gửi được email xác minh. ${error.message} Có thể gửi lại.',
      );
    } catch (_) {
      warnings.add('Chưa gửi được email xác minh. Có thể gửi lại.');
    }
    return RegistrationResult(
      uid: user.uid,
      verificationSent: verificationSent,
      warning: warnings.isEmpty
          ? null
          : 'Tài khoản đã được tạo và đăng nhập. Không đăng ký lại. '
                '${warnings.join(' ')}',
    );
  }

  @override
  Future<void> signOut({String? expectedUid}) => _translate(() async {
    if (expectedUid != null) _requireUser(expectedUid);
    await _auth.signOut();
  });

  @override
  Future<void> changePassword({
    required String expectedUid,
    required String currentPassword,
    required String newPassword,
  }) => _translate(() async {
    final user = _requireUser(expectedUid);
    final email = user.email;
    if (email == null) {
      throw const AuthFailure('Phiên tài khoản không có email đăng nhập.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        throw const AuthFailure('Mật khẩu hiện tại không đúng.');
      }
      rethrow;
    }
    // Reauthentication can finish after the app has switched to another account.
    _requireUser(expectedUid);
    await user.updatePassword(newPassword);
  });

  @override
  Future<void> requestPasswordReset(String email) => _translate(() async {
    try {
      // Firebase's hosted page consumes the one-time code and sets the password.
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // Older projects can disclose a missing user. Match the protected Firebase
      // response for this case and surface all other failures.
      if (error.code != 'user-not-found') rethrow;
    }
  });

  @override
  Future<void> updateDisplayName({
    required String expectedUid,
    required String displayName,
  }) => _translate(() async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const AuthFailure('Tên hiển thị không được để trống.');
    }
    final user = _requireUser(expectedUid);
    await user.updateDisplayName(name);
    // userChanges publishes the updated SDK profile; do not synthesize a session.
  });

  User _requireUser(String expectedUid) {
    final user = _auth.currentUser;
    if (user == null || user.uid != expectedUid) {
      throw const AuthFailure('Phiên tài khoản đã thay đổi. Hãy thử lại.');
    }
    return user;
  }

  @override
  Future<void> sendVerificationEmail(String expectedUid) =>
      _translate(() async {
        final user = _requireUser(expectedUid);
        if (user.emailVerified) return;
        // No continue URL/custom handler: Firebase's hosted HTTPS page handles the link
        // in a browser on Web/Android. Never expose the action code to application state.
        await user.sendEmailVerification();
      });

  @override
  Future<void> refreshCurrentUser(String expectedUid) => _translate(() async {
    final user = _requireUser(expectedUid);
    await user.reload();
    // userChanges publishes the SDK snapshot; the controller never sets verified.
  });

  Future<T> _translate<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(authErrorMessage(error.code));
    }
  }
}
