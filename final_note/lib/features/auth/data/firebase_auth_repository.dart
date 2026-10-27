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
  Future<void> signOut() => _translate(_auth.signOut);

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
