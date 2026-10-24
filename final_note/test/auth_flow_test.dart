import 'dart:async';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> signedOut(WidgetTester tester) async {
    await boot(tester);
    fake.events.add(null);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'initial session and direct protected route never paint private UI',
    (tester) async {
      await boot(tester);
      container.read(appRouterProvider).go('/home');
      await tester.pump();
      expect(find.text('Đang xác định phiên đăng nhập…'), findsOneWidget);
      expect(find.textContaining('Firebase UID:'), findsNothing);
      fake.events.add(null);
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
      expect(find.byKey(const Key('email')), findsOneWidget);
    },
  );

  testWidgets(
    'registration validates fields and confirmation without calling repository',
    (tester) async {
      await signedOut(tester);
      container.read(appRouterProvider).go('/register');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
      expect(find.text('Nhập tên hiển thị.'), findsOneWidget);
      expect(find.text('Nhập mật khẩu.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('email')), 'a@example.test');
      await tester.enterText(find.byKey(const Key('displayName')), 'Alice');
      await tester.enterText(find.byKey(const Key('password')), 'abcdef');
      await tester.enterText(
        find.byKey(const Key('confirmation')),
        'different',
      );
      await tester.ensureVisible(find.byKey(const Key('submit')));
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
      expect(fake.registerCalls, 0);
    },
  );

  testWidgets(
    'registration stream auto-login shows exact UID and unverified banner',
    (tester) async {
      await signedOut(tester);
      container.read(appRouterProvider).go('/register');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email')),
        ' a@example.test ',
      );
      await tester.enterText(find.byKey(const Key('displayName')), ' Alice ');
      await tester.enterText(find.byKey(const Key('password')), 'abcdef');
      await tester.enterText(find.byKey(const Key('confirmation')), 'abcdef');
      await tester.ensureVisible(find.byKey(const Key('submit')));
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      expect(fake.registerCalls, 1);
      expect(fake.receivedName, 'Alice');
      expect(find.text('Firebase UID: uid-A'), findsOneWidget);
      expect(find.textContaining('Email chưa được xác minh.'), findsOneWidget);
      fake.events.add(userB);
      await tester.pumpAndSettle();
      expect(find.text('Firebase UID: uid-A'), findsNothing);
      expect(find.text('Firebase UID: uid-B'), findsOneWidget);
      expect(find.textContaining('Email chưa được xác minh.'), findsNothing);
    },
  );

  testWidgets(
    'login pending blocks duplicate submits; network error is visible and retry works',
    (tester) async {
      await signedOut(tester);
      fake.pending = Completer<void>();
      fake.failure = AuthFailure(authErrorMessage('network-request-failed'));
      await tester.enterText(find.byKey(const Key('email')), 'a@example.test');
      await tester.enterText(find.byKey(const Key('password')), 'abcdef');
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('submit'))).onPressed,
        isNull,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(fake.signInCalls, 1);
      fake.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Không kết nối được mạng.'), findsOneWidget);
      expect(find.textContaining('Firebase UID:'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('submit'))).onPressed,
        isNotNull,
      );
      fake.failure = null;
      fake.pending = null;
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      expect(find.text('Firebase UID: uid-A'), findsOneWidget);
    },
  );

  testWidgets(
    'logout blocks old URL and router back; next account replaces old identity',
    (tester) async {
      await boot(tester);
      fake.events.add(userA);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Firebase UID:'), findsNothing);
      container.read(appRouterProvider).go('/home');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('Firebase UID:'), findsNothing);
      expect(find.byKey(const Key('email')), findsOneWidget);
      fake.events.add(userB);
      await tester.pumpAndSettle();
      expect(find.text('Firebase UID: uid-B'), findsOneWidget);
      expect(find.text('Firebase UID: uid-A'), findsNothing);
    },
  );
}
