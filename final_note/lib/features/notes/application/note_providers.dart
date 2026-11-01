import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/note.dart';
import '../../auth/application/auth_providers.dart';
import '../data/in_memory_note_repository.dart';
import '../domain/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final repository = InMemoryNoteRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Watches notes for the active [AccountSession] and cancels immediately when
/// the account changes or signs out (per docs/auth-contract.md).
final accountNotesStreamProvider = StreamProvider.autoDispose<List<Note>>((
  ref,
) {
  final session = ref.watch(accountSessionProvider);
  if (session == null || !session.isActive) {
    return const Stream<List<Note>>.empty();
  }
  final repository = ref.watch(noteRepositoryProvider);
  final controller = StreamController<List<Note>>();
  final subscription = repository
      .watchNotes(session.uid)
      .listen(
        (notes) {
          if (session.isActive && !controller.isClosed) {
            controller.add(notes);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (session.isActive && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Watches the label catalog for the active [AccountSession] (R20).
final accountLabelsStreamProvider = StreamProvider.autoDispose<List<String>>((
  ref,
) {
  final session = ref.watch(accountSessionProvider);
  if (session == null || !session.isActive) {
    return const Stream<List<String>>.empty();
  }
  final repository = ref.watch(noteRepositoryProvider);
  final controller = StreamController<List<String>>();
  final subscription = repository
      .watchLabels(session.uid)
      .listen(
        (labels) {
          if (session.isActive && !controller.isClosed) {
            controller.add(labels);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (session.isActive && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

enum NoteAutosavePhase { idle, saving, saved, error }

class NoteActionState {
  const NoteActionState({
    this.busy = false,
    this.autosavePhase = NoteAutosavePhase.idle,
    this.error,
    this.lastSavedAt,
  });

  final bool busy;
  final NoteAutosavePhase autosavePhase;
  final String? error;
  final DateTime? lastSavedAt;

  NoteActionState copyWith({
    bool? busy,
    NoteAutosavePhase? autosavePhase,
    String? error,
    bool clearError = false,
    DateTime? lastSavedAt,
  }) {
    return NoteActionState(
      busy: busy ?? this.busy,
      autosavePhase: autosavePhase ?? this.autosavePhase,
      error: clearError ? null : (error ?? this.error),
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

final noteActionsProvider =
    NotifierProvider.autoDispose<NoteActions, NoteActionState>(NoteActions.new);

class NoteActions extends Notifier<NoteActionState> {
  @override
  NoteActionState build() {
    ref.listen<AccountSession?>(accountSessionProvider, (previous, next) {
      if (previous?.uid != next?.uid) {
        state = const NoteActionState();
      }
    });
    return const NoteActionState();
  }

  AccountSession? _activeSession() {
    final session = ref.read(accountSessionProvider);
    if (session == null || !session.isActive) return null;
    return session;
  }

  Future<Note?> saveNote(Note note, {bool isAutosave = false}) async {
    final session = _activeSession();
    if (session == null) return null;

    state = state.copyWith(
      busy: !isAutosave,
      autosavePhase: NoteAutosavePhase.saving,
      clearError: true,
    );

    try {
      final repository = ref.read(noteRepositoryProvider);
      final saved = await repository.saveNote(session.uid, note);
      if (!ref.mounted || !session.isActive) return null;
      state = NoteActionState(
        busy: false,
        autosavePhase: NoteAutosavePhase.saved,
        lastSavedAt: saved.updatedAt,
      );
      return saved;
    } on NoteFailure catch (error) {
      if (ref.mounted && session.isActive) {
        state = NoteActionState(
          busy: false,
          autosavePhase: NoteAutosavePhase.error,
          error: error.message,
        );
      }
      return null;
    } catch (_) {
      if (ref.mounted && session.isActive) {
        state = const NoteActionState(
          busy: false,
          autosavePhase: NoteAutosavePhase.error,
          error: 'Không thể lưu ghi chú. Vui lòng thử lại.',
        );
      }
      return null;
    }
  }

  Future<bool> deleteNote(String noteId) async {
    final session = _activeSession();
    if (session == null) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final repository = ref.read(noteRepositoryProvider);
      await repository.deleteNote(session.uid, noteId);
      if (!ref.mounted || !session.isActive) return false;
      state = state.copyWith(busy: false, clearError: true);
      return true;
    } on NoteFailure catch (error) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(busy: false, error: error.message);
      }
      return false;
    } catch (_) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(
          busy: false,
          error: 'Không thể xoá ghi chú. Vui lòng thử lại.',
        );
      }
      return false;
    }
  }

  Future<Note?> togglePin(String noteId) async {
    final session = _activeSession();
    if (session == null) return null;

    try {
      final repository = ref.read(noteRepositoryProvider);
      final updated = await repository.togglePin(session.uid, noteId);
      if (!ref.mounted || !session.isActive) return null;
      return updated;
    } on NoteFailure catch (error) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: error.message);
      }
      return null;
    } catch (_) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(
          error: 'Không thể cập nhật trạng thái ghim. Vui lòng thử lại.',
        );
      }
      return null;
    }
  }

  Future<bool> addLabel(String label) async {
    final session = _activeSession();
    if (session == null) return false;

    try {
      final repository = ref.read(noteRepositoryProvider);
      await repository.addLabel(session.uid, label);
      if (!ref.mounted || !session.isActive) return false;
      state = state.copyWith(clearError: true);
      return true;
    } on NoteFailure catch (error) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: error.message);
      }
      return false;
    } catch (_) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: 'Could not add label.');
      }
      return false;
    }
  }

  Future<bool> renameLabel({
    required String oldLabel,
    required String newLabel,
  }) async {
    final session = _activeSession();
    if (session == null) return false;

    try {
      final repository = ref.read(noteRepositoryProvider);
      await repository.renameLabel(
        session.uid,
        oldLabel: oldLabel,
        newLabel: newLabel,
      );
      if (!ref.mounted || !session.isActive) return false;
      state = state.copyWith(clearError: true);
      return true;
    } on NoteFailure catch (error) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: error.message);
      }
      return false;
    } catch (_) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: 'Could not rename label.');
      }
      return false;
    }
  }

  Future<bool> deleteLabel(String label) async {
    final session = _activeSession();
    if (session == null) return false;

    try {
      final repository = ref.read(noteRepositoryProvider);
      await repository.deleteLabel(session.uid, label);
      if (!ref.mounted || !session.isActive) return false;
      state = state.copyWith(clearError: true);
      return true;
    } on NoteFailure catch (error) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: error.message);
      }
      return false;
    } catch (_) {
      if (ref.mounted && session.isActive) {
        state = state.copyWith(error: 'Could not delete label.');
      }
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
