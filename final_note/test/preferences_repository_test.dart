import 'dart:async';
import 'dart:convert';

import 'package:final_note/features/preferences/data/local_preferences_repository.dart';
import 'package:final_note/features/preferences/domain/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_preferences_store.dart';

void main() {
  const custom = UserPreferences(
    themeMode: PreferenceThemeMode.dark,
    noteFontScale: 1.3,
    notesViewMode: NotesViewMode.list,
  );

  test('default is light, 100 percent, grid; fresh repository reloads persisted UID settings', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalPreferencesRepository();
    expect((await repository.load('uid-A')).value, UserPreferences.defaults);
    expect(UserPreferences.defaults.notesViewMode, NotesViewMode.grid);
    await repository.save('uid-A', custom);
    final fresh = LocalPreferencesRepository();
    expect((await fresh.load('uid-A')).value, custom);
    expect((await fresh.load('uid-B')).value, UserPreferences.defaults);
    expect(
      LocalPreferencesRepository.keyFor('a/b'),
      isNot(LocalPreferencesRepository.keyFor('a_b')),
    );
    expect(
      LocalPreferencesRepository.keyFor('a@example.test'),
      isNot(contains('@')),
    );
    expect(() => LocalPreferencesRepository.keyFor(''), throwsArgumentError);
  });

  test('corrupt type JSON version enum or scale recovers defaults without overwriting bytes', () async {
    final store = MemoryPreferencesStore();
    final repository = LocalPreferencesRepository(store: store);
    final key = LocalPreferencesRepository.keyFor('uid-A');
    for (final raw in [
      true,
      '{broken',
      '[]',
      '{}',
      jsonEncode({...custom.toJson(), 'schemaVersion': 2}),
      jsonEncode({...custom.toJson(), 'themeMode': 'unknown'}),
      jsonEncode({...custom.toJson(), 'notesViewMode': 'unknown'}),
      jsonEncode({...custom.toJson(), 'noteFontScale': 'large'}),
      jsonEncode({...custom.toJson(), 'noteFontScale': 0.1}),
      jsonEncode({...custom.toJson(), 'noteFontScale': 1.6}),
    ]) {
      store.values[key] = raw;
      final loaded = await repository.load('uid-A');
      expect(loaded.value, UserPreferences.defaults);
      expect(loaded.recoveredCorruption, isTrue);
      expect(store.values[key], raw);
    }
    expect(store.writes, isEmpty);
    await repository.save('uid-A', UserPreferences.defaults);
    expect((await repository.load('uid-A')).recoveredCorruption, isFalse);
  });

  test('write rejection is a failure and the queue permits a retry', () async {
    final store = MemoryPreferencesStore()..rejectWrites = true;
    final repository = LocalPreferencesRepository(store: store);
    await expectLater(
      repository.save('uid-A', custom),
      throwsA(isA<PreferencesFailure>()),
    );
    expect((await repository.load('uid-A')).value, UserPreferences.defaults);
    store.rejectWrites = false;
    await repository.save('uid-A', custom);
    expect((await repository.load('uid-A')).value, custom);
    expect(
      () => repository.save(
        'uid-A',
        const UserPreferences(noteFontScale: double.nan),
      ),
      throwsA(isA<PreferencesFailure>()),
    );
  });

  test('writes are FIFO per UID and load waits for pending writes; B is independent', () async {
    final store = MemoryPreferencesStore();
    final keyA = LocalPreferencesRepository.keyFor('uid-A');
    final hold = Completer<void>();
    store.writeHolds[keyA] = hold;
    final repository = LocalPreferencesRepository(store: store);
    final first = repository.save('uid-A', custom);
    final last = repository.save('uid-A', UserPreferences.defaults);
    var readFinished = false;
    final read = repository.load('uid-A').then((result) {
      readFinished = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(store.writes.where((key) => key == keyA).length, 1);
    expect(readFinished, isFalse);
    await repository.save('uid-B', custom);
    expect((await repository.load('uid-B')).value, custom);
    hold.complete();
    await Future.wait([first, last]);
    expect((await read).value, UserPreferences.defaults);
    expect(store.writes.where((key) => key == keyA).length, 2);
  });

  test(
    'read and write exceptions are not mislabeled as corrupt stored data',
    () async {
      final store = MemoryPreferencesStore()
        ..readFailure = StateError('IO unavailable');
      final repository = LocalPreferencesRepository(store: store);
      await expectLater(repository.load('uid-A'), throwsStateError);
      store.readFailure = null;
      store.writeFailure = StateError('IO unavailable');
      await expectLater(repository.save('uid-A', custom), throwsStateError);
      store.writeFailure = null;
      await repository.save('uid-A', custom);
      expect((await repository.load('uid-A')).value, custom);
    },
  );
}
