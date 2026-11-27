import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/note.dart';
import '../application/note_password_security.dart';
import '../domain/note_repository.dart';

class NoteStoreSnapshot {
  const NoteStoreSnapshot({required this.notes, required this.labels});

  final List<Note> notes;
  final List<String> labels;
}

abstract interface class NoteLocalStore {
  Future<NoteStoreSnapshot?> load(String uid);

  Future<void> save(String uid, NoteStoreSnapshot snapshot);
}

class SharedPreferencesNoteStore implements NoteLocalStore {
  static const _keyPrefix = 'noteflow_account_notes_v1_';

  String _keyFor(String uid) =>
      '$_keyPrefix${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}';

  @override
  Future<NoteStoreSnapshot?> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(uid));
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported local note data format.');
    }

    final rawNotes = decoded['notes'];
    final rawLabels = decoded['labels'];
    if (rawNotes is! List || rawLabels is! List) {
      throw const FormatException('Invalid local note data.');
    }

    final notes = <Note>[];
    for (final value in rawNotes) {
      if (value is! Map) {
        throw const FormatException('Invalid note in local note data.');
      }
      notes.add(Note.fromJson(Map<String, dynamic>.from(value)));
    }
    final labels = <String>[];
    for (final value in rawLabels) {
      if (value is! String) {
        throw const FormatException('Invalid label in local note data.');
      }
      labels.add(value);
    }

    return NoteStoreSnapshot(notes: notes, labels: labels);
  }

  @override
  Future<void> save(String uid, NoteStoreSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'schemaVersion': 1,
      'notes': snapshot.notes.map((note) => note.toJson()).toList(),
      'labels': snapshot.labels,
    });
    final saved = await prefs.setString(_keyFor(uid), payload);
    if (!saved) {
      throw StateError('SharedPreferences rejected the note data write.');
    }
  }
}

/// UID-partitioned note repository backed by local storage.
class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository({
    this.seedDemoNotes = true,
    this.latency = Duration.zero,
    NoteLocalStore? store,
  }) : _store = store ?? SharedPreferencesNoteStore();

  LocalNoteRepository.inMemory({
    this.seedDemoNotes = true,
    this.latency = Duration.zero,
  }) : _store = null;

  final bool seedDemoNotes;
  final Duration latency;
  final NoteLocalStore? _store;

  /// Optional test hook to inject an error on the next write operation.
  NoteFailure? nextFailure;

  final Map<String, List<Note>> _notesByUid = <String, List<Note>>{};
  final Map<String, Set<String>> _labelsByUid = <String, Set<String>>{};
  final Map<String, Set<String>> _unlockedNotesByUid = <String, Set<String>>{};
  final Map<String, String> _emailToUid = <String, String>{};
  final Map<String, String> _uidToEmail = <String, String>{};
  final Map<String, Future<void>> _loadsByUid = <String, Future<void>>{};
  final Map<String, Future<void>> _writeTailsByUid = <String, Future<void>>{};
  final Map<String, StreamController<List<Note>>> _noteControllersByUid =
      <String, StreamController<List<Note>>>{};
  final Map<String, StreamController<List<Note>>> _sharedNoteControllersByUid =
      <String, StreamController<List<Note>>>{};
  final Map<String, StreamController<List<String>>> _labelControllersByUid =
      <String, StreamController<List<String>>>{};

  /// Whether `shareNote` requires the recipient email to have been registered
  /// via [registerAccountIdentity]. When `false` (default), any valid email
  /// format except the owner's own email is accepted and linked automatically
  /// when that account signs in.
  bool requireRegisteredRecipients = false;

  List<Note> _bucketFor(String uid) {
    if (uid.trim().isEmpty) {
      throw const NoteFailure('Phiên đăng nhập không hợp lệ.');
    }
    return _notesByUid.putIfAbsent(uid, () {
      final seeded = seedDemoNotes
          ? sortNotes(createDemoNotes(ownerUid: uid))
          : <Note>[];
      final labelSet = _labelsByUid.putIfAbsent(uid, () => <String>{});
      for (final note in seeded) {
        labelSet.addAll(note.labels);
      }
      return seeded;
    });
  }

  Future<void> _ensureLoaded(String uid) async {
    if (uid.trim().isEmpty) {
      throw const NoteFailure('Phiên đăng nhập không hợp lệ.');
    }
    if (_notesByUid.containsKey(uid)) return;

    final load = _loadsByUid.putIfAbsent(uid, () => _loadUid(uid));
    try {
      await load;
    } catch (_) {
      if (identical(_loadsByUid[uid], load)) {
        _loadsByUid.remove(uid);
      }
      rethrow;
    }
  }

  Future<void> _loadUid(String uid) async {
    try {
      final snapshot = await _store?.load(uid);
      if (snapshot == null) {
        final notes = seedDemoNotes
            ? sortNotes(createDemoNotes(ownerUid: uid))
            : <Note>[];
        final labels = notes.expand((note) => note.labels).toSet();
        await _saveSnapshot(uid, notes, labels);
        _notesByUid[uid] = notes;
        _labelsByUid[uid] = labels;
        return;
      }

      final notes = <Note>[];
      final labels = <String>{...snapshot.labels};
      for (final note in snapshot.notes) {
        if (note.ownerUid != null && note.ownerUid != uid) {
          throw const NoteFailure(
            'Local note data does not belong to the active account.',
          );
        }
        final scopedAttachments = <NoteAttachment>[];
        for (final attachment in note.attachments) {
          if (attachment.ownerUid != null && attachment.ownerUid != uid) {
            throw const NoteFailure(
              'Local attachment data does not belong to the active account.',
            );
          }
          scopedAttachments.add(attachment.copyWith(ownerUid: uid));
        }
        final accountNote = note.copyWith(
          ownerUid: uid,
          attachments: List<NoteAttachment>.unmodifiable(scopedAttachments),
        );
        notes.add(accountNote);
        labels.addAll(accountNote.labels);
      }
      _notesByUid[uid] = sortNotes(notes);
      _labelsByUid[uid] = labels;
    } on NoteFailure {
      rethrow;
    } on FormatException catch (error) {
      throw NoteFailure('Saved note data is invalid: ${error.message}');
    } catch (error) {
      throw NoteFailure('Could not load local notes: $error');
    }
  }

  Future<void> _saveSnapshot(
    String uid,
    List<Note> notes,
    Set<String> labels,
  ) async {
    final store = _store;
    if (store == null) return;
    final sortedLabels = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    try {
      await store.save(
        uid,
        NoteStoreSnapshot(
          notes: List<Note>.unmodifiable(notes),
          labels: List<String>.unmodifiable(sortedLabels),
        ),
      );
    } catch (error) {
      throw NoteFailure('Could not save local notes: $error');
    }
  }

  Future<T> _change<T>(
    String uid,
    T Function(List<Note> notes, Set<String> labels) update, {
    bool emitLabels = true,
  }) async {
    await _ensureLoaded(uid);
    final previous = _writeTailsByUid[uid] ?? Future<void>.value();
    final release = Completer<void>();
    _writeTailsByUid[uid] = release.future;
    await previous;
    try {
      final notes = List<Note>.of(_notesByUid[uid]!);
      final labels = Set<String>.of(_labelsByUid[uid]!);
      final result = update(notes, labels);
      await _saveSnapshot(uid, notes, labels);
      _notesByUid[uid] = notes;
      _labelsByUid[uid] = labels;
      _emitNotes(uid);
      if (emitLabels) _emitLabels(uid);
      return result;
    } finally {
      release.complete();
      if (identical(_writeTailsByUid[uid], release.future)) {
        _writeTailsByUid.remove(uid);
      }
    }
  }

  Set<String> _labelSetFor(String uid) {
    _bucketFor(uid);
    return _labelsByUid.putIfAbsent(uid, () => <String>{});
  }

  List<String> _sortedLabelsFor(String uid) {
    final labels = _labelSetFor(uid).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(labels);
  }

  void _emitNotes(String uid) {
    final controller = _noteControllersByUid[uid];
    if (controller != null && !controller.isClosed) {
      controller.add(List<Note>.unmodifiable(sortNotes(_bucketFor(uid))));
    }
    _emitSharedNotesForAll();
  }

  List<Note> _sharedNotesFor(String uid, {String? email}) {
    final normalizedEmail = (email ?? _uidToEmail[uid])?.trim().toLowerCase();
    final shared = <Note>[];
    for (final entry in _notesByUid.entries) {
      if (entry.key == uid) continue;
      for (final note in entry.value) {
        if (note.shareFor(uid: uid, email: normalizedEmail) != null) {
          shared.add(note);
        }
      }
    }
    return List<Note>.unmodifiable(sortNotes(shared));
  }

  void _emitSharedNotesForAll() {
    for (final entry in _sharedNoteControllersByUid.entries) {
      final controller = entry.value;
      if (!controller.isClosed) {
        controller.add(_sharedNotesFor(entry.key));
      }
    }
  }

  void _emitLabels(String uid) {
    final controller = _labelControllersByUid[uid];
    if (controller != null && !controller.isClosed) {
      controller.add(_sortedLabelsFor(uid));
    }
  }

  String _validateLabelName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const NoteFailure('Label name cannot be empty.');
    }
    if (trimmed.length > 32) {
      throw const NoteFailure('Label name must be 32 characters or fewer.');
    }
    return trimmed;
  }

  Future<void> _guardWrite() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }

  @override
  Stream<List<Note>> watchNotes(String uid) {
    final controller = _noteControllersByUid.putIfAbsent(
      uid,
      () => StreamController<List<Note>>.broadcast(),
    );

    return Stream<List<Note>>.multi((multi) {
      StreamSubscription<List<Note>>? subscription;
      var cancelled = false;
      multi.onCancel = () {
        cancelled = true;
        return subscription?.cancel();
      };
      () async {
        try {
          await _ensureLoaded(uid);
          if (cancelled) return;
          multi.add(List<Note>.unmodifiable(sortNotes(_bucketFor(uid))));
          subscription = controller.stream.listen(
            multi.add,
            onError: multi.addError,
            onDone: multi.close,
          );
        } catch (error, stackTrace) {
          if (!cancelled) multi.addError(error, stackTrace);
        }
      }();
    });
  }

  @override
  Future<List<Note>> listNotes(String uid) async {
    await _ensureLoaded(uid);
    return List<Note>.unmodifiable(sortNotes(_bucketFor(uid)));
  }

  @override
  Future<Note> saveNote(String uid, Note note) async {
    await _guardWrite();
    // Check if this is a collaborator editing a shared note owned by another UID (R25, R26).
    if (note.ownerUid != null && note.ownerUid != uid) {
      final ownerUid = note.ownerUid!;
      await _ensureLoaded(ownerUid);
      return _change(ownerUid, (ownerBucket, ownerLabelSet) {
        final index = ownerBucket.indexWhere((item) => item.id == note.id);
        if (index == -1) {
          throw const NoteFailure('Bạn không có quyền chỉnh sửa ghi chú này.');
        }
        final existing = ownerBucket[index];
        final share = existing.shareFor(uid: uid, email: _uidToEmail[uid]);
        if (share == null) {
          throw const NoteFailure('Bạn không có quyền chỉnh sửa ghi chú này.');
        }
        if (share.permission != NoteSharePermission.edit) {
          throw const NoteFailure(
            'You only have read-only access to this shared note.',
          );
        }
        if (existing.isPasswordProtected &&
            !isNoteUnlocked(uid, existing.id) &&
            !isNoteUnlocked(ownerUid, existing.id)) {
          throw const NoteFailure(
            'This note is password-protected. Unlock it before editing.',
          );
        }

        final cleanedLabels = <String>[];
        for (final label in note.labels) {
          final trimmed = label.trim();
          if (trimmed.isNotEmpty && !cleanedLabels.contains(trimmed)) {
            cleanedLabels.add(trimmed);
            ownerLabelSet.add(trimmed);
          }
        }

        final updated = existing.copyWith(
          title: note.title,
          content: note.content,
          labels: List<String>.unmodifiable(cleanedLabels),
          colorIndex: note.colorIndex,
          updatedAt: note.updatedAt,
          status: note.status,
          attachments: note.attachments,
          syncStatus: NoteSyncStatus.pending,
        );
        ownerBucket[index] = updated;
        return updated;
      });
    }

    return _change(uid, (bucket, labelSet) {
      final index = bucket.indexWhere((existing) => existing.id == note.id);
      if (index != -1) {
        final existing = bucket[index];
        if (existing.isPasswordProtected && !isNoteUnlocked(uid, existing.id)) {
          throw const NoteFailure(
            'This note is password-protected. Unlock it before editing.',
          );
        }
      }

      final cleanedLabels = <String>[];
      for (final label in note.labels) {
        final trimmed = label.trim();
        if (trimmed.isNotEmpty && !cleanedLabels.contains(trimmed)) {
          cleanedLabels.add(trimmed);
          labelSet.add(trimmed);
        }
      }

      final scopedAttachments = <NoteAttachment>[];
      for (final attachment in note.attachments) {
        if (attachment.ownerUid != null && attachment.ownerUid != uid) {
          throw const NoteFailure(
            'Bạn không có quyền đính kèm tệp của tài khoản khác.',
          );
        }
        scopedAttachments.add(attachment.copyWith(ownerUid: uid));
      }

      final existing = index == -1 ? null : bucket[index];
      final scoped = note.copyWith(
        ownerUid: uid,
        ownerEmail: note.ownerEmail ?? existing?.ownerEmail ?? _uidToEmail[uid],
        labels: List<String>.unmodifiable(cleanedLabels),
        attachments: List<NoteAttachment>.unmodifiable(scopedAttachments),
        passwordHash: note.passwordHash ?? existing?.passwordHash,
        passwordSalt: note.passwordSalt ?? existing?.passwordSalt,
        shares: note.shares.isNotEmpty
            ? note.shares
            : (existing?.shares ?? const <NoteShareEntry>[]),
        syncStatus: NoteSyncStatus.pending,
      );
      if (index == -1) {
        bucket.add(scoped);
      } else {
        bucket[index] = scoped;
      }
      if (scoped.isPasswordProtected) {
        _unlockedNotesByUid.putIfAbsent(uid, () => <String>{}).add(scoped.id);
      }
      return scoped;
    });
  }

  @override
  Future<Note> updateSyncStatus(
    String uid,
    String noteId,
    NoteSyncStatus status,
  ) {
    return _change(uid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure('Không tìm thấy ghi chú.');
      }
      final updated = bucket[index].copyWith(syncStatus: status);
      bucket[index] = updated;
      return updated;
    }, emitLabels: false);
  }

  @override
  Future<void> deleteNote(String uid, String noteId) async {
    await _guardWrite();
    await _change<void>(uid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        final ownedByOther = _notesByUid.entries.any(
          (entry) =>
              entry.key != uid && entry.value.any((note) => note.id == noteId),
        );
        if (ownedByOther) {
          throw const NoteFailure('Only the note owner can delete this note.');
        }
        return;
      }
      if (bucket[index].isPasswordProtected && !isNoteUnlocked(uid, noteId)) {
        throw const NoteFailure(
          'This note is password-protected. Unlock it before deleting.',
        );
      }
      bucket.removeWhere((note) => note.id == noteId);
      _unlockedNotesByUid[uid]?.remove(noteId);
    }, emitLabels: false);
  }

  @override
  Future<Note> togglePin(String uid, String noteId, {DateTime? now}) async {
    await _guardWrite();
    return _change(uid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure('Không tìm thấy ghi chú.');
      }
      final existing = bucket[index];
      final pinning = !existing.isPinned;
      final timestamp = now ?? DateTime.now();
      final updated = existing.copyWith(
        isPinned: pinning,
        pinnedAt: pinning ? timestamp : null,
        clearPinnedAt: !pinning,
        updatedAt: timestamp,
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      return updated;
    }, emitLabels: false);
  }

  @override
  Stream<List<String>> watchLabels(String uid) {
    final controller = _labelControllersByUid.putIfAbsent(
      uid,
      () => StreamController<List<String>>.broadcast(),
    );

    return Stream<List<String>>.multi((multi) {
      StreamSubscription<List<String>>? subscription;
      var cancelled = false;
      multi.onCancel = () {
        cancelled = true;
        return subscription?.cancel();
      };
      () async {
        try {
          await _ensureLoaded(uid);
          if (cancelled) return;
          multi.add(_sortedLabelsFor(uid));
          subscription = controller.stream.listen(
            multi.add,
            onError: multi.addError,
            onDone: multi.close,
          );
        } catch (error, stackTrace) {
          if (!cancelled) multi.addError(error, stackTrace);
        }
      }();
    });
  }

  @override
  Future<List<String>> listLabels(String uid) async {
    await _ensureLoaded(uid);
    return _sortedLabelsFor(uid);
  }

  @override
  Future<List<String>> addLabel(String uid, String label) async {
    await _guardWrite();
    final normalized = _validateLabelName(label);
    return _change(uid, (_, labelSet) {
      final duplicate = labelSet.any(
        (existing) => existing.toLowerCase() == normalized.toLowerCase(),
      );
      if (duplicate) {
        throw const NoteFailure('Label already exists.');
      }
      labelSet.add(normalized);
      return _sortedLabelsFrom(labelSet);
    }, emitLabels: true);
  }

  @override
  Future<List<String>> renameLabel(
    String uid, {
    required String oldLabel,
    required String newLabel,
  }) async {
    await _guardWrite();
    final targetOld = oldLabel.trim();
    final normalizedNew = _validateLabelName(newLabel);
    return _change(uid, (bucket, labelSet) {
      if (!labelSet.contains(targetOld)) {
        throw const NoteFailure('Label not found.');
      }
      final conflictsWithOther = labelSet.any(
        (existing) =>
            existing != targetOld &&
            existing.toLowerCase() == normalizedNew.toLowerCase(),
      );
      if (conflictsWithOther) {
        throw const NoteFailure('Label already exists.');
      }

      labelSet
        ..remove(targetOld)
        ..add(normalizedNew);

      for (var i = 0; i < bucket.length; i++) {
        final note = bucket[i];
        if (!note.labels.contains(targetOld)) continue;
        final updatedLabels = <String>[];
        for (final item in note.labels) {
          final replacement = item == targetOld ? normalizedNew : item;
          if (!updatedLabels.contains(replacement)) {
            updatedLabels.add(replacement);
          }
        }
        bucket[i] = note.copyWith(
          labels: List<String>.unmodifiable(updatedLabels),
          syncStatus: NoteSyncStatus.pending,
        );
      }

      return _sortedLabelsFrom(labelSet);
    });
  }

  @override
  Future<List<String>> deleteLabel(String uid, String label) async {
    await _guardWrite();
    final target = label.trim();
    return _change(uid, (bucket, labelSet) {
      labelSet.remove(target);
      for (var i = 0; i < bucket.length; i++) {
        final note = bucket[i];
        if (!note.labels.contains(target)) continue;
        final remaining = note.labels.where((item) => item != target).toList();
        bucket[i] = note.copyWith(
          labels: List<String>.unmodifiable(remaining),
          syncStatus: NoteSyncStatus.pending,
        );
      }
      return _sortedLabelsFrom(labelSet);
    });
  }

  @override
  Future<Note> enableNotePassword(
    String uid,
    String noteId, {
    required String password,
    required String confirmPassword,
  }) async {
    await _guardWrite();
    final validated = NotePasswordSecurity.validateNewPassword(
      password: password,
      confirmPassword: confirmPassword,
    );
    return _change(uid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure('Không tìm thấy ghi chú.');
      }
      final existing = bucket[index];
      if (existing.isPasswordProtected) {
        throw const NoteFailure(
          'Note is already password-protected. Use change password instead.',
        );
      }
      final salt = NotePasswordSecurity.generateSalt();
      final hash = NotePasswordSecurity.hashPassword(
        password: validated,
        salt: salt,
      );
      final updated = existing.copyWith(
        passwordSalt: salt,
        passwordHash: hash,
        updatedAt: DateTime.now(),
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      _unlockedNotesByUid.putIfAbsent(uid, () => <String>{}).add(noteId);
      return updated;
    }, emitLabels: false);
  }

  @override
  Future<bool> verifyNotePassword(
    String uid,
    String noteId,
    String password,
  ) async {
    await _ensureLoaded(uid);
    final bucket = _bucketFor(uid);
    final index = bucket.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      throw const NoteFailure('Không tìm thấy ghi chú.');
    }
    final existing = bucket[index];
    if (!existing.isPasswordProtected) {
      return true;
    }
    final ok = NotePasswordSecurity.verifyPassword(
      password: password,
      salt: existing.passwordSalt,
      expectedHash: existing.passwordHash,
    );
    if (!ok) {
      throw const NoteFailure('Incorrect note password.');
    }
    _unlockedNotesByUid.putIfAbsent(uid, () => <String>{}).add(noteId);
    return true;
  }

  @override
  Future<Note> changeNotePassword(
    String uid,
    String noteId, {
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await _guardWrite();
    final validatedNew = NotePasswordSecurity.validateNewPassword(
      password: newPassword,
      confirmPassword: confirmNewPassword,
    );
    return _change(uid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure('Không tìm thấy ghi chú.');
      }
      final existing = bucket[index];
      if (!existing.isPasswordProtected) {
        throw const NoteFailure('This note does not have a password set.');
      }
      final verified = NotePasswordSecurity.verifyPassword(
        password: currentPassword,
        salt: existing.passwordSalt,
        expectedHash: existing.passwordHash,
      );
      if (!verified) {
        throw const NoteFailure('Current note password is incorrect.');
      }
      final newSalt = NotePasswordSecurity.generateSalt();
      final newHash = NotePasswordSecurity.hashPassword(
        password: validatedNew,
        salt: newSalt,
      );
      final updated = existing.copyWith(
        passwordSalt: newSalt,
        passwordHash: newHash,
        updatedAt: DateTime.now(),
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      _unlockedNotesByUid.putIfAbsent(uid, () => <String>{}).add(noteId);
      return updated;
    }, emitLabels: false);
  }

  @override
  Future<Note> disableNotePassword(
    String uid,
    String noteId, {
    required String currentPassword,
  }) async {
    await _guardWrite();
    return _change(uid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure('Không tìm thấy ghi chú.');
      }
      final existing = bucket[index];
      if (!existing.isPasswordProtected) {
        return existing;
      }
      final verified = NotePasswordSecurity.verifyPassword(
        password: currentPassword,
        salt: existing.passwordSalt,
        expectedHash: existing.passwordHash,
      );
      if (!verified) {
        throw const NoteFailure('Current note password is incorrect.');
      }
      final updated = existing.copyWith(
        clearPasswordProtection: true,
        updatedAt: DateTime.now(),
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      _unlockedNotesByUid[uid]?.remove(noteId);
      return updated;
    }, emitLabels: false);
  }

  @override
  bool isNoteUnlocked(String uid, String noteId) {
    return _unlockedNotesByUid[uid]?.contains(noteId) ?? false;
  }

  @override
  void lockNoteSession(String uid, String noteId) {
    _unlockedNotesByUid[uid]?.remove(noteId);
  }

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  String _validateRecipientEmail(String rawEmail, {String? ownerEmail}) {
    final normalized = rawEmail.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const NoteFailure('Recipient email address cannot be empty.');
    }
    if (!_emailPattern.hasMatch(normalized)) {
      throw const NoteFailure('Enter a valid recipient email address.');
    }
    final cleanOwner = ownerEmail?.trim().toLowerCase();
    if (cleanOwner != null && cleanOwner == normalized) {
      throw const NoteFailure('You cannot share a note with yourself.');
    }
    if (requireRegisteredRecipients && !_emailToUid.containsKey(normalized)) {
      throw const NoteFailure(
        'No registered account found for that email address.',
      );
    }
    return normalized;
  }

  @override
  void registerAccountIdentity({required String uid, required String email}) {
    final cleanUid = uid.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanUid.isEmpty || cleanEmail.isEmpty) return;
    _emailToUid[cleanEmail] = cleanUid;
    _uidToEmail[cleanUid] = cleanEmail;

    // Backfill recipientUid on any existing shares targeting cleanEmail.
    for (final entry in _notesByUid.entries) {
      final bucket = entry.value;
      for (var i = 0; i < bucket.length; i++) {
        final note = bucket[i];
        if (!note.isShared) continue;
        var changed = false;
        final updatedShares = note.shares.map((share) {
          if (share.normalizedRecipientEmail == cleanEmail &&
              share.recipientUid != cleanUid) {
            changed = true;
            return share.copyWith(recipientUid: cleanUid);
          }
          return share;
        }).toList();
        if (changed) {
          bucket[i] = note.copyWith(
            shares: List<NoteShareEntry>.unmodifiable(updatedShares),
          );
        }
      }
    }
    _emitSharedNotesForAll();
  }

  @override
  Stream<List<Note>> watchSharedWithMe(String uid, {String? email}) {
    if (email != null && email.trim().isNotEmpty) {
      registerAccountIdentity(uid: uid, email: email);
    }
    final controller = _sharedNoteControllersByUid.putIfAbsent(
      uid,
      () => StreamController<List<Note>>.broadcast(),
    );

    return Stream<List<Note>>.multi((multi) {
      StreamSubscription<List<Note>>? subscription;
      var cancelled = false;
      multi.onCancel = () {
        cancelled = true;
        return subscription?.cancel();
      };
      () async {
        try {
          await _ensureLoaded(uid);
          if (cancelled) return;
          multi.add(_sharedNotesFor(uid, email: email));
          subscription = controller.stream.listen(
            multi.add,
            onError: multi.addError,
            onDone: multi.close,
          );
        } catch (error, stackTrace) {
          if (!cancelled) multi.addError(error, stackTrace);
        }
      }();
    });
  }

  @override
  Future<List<Note>> listSharedWithMe(String uid, {String? email}) async {
    if (email != null && email.trim().isNotEmpty) {
      registerAccountIdentity(uid: uid, email: email);
    }
    await _ensureLoaded(uid);
    return _sharedNotesFor(uid, email: email);
  }

  @override
  Future<Note> shareNote(
    String ownerUid,
    String noteId, {
    required String recipientEmail,
    required NoteSharePermission permission,
    String? ownerEmail,
  }) async {
    await _guardWrite();
    final resolvedOwnerEmail =
        (ownerEmail ?? _uidToEmail[ownerUid] ?? 'owner@noteflow.app')
            .trim()
            .toLowerCase();
    if (ownerEmail != null && ownerEmail.trim().isNotEmpty) {
      registerAccountIdentity(uid: ownerUid, email: resolvedOwnerEmail);
    }
    final normalizedRecipient = _validateRecipientEmail(
      recipientEmail,
      ownerEmail: resolvedOwnerEmail,
    );
    final recipientUid = _emailToUid[normalizedRecipient];
    if (recipientUid == ownerUid) {
      throw const NoteFailure('You cannot share a note with yourself.');
    }

    return _change(ownerUid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure(
          'Only the note owner can manage sharing permissions.',
        );
      }
      final existing = bucket[index];
      if (existing.ownerUid != null && existing.ownerUid != ownerUid) {
        throw const NoteFailure(
          'Only the note owner can manage sharing permissions.',
        );
      }
      if (existing.isPasswordProtected &&
          !isNoteUnlocked(ownerUid, existing.id)) {
        throw const NoteFailure(
          'Unlock this password-protected note before sharing it.',
        );
      }
      final duplicate = existing.shares.any(
        (entry) => entry.normalizedRecipientEmail == normalizedRecipient,
      );
      if (duplicate) {
        throw const NoteFailure(
          'This note is already shared with that email address.',
        );
      }

      final now = DateTime.now();
      final newEntry = NoteShareEntry(
        recipientEmail: normalizedRecipient,
        recipientUid: recipientUid,
        permission: permission,
        sharedAt: now,
        sharedByEmail: resolvedOwnerEmail,
        sharedByUid: ownerUid,
      );
      final updated = existing.copyWith(
        ownerUid: ownerUid,
        ownerEmail: existing.ownerEmail ?? resolvedOwnerEmail,
        shares: List<NoteShareEntry>.unmodifiable([
          ...existing.shares,
          newEntry,
        ]),
        updatedAt: now,
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      return updated;
    }, emitLabels: false);
  }

  @override
  Future<Note> updateSharePermission(
    String ownerUid,
    String noteId, {
    required String recipientEmail,
    required NoteSharePermission permission,
  }) async {
    await _guardWrite();
    final normalizedRecipient = recipientEmail.trim().toLowerCase();
    return _change(ownerUid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure(
          'Only the note owner can manage sharing permissions.',
        );
      }
      final existing = bucket[index];
      if (existing.ownerUid != null && existing.ownerUid != ownerUid) {
        throw const NoteFailure(
          'Only the note owner can manage sharing permissions.',
        );
      }
      var found = false;
      final updatedShares = existing.shares.map((entry) {
        if (entry.normalizedRecipientEmail == normalizedRecipient) {
          found = true;
          return entry.copyWith(permission: permission);
        }
        return entry;
      }).toList();
      if (!found) {
        throw const NoteFailure('Recipient not found in share list.');
      }
      final updated = existing.copyWith(
        shares: List<NoteShareEntry>.unmodifiable(updatedShares),
        updatedAt: DateTime.now(),
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      return updated;
    }, emitLabels: false);
  }

  @override
  Future<Note> revokeShare(
    String ownerUid,
    String noteId, {
    required String recipientEmail,
  }) async {
    await _guardWrite();
    final normalizedRecipient = recipientEmail.trim().toLowerCase();
    return _change(ownerUid, (bucket, _) {
      final index = bucket.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        throw const NoteFailure(
          'Only the note owner can manage sharing permissions.',
        );
      }
      final existing = bucket[index];
      if (existing.ownerUid != null && existing.ownerUid != ownerUid) {
        throw const NoteFailure(
          'Only the note owner can manage sharing permissions.',
        );
      }
      final remaining = existing.shares
          .where(
            (entry) => entry.normalizedRecipientEmail != normalizedRecipient,
          )
          .toList();
      final updated = existing.copyWith(
        shares: List<NoteShareEntry>.unmodifiable(remaining),
        updatedAt: DateTime.now(),
        syncStatus: NoteSyncStatus.pending,
      );
      bucket[index] = updated;
      return updated;
    }, emitLabels: false);
  }

  @override
  Future<List<Note>> synchronizeNotes(
    String uid, {
    bool simulateOfflineFailure = false,
  }) async {
    await _guardWrite();
    if (simulateOfflineFailure) {
      await _change(uid, (bucket, _) {
        for (var i = 0; i < bucket.length; i++) {
          final current = bucket[i];
          if (current.syncStatus != NoteSyncStatus.synced) {
            bucket[i] = current.copyWith(syncStatus: NoteSyncStatus.failed);
          }
        }
        return null;
      }, emitLabels: false);
      throw const NoteFailure(
        'Offline or network error: pending changes are saved locally and will sync when online.',
      );
    }

    return _change(uid, (bucket, _) {
      for (var i = 0; i < bucket.length; i++) {
        final current = bucket[i];
        if (current.syncStatus != NoteSyncStatus.synced) {
          bucket[i] = current.copyWith(syncStatus: NoteSyncStatus.synced);
        }
      }
      return List<Note>.unmodifiable(sortNotes(bucket));
    }, emitLabels: false);
  }

  @override
  Future<Note> resolveConflict(
    String uid, {
    required Note localNote,
    required Note remoteNote,
  }) async {
    await _guardWrite();
    if (localNote.id != remoteNote.id) {
      throw const NoteFailure(
        'Cannot resolve conflict for notes with different IDs.',
      );
    }

    return _change(uid, (bucket, labelSet) {
      // Deterministic Last-Write-Wins (LWW) by updatedAt timestamp, with safe
      // content preservation if both copies contain distinct non-empty bodies.
      final localIsNewer = !localNote.updatedAt.isBefore(remoteNote.updatedAt);
      final winner = localIsNewer ? localNote : remoteNote;
      final loser = localIsNewer ? remoteNote : localNote;

      var resolvedContent = winner.content;
      if (loser.content.trim().isNotEmpty &&
          loser.content.trim() != winner.content.trim() &&
          !winner.content.contains(loser.content.trim())) {
        resolvedContent =
            '${winner.content}\n\n--- [Conflict backup from ${loser.updatedAt.toIso8601String()}] ---\n${loser.content}';
      }

      final mergedLabels = <String>{...winner.labels, ...loser.labels}.toList();
      final mergedAttachments = <NoteAttachment>[...winner.attachments];
      for (final att in loser.attachments) {
        if (!mergedAttachments.any((item) => item.id == att.id)) {
          mergedAttachments.add(att);
        }
      }

      final resolved = winner.copyWith(
        ownerUid: uid,
        content: resolvedContent,
        labels: List<String>.unmodifiable(mergedLabels),
        attachments: List<NoteAttachment>.unmodifiable(mergedAttachments),
        syncStatus: NoteSyncStatus.synced,
      );

      for (final label in resolved.labels) {
        labelSet.add(label);
      }

      final index = bucket.indexWhere((item) => item.id == resolved.id);
      if (index == -1) {
        bucket.add(resolved);
      } else {
        bucket[index] = resolved;
      }
      return resolved;
    });
  }

  List<String> _sortedLabelsFrom(Set<String> labels) {
    final sorted = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(sorted);
  }

  Future<void> dispose() async {
    for (final controller in _noteControllersByUid.values) {
      await controller.close();
    }
    for (final controller in _sharedNoteControllersByUid.values) {
      await controller.close();
    }
    for (final controller in _labelControllersByUid.values) {
      await controller.close();
    }
    _noteControllersByUid.clear();
    _sharedNoteControllersByUid.clear();
    _labelControllersByUid.clear();
    _loadsByUid.clear();
  }
}
