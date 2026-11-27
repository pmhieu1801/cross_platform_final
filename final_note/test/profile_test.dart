import 'dart:async';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/application/profile_controller.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:final_note/features/auth/presentation/profile_avatar.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:final_note/routing/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;
  final nameInput = find.byKey(const Key('profile-name-input'));
  final save = find.byKey(const Key('profile-save'));
  const changed = AuthUser(
    uid: 'uid-A',
    email: 'a@example.test',
    displayName: 'Tên mới',
    emailVerified: false,
  );
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
  Future<void> boot(WidgetTester tester, {AuthUser? user = userA}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    fake.events.add(user);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('open-profile')));
    await tester.tap(find.byKey(const Key('open-profile')));
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('profile-edit')));
    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'profile is private; home opens current UID email name and default avatar',
    (tester) async {
      await boot(tester, user: null);
      container.read(appRouterProvider).go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.byKey(const Key('profile-current-name')), findsNothing);
      fake.events.add(userA);
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text('uid-A'), findsOneWidget);
      expect(find.text('a@example.test'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byKey(const Key('profile-default-avatar')), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(fake.refreshCalls, 1);
    },
  );

  testWidgets(
    'empty names never write; save trims name and waits for SDK snapshot to display it',
    (tester) async {
      await boot(tester);
      await open(tester);
      await edit(tester);
      await tester.enterText(nameInput, '   ');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enter your display name.'), findsOneWidget);
      expect(fake.profileUpdateCalls, 0);
      await tester.enterText(nameInput, '  Tên mới  ');
      fake.profilePending = Completer<void>();
      await tester.tap(save);
      await tester.pump();
      await container
          .read(profileActionsProvider.notifier)
          .saveName('duplicate');
      expect(fake.profileUpdateCalls, 1);
      expect(fake.profileUid, userA.uid);
      expect(fake.profileName, 'Tên mới');
      fake.profilePending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu tên hiển thị.'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Tên mới'), findsNothing);
      fake.events.add(changed);
      await tester.pumpAndSettle();
      expect(find.text('Tên mới'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      await tester.tap(find.byKey(const Key('profile-back')));
      await tester.pumpAndSettle();
      expect(find.text('Xin chào, Tên mới'), findsOneWidget);
    },
  );

  testWidgets('save error retains draft, releases busy and retry succeeds', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await edit(tester);
    await tester.enterText(nameInput, 'Tên mới');
    fake.profileFailure = const AuthFailure('Không kết nối được mạng.');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Không kết nối được mạng.'), findsOneWidget);
    expect(find.text('Đã lưu tên hiển thị.'), findsNothing);
    expect(tester.widget<TextFormField>(nameInput).controller!.text, 'Tên mới');
    expect(container.read(profileActionsProvider).busy, isFalse);
    expect(container.read(authenticatedUserProvider)?.displayName, 'Alice');
    fake.profileFailure = null;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(fake.profileUpdateCalls, 2);
    expect(nameInput, findsNothing);
  });

  testWidgets('late save from A cannot show feedback or draft in B profile', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await edit(tester);
    await tester.enterText(nameInput, 'Draft A');
    fake.profilePending = Completer<void>();
    fake.profileFailure = const AuthFailure('late A error');
    await tester.tap(save);
    await tester.pump();
    fake.refreshedUser = userB;
    fake.events.add(userB);
    await tester.pumpAndSettle();
    expect(find.text('uid-A'), findsNothing);
    expect(find.text('uid-B'), findsOneWidget);
    await edit(tester);
    expect(tester.widget<TextFormField>(nameInput).controller!.text, 'Bob');
    fake.profilePending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('late A error'), findsNothing);
    expect(find.text('Draft A'), findsNothing);
    expect(container.read(authenticatedUidProvider), 'uid-B');
  });

  testWidgets(
    'refresh error keeps current profile and retry receives server snapshot',
    (tester) async {
      fake.refreshFailure = const AuthFailure('refresh unavailable');
      await boot(tester);
      await open(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('refresh unavailable'), findsOneWidget);
      expect(container.read(profileActionsProvider).busy, isFalse);
      fake.refreshFailure = null;
      fake.refreshedUser = changed;
      await tester.tap(find.byKey(const Key('profile-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Tên mới'), findsOneWidget);
      expect(fake.refreshCalls, 2);
    },
  );

  testWidgets(
    'cancel and leaving discard draft; compact large text remains usable',
    (tester) async {
      await boot(tester);
      await open(tester);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await edit(tester);
      await tester.enterText(nameInput, 'unsaved draft');
      await tester.ensureVisible(find.byKey(const Key('profile-cancel')));
      await tester.tap(find.byKey(const Key('profile-cancel')));
      await tester.pumpAndSettle();
      await edit(tester);
      expect(tester.widget<TextFormField>(nameInput).controller!.text, 'Alice');
      expect(fake.profileUpdateCalls, 0);
      container.read(appRouterProvider).go(AppRoutes.login);
      fake.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);
      expect(nameInput, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unusable and failed remote avatars show default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileAvatar(photoUrl: 'local://avatar')),
    );
    expect(find.byKey(const Key('profile-default-avatar')), findsOneWidget);
    // Flutter tests return HTTP 400 for network images; exercise errorBuilder.
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileAvatar(
          photoUrl: 'https://avatar.example.test/missing.png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-default-avatar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
