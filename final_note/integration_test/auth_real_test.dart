import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in test against the configured real Firebase project, never a fake.
/// Creates two disposable accounts; credentials exist only in process memory.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real Firebase register/login/logout and account isolation', (
    tester,
  ) async {
    final container = ProviderContainer();
    final createdUsers = <String, String>{};
    FirebaseAuth? auth;
    final random = Random.secure();
    final password =
        'Aa1!${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}';
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final emailA = 'm1-w1-a-$nonce@example.test';
    final emailB = 'm1-w1-b-$nonce@example.test';
    final testEmails = {emailA, emailB};

    void rememberCreatedUser() {
      final user = auth?.currentUser;
      if (user != null && testEmails.contains(user.email)) {
        createdUsers[user.uid] = user.email!;
      }
    }

    // Register cleanup before initialization/assertions can fail. Report cleanup
    // separately so it cannot replace the original test failure.
    addTearDown(() async {
      rememberCreatedUser();
      final cleanupErrors = <String>[];
      final firebaseAuth = auth;
      try {
        if (firebaseAuth != null) {
          for (final account in createdUsers.entries) {
            try {
              await firebaseAuth.signInWithEmailAndPassword(
                email: account.value,
                password: password,
              );
              final user = firebaseAuth.currentUser;
              if (user?.uid != account.key) {
                cleanupErrors.add('test-account-uid-mismatch');
                continue;
              }
              await user!.delete();
            } on FirebaseAuthException catch (error) {
              cleanupErrors.add(error.code);
            } catch (_) {
              cleanupErrors.add('unexpected-account-cleanup-error');
            }
          }
          try {
            await firebaseAuth.signOut();
          } catch (_) {
            cleanupErrors.add('test-sign-out-failed');
          }
        }
      } finally {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          container.dispose();
        }
      }
      expect(
        cleanupErrors,
        isEmpty,
        reason:
            'Disposable account cleanup failed; inspect the test project. '
            'No passwords or raw SDK errors are logged.',
      );
    });

    final repository = await container.read(authRepositoryProvider.future);
    auth = FirebaseAuth.instance;
    await repository.signOut();

    Future<void> waitFor(Finder finder) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsOneWidget);
    }

    Future<void> submit() async {
      await tester.ensureVisible(find.byKey(const Key('submit')));
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pump();
    }

    Future<void> waitForIdle() async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (container.read(authActionsProvider).busy &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(authActionsProvider).busy, isFalse);
    }

    Future<void> register(String email, String name) async {
      container.read(appRouterProvider).go('/register');
      await waitFor(find.byKey(const Key('displayName')));
      await tester.enterText(find.byKey(const Key('email')), email);
      await tester.enterText(find.byKey(const Key('displayName')), name);
      await tester.enterText(find.byKey(const Key('password')), password);
      await tester.enterText(find.byKey(const Key('confirmation')), password);
      await submit();
      await waitFor(find.byKey(const Key('logout')));
      rememberCreatedUser();
      // Profile update can still be running after the sign-in stream event.
      await waitForIdle();
      expect(container.read(authActionsProvider).error, isNull);
      final sdk = FirebaseAuth.instance.currentUser!;
      expect(sdk.email, email);
      expect(sdk.displayName, name);
      expect(container.read(authenticatedUidProvider), sdk.uid);
      expect(find.text('Firebase UID: ${sdk.uid}'), findsOneWidget);
      expect(find.textContaining('Email chưa được xác minh.'), findsOneWidget);
    }

    Future<void> logout() async {
      await waitForIdle();
      await tester.ensureVisible(find.byKey(const Key('logout')));
      await tester.tap(find.byKey(const Key('logout')));
      await waitFor(find.byKey(const Key('email')));
      expect(FirebaseAuth.instance.currentUser, isNull);
      expect(container.read(authenticatedUidProvider), isNull);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    await waitFor(find.byKey(const Key('email')));
    container.read(appRouterProvider).go('/home');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('logout')), findsNothing);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );

    await register(emailA, 'W1 Integration A');
    final uidA = FirebaseAuth.instance.currentUser!.uid;
    final leaseA = container.read(accountSessionProvider)!;
    await logout();
    expect(leaseA.isActive, isFalse);
    container.read(appRouterProvider).go('/home');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Firebase UID: $uidA'), findsNothing);

    // Duplicate email must fail in Firebase rather than claiming success.
    container.read(appRouterProvider).go('/register');
    await waitFor(find.byKey(const Key('displayName')));
    await tester.enterText(find.byKey(const Key('email')), emailA);
    await tester.enterText(find.byKey(const Key('displayName')), 'Duplicate');
    await tester.enterText(find.byKey(const Key('password')), password);
    await tester.enterText(find.byKey(const Key('confirmation')), password);
    await submit();
    await waitFor(find.textContaining('đã được đăng ký'));
    expect(FirebaseAuth.instance.currentUser, isNull);

    container.read(authActionsProvider.notifier).clearError();
    container.read(appRouterProvider).go('/login');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('email')), emailA);
    await tester.enterText(
      find.byKey(const Key('password')),
      '${password}wrong',
    );
    await submit();
    await waitFor(find.text('Email hoặc mật khẩu không đúng.'));
    expect(FirebaseAuth.instance.currentUser, isNull);
    await tester.enterText(find.byKey(const Key('password')), password);
    await submit();
    await waitFor(find.byKey(const Key('logout')));
    expect(FirebaseAuth.instance.currentUser!.uid, uidA);
    await logout();
    await register(emailB, 'W1 Integration B');
    expect(FirebaseAuth.instance.currentUser!.uid, isNot(uidA));
    expect(find.text('Firebase UID: $uidA'), findsNothing);
    await logout();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
