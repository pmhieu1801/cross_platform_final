import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_preferences.dart';

abstract interface class PreferencesStore {
  Future<Object?> read(String key);
  Future<bool> write(String key, String payload);
}

class SharedPreferencesStore implements PreferencesStore {
  @override
  Future<Object?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    // Existing project uses the legacy API. Refresh its cache before reading;
    // do not change NoteStorage's backend or global prefix as part of settings.
    await prefs.reload();
    return prefs.get(key);
  }

  @override
  Future<bool> write(String key, String payload) async =>
      (await SharedPreferences.getInstance()).setString(key, payload);
}

class LocalPreferencesRepository implements PreferencesRepository {
  LocalPreferencesRepository({PreferencesStore? store})
    : _store = store ?? SharedPreferencesStore();
  final PreferencesStore _store;
  final _writes = <String, Future<void>>{};

  static String keyFor(String uid) {
    if (uid.isEmpty) throw ArgumentError('A Firebase UID is required.');
    return 'noteflow_user_preferences_v1_${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}';
  }

  @override
  Future<PreferencesLoadResult> load(String uid) async {
    await (_writes[uid] ?? Future<void>.value());
    final raw = await _store.read(keyFor(uid));
    if (raw == null) {
      return const PreferencesLoadResult(UserPreferences.defaults);
    }
    try {
      if (raw is! String) {
        throw const FormatException('Invalid stored preference type.');
      }
      return PreferencesLoadResult(UserPreferences.fromJson(jsonDecode(raw)));
    } on FormatException {
      // Do not silently overwrite corrupted/unknown-version data. Only an
      // explicit Save/Restore defaults replaces this account's payload.
      return const PreferencesLoadResult(
        UserPreferences.defaults,
        recoveredCorruption: true,
      );
    }
  }

  @override
  Future<void> save(String uid, UserPreferences value) {
    final key = keyFor(uid);
    if (!value.isValid) throw const PreferencesFailure('Cỡ chữ không hợp lệ.');
    final payload = jsonEncode(value.toJson());
    final operation = (_writes[uid] ?? Future<void>.value()).then((_) async {
      if (!await _store.write(key, payload)) {
        throw const PreferencesFailure('Chưa lưu được cài đặt. Hãy thử lại.');
      }
    });
    // FIFO per UID also covers A -> logout -> A while the first write is pending.
    // A settled tail releases later writes even after one operation fails.
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[uid] = settled;
    settled.then((_) {
      if (identical(_writes[uid], settled)) _writes.remove(uid);
    });
    return operation;
  }
}
