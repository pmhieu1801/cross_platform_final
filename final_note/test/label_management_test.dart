import 'package:final_note/features/notes/data/in_memory_note_repository.dart';
import 'package:final_note/features/notes/domain/note_repository.dart';
import 'package:final_note/models/note.dart';
import 'package:final_note/screens/note_editor_sheet.dart';
import 'package:final_note/screens/notes_home_screen.dart';
import 'package:final_note/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.dark, home: child);
}

void main() {
  group('Label repository semantics (R20, R21)', () {
    late InMemoryNoteRepository repo;

    setUp(() {
      repo = InMemoryNoteRepository(seedDemoNotes: false);
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('adds labels, rejects duplicates, renames preserving note associations, and deletes without deleting notes', () async {
      const uid = 'uid-label-test';
      final note = Note(
        id: 'n1',
        title: 'Architecture Spec',
        content: 'Riverpod + Firebase',
        labels: const ['Work', 'Urgent'],
        colorIndex: 0,
        updatedAt: DateTime(2026, 10, 25),
      );
      await repo.saveNote(uid, note);
      expect(await repo.listLabels(uid), ['Urgent', 'Work']);

      // Add a new label.
      await repo.addLabel(uid, 'Research');
      expect(await repo.listLabels(uid), ['Research', 'Urgent', 'Work']);

      // Case-insensitive duplicate is rejected.
      await expectLater(
        () => repo.addLabel(uid, 'work'),
        throwsA(isA<NoteFailure>()),
      );

      // Rename 'Work' -> 'Engineering' updates the note's labels.
      await repo.renameLabel(uid, oldLabel: 'Work', newLabel: 'Engineering');
      expect(await repo.listLabels(uid), ['Engineering', 'Research', 'Urgent']);
      final afterRename = (await repo.listNotes(uid)).single;
      expect(afterRename.labels, ['Engineering', 'Urgent']);

      // Delete 'Urgent' detaches it from the note without deleting the note itself.
      await repo.deleteLabel(uid, 'Urgent');
      expect(await repo.listLabels(uid), ['Engineering', 'Research']);
      final afterDelete = (await repo.listNotes(uid)).single;
      expect(afterDelete.id, 'n1');
      expect(afterDelete.labels, ['Engineering']);
    });
  });

  group('Label Management Dialog & Filtering UI (R19, R20, R21, R22)', () {
    testWidgets(
      'manages labels via dialog and updates filtered notes without losing notes',
      (tester) async {
        final notes = [
          Note(
            id: 'n1',
            title: 'Sprint Retro',
            content: 'Team velocity',
            labels: const ['Work'],
            colorIndex: 0,
            updatedAt: DateTime(2026, 10, 25, 10),
          ),
          Note(
            id: 'n2',
            title: 'Weekend Hike',
            content: 'Pack water',
            labels: const ['Personal'],
            colorIndex: 1,
            updatedAt: DateTime(2026, 10, 25, 11),
            isPinned: true,
            pinnedAt: DateTime(2026, 10, 25, 11),
          ),
        ];

        await tester.pumpWidget(_wrap(NotesHomeScreen(initialNotes: notes)));

        // Filter by 'Work' label chip (R22).
        await tester.tap(find.byKey(const Key('filter-label-chip-Work')));
        await tester.pumpAndSettle();
        expect(find.text('Sprint Retro'), findsOneWidget);
        expect(find.text('Weekend Hike'), findsNothing);

        // Open Manage labels dialog (R20).
        await tester.tap(find.byKey(const Key('manage-labels-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('new-label-input')), findsOneWidget);

        // Add a new label 'Study'.
        await tester.enterText(
          find.byKey(const Key('new-label-input')),
          'Study',
        );
        await tester.tap(find.byKey(const Key('add-label-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rename-label-Study')), findsOneWidget);

        // Rename 'Work' -> 'Office'.
        await tester.tap(find.byKey(const Key('rename-label-Work')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('rename-label-input-Work')),
          'Office',
        );
        await tester.tap(find.byKey(const Key('save-rename-label-Work')));
        await tester.pumpAndSettle();

        // Close dialog: active filter automatically tracks renamed label 'Office'
        // and 'Sprint Retro' now carries the 'Office' badge.
        await tester.tap(find.byKey(const Key('close-manage-labels')));
        await tester.pumpAndSettle();
        expect(find.text('Sprint Retro'), findsOneWidget);
        expect(
          find.byKey(const Key('filter-label-chip-Office')),
          findsOneWidget,
        );

        // Re-open Manage labels and delete 'Office': note 'Sprint Retro' remains!
        await tester.tap(find.byKey(const Key('manage-labels-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('delete-label-Office')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('close-manage-labels')));
        await tester.pumpAndSettle();

        expect(find.text('Sprint Retro'), findsOneWidget);
        expect(find.text('Weekend Hike'), findsOneWidget);
      },
    );

    testWidgets('attaches and detaches labels inside NoteEditorPanel (R21)', (
      tester,
    ) async {
      Note? latestSaved;
      final initial = Note(
        id: 'n-edit',
        title: 'Draft',
        content: 'Content',
        labels: const ['Personal'],
        colorIndex: 0,
        updatedAt: DateTime(2026, 10, 25),
      );

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: NoteEditorPanel(
                initialNote: initial,
                availableLabels: const ['Personal', 'Ideas'],
                debounceDuration: const Duration(milliseconds: 100),
                onSave: (draft, {required isAutosave}) async {
                  latestSaved = draft;
                  return draft;
                },
              ),
            ),
          ),
        ),
      );

      // Attach 'Ideas' via chip.
      await tester.tap(find.byKey(const Key('editor-label-chip-Ideas')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(latestSaved?.labels, containsAll(['Personal', 'Ideas']));

      // Add a brand-new label 'Urgent' from the editor input.
      await tester.enterText(
        find.byKey(const Key('editor-new-label-input')),
        'Urgent',
      );
      await tester.tap(find.byKey(const Key('editor-add-label-button')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(latestSaved?.labels, containsAll(['Personal', 'Ideas', 'Urgent']));
    });
  });
}
