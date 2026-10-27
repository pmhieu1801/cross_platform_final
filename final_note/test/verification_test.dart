import 'dart:async';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/application/verification_providers.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

const verifiedA = AuthUser(
  uid: 'uid-A',
  email: 'a@example.test',
  displayName: 'Alice',
  emailVerified: true,
);
const unverifiedB = AuthUser(
  uid: 'uid-B',
  email: 'b@example.test',
  displayName: 'Bob',
  emailVerified: false,
);

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;
  setUp(() {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) async => fake)],
    );
  });
  tearDown(() async {
    container.dispose();
    await fake.dispose();
  });
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    // The initial session is deliberately unresolved; its spinner cannot settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    fake.events.add(userA);
    await tester.pumpAndSettle();
  }

  final providerA = verificationActionsProvider(userA.uid);

  void testVerificationWidgets(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        // The externally owned container must dispose before Flutter checks for
        // pending timers, not in package:test tearDown after that check.
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    });
  }

  testVerificationWidgets(
    'resend blocks duplicates and cooldown expires after 60 seconds',
    (tester) async {
      await boot(tester);
      fake.verificationPending = Completer<void>();
      final actions = container.read(providerA.notifier);
      final pending = actions.resend();
      await actions.resend();
      await tester.pump();
      expect(fake.verificationCalls, 1);
      expect(container.read(providerA).sending, isTrue);
      fake.verificationPending!.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(container.read(providerA).busy, isFalse);
      expect(container.read(providerA).coolingDown, isTrue);
      expect(find.text('Địa chỉ nhận: a@example.test'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('verification-resend')),
            )
            .onPressed,
        isNull,
      );
      await actions.resend();
      expect(fake.verificationCalls, 1);
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(container.read(providerA).retryAt, isNull);
      await actions.resend();
      expect(fake.verificationCalls, 2);
    },
  );

  for (final code in ['network-request-failed', 'too-many-requests']) {
    testVerificationWidgets(
      '$code releases loading without claiming delivery, retry succeeds',
      (tester) async {
        await boot(tester);
        fake.verificationFailure = AuthFailure(authErrorMessage(code));
        await container.read(providerA.notifier).resend();
        await tester.pumpAndSettle();
        final state = container.read(providerA);
        expect(state.busy, isFalse);
        expect(state.error, authErrorMessage(code));
        expect(state.message, isNull);
        expect(state.retryAt, isNull);
        expect(find.text(authErrorMessage(code)), findsOneWidget);
        fake.verificationFailure = null;
        await container.read(providerA.notifier).resend();
        expect(container.read(providerA).message, contains('Đã yêu cầu gửi'));
      },
    );
  }

  testVerificationWidgets(
    'reload failure retains banner and retry uses SDK stream to remove it',
    (tester) async {
      await boot(tester);
      fake.refreshFailure = const AuthFailure(
        'Không kết nối được mạng. Hãy thử lại.',
      );
      await tester.tap(find.byKey(const Key('verification-refresh')));
      await tester.pumpAndSettle();
      expect(container.read(providerA).refreshing, isFalse);
      expect(find.byKey(const Key('verification-banner')), findsOneWidget);
      expect(container.read(authenticatedUserProvider)!.emailVerified, isFalse);
      fake.refreshFailure = null;
      fake.refreshedUser = verifiedA;
      await tester.tap(find.byKey(const Key('verification-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('verification-banner')), findsNothing);
      expect(find.text('Firebase UID: uid-A'), findsOneWidget);
      expect(fake.refreshCalls, 2);
    },
  );

  testVerificationWidgets(
    'resume refreshes unverified session and avoids overlapping requests',
    (tester) async {
      await boot(tester);
      fake.verificationPending = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await container.read(providerA.notifier).refresh();
      expect(fake.refreshCalls, 1);
      fake.refreshedUser = verifiedA;
      fake.verificationPending!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('verification-banner')), findsNothing);
    },
  );

  testVerificationWidgets(
    'late A email failure cannot affect B or a later A lease',
    (tester) async {
      await boot(tester);
      fake.verificationPending = Completer<void>();
      fake.verificationFailure = const AuthFailure('A-only failure');
      final pending = container.read(providerA.notifier).resend();
      await tester.pump();
      fake.events.add(unverifiedB);
      await tester.pumpAndSettle();
      expect(
        container.read(verificationActionsProvider(userB.uid)).error,
        isNull,
      );
      fake.events.add(userA);
      await tester.pumpAndSettle();
      fake.verificationPending!.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(container.read(providerA).busy, isFalse);
      expect(container.read(providerA).error, isNull);
      expect(find.text('A-only failure'), findsNothing);
    },
  );

  testVerificationWidgets(
    'partial registration preserves session, warns and permits resend',
    (tester) async {
      await boot(tester);
      await container.read(authActionsProvider.notifier).signOut();
      await tester.pumpAndSettle();
      fake.registrationResult = const RegistrationResult(
        uid: 'uid-A',
        verificationSent: false,
        warning: 'Tài khoản đã được tạo và đăng nhập. Không đăng ký lại. Chưa gửi được email xác minh.',
      );
      await container
          .read(authActionsProvider.notifier)
          .register('a@example.test', 'Alice', 'test-only');
      await tester.pumpAndSettle();
      expect(container.read(authenticatedUidProvider), userA.uid);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/home',
      );
      expect(find.textContaining('Không đăng ký lại.'), findsOneWidget);
      expect(container.read(providerA).coolingDown, isFalse);
      await tester.tap(find.byKey(const Key('verification-resend')));
      await tester.pumpAndSettle();
      expect(fake.registerCalls, 1);
      expect(fake.verificationCalls, 1);
      expect(container.read(providerA).error, isNull);
    },
  );

  testVerificationWidgets(
    'successful registration starts resend cooldown; unverified user keeps home access',
    (tester) async {
      await boot(tester);
      await container.read(authActionsProvider.notifier).signOut();
      await tester.pumpAndSettle();
      await container
          .read(authActionsProvider.notifier)
          .register('a@example.test', 'Alice', 'test-only');
      await tester.pumpAndSettle();
      expect(container.read(providerA).coolingDown, isTrue);
      expect(find.textContaining('Đã yêu cầu gửi email'), findsOneWidget);
      expect(find.text('Firebase UID: uid-A'), findsOneWidget);
    },
  );

  testVerificationWidgets(
    'compact layout and large text keep banner controls reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(tester);
      await tester.ensureVisible(find.byKey(const Key('verification-refresh')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('verification-refresh')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testVerificationWidgets(
    'late registration result is discarded after A to B',
    (tester) async {
      await boot(tester);
      await container.read(authActionsProvider.notifier).signOut();
      await tester.pumpAndSettle();
      fake.registrationFollowUp = Completer<void>();
      final pending = container
          .read(authActionsProvider.notifier)
          .register('a@example.test', 'Alice', 'test-only');
      await tester.pumpAndSettle();
      fake.events.add(unverifiedB);
      await tester.pumpAndSettle();
      fake.registrationFollowUp!.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(
        container.read(verificationActionsProvider(userB.uid)).message,
        isNull,
      );
      expect(container.read(providerA).message, isNull);
      expect(find.text('Firebase UID: uid-B'), findsOneWidget);
    },
  );
}
