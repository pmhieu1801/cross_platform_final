import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/notes/application/note_providers.dart';
import 'package:final_note/features/notes/data/in_memory_note_repository.dart';
import 'package:final_note/features/notes/domain/note_repository.dart';
import 'package:final_note/models/note.dart';
import 'package:final_note/screens/note_editor_sheet.dart';
import 'package:final_note/screens/notes_home_screen.dart';
import 'package:final_note/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(theme: AppTheme.dark, home: child);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('NoteRepository & UID isolation (R11, R12, R13, R17)', () {
    test(
      'isolates notes strictly per UID and cancels old account streams',
      () async {
        final fakeAuth = FakeAuthRepository();
        final repo = InMemoryNoteRepository(seedDemoNotes: false);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith((ref) async => fakeAuth),
            noteRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await fakeAuth.dispose();
          await repo.dispose();
        });

        container.listen(authSessionProvider, (_, _) {});
        container.listen(accountNotesStreamProvider, (_, _) {});
        await container.read(authRepositoryProvider.future);
        await Future<void>.delayed(Duration.zero);

        fakeAuth.events.add(userA);
        await container.read(authSessionProvider.future);
        await Future<void>.delayed(Duration.zero);

        final noteA = Note(
          id: 'note-a1',
          title: 'Secret A',
          content: 'Only for A',
          labels: const ['Personal'],
          colorIndex: 1,
          updatedAt: DateTime(2026, 10, 24, 10),
        );
        await container.read(noteActionsProvider.notifier).saveNote(noteA);
        await Future<void>.delayed(Duration.zero);

        expect(
          container
              .read(accountNotesStreamProvider)
              .asData
              ?.value
              .map((n) => n.title),
          ['Secret A'],
        );

        // Switch to userB: userA's notes must not leak into userB's stream.
        fakeAuth.events.add(userB);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(accountNotesStreamProvider).asData?.value ??
              const <Note>[],
          isEmpty,
        );

        // Cross-account write attempt must be rejected.
        await expectLater(
          () => repo.saveNote(userB.uid, noteA.copyWith(ownerUid: userA.uid)),
          throwsA(isA<NoteFailure>()),
        );
      },
    );

    test('sortNotes orders pinned notes first by pinnedAt desc, then updatedAt desc', () {
      final t1 = DateTime(2026, 10, 20);
      final t2 = DateTime(2026, 10, 21);
      final t3 = DateTime(2026, 10, 22);

      final notes = [
        Note(
          id: 'unpinned-new',
          title: 'Unpinned New',
          content: '',
          labels: const [],
          colorIndex: 0,
          updatedAt: t3,
        ),
        Note(
          id: 'pinned-older',
          title: 'Pinned Older',
          content: '',
          labels: const [],
          colorIndex: 0,
          updatedAt: t3,
          isPinned: true,
          pinnedAt: t1,
        ),
        Note(
          id: 'pinned-newer',
          title: 'Pinned Newer',
          content: '',
          labels: const [],
          colorIndex: 0,
          updatedAt: t1,
          isPinned: true,
          pinnedAt: t2,
        ),
      ];

      final sorted = sortNotes(notes);
      expect(sorted.map((n) => n.id).toList(), [
        'pinned-newer',
        'pinned-older',
        'unpinned-new',
      ]);
    });
  });

  group('NoteEditorPanel Auto-save & AppLifecycle (R11, R12, R13, R14)', () {
    testWidgets(
      'debounced auto-save persists edits and shows Retry on failure',
      (tester) async {
        final savedNotes = <Note>[];
        var shouldFail = false;

        await tester.pumpWidget(
          _wrapWithTheme(
            Scaffold(
              body: NoteEditorPanel(
                debounceDuration: const Duration(milliseconds: 150),
                onSave: (draft, {required isAutosave}) async {
                  if (shouldFail) return null;
                  savedNotes.add(draft);
                  return draft;
                },
              ),
            ),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('note-title-input')),
          'Sprint Planning',
        );
        await tester.pump();
        expect(find.text('Saving…'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 200));
        expect(savedNotes, hasLength(1));
        expect(savedNotes.last.title, 'Sprint Planning');
        expect(find.text('Saved'), findsOneWidget);

        // Simulate a save failure followed by manual retry.
        shouldFail = true;
        await tester.enterText(
          find.byKey(const Key('note-content-input')),
          'Check deliverables',
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const Key('note-autosave-retry')), findsOneWidget);

        shouldFail = false;
        await tester.tap(find.byKey(const Key('note-autosave-retry')));
        await tester.pumpAndSettle();
        expect(savedNotes.last.content, 'Check deliverables');
        expect(find.text('Saved'), findsOneWidget);
      },
    );

    testWidgets('flushes pending draft immediately when app pauses (R14)', (
      tester,
    ) async {
      final savedNotes = <Note>[];

      await tester.pumpWidget(
        _wrapWithTheme(
          Scaffold(
            body: NoteEditorPanel(
              debounceDuration: const Duration(seconds: 10),
              onSave: (draft, {required isAutosave}) async {
                savedNotes.add(draft);
                return draft;
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('note-title-input')),
        'Paused Draft',
      );
      await tester.pump();
      // Debounce timer (10s) has not fired yet.
      expect(savedNotes, isEmpty);

      // Simulate app transitioning to background/paused.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(savedNotes, hasLength(1));
      expect(savedNotes.single.title, 'Paused Draft');
    });

    testWidgets('delete confirmation dialog cancels or deletes note (R13)', (
      tester,
    ) async {
      final initial = Note(
        id: 'note-del',
        title: 'Delete Me',
        content: 'Body',
        labels: const [],
        colorIndex: 0,
        updatedAt: DateTime(2026, 10, 24),
      );

      await tester.pumpWidget(
        _wrapWithTheme(NotesHomeScreen(initialNotes: [initial])),
      );

      expect(find.text('Delete Me'), findsOneWidget);

      // Open note actions menu and tap Delete note, then Cancel.
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete note'));
      await tester.pumpAndSettle();

      expect(find.text('Delete note?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel-delete-note')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Me'), findsOneWidget);

      // Now confirm deletion.
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-note')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Me'), findsNothing);
    });

    testWidgets(
      'desktop side-by-side editor saves new notes and edits without remounting mid-typing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final existing = Note(
          id: 'note-existing',
          title: 'Initial Homework',
          content: 'Chapter 1 exercises',
          labels: const ['Study'],
          colorIndex: 3,
          updatedAt: DateTime(2026, 4, 15, 10),
        );

        await tester.pumpWidget(
          _wrapWithTheme(
            NotesHomeScreen(
              initialNotes: [existing],
              editorDebounceDuration: const Duration(milliseconds: 200),
            ),
          ),
        );

        // 1. Create a new note on wide desktop and continue typing after first autosave.
        await tester.tap(find.byKey(const Key('sidebar-create-note')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('note-title-input')),
          'Draft Title',
        );
        await tester.pump(const Duration(milliseconds: 250));

        // Continue typing after autosave fired; editor must not remount or lose text.
        await tester.enterText(
          find.byKey(const Key('note-title-input')),
          'Final Saved Title',
        );
        await tester.enterText(
          find.byKey(const Key('note-content-input')),
          'Final Saved Content Body',
        );
        await tester.tap(find.byKey(const Key('note-editor-save-button')));
        await tester.pumpAndSettle();

        expect(find.text('Final Saved Title'), findsOneWidget);
        expect(find.text('Final Saved Content Body'), findsOneWidget);

        // 2. Edit the existing note and click Save changes.
        await tester.tap(find.byKey(const Key('note-card-note-existing')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('note-title-input')),
          'Updated Homework Title',
        );
        await tester.enterText(
          find.byKey(const Key('note-content-input')),
          'Completed all chapters',
        );
        await tester.tap(find.byKey(const Key('note-editor-save-button')));
        await tester.pumpAndSettle();

        expect(find.text('Updated Homework Title'), findsOneWidget);
        expect(find.text('Completed all chapters'), findsOneWidget);
      },
    );
  });
}
