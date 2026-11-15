import 'local_note_repository.dart';

/// Non-persistent repository used by tests that need isolated in-memory state.
class InMemoryNoteRepository extends LocalNoteRepository {
  InMemoryNoteRepository({
    super.seedDemoNotes = true,
    super.latency = Duration.zero,
  }) : super.inMemory();
}
