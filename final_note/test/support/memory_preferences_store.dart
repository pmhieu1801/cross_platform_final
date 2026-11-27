import 'dart:async';

import 'package:final_note/features/preferences/data/local_preferences_repository.dart';

class MemoryPreferencesStore implements PreferencesStore {
  final values = <String, Object?>{};
  final readHolds = <String, Completer<void>>{};
  final writeHolds = <String, Completer<void>>{};
  final writes = <String>[];
  bool rejectWrites = false;
  Object? readFailure;
  Object? writeFailure;

  @override
  Future<Object?> read(String key) async {
    if (readHolds[key] != null) await readHolds[key]!.future;
    if (readFailure != null) throw readFailure!;
    return values[key];
  }

  @override
  Future<bool> write(String key, String payload) async {
    writes.add(key);
    if (writeHolds[key] != null) await writeHolds[key]!.future;
    if (writeFailure != null) throw writeFailure!;
    if (rejectWrites) return false;
    values[key] = payload;
    return true;
  }
}
