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
  int passwordResetCalls = 0;
  int changePasswordCalls = 0;
  Completer<void>? changePending;
  AuthFailure? changeFailure;
  AuthFailure? signOutFailure;
  bool emitSignOut = true;
  String? changeUid;
  String? receivedCurrentPassword;
  String? receivedNewPassword;
  String? receivedEmail;
  String? receivedName;
  int verificationCalls = 0;
  int refreshCalls = 0;
  int profileUpdateCalls = 0;
  String? profileUid;
  String? profileName;
  Completer<void>? profilePending;
  AuthFailure? profileFailure;
  Completer<void>? verificationPending;
  AuthFailure? verificationFailure;
  AuthFailure? refreshFailure;
  RegistrationResult registrationResult = const RegistrationResult(
    uid: 'uid-A',
    verificationSent: true,
  );
  AuthUser refreshedUser = userA;
  Completer<void>? registrationFollowUp;

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
  Future<RegistrationResult> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    registerCalls++;
    receivedEmail = email;
    receivedName = displayName;
    await _complete();
    events.add(userA);
    if (registrationFollowUp != null) await registrationFollowUp!.future;
    return registrationResult;
  }

  @override
  Future<void> sendVerificationEmail(String expectedUid) async {
    verificationCalls++;
    if (verificationPending != null) await verificationPending!.future;
    if (verificationFailure != null) throw verificationFailure!;
  }

  @override
  Future<void> refreshCurrentUser(String expectedUid) async {
    refreshCalls++;
    if (verificationPending != null) await verificationPending!.future;
    if (refreshFailure != null) throw refreshFailure!;
    events.add(refreshedUser);
  }

  @override
  Future<void> signOut({String? expectedUid}) async {
    signOutCalls++;
    await _complete();
    if (signOutFailure != null) throw signOutFailure!;
    if (emitSignOut) events.add(null);
  }

  @override
  Future<void> updateDisplayName({
    required String expectedUid,
    required String displayName,
  }) async {
    profileUpdateCalls++;
    profileUid = expectedUid;
    profileName = displayName;
    if (profilePending != null) await profilePending!.future;
    if (profileFailure != null) throw profileFailure!;
  }

  @override
  Future<void> changePassword({
    required String expectedUid,
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    changeUid = expectedUid;
    receivedCurrentPassword = currentPassword;
    receivedNewPassword = newPassword;
    if (changePending != null) await changePending!.future;
    if (changeFailure != null) throw changeFailure!;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetCalls++;
    receivedEmail = email;
    await _complete();
  }

  Future<void> dispose() => events.close();
}
