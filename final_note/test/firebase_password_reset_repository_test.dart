import 'package:firebase_auth/firebase_auth.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends Fake implements FirebaseAuth {
  String? requestedEmail;
  ActionCodeSettings? settings;
  String? failureCode;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    requestedEmail = email;
    settings = actionCodeSettings;
    final code = failureCode;
    if (code != null) {
      throw FirebaseAuthException(code: code, message: 'raw backend detail');
    }
  }
}

void main() {
  test(
    'requests Firebase hosted reset and treats unknown email like success',
    () async {
      final auth = _Auth();
      final repository = FirebaseAuthRepository(auth);
      await repository.requestPasswordReset('owner@example.test');
      expect(auth.requestedEmail, 'owner@example.test');
      expect(auth.settings, isNull);

      auth.failureCode = 'user-not-found';
      await repository.requestPasswordReset('unknown@example.test');
      expect(auth.requestedEmail, 'unknown@example.test');
    },
  );

  test('keeps request failures and omits raw SDK error details', () async {
    final auth = _Auth();
    final repository = FirebaseAuthRepository(auth);
    for (final code in [
      'network-request-failed',
      'too-many-requests',
      'invalid-email',
    ]) {
      auth.failureCode = code;
      await expectLater(
        repository.requestPasswordReset('owner@example.test'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            authErrorMessage(code),
          ),
        ),
      );
    }
  });
}
