import 'dart:async';

import '../../../models/note.dart';
import '../domain/note_repository.dart';

/// Account-partitioned in-memory [NoteRepository] implementation.
///
/// Each Firebase [uid] gets its own isolated bucket and broadcast stream.
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
  final Map<String, StreamController<List<Note>>> _controllersByUid =
      <String, StreamController<List<Note>>>{};

  List<Note> _bucketFor(String uid) {
    if (uid.trim().isEmpty) {
      throw const NoteFailure('Phiên đăng nhập không hợp lệ.');
    }
    return _notesByUid.putIfAbsent(
      uid,
      () =>
          seedDemoNotes ? sortNotes(createDemoNotes(ownerUid: uid)) : <Note>[],
    );
  }

  void _emit(String uid) {
    final controller = _controllersByUid[uid];
    if (controller != null && !controller.isClosed) {
      controller.add(List<Note>.unmodifiable(sortNotes(_bucketFor(uid))));
    }
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
    final controller = _controllersByUid.putIfAbsent(
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
    final scoped = note.copyWith(ownerUid: uid);
    final index = bucket.indexWhere((existing) => existing.id == scoped.id);
    if (index == -1) {
      bucket.add(scoped);
    } else {
      bucket[index] = scoped;
    }
    _emit(uid);
    return scoped;
  }

  @override
  Future<void> deleteNote(String uid, String noteId) async {
    await _guardWrite();
    final bucket = _bucketFor(uid);
    bucket.removeWhere((note) => note.id == noteId);
    _emit(uid);
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
    _emit(uid);
    return updated;
  }

  Future<void> dispose() async {
    for (final controller in _controllersByUid.values) {
      await controller.close();
    }
    _controllersByUid.clear();
  }
}
