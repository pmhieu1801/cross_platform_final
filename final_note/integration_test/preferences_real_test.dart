import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:final_note/app.dart';
import 'package:final_note/core/firebase_config.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/data/firebase_auth_repository.dart';
import 'package:final_note/features/notes/application/note_providers.dart';
import 'package:final_note/features/notes/data/in_memory_note_repository.dart';
import 'package:final_note/features/preferences/application/preferences_providers.dart';
import 'package:final_note/features/preferences/data/local_preferences_repository.dart';
import 'package:final_note/features/preferences/domain/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _aSettings = UserPreferences(
  themeMode: PreferenceThemeMode.light,
  noteFontScale: 1.3,
  notesViewMode: NotesViewMode.list,
);
const _bSettings = UserPreferences(noteFontScale: 0.85);

/// Two separate runs: seed exercises real Auth/settings UI/plugin; verify reads
/// the real store after process death. Only this run's accounts/keys are cleaned.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('PREFS_PHASE', defaultValue: 'seed');
  const runId = String.fromEnvironment('PREFS_TEST_RUN');
  testWidgets('real per-UID settings persistence ($phase)', (tester) async {
    expect(
      RegExp(r'^\d+$').hasMatch(runId),
      isTrue,
      reason: 'Supply a unique numeric PREFS_TEST_RUN.',
    );
    final markerKey = 'noteflow_w206_fixture_$runId';
    if (phase == 'verify') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(markerKey);
      expect(
        raw,
        isNotNull,
        reason: 'The successful seed phase must create its own marker.',
      );
      final marker = jsonDecode(raw!) as Map<String, dynamic>;
      expect(marker['runId'], runId);
      final uidA = marker['uidA'] as String;
      final uidB = marker['uidB'] as String;
      expect(uidA.isNotEmpty && uidB.isNotEmpty && uidA != uidB, isTrue);
      try {
        final freshRepository = LocalPreferencesRepository();
        expect((await freshRepository.load(uidA)).value, _aSettings);
        expect((await freshRepository.load(uidB)).value, _bSettings);
      } finally {
        // These UIDs come only from the seed marker for this exact test run.
        expect(
          await prefs.remove(LocalPreferencesRepository.keyFor(uidA)),
          isTrue,
        );
        expect(
          await prefs.remove(LocalPreferencesRepository.keyFor(uidB)),
          isTrue,
        );
        expect(await prefs.remove(markerKey), isTrue);
      }
      return;
    }
    expect(phase, 'seed');
    final random = Random.secure();
    String password() =>
        'Aa1!${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}';
    final passwordA = password();
    final passwordB = password();
    final emailA = 'm1-w206-$runId-a@example.test';
    final emailB = 'm1-w206-$runId-b@example.test';
    final app = await Firebase.initializeApp(
      name: 'm1-preferences-$runId',
      options: FirebaseConfig.fromEnvironment(),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final repository = FirebaseAuthRepository(auth);
    final notes = InMemoryNoteRepository();
    ProviderContainer? container;
    String? uidA;
    String? uidB;
    var readyToVerify = false;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container?.dispose();
      await notes.dispose();
      var cleanupOk = true;
      // If creation failed after the SDK installed a session, capture only the
      // known test email. Never infer ownership of an existing primary account.
      if (uidA == null && auth.currentUser?.email == emailA) {
        uidA = auth.currentUser?.uid;
      }
      if (uidB == null && auth.currentUser?.email == emailB) {
        uidB = auth.currentUser?.uid;
      }
      for (final fixture in [
        (uidA, emailA, passwordA),
        (uidB, emailB, passwordB),
      ]) {
        if (fixture.$1 == null) continue;
        try {
          await auth.signInWithEmailAndPassword(
            email: fixture.$2,
            password: fixture.$3,
          );
          final user = auth.currentUser;
          if (user?.uid == fixture.$1 && user?.email == fixture.$2) {
            await user!.delete();
          } else {
            cleanupOk = false;
          }
        } catch (_) {
          cleanupOk = false;
        }
      }
      if (!readyToVerify) {
        final prefs = await SharedPreferences.getInstance();
        for (final uid in [uidA, uidB]) {
          if (uid != null) {
            await prefs.remove(LocalPreferencesRepository.keyFor(uid));
          }
        }
        await prefs.remove(markerKey);
      }
      try {
        await app.delete();
      } catch (_) {
        cleanupOk = false;
      }
      expect(
        cleanupOk,
        isTrue,
        reason: 'Only the two disposable accounts and secondary app may be cleaned.',
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
        reason: 'Expected real settings/Auth state must arrive.',
      );
    }

    Future<void> choose(String key, String label) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    try {
      uidA = (await auth.createUserWithEmailAndPassword(
        email: emailA,
        password: passwordA,
      )).user!.uid;
      final scope = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) async => repository),
          // Notes content is a fixture; Auth and preferences use real SDK/storage.
          noteRepositoryProvider.overrideWithValue(notes),
        ],
      );
      container = scope;
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const NoteFlowApp()),
      );
      await waitFor(
        () =>
            find.byKey(const Key('open-preferences')).evaluate().isNotEmpty &&
            !scope.read(accountPreferencesProvider).isLoading,
      );
      await tester.tap(find.byKey(const Key('open-preferences')));
      await tester.pumpAndSettle();
      await choose('preferences-theme', 'Light');
      await choose('preferences-view', 'List');
      tester
          .widget<Slider>(find.byKey(const Key('preferences-font')))
          .onChanged!(1.3);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('preferences-save')));
      await tester.tap(find.byKey(const Key('preferences-save')));
      await waitFor(
        () =>
            scope.read(effectivePreferencesProvider) == _aSettings &&
            !scope.read(accountPreferencesProvider).asData!.value.saving,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      expect(
        (await LocalPreferencesRepository().load(uidA!)).value,
        _aSettings,
      );

      uidB = (await auth.createUserWithEmailAndPassword(
        email: emailB,
        password: passwordB,
      )).user!.uid;
      await waitFor(
        () =>
            scope.read(authenticatedUidProvider) == uidB &&
            scope.read(accountPreferencesProvider).asData?.value.uid == uidB &&
            !scope.read(accountPreferencesProvider).isLoading,
      );
      await tester.pumpAndSettle();
      expect(
        scope.read(effectivePreferencesProvider),
        UserPreferences.defaults,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
        1,
      );
      tester
          .widget<Slider>(find.byKey(const Key('preferences-font')))
          .onChanged!(0.85);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('preferences-save')));
      await tester.tap(find.byKey(const Key('preferences-save')));
      await waitFor(
        () =>
            scope.read(effectivePreferencesProvider) == _bSettings &&
            !scope.read(accountPreferencesProvider).asData!.value.saving,
      );
      await repository.signIn(email: emailA, password: passwordA);
      await waitFor(
        () =>
            scope.read(authenticatedUidProvider) == uidA &&
            scope.read(effectivePreferencesProvider) == _aSettings,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
        1.3,
      );
      await tester.ensureVisible(find.byKey(const Key('preferences-back')));
      await tester.tap(find.byKey(const Key('preferences-back')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('List view'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        await prefs.setString(
          markerKey,
          jsonEncode({'runId': runId, 'uidA': uidA, 'uidB': uidB}),
        ),
        isTrue,
      );
      readyToVerify = true;
    } on FirebaseAuthException catch (error) {
      fail('Real settings Firebase operation failed with code ${error.code}.');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
