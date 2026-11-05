import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NoteStorage {
  static const _notesKey = 'noteflow_notes_v1';

  static Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) {
      return createDemoNotes();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return createDemoNotes();
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList();
    } catch (_) {
      return createDemoNotes();
    }
  }

  static Future<void> saveNotes(List<Note> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(notes.map((note) => note.toJson()).toList());
      await prefs.setString(_notesKey, payload);
    } catch (_) {
      // Ignore missing platform channel errors in isolated widget tests.
    }
  }
}
