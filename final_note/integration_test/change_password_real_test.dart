import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:final_note/core/firebase_config.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/application/change_password_controller.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in real SDK test. A secondary Firebase app preserves the primary app's
/// session. Only the account created by this test may be deleted in cleanup.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase reauth, password update and manual new-password login', (
    tester,
  ) async {
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure();
    String password() =>
        'Aa1!${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}';
    final originalPassword = password();
    final newPassword = password();
    final email = 'm1-w203-$nonce@example.test';
    final app = await Firebase.initializeApp(
      name: 'm1-change-$nonce',
      options: FirebaseConfig.fromEnvironment(),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final repository = FirebaseAuthRepository(auth);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    String? createdUid;

    addTearDown(() async {
      container.dispose();
      if (createdUid == null && auth.currentUser?.email == email) {
        createdUid = auth.currentUser?.uid;
      }
      var accountDeleted = createdUid == null;
      var appDeleted = false;
      try {
        if (createdUid != null) {
          // An assertion may fail either before or after the password update.
          // Retry only credentials for this test's freshly created account.
          for (final credentialPassword in [newPassword, originalPassword]) {
            try {
              await auth.signInWithEmailAndPassword(
                email: email,
                password: credentialPassword,
              );
              if (auth.currentUser?.uid != createdUid) break;
              await auth.currentUser!.delete();
              accountDeleted = true;
              break;
            } on FirebaseAuthException catch (error) {
              if (error.code != 'invalid-credential' &&
                  error.code != 'wrong-password') {
                break;
              }
            } catch (_) {
              break;
            }
          }
        }
      } finally {
        try {
          await app.delete();
          appDeleted = true;
        } catch (_) {
          // Cleanup reports only status, never the raw SDK exception.
        }
      }
      expect(
        accountDeleted,
        isTrue,
        reason: 'The disposable test account needs cleanup. No credentials are logged.',
      );
      expect(
        appDeleted,
        isTrue,
        reason: 'The secondary test Firebase app needs cleanup.',
      );
    });

    await tester.pumpWidget(const SizedBox.shrink());
    container.listen(authSessionProvider, (_, _) {});
    container.listen(changePasswordProvider, (_, _) {});
    await container.read(authRepositoryProvider.future);

    Future<void> waitFor(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      expect(
        condition(),
        isTrue,
        reason: 'The expected SDK session event must arrive.',
      );
    }

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: originalPassword,
      );
      createdUid = credential.user!.uid;
      await waitFor(
        () => container.read(authenticatedUidProvider) == createdUid,
      );
      final controller = container.read(changePasswordProvider.notifier);

      await controller.submit('${originalPassword}wrong', newPassword);
      expect(
        container.read(changePasswordProvider).error,
        'Mật khẩu hiện tại không đúng.',
      );
      expect(auth.currentUser?.uid, createdUid);
      // The original password must still work after the rejected attempt.
      await repository.signIn(email: email, password: originalPassword);
      await waitFor(
        () => container.read(authenticatedUidProvider) == createdUid,
      );

      await controller.submit(originalPassword, newPassword);
      await waitFor(
        () =>
            container.read(changePasswordProvider).phase ==
            PasswordChangePhase.completed,
      );
      expect(auth.currentUser, isNull);
      expect(container.read(authenticatedUidProvider), isNull);

      await expectLater(
        repository.signIn(email: email, password: originalPassword),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            authErrorMessage('invalid-credential'),
          ),
        ),
      );
      expect(auth.currentUser, isNull);
      await repository.signIn(email: email, password: newPassword);
      await waitFor(
        () => container.read(authenticatedUidProvider) == createdUid,
      );
      expect(auth.currentUser?.uid, createdUid);
      expect(
        container.read(changePasswordProvider).phase,
        PasswordChangePhase.idle,
      );
    } on FirebaseAuthException catch (error) {
      // Keep SDK details, passwords and tokens out of the test runner's output.
      fail('Real Firebase operation failed with code ${error.code}.');
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
