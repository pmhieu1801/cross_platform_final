import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:final_note/app.dart';
import 'package:final_note/core/firebase_config.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/application/profile_controller.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Real form + SDK. Two secondary clients verify server persistence without
/// touching the primary Firebase app's existing owner session.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'profile form persists name and reloads another Firebase client update',
    (tester) async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final random = Random.secure();
      final password =
          'Aa1!${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}';
      final email = 'm1-w204-$nonce@example.test';
      final options = FirebaseConfig.fromEnvironment();
      final app = await Firebase.initializeApp(
        name: 'm1-profile-$nonce',
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      final repository = FirebaseAuthRepository(auth);
      FirebaseApp? otherApp;
      FirebaseAuth? otherAuth;
      ProviderContainer? container;
      String? createdUid;

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container?.dispose();
        if (createdUid == null && auth.currentUser?.email == email) {
          createdUid = auth.currentUser?.uid;
        }
        var deleted = createdUid == null;
        var appsDeleted = true;
        try {
          if (createdUid != null) {
            final cleanupAuth = otherAuth ?? auth;
            if (cleanupAuth.currentUser?.uid != createdUid) {
              await cleanupAuth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            }
            final candidate = cleanupAuth.currentUser;
            if (candidate?.uid == createdUid && candidate?.email == email) {
              await candidate!.delete();
              deleted = true;
            }
          }
        } catch (_) {
          // Report cleanup status without logging credentials or raw SDK errors.
        } finally {
          for (final secondaryApp in [otherApp, app]) {
            if (secondaryApp == null) continue;
            try {
              await secondaryApp.delete();
            } catch (_) {
              appsDeleted = false;
            }
          }
        }
        expect(
          deleted,
          isTrue,
          reason: 'Only this disposable account may be cleaned up.',
        );
        expect(
          appsDeleted,
          isTrue,
          reason: 'Secondary Firebase apps must be cleaned up.',
        );
      });

      Future<void> waitFor(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          condition(),
          isTrue,
          reason: 'Expected profile SDK/UI state must arrive.',
        );
      }

      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        createdUid = credential.user!.uid;
        await repository.updateDisplayName(
          expectedUid: createdUid!,
          displayName: 'Before profile',
        );
        final scope = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith((ref) async => repository),
          ],
        );
        container = scope;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: const NoteFlowApp(),
          ),
        );
        await waitFor(
          () => find.byKey(const Key('open-profile')).evaluate().isNotEmpty,
        );
        await tester.ensureVisible(find.byKey(const Key('open-profile')));
        await tester.tap(find.byKey(const Key('open-profile')));
        await waitFor(
          () =>
              find.byKey(const Key('profile-edit')).evaluate().isNotEmpty &&
              !scope.read(profileActionsProvider).busy,
        );
        await tester.pumpAndSettle();
        expect(find.text(createdUid!), findsOneWidget);
        expect(find.text(email), findsOneWidget);
        expect(find.byKey(const Key('profile-default-avatar')), findsOneWidget);

        final updatedName = 'Tên hồ sơ $nonce';
        await tester.ensureVisible(find.byKey(const Key('profile-edit')));
        await tester.tap(find.byKey(const Key('profile-edit')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('profile-name-input')),
          '  $updatedName  ',
        );
        await tester.ensureVisible(find.byKey(const Key('profile-save')));
        await tester.tap(find.byKey(const Key('profile-save')));
        await waitFor(
          () =>
              scope.read(authenticatedUserProvider)?.displayName ==
                  updatedName &&
              find.byKey(const Key('profile-name-input')).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text(updatedName), findsOneWidget);
        expect(scope.read(profileActionsProvider).error, isNull);

        otherApp = await Firebase.initializeApp(
          name: 'm1-profile-other-$nonce',
          options: options,
        );
        final reader = FirebaseAuth.instanceFor(app: otherApp);
        otherAuth = reader;
        await reader.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        expect(reader.currentUser?.uid, createdUid);
        expect(reader.currentUser?.displayName, updatedName);

        final remoteName = 'Tên từ client khác $nonce';
        await FirebaseAuthRepository(
          reader,
        ).updateDisplayName(expectedUid: createdUid!, displayName: remoteName);
        await tester.ensureVisible(find.byKey(const Key('profile-refresh')));
        await tester.tap(find.byKey(const Key('profile-refresh')));
        await waitFor(
          () =>
              scope.read(authenticatedUserProvider)?.displayName ==
                  remoteName &&
              !scope.read(profileActionsProvider).busy,
        );
        await tester.pumpAndSettle();
        expect(find.text(remoteName), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('profile-back')));
        await tester.tap(find.byKey(const Key('profile-back')));
        await tester.pumpAndSettle();
        expect(find.text('Xin chào, $remoteName'), findsOneWidget);
      } on FirebaseAuthException catch (error) {
        fail('Real profile Firebase operation failed with code ${error.code}.');
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
