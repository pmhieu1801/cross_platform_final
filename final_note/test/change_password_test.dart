import 'dart:async';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/application/change_password_controller.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:final_note/routing/session_guard.dart';
import 'package:final_note/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;
  final current = find.byKey(const Key('change-current'));
  final newPassword = find.byKey(const Key('change-new'));
  final confirm = find.byKey(const Key('change-confirm'));
  final submit = find.byKey(const Key('change-submit'));
  const notice = 'Password changed. Sign in with your new password.';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) async => fake)],
    );
  });
  tearDown(() async {
    container.dispose();
    await fake.dispose();
  });

  Future<void> boot(WidgetTester tester, {bool signedIn = true}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    fake.events.add(signedIn ? userA : null);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('open-change-password')));
    await tester.tap(find.byKey(const Key('open-change-password')));
    await tester.pumpAndSettle();
    expect(current, findsOneWidget);
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(current, ' current test value ');
    await tester.enterText(newPassword, ' new test value ');
    await tester.enterText(confirm, ' new test value ');
  }

  testWidgets('change route is private and home entry validates the form', (
    tester,
  ) async {
    await boot(tester, signedIn: false);
    container.read(appRouterProvider).go(AppRoutes.changePassword);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(current, findsNothing);
    fake.events.add(userA);
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('Create a password.'), findsOneWidget);
    await tester.enterText(current, 'test-only');
    await tester.enterText(newPassword, 'short');
    await tester.enterText(confirm, 'different');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(fake.changePasswordCalls, 0);
  });

  testWidgets(
    'pending duplicate and wrong current password preserve session and clear fields',
    (tester) async {
      await boot(tester);
      await open(tester);
      await fill(tester);
      fake.changePending = Completer<void>();
      fake.changeFailure = const AuthFailure('Mật khẩu hiện tại không đúng.');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await container
          .read(changePasswordProvider.notifier)
          .submit('ignored', 'ignored');
      expect(fake.changePasswordCalls, 1);
      expect(tester.widget<GradientButton>(submit).loading, isTrue);
      fake.changePending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(container.read(changePasswordProvider).busy, isFalse);
      expect(fake.signOutCalls, 0);
      expect(container.read(authenticatedUidProvider), userA.uid);
      expect(tester.widget<TextFormField>(current).controller!.text, isEmpty);
      expect(
        tester.widget<TextFormField>(newPassword).controller!.text,
        isEmpty,
      );
      expect(tester.widget<TextFormField>(confirm).controller!.text, isEmpty);
      expect(fake.receivedCurrentPassword == ' current test value ', isTrue);
      expect(fake.receivedNewPassword == ' new test value ', isTrue);
    },
  );

  testWidgets(
    'completion waits for SDK sign-out stream and clears its notice for B',
    (tester) async {
      await boot(tester);
      await open(tester);
      await fill(tester);
      fake.emitSignOut = false;
      await tester.tap(submit);
      await tester.pump();
      expect(fake.changePasswordCalls, 1);
      expect(fake.signOutCalls, 1);
      expect(
        container.read(changePasswordProvider).phase,
        PasswordChangePhase.signingOut,
      );
      expect(find.byKey(const Key('login-email')), findsNothing);
      fake.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(container.read(authenticatedUidProvider), isNull);
      expect(fake.signInCalls, 0);
      fake.events.add(userB);
      await tester.pumpAndSettle();
      expect(find.text(notice), findsNothing);
      expect(
        container.read(changePasswordProvider).phase,
        PasswordChangePhase.idle,
      );
    },
  );

  testWidgets('partial sign-out failure retries only sign-out', (tester) async {
    await boot(tester);
    await open(tester);
    await fill(tester);
    fake.signOutFailure = const AuthFailure('network error');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      container.read(changePasswordProvider).phase,
      PasswordChangePhase.signOutFailed,
    );
    expect(find.textContaining('Mật khẩu đã được đổi'), findsOneWidget);
    expect(current, findsNothing);
    expect(container.read(authenticatedUidProvider), userA.uid);
    await container
        .read(changePasswordProvider.notifier)
        .submit('old', 'another');
    expect(fake.changePasswordCalls, 1);
    fake.signOutFailure = null;
    await tester.tap(find.byKey(const Key('change-retry-signout')));
    await tester.pumpAndSettle();
    expect(fake.changePasswordCalls, 1);
    expect(fake.signOutCalls, 2);
    expect(find.text(notice), findsOneWidget);
  });

  testWidgets(
    'late A result does not sign out B or carry credentials into B form',
    (tester) async {
      await boot(tester);
      await open(tester);
      await fill(tester);
      fake.changePending = Completer<void>();
      await tester.tap(submit);
      await tester.pump();
      fake.events.add(userB);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(current).controller!.text, isEmpty);
      fake.changePending!.complete();
      await tester.pumpAndSettle();
      expect(fake.signOutCalls, 0);
      expect(container.read(authenticatedUidProvider), userB.uid);
      expect(container.read(changePasswordProvider).passwordChanged, isFalse);
    },
  );

  testWidgets(
    'late failure from an earlier A lease is discarded after A signs in again',
    (tester) async {
      await boot(tester);
      await open(tester);
      await fill(tester);
      fake.changePending = Completer<void>();
      fake.changeFailure = const AuthFailure('old lease failure');
      await tester.tap(submit);
      await tester.pump();
      fake.events.add(null);
      await tester.pumpAndSettle();
      fake.events.add(userA);
      await tester.pumpAndSettle();
      fake.changePending!.complete();
      await tester.pumpAndSettle();
      await open(tester);
      expect(current, findsOneWidget);
      expect(find.text('old lease failure'), findsNothing);
      expect(fake.signOutCalls, 0);
    },
  );

  testWidgets('compact form supports large text and clears inputs on leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await boot(tester);
    await open(tester);
    await fill(tester);
    await tester.ensureVisible(find.byKey(const Key('change-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-back')));
    await tester.pumpAndSettle();
    await open(tester);
    expect(tester.widget<TextFormField>(current).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
