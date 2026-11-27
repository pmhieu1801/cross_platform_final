import 'dart:async';
import 'dart:convert';

import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/notes/application/note_providers.dart';
import 'package:final_note/features/notes/data/in_memory_note_repository.dart';
import 'package:final_note/features/preferences/application/preferences_providers.dart';
import 'package:final_note/features/preferences/data/local_preferences_repository.dart';
import 'package:final_note/features/preferences/domain/user_preferences.dart';
import 'package:final_note/models/note.dart';
import 'package:final_note/routing/app_router.dart';
import 'package:final_note/routing/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';
import 'support/memory_preferences_store.dart';

void main() {
  late FakeAuthRepository auth;
  late MemoryPreferencesStore store;
  late ProviderContainer container;
  late InMemoryNoteRepository notes;
  const custom = UserPreferences(
    themeMode: PreferenceThemeMode.light,
    noteFontScale: 1.3,
    notesViewMode: NotesViewMode.list,
  );
  final saveButton = find.byKey(const Key('preferences-save'));
  final keyA = LocalPreferencesRepository.keyFor('uid-A');
  final keyB = LocalPreferencesRepository.keyFor('uid-B');
  Finder notesScroll() => find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthRepository();
    store = MemoryPreferencesStore();
    notes = InMemoryNoteRepository(seedDemoNotes: false);
    await notes.saveNote(
      'uid-A',
      Note(
        id: 'prefs-note',
        title: 'Settings note',
        content: 'Note content sample',
        labels: const [],
        colorIndex: 0,
        updatedAt: DateTime(2026, 11, 22),
      ),
    );
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) async => auth),
        preferencesRepositoryProvider.overrideWithValue(
          LocalPreferencesRepository(store: store),
        ),
        noteRepositoryProvider.overrideWithValue(notes),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await auth.dispose();
    await notes.dispose();
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
    auth.events.add(signedIn ? userA : null);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('open-preferences')));
    await tester.tap(find.byKey(const Key('open-preferences')));
    await tester.pumpAndSettle();
  }

  Future<void> revealNote(WidgetTester tester, {bool list = false}) async {
    await tester.scrollUntilVisible(
      find.byKey(Key('${list ? 'note-tile' : 'note-card'}-prefs-note')),
      200,
      scrollable: notesScroll(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String label) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> editCustom(WidgetTester tester) async {
    await choose(tester, 'preferences-theme', 'Light');
    await choose(tester, 'preferences-view', 'List');
    tester.widget<Slider>(find.byKey(const Key('preferences-font'))).onChanged!(
      1.3,
    );
    await tester.pump();
  }

  ThemeMode? appTheme(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

  testWidgets(
    'settings route is private and defaults are grid dark and normal size',
    (tester) async {
      await boot(tester, signedIn: false);
      container.read(appRouterProvider).go(AppRoutes.preferences);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(saveButton, findsNothing);
      auth.events.add(userA);
      await tester.pumpAndSettle();
      await revealNote(tester);
      expect(find.byKey(const Key('note-card-prefs-note')), findsOneWidget);
      await open(tester);
      expect(appTheme(tester), ThemeMode.dark);
      expect(
        tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
        1,
      );
      expect(store.writes, isEmpty);
    },
  );

  testWidgets(
    'save applies theme view and font to Notes card/list and editor after persistence',
    (tester) async {
      await boot(tester);
      await open(tester);
      await editCustom(tester);
      expect(appTheme(tester), ThemeMode.dark);
      store.writeHolds[keyA] = Completer<void>();
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      expect(
        await container
            .read(accountPreferencesProvider.notifier)
            .save(UserPreferences.defaults),
        isFalse,
      );
      expect(store.writes.length, 1);
      expect(
        container.read(effectivePreferencesProvider),
        UserPreferences.defaults,
      );
      store.writeHolds[keyA]!.complete();
      await tester.pumpAndSettle();
      expect(appTheme(tester), ThemeMode.light);
      expect(container.read(effectivePreferencesProvider), custom);
      expect(find.text('Đã lưu cài đặt trên thiết bị này.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('preferences-back')));
      await tester.pumpAndSettle();
      await revealNote(tester, list: true);
      expect(find.byKey(const Key('note-tile-prefs-note')), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Settings note')).style!.fontSize,
        closeTo(15 * 1.3, 0.01),
      );
      await tester.ensureVisible(find.byKey(const Key('note-tile-prefs-note')));
      await tester.tap(find.byKey(const Key('note-tile-prefs-note')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-content-input')))
            .style!
            .fontSize,
        closeTo(16 * 1.3, 0.01),
      );
      expect(jsonDecode(store.values[keyA] as String)['notesViewMode'], 'list');
    },
  );

  testWidgets(
    'save failure keeps draft and old effective settings; retry succeeds',
    (tester) async {
      await boot(tester);
      await open(tester);
      await editCustom(tester);
      store.rejectWrites = true;
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('Chưa lưu được cài đặt. Hãy thử lại.'), findsOneWidget);
      expect(appTheme(tester), ThemeMode.dark);
      expect(
        tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
        1.3,
      );
      expect(find.text('Đã lưu cài đặt trên thiết bị này.'), findsNothing);
      store.rejectWrites = false;
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(container.read(effectivePreferencesProvider), custom);
    },
  );

  testWidgets(
    'Notes layout toggle persists and rejects failed writes without pretending to switch',
    (tester) async {
      await boot(tester);
      store.rejectWrites = true;
      await tester.ensureVisible(find.byIcon(Icons.view_agenda_outlined));
      await tester.tap(find.byIcon(Icons.view_agenda_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Chưa lưu được cài đặt. Hãy thử lại.'), findsOneWidget);
      await revealNote(tester);
      expect(find.byKey(const Key('note-card-prefs-note')), findsOneWidget);
      store.rejectWrites = false;
      tester.state<ScrollableState>(notesScroll()).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.view_agenda_outlined));
      await tester.tap(find.byIcon(Icons.view_agenda_outlined));
      await tester.pumpAndSettle();
      await revealNote(tester, list: true);
      expect(find.byKey(const Key('note-tile-prefs-note')), findsOneWidget);
      container.invalidate(accountPreferencesProvider);
      await tester.pumpAndSettle();
      expect(
        container.read(effectivePreferencesProvider).notesViewMode,
        NotesViewMode.list,
      );
      expect(find.byKey(const Key('note-tile-prefs-note')), findsOneWidget);
    },
  );

  testWidgets(
    'B loading and late A result never expose A theme draft or feedback',
    (tester) async {
      store.values[keyA] = jsonEncode(custom.toJson());
      await boot(tester);
      expect(appTheme(tester), ThemeMode.light);
      await open(tester);
      await choose(tester, 'preferences-theme', 'Dark');
      store.writeHolds[keyA] = Completer<void>();
      await tester.tap(saveButton);
      await tester.pump();
      store.readHolds[keyB] = Completer<void>();
      auth.events.add(userB);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(effectivePreferencesProvider),
        UserPreferences.defaults,
      );
      expect(appTheme(tester), ThemeMode.dark);
      store.writeHolds[keyA]!.complete();
      await tester.pump();
      store.readHolds[keyB]!.complete();
      await tester.pumpAndSettle();
      expect(
        container.read(accountPreferencesProvider).asData!.value.uid,
        'uid-B',
      );
      expect(
        container.read(effectivePreferencesProvider),
        UserPreferences.defaults,
      );
      expect(find.text('Đã lưu cài đặt trên thiết bị này.'), findsNothing);
      expect(
        tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
        1,
      );
    },
  );

  testWidgets('read failure is visible and retry loads current UID settings', (
    tester,
  ) async {
    store.values[keyA] = jsonEncode(custom.toJson());
    store.readFailure = StateError('private storage detail');
    await boot(tester);
    expect(appTheme(tester), ThemeMode.dark);
    await open(tester);
    expect(find.text('Không thể tải cài đặt. Hãy thử lại.'), findsOneWidget);
    expect(find.textContaining('private storage detail'), findsNothing);
    store.readFailure = null;
    await tester.tap(find.byKey(const Key('preferences-retry')));
    await tester.pumpAndSettle();
    expect(appTheme(tester), ThemeMode.light);
    expect(
      tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
      1.3,
    );
  });

  testWidgets(
    'corrupt settings warn without automatic write and reset affects only active UID',
    (tester) async {
      store.values[keyA] = 'broken';
      store.values[keyB] = jsonEncode(custom.toJson());
      await boot(tester);
      await open(tester);
      expect(
        find.textContaining('Dữ liệu cài đặt không hợp lệ.'),
        findsOneWidget,
      );
      expect(store.writes, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('preferences-reset')));
      await tester.tap(find.byKey(const Key('preferences-reset')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Dữ liệu cài đặt không hợp lệ.'),
        findsNothing,
      );
      expect(store.values[keyB], jsonEncode(custom.toJson()));
      expect(
        container.read(effectivePreferencesProvider),
        UserPreferences.defaults,
      );
    },
  );

  testWidgets(
    'fresh A lease reads queued storage without accepting the old save callback',
    (tester) async {
      await boot(tester);
      store.writeHolds[keyA] = Completer<void>();
      final oldSave = container
          .read(accountPreferencesProvider.notifier)
          .save(custom);
      await tester.pump();
      auth.events.add(null);
      await tester.pumpAndSettle();
      expect(appTheme(tester), ThemeMode.dark);
      auth.events.add(userA);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(effectivePreferencesProvider),
        UserPreferences.defaults,
      );
      store.writeHolds[keyA]!.complete();
      await tester.pumpAndSettle();
      expect(await oldSave, isFalse);
      final loaded = container.read(accountPreferencesProvider).asData!.value;
      expect(loaded.uid, 'uid-A');
      expect(loaded.value, custom);
      expect(loaded.message, isNull);
    },
  );

  testWidgets(
    'grid note typography consumes maximum font size without overflowing',
    (tester) async {
      store.values[keyA] = jsonEncode(
        const UserPreferences(noteFontScale: 1.5).toJson(),
      );
      await boot(tester);
      await revealNote(tester);
      expect(
        tester.widget<Text>(find.text('Settings note')).style!.fontSize,
        closeTo(17 * 1.5, 0.01),
      );
      expect(
        tester.widget<Text>(find.text('Note content sample')).style!.fontSize,
        closeTo(12 * 1.5, 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system theme follows platform brightness after saving', (
    tester,
  ) async {
    await boot(tester);
    await open(tester);
    await choose(tester, 'preferences-theme', 'System');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(appTheme(tester), ThemeMode.system);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(saveButton)).brightness, Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(saveButton)).brightness, Brightness.dark);
  });

  testWidgets(
    'compact settings support large text and leaving discards unsaved draft',
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
      tester
          .widget<Slider>(find.byKey(const Key('preferences-font')))
          .onChanged!(1.5);
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton);
      expect(tester.takeException(), isNull);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('preferences-back')));
      await tester.tap(find.byKey(const Key('preferences-back')));
      await tester.pumpAndSettle();
      await open(tester);
      expect(
        tester.widget<Slider>(find.byKey(const Key('preferences-font'))).value,
        1,
      );
      expect(store.writes, isEmpty);
    },
  );
}
