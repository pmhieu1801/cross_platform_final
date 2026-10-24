import 'dart:async';

import 'package:final_note/features/auth/domain/auth_repository.dart';

const userA = AuthUser(
  uid: 'uid-A',
  email: 'a@example.test',
  displayName: 'Alice',
  emailVerified: false,
);
const userB = AuthUser(
  uid: 'uid-B',
  email: 'b@example.test',
  displayName: 'Bob',
  emailVerified: true,
);

/// Test-only fake. Production always resolves FirebaseAuthRepository.
class FakeAuthRepository implements AuthRepository {
  final events = StreamController<AuthUser?>.broadcast();
  Completer<void>? pending;
  AuthFailure? failure;
  int signInCalls = 0;
  int registerCalls = 0;
  int signOutCalls = 0;
  String? receivedEmail;
  String? receivedName;

  @override
  Stream<AuthUser?> watchSession() => events.stream;

  Future<void> _complete() async {
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    receivedEmail = email;
    await _complete();
    events.add(userA);
  }

  @override
  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    registerCalls++;
    receivedEmail = email;
    receivedName = displayName;
    await _complete();
    events.add(userA);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await _complete();
    events.add(null);
  }

  Future<void> dispose() => events.close();
}
