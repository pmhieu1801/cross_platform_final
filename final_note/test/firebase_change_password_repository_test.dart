import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  _User(this.uid, this.email);
  @override
  final String uid;
  @override
  final String? email;
  final calls = <String>[];
  AuthCredential? receivedCredential;
  String? updatedPassword;
  Completer<void>? reauthPending;
  String? reauthError;
  String? updateError;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    calls.add('reauthenticate');
    receivedCredential = credential;
    if (reauthPending != null) await reauthPending!.future;
    if (reauthError != null) {
      throw FirebaseAuthException(
        code: reauthError!,
        message: 'sensitive SDK detail',
      );
    }
    return _Credential();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('update');
    if (updateError != null) {
      throw FirebaseAuthException(
        code: updateError!,
        message: 'sensitive SDK detail',
      );
    }
    updatedPassword = newPassword;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }
}

void main() {
  late _User user;
  late _Auth auth;
  late FirebaseAuthRepository repository;
  setUp(() {
    user = _User('uid-A', 'owner@example.test');
    auth = _Auth()..currentUser = user;
    repository = FirebaseAuthRepository(auth);
  });

  Future<void> change() => repository.changePassword(
    expectedUid: 'uid-A',
    currentPassword: ' current test value ',
    newPassword: ' new test value ',
  );

  test(
    'reauthenticates before updating and forwards passwords without trimming',
    () async {
      await change();
      final credential = user.receivedCredential as EmailAuthCredential;
      expect(credential.email, user.email);
      expect(credential.password == ' current test value ', isTrue);
      expect(user.updatedPassword == ' new test value ', isTrue);
      expect(user.calls, ['reauthenticate', 'update']);
      expect(auth.currentUser, same(user));
      expect(auth.signOutCalls, 0);
    },
  );

  for (final code in [
    'wrong-password',
    'invalid-credential',
    'network-request-failed',
  ]) {
    test('$code during reauthentication never updates password', () async {
      user.reauthError = code;
      await expectLater(
        change(),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'safe message',
            code == 'network-request-failed'
                ? authErrorMessage(code)
                : 'Mật khẩu hiện tại không đúng.',
          ),
        ),
      );
      expect(user.calls, ['reauthenticate']);
      expect(user.updatedPassword, isNull);
      expect(auth.currentUser, same(user));
    });
  }

  test(
    'update policy failure preserves session and surfaces a safe error',
    () async {
      user.updateError = 'weak-password';
      await expectLater(
        change(),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            authErrorMessage('weak-password'),
          ),
        ),
      );
      expect(user.updatedPassword, isNull);
      expect(auth.currentUser, same(user));
      expect(auth.signOutCalls, 0);
    },
  );

  test(
    'A to B during reauthentication prevents update and sign-out of B',
    () async {
      user.reauthPending = Completer<void>();
      final pending = change();
      await Future<void>.delayed(Duration.zero);
      final other = _User('uid-B', 'other@example.test');
      auth.currentUser = other;
      user.reauthPending!.complete();
      await expectLater(pending, throwsA(isA<AuthFailure>()));
      expect(user.calls, ['reauthenticate']);
      expect(other.calls, isEmpty);
      await expectLater(
        repository.signOut(expectedUid: 'uid-A'),
        throwsA(isA<AuthFailure>()),
      );
      expect(auth.signOutCalls, 0);
      expect(auth.currentUser, same(other));
    },
  );

  test('missing email cannot create a reauthentication credential', () async {
    final noEmail = _User('uid-A', null);
    auth.currentUser = noEmail;
    await expectLater(change(), throwsA(isA<AuthFailure>()));
    expect(noEmail.calls, isEmpty);
  });

  test(
    'scoped and existing unscoped sign-out callers remain supported',
    () async {
      await repository.signOut(expectedUid: 'uid-A');
      expect(auth.currentUser, isNull);
      auth.currentUser = user;
      await repository.signOut();
      expect(auth.signOutCalls, 2);
    },
  );
}
