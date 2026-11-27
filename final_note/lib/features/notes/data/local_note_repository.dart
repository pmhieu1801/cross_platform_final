import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/note.dart';
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
  final Map<String, Future<void>> _loadsByUid = <String, Future<void>>{};
  final Map<String, Future<void>> _writeTailsByUid = <String, Future<void>>{};
  final Map<String, StreamController<List<Note>>> _noteControllersByUid =
      <String, StreamController<List<Note>>>{};
  final Map<String, StreamController<List<String>>> _labelControllersByUid =
      <String, StreamController<List<String>>>{};

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
    return _change(uid, (bucket, labelSet) {
      if (note.ownerUid != null && note.ownerUid != uid) {
        throw const NoteFailure('Bạn không có quyền chỉnh sửa ghi chú này.');
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

      final scoped = note.copyWith(
        ownerUid: uid,
        labels: List<String>.unmodifiable(cleanedLabels),
        attachments: List<NoteAttachment>.unmodifiable(scopedAttachments),
        syncStatus: NoteSyncStatus.pending,
      );
      final index = bucket.indexWhere((existing) => existing.id == scoped.id);
      if (index == -1) {
        bucket.add(scoped);
      } else {
        bucket[index] = scoped;
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
    await _change<void>(
      uid,
      (bucket, _) => bucket.removeWhere((note) => note.id == noteId),
      emitLabels: false,
    );
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

  List<String> _sortedLabelsFrom(Set<String> labels) {
    final sorted = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(sorted);
  }

  Future<void> dispose() async {
    for (final controller in _noteControllersByUid.values) {
      await controller.close();
    }
    for (final controller in _labelControllersByUid.values) {
      await controller.close();
    }
    _noteControllersByUid.clear();
    _labelControllersByUid.clear();
    _loadsByUid.clear();
  }
}
