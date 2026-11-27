import '../../../models/note.dart';

class NoteFailure implements Exception {
  const NoteFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Account-scoped contract for simple note and label management (R09-R14, R17, R19-R22).
///
/// Every method requires the authenticated [uid] and isolates data strictly by
/// account so switching accounts never leaks or mutates another user's notes or labels.
abstract class NoteRepository {
  Stream<List<Note>> watchNotes(String uid);

  Future<List<Note>> listNotes(String uid);

  Future<Note> saveNote(String uid, Note note);

  Future<Note> updateSyncStatus(
    String uid,
    String noteId,
    NoteSyncStatus status,
  );

  Future<void> deleteNote(String uid, String noteId);

  Future<Note> togglePin(String uid, String noteId, {DateTime? now});

  Stream<List<String>> watchLabels(String uid);

  Future<List<String>> listLabels(String uid);

  Future<List<String>> addLabel(String uid, String label);

  Future<List<String>> renameLabel(
    String uid, {
    required String oldLabel,
    required String newLabel,
  });

  Future<List<String>> deleteLabel(String uid, String label);

  /// Enables individual note password protection after confirming the new
  /// password twice (R23).
  Future<Note> enableNotePassword(
    String uid,
    String noteId, {
    required String password,
    required String confirmPassword,
  });

  /// Verifies [password] against the protected note's stored salted hash and
  /// unlocks the note for the current [uid] session (R24).
  Future<bool> verifyNotePassword(String uid, String noteId, String password);

  /// Changes the password of a protected note after verifying [currentPassword]
  /// and confirming [newPassword] twice (R24).
  Future<Note> changeNotePassword(
    String uid,
    String noteId, {
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  });

  /// Disables password protection on a note after verifying [currentPassword] (R23).
  Future<Note> disableNotePassword(
    String uid,
    String noteId, {
    required String currentPassword,
  });

  /// Returns whether a password-protected note is currently unlocked for [uid].
  bool isNoteUnlocked(String uid, String noteId);

  /// Explicitly locks a note again in the active session for [uid].
  void lockNoteSession(String uid, String noteId);

  /// Registers a known account identity `(uid, email)` so email-based sharing
  /// can resolve recipients and validate registered accounts (R25).
  void registerAccountIdentity({required String uid, required String email});

  /// Watches notes shared WITH the given account ([uid] / [email]) in real time (R25, R26).
  Stream<List<Note>> watchSharedWithMe(String uid, {String? email});

  /// Lists notes shared WITH the given account ([uid] / [email]) (R25).
  Future<List<Note>> listSharedWithMe(String uid, {String? email});

  /// Shares [noteId] owned by [ownerUid] with [recipientEmail] at [permission] (R25).
  Future<Note> shareNote(
    String ownerUid,
    String noteId, {
    required String recipientEmail,
    required NoteSharePermission permission,
    String? ownerEmail,
  });

  /// Updates an existing recipient's [permission] on [noteId] owned by [ownerUid] (R25).
  Future<Note> updateSharePermission(
    String ownerUid,
    String noteId, {
    required String recipientEmail,
    required NoteSharePermission permission,
  });

  /// Revokes [recipientEmail]'s access to [noteId] owned by [ownerUid] (R25).
  Future<Note> revokeShare(
    String ownerUid,
    String noteId, {
    required String recipientEmail,
  });
}
