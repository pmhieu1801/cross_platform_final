import '../../../models/note.dart';

class NoteFailure implements Exception {
  const NoteFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Account-scoped contract for simple note management (R09-R14, R17).
///
/// Every method requires the authenticated [uid] and isolates data strictly by
/// account so switching accounts never leaks or mutates another user's notes.
abstract class NoteRepository {
  Stream<List<Note>> watchNotes(String uid);

  Future<List<Note>> listNotes(String uid);

  Future<Note> saveNote(String uid, Note note);

  Future<void> deleteNote(String uid, String noteId);

  Future<Note> togglePin(String uid, String noteId, {DateTime? now});
}
