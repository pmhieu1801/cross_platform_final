import 'dart:async';

import '../../../models/note.dart';
import '../domain/note_repository.dart';

/// Account-partitioned in-memory [NoteRepository] implementation.
///
/// Each Firebase [uid] gets its own isolated note bucket, label catalog, and
/// broadcast streams.
class InMemoryNoteRepository implements NoteRepository {
  InMemoryNoteRepository({
    this.seedDemoNotes = true,
    this.latency = Duration.zero,
  });

  final bool seedDemoNotes;
  final Duration latency;

  /// Optional test hook to inject an error on the next write operation.
  NoteFailure? nextFailure;

  final Map<String, List<Note>> _notesByUid = <String, List<Note>>{};
  final Map<String, Set<String>> _labelsByUid = <String, Set<String>>{};
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
      multi.add(List<Note>.unmodifiable(sortNotes(_bucketFor(uid))));
      final sub = controller.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = sub.cancel;
    });
  }

  @override
  Future<List<Note>> listNotes(String uid) async {
    return List<Note>.unmodifiable(sortNotes(_bucketFor(uid)));
  }

  @override
  Future<Note> saveNote(String uid, Note note) async {
    await _guardWrite();
    if (note.ownerUid != null && note.ownerUid != uid) {
      throw const NoteFailure('Bạn không có quyền chỉnh sửa ghi chú này.');
    }

    final bucket = _bucketFor(uid);
    final labelSet = _labelSetFor(uid);
    final cleanedLabels = <String>[];
    for (final label in note.labels) {
      final trimmed = label.trim();
      if (trimmed.isNotEmpty && !cleanedLabels.contains(trimmed)) {
        cleanedLabels.add(trimmed);
        labelSet.add(trimmed);
      }
    }

    final scoped = note.copyWith(
      ownerUid: uid,
      labels: List<String>.unmodifiable(cleanedLabels),
    );
    final index = bucket.indexWhere((existing) => existing.id == scoped.id);
    if (index == -1) {
      bucket.add(scoped);
    } else {
      bucket[index] = scoped;
    }
    _emitNotes(uid);
    _emitLabels(uid);
    return scoped;
  }

  @override
  Future<void> deleteNote(String uid, String noteId) async {
    await _guardWrite();
    final bucket = _bucketFor(uid);
    bucket.removeWhere((note) => note.id == noteId);
    _emitNotes(uid);
  }

  @override
  Future<Note> togglePin(String uid, String noteId, {DateTime? now}) async {
    await _guardWrite();
    final bucket = _bucketFor(uid);
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
    );
    bucket[index] = updated;
    _emitNotes(uid);
    return updated;
  }

  @override
  Stream<List<String>> watchLabels(String uid) {
    final controller = _labelControllersByUid.putIfAbsent(
      uid,
      () => StreamController<List<String>>.broadcast(),
    );

    return Stream<List<String>>.multi((multi) {
      multi.add(_sortedLabelsFor(uid));
      final sub = controller.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = sub.cancel;
    });
  }

  @override
  Future<List<String>> listLabels(String uid) async {
    return _sortedLabelsFor(uid);
  }

  @override
  Future<List<String>> addLabel(String uid, String label) async {
    await _guardWrite();
    final normalized = _validateLabelName(label);
    final labelSet = _labelSetFor(uid);
    final duplicate = labelSet.any(
      (existing) => existing.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicate) {
      throw const NoteFailure('Label already exists.');
    }
    labelSet.add(normalized);
    _emitLabels(uid);
    return _sortedLabelsFor(uid);
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
    final labelSet = _labelSetFor(uid);

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

    final bucket = _bucketFor(uid);
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
      );
    }

    _emitLabels(uid);
    _emitNotes(uid);
    return _sortedLabelsFor(uid);
  }

  @override
  Future<List<String>> deleteLabel(String uid, String label) async {
    await _guardWrite();
    final target = label.trim();
    final labelSet = _labelSetFor(uid);
    labelSet.remove(target);

    final bucket = _bucketFor(uid);
    for (var i = 0; i < bucket.length; i++) {
      final note = bucket[i];
      if (!note.labels.contains(target)) continue;
      final remaining = note.labels.where((item) => item != target).toList();
      bucket[i] = note.copyWith(labels: List<String>.unmodifiable(remaining));
    }

    _emitLabels(uid);
    _emitNotes(uid);
    return _sortedLabelsFor(uid);
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
  }
}
