import 'package:firebase_auth/firebase_auth.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'uid-A';
  @override
  String get email => 'a@example.test';
  @override
  String? displayName = 'Before';
  @override
  bool get emailVerified => true;
  @override
  String? get photoURL => 'https://avatar.example.test/a.png';
  int updates = 0;
  String? errorCode;
  @override
  Future<void> updateDisplayName(String? value) async {
    updates++;
    if (errorCode != null) {
      throw FirebaseAuthException(
        code: errorCode!,
        message: 'sensitive SDK detail',
      );
    }
    displayName = value;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  @override
  Stream<User?> userChanges() => Stream.value(currentUser);
}

void main() {
  late _User user;
  late _Auth auth;
  late FirebaseAuthRepository repository;
  setUp(() {
    user = _User();
    auth = _Auth()..currentUser = user;
    repository = FirebaseAuthRepository(auth);
  });
  test(
    'updates trimmed display name on current UID and maps profile photo',
    () async {
      await repository.updateDisplayName(
        expectedUid: 'uid-A',
        displayName: '  Tên mới  ',
      );
      expect(user.displayName, 'Tên mới');
      final snapshot = await repository.watchSession().first;
      expect(snapshot?.uid, 'uid-A');
      expect(snapshot?.displayName, 'Tên mới');
      expect(snapshot?.photoUrl, user.photoURL);
      expect(snapshot?.email, user.email);
      auth.currentUser = null;
      expect(await repository.watchSession().first, isNull);
    },
  );
  test('blank name is rejected even without the form', () async {
    await expectLater(
      repository.updateDisplayName(expectedUid: 'uid-A', displayName: '  '),
      throwsA(isA<AuthFailure>()),
    );
    expect(user.updates, 0);
  });
  test('wrong UID cannot update another account', () async {
    await expectLater(
      repository.updateDisplayName(expectedUid: 'uid-B', displayName: 'new'),
      throwsA(isA<AuthFailure>()),
    );
    expect(user.updates, 0);
  });
  test('SDK error is sanitized and the old name survives', () async {
    user.errorCode = 'network-request-failed';
    await expectLater(
      repository.updateDisplayName(expectedUid: 'uid-A', displayName: 'new'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'safe message',
          authErrorMessage('network-request-failed'),
        ),
      ),
    );
    expect(user.displayName, 'Before');
  });
}
