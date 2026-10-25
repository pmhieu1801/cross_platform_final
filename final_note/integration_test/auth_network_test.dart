import 'dart:convert';
import 'dart:math';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run with the Android emulator's Wi-Fi/mobile data disabled by the host.
/// Exercises the production controller and Firebase SDK; no fake repository.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real offline Auth failure releases loading without a session', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(() async {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        container.dispose();
      }
    });
    final repository = await container.read(authRepositoryProvider.future);
    await repository.signOut();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    final initialDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (find.byKey(const Key('login-submit')).evaluate().isEmpty &&
        DateTime.now().isBefore(initialDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    final random = Random.secure();
    final password =
        'Aa1!${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}';
    final email =
        'm1-network-${DateTime.now().microsecondsSinceEpoch}@example.test';
    final actions = container.read(authActionsProvider.notifier);
    final request = actions.signIn(email, password);
    expect(container.read(authActionsProvider).busy, isTrue);
    // The same production busy guard must ignore another action while pending.
    final duplicate = actions.signIn(email, password);
    await tester.pump();
    await duplicate;
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (container.read(authActionsProvider).busy &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      container.read(authActionsProvider).busy,
      isFalse,
      reason: 'A real network error must release loading.',
    );
    await request;
    await tester.pump();
    expect(container.read(authActionsProvider).error, contains('mạng'));
    expect(find.textContaining('Không kết nối được mạng.'), findsOneWidget);
    expect(container.read(authenticatedUidProvider), isNull);
    expect(find.byKey(const Key('logout')), findsNothing);
    expect(
      tester
          .widget<GradientButton>(find.byKey(const Key('login-submit')))
          .loading,
      isFalse,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
