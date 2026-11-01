import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);
  @override
  final User user;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String get email => 'test@example.test';
  @override
  String? displayName;
  @override
  bool emailVerified = false;
  FirebaseAuthException? nameError;
  FirebaseAuthException? mailError;
  Completer<void>? namePending;
  int mailCalls = 0;
  int reloadCalls = 0;
  ActionCodeSettings? settings;
  @override
  Future<void> updateDisplayName(String? value) async {
    if (namePending != null) await namePending!.future;
    if (nameError != null) throw nameError!;
    displayName = value;
  }

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    mailCalls++;
    settings = actionCodeSettings;
    if (mailError != null) throw mailError!;
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.createdUser);
  final _User createdUser;
  @override
  User? currentUser;
  FirebaseAuthException? createError;
  int createCalls = 0;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createCalls++;
    if (createError != null) throw createError!;
    currentUser = createdUser;
    return _Credential(createdUser);
  }
}

void main() {
  late _User user;
  late _Auth auth;
  late FirebaseAuthRepository repository;
  setUp(() {
    user = _User('created-uid');
    auth = _Auth(user);
    repository = FirebaseAuthRepository(auth);
  });
  Future<RegistrationResult> register() => repository.register(
    email: 'test@example.test',
    displayName: 'Test',
    password: 'test-only',
  );

  test('creates session, updates name, requests hosted verification without continue URL', () async {
    final result = await register();
    expect(result.uid, user.uid);
    expect(result.verificationSent, isTrue);
    expect(result.warning, isNull);
    expect(auth.currentUser, same(user));
    expect(user.displayName, 'Test');
    expect(user.mailCalls, 1);
    expect(user.settings, isNull);
    expect(user.emailVerified, isFalse);
  });
  test(
    'mail failure is a partial result and account/session remain usable',
    () async {
      user.mailError = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'RAW-SENSITIVE',
      );
      final result = await register();
      expect(result.verificationSent, isFalse);
      expect(result.warning, contains('Không đăng ký lại'));
      expect(result.warning, contains('mạng'));
      expect(result.warning, isNot(contains('RAW-SENSITIVE')));
      expect(auth.currentUser, same(user));
      user.mailError = null;
      await repository.sendVerificationEmail(user.uid);
      expect(user.mailCalls, 2);
      expect(auth.createCalls, 1);
    },
  );
  test('failed name update still sends verification and reports partial completion', () async {
    user.nameError = FirebaseAuthException(code: 'network-request-failed');
    final result = await register();
    expect(result.verificationSent, isTrue);
    expect(result.warning, contains('Chưa cập nhật được tên'));
    expect(user.mailCalls, 1);
  });
  test('failed creation never attempts follow-up email', () async {
    auth.createError = FirebaseAuthException(code: 'email-already-in-use');
    await expectLater(register(), throwsA(isA<AuthFailure>()));
    expect(user.mailCalls, 0);
    expect(auth.currentUser, isNull);
  });
  test(
    'account switch while updating name never sends verification for B',
    () async {
      user.namePending = Completer<void>();
      final pending = register();
      await Future<void>.delayed(Duration.zero);
      final other = _User('other-uid');
      auth.currentUser = other;
      user.namePending!.complete();
      final result = await pending;
      expect(result.verificationSent, isFalse);
      expect(user.mailCalls, 0);
      expect(other.mailCalls, 0);
    },
  );
  test('explicit resend/reload require exact SDK UID and reload never fabricates verified', () async {
    auth.currentUser = user;
    await expectLater(
      repository.sendVerificationEmail('other-uid'),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      repository.refreshCurrentUser('other-uid'),
      throwsA(isA<AuthFailure>()),
    );
    expect(user.mailCalls, 0);
    expect(user.reloadCalls, 0);
    await repository.refreshCurrentUser(user.uid);
    expect(user.reloadCalls, 1);
    expect(user.emailVerified, isFalse);
  });
}
