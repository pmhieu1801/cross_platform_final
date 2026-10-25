import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run seed with --no-uninstall, stop the Android process, then run verify with
/// --no-uninstall and the emitted UID. Flutter test otherwise removes app data.
/// Only a non-secret UID crosses processes; the password is never persisted.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('AUTH_PERSISTENCE_PHASE');
  const expectedUid = String.fromEnvironment('AUTH_EXPECTED_UID');

  testWidgets('real Firebase persistence across Android processes ($phase)', (
    tester,
  ) async {
    expect(
      ['seed', 'verify'],
      contains(phase),
      reason: 'Set AUTH_PERSISTENCE_PHASE=seed or verify.',
    );
    if (phase == 'verify') expect(expectedUid, isNotEmpty);
    final container = ProviderContainer();
    FirebaseAuth? auth;
    String? createdUid;
    String? createdEmail;
    bool seeded = false;
    addTearDown(() async {
      try {
        final current = auth?.currentUser;
        final ownedUid = phase == 'seed' ? createdUid : expectedUid;
        final owned =
            current != null &&
            (current.uid == ownedUid ||
                (phase == 'seed' && current.email == createdEmail)) &&
            (current.email?.startsWith('m1-persistence-') ?? false) &&
            (current.email?.endsWith('@example.test') ?? false);
        if (owned && (phase == 'verify' || !seeded)) {
          await current.delete();
        }
      } finally {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          container.dispose();
        }
      }
    });

    // Mount production consumers first: Riverpod streams must stay observed
    // while the native SDK resolves and publishes its initial persisted user.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    final repository = await container.read(authRepositoryProvider.future);
    auth = FirebaseAuth.instance;
    if (phase == 'seed') {
      await repository.signOut();
      final loginDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (find.byKey(const Key('login-email')).evaluate().isEmpty &&
          DateTime.now().isBefore(loginDeadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      final random = Random.secure();
      final password =
          'Aa1!${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}';
      final email =
          'm1-persistence-${DateTime.now().microsecondsSinceEpoch}@example.test';
      createdEmail = email;
      final request = container
          .read(authActionsProvider.notifier)
          .register(email, 'W1 Persistence Test', password);
      final requestDeadline = DateTime.now().add(const Duration(seconds: 60));
      while (container.read(authActionsProvider).busy &&
          DateTime.now().isBefore(requestDeadline)) {
        createdUid = auth.currentUser?.uid;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(authActionsProvider).busy, isFalse);
      await request;
      expect(container.read(authActionsProvider).error, isNull);
      createdUid = auth.currentUser!.uid;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (find.byKey(const Key('logout')).evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final session = container.read(authenticatedUserProvider);
    expect(session, isNotNull);
    expect(session!.uid, phase == 'seed' ? createdUid : expectedUid);
    expect(auth.currentUser!.uid, session.uid);
    expect(find.text('Firebase UID: ${session.uid}'), findsOneWidget);
    expect(find.byKey(const Key('logout')), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    if (phase == 'seed') {
      await tester.pump(const Duration(seconds: 1));
      // UID is a public identifier, not a token or password.
      // ignore: avoid_print
      print('AUTH_PERSISTENCE_UID=${session.uid}');
      seeded = true;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
