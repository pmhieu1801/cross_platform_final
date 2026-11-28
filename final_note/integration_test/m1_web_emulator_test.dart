import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/data/firestore_avatar_store.dart';
import 'package:final_note/features/auth/data/local_avatar_repository.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:final_note/routing/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const _project = 'demo-noteflow';
const _host = '127.0.0.1';

Future<FirebaseApp> _connect(String name) async {
  final app = await Firebase.initializeApp(
    name: name,
    options: const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: '1:123456:web:0000000000000000',
      messagingSenderId: '123456',
      projectId: _project,
      authDomain: '$_project.firebaseapp.com',
    ),
  );
  await FirebaseAuth.instanceFor(app: app).useAuthEmulator(_host, 9099);
  FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(_host, 8080);
  return app;
}

Future<String> _emailCode(String address, String kind) async {
  final endpoint = Uri.http(
    '$_host:9099',
    '/emulator/v1/projects/$_project/oobCodes',
  );
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  do {
    final response = await http
        .get(endpoint)
        .timeout(const Duration(seconds: 5));
    expect(response.statusCode, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final pending = (body['oobCodes'] as List).cast<Map<String, dynamic>>();
    for (final entry in pending) {
      if (entry['email'] == address && entry['requestType'] == kind) {
        return entry['oobCode'] as String;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  } while (DateTime.now().isBefore(deadline));
  throw StateError('The emulator did not send the expected test email.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M1 Web account flows and cross-session avatar with Firebase', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('FIREBASE_CLOUD_AVATARS'), isTrue);
    final run = DateTime.now().microsecondsSinceEpoch;
    final email = 'owner-$run@example.test';
    const initialPassword = 'LocalStart!4200';
    const changedPassword = 'LocalChange!7630';
    const resetPassword = 'LocalReset!8430';
    final app = await _connect('m1-web-$run');
    final auth = FirebaseAuth.instanceFor(app: app);
    final container = ProviderContainer(
      overrides: [firebaseAppProvider.overrideWith((_) async => app)],
    );
    addTearDown(container.dispose);

    Finder key(String value) => find.byKey(Key(value));

    Future<void> waitUntil(
      bool Function() condition,
      String description,
    ) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), isTrue, reason: description);
    }

    Future<void> visible(String value) =>
        waitUntil(() => key(value).evaluate().isNotEmpty, 'Expected $value.');

    Future<void> tap(String value) async {
      final finder = key(value);
      await visible(value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(finder);
      await tester.pump();
    }

    Future<void> fill(String value, String text) async {
      await visible(value);
      await tester.ensureVisible(key(value));
      await tester.enterText(key(value), text);
      await tester.pump();
    }

    Future<void> go(String path, String control) async {
      container.read(appRouterProvider).go(path);
      await tester.pump();
      await visible(control);
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> logIn(String password) async {
      await fill('login-email', email);
      await fill('login-password', password);
      await tap('login-submit');
      await waitUntil(
        () => container.read(authenticatedUidProvider) != null,
        'Manual login should restore the account.',
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    await visible('login-submit');
    await go(AppRoutes.register, 'register-submit');
    await fill('register-name', 'M1 Emulator Owner');
    await fill('register-email', email);
    await fill('register-password', initialPassword);
    await fill('register-confirm-password', initialPassword);
    await tap('register-submit');
    await visible('verification-banner');
    final uid = auth.currentUser!.uid;
    await auth.applyActionCode(await _emailCode(email, 'VERIFY_EMAIL'));
    await tap('verification-refresh');
    await waitUntil(
      () => key('verification-banner').evaluate().isEmpty,
      'Verification should remove the banner.',
    );

    await go(AppRoutes.profile, 'profile-edit');
    await tap('profile-edit');
    await fill('profile-name-input', 'Updated M1 Owner');
    await tap('profile-save');
    await waitUntil(
      () => auth.currentUser?.displayName == 'Updated M1 Owner',
      'The profile name should persist in Firebase Auth.',
    );
    await waitUntil(
      () =>
          tester.widget<TextButton>(key('profile-change-avatar')).onPressed !=
          null,
      'Avatar editing should be ready after loading.',
    );
    await tap('profile-change-avatar');
    await tap('avatar-preset-crimson');
    await visible('profile-avatar-feedback');
    final message = tester.widget<Text>(key('profile-avatar-feedback')).data;
    if (message != 'Đã cập nhật ảnh đại diện.') {
      final local = container.read(avatarRepositoryProvider);
      final image = await local.validator.normalizeForAvatar(
        LocalAvatarRepository.sampleAvatars.first.bytes,
        maxDimension: FirestoreAvatarStore.maxDimension,
      );
      try {
        await FirestoreAvatarStore(
          FirebaseFirestore.instanceFor(app: app),
          auth,
        ).save(uid, image);
      } on FirebaseException catch (error) {
        fail(
          'Avatar UI reported "$message". Firestore returned ${error.code}.',
        );
      }
      fail('Avatar UI reported "$message". A direct avatar save succeeded.');
    }

    final second = await _connect('m1-web-second-$run');
    final secondAuth = FirebaseAuth.instanceFor(app: second);
    await secondAuth.signInWithEmailAndPassword(
      email: email,
      password: initialPassword,
    );
    final secondStore = FirestoreAvatarStore(
      FirebaseFirestore.instanceFor(app: second),
      secondAuth,
    );
    expect((await secondStore.load(uid)).image?.contentType, 'image/png');
    await tap('profile-change-avatar');
    await tap('avatar-remove-button');
    await waitUntil(
      () => find
          .text('Đã khôi phục ảnh đại diện mặc định.')
          .evaluate()
          .isNotEmpty,
      'Avatar removal should finish through the production repository.',
    );
    final reset = await secondStore.load(uid);
    expect(reset.initialized, isTrue);
    expect(reset.image, isNull);

    await go(AppRoutes.changePassword, 'change-submit');
    await fill('change-current', initialPassword);
    await fill('change-new', changedPassword);
    await fill('change-confirm', changedPassword);
    await tap('change-submit');
    await visible('login-submit');
    expect(auth.currentUser, isNull);
    await logIn(changedPassword);
    expect(auth.currentUser?.uid, uid);

    await container.read(authActionsProvider.notifier).signOut();
    await visible('login-submit');
    await go(AppRoutes.forgotPassword, 'forgot-submit');
    await fill('forgot-email', email);
    await tap('forgot-submit');
    await auth.confirmPasswordReset(
      code: await _emailCode(email, 'PASSWORD_RESET'),
      newPassword: resetPassword,
    );
    expect(auth.currentUser, isNull);
    await go(AppRoutes.login, 'login-submit');
    await logIn(resetPassword);
    expect(auth.currentUser?.uid, uid);
  });
}
