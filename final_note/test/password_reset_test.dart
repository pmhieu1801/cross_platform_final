import 'dart:async';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:final_note/routing/session_guard.dart';
import 'package:final_note/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

void main() {
  final email = find.byKey(const Key('forgot-email'));
  final submit = find.byKey(const Key('forgot-submit'));
  final instruction = find.textContaining(
    'If an account exists for this email',
  );
  late FakeAuthRepository fake;
  late ProviderContainer container;

  Future<void> boot(WidgetTester tester, {bool resolveSession = true}) async {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) async => fake)],
    );
    addTearDown(() async {
      container.dispose();
      await fake.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    if (resolveSession) {
      fake.events.add(null);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('direct recovery link survives session restoration', (
    tester,
  ) async {
    await boot(tester, resolveSession: false);
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.forgotPassword);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.forgotPassword,
    );
    expect(email, findsNothing);
    fake.events.add(null);
    await tester.pumpAndSettle();
    expect(email, findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.forgotPassword,
    );
  });

  testWidgets(
    'login link validates email and reset request leaves user signed out',
    (tester) async {
      await boot(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.forgotPassword,
      );
      await tester.enterText(email, 'invalid');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(fake.passwordResetCalls, 0);

      await tester.enterText(email, ' owner+qa@example.test ');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(fake.receivedEmail, 'owner+qa@example.test');
      expect(fake.passwordResetCalls, 1);
      expect(instruction, findsOneWidget);
      expect(container.read(authSessionProvider).asData?.value, isNull);
      expect(fake.signInCalls, 0);
      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
    },
  );

  for (final code in ['network-request-failed', 'too-many-requests']) {
    testWidgets('$code releases loading and permits a retry', (tester) async {
      await boot(tester);
      container.read(appRouterProvider).go(AppRoutes.forgotPassword);
      await tester.pumpAndSettle();
      fake.pending = Completer<void>();
      fake.failure = AuthFailure(authErrorMessage(code));
      await tester.enterText(email, 'owner@example.test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<GradientButton>(submit).loading, isTrue);
      await tester.tap(submit);
      await tester.pump();
      expect(fake.passwordResetCalls, 1);
      fake.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<GradientButton>(submit).loading, isFalse);
      expect(find.text(authErrorMessage(code)), findsOneWidget);
      expect(instruction, findsNothing);

      fake.failure = null;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(fake.passwordResetCalls, 2);
      expect(instruction, findsOneWidget);
    });
  }

  testWidgets('late recovery result is discarded after leaving the route', (
    tester,
  ) async {
    await boot(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    fake.pending = Completer<void>();
    await tester.enterText(email, 'owner@example.test');
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    fake.pending!.complete();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(instruction, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
