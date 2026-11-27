import 'package:final_note/features/notes/data/local_note_repository.dart';
import 'package:final_note/features/notes/domain/note_repository.dart';
import 'package:final_note/models/note.dart';
import 'package:final_note/screens/notes_home_screen.dart';
import 'package:final_note/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Note Sharing, Permissions & Real-Time Collaboration (R25, R26)', () {
    test('shares note by email, enforces read-only vs edit permissions at repository level, and streams real-time updates and revocation', () async {
      final repo = LocalNoteRepository.inMemory(seedDemoNotes: false)
        ..requireRegisteredRecipients = true;
      addTearDown(repo.dispose);

      repo.registerAccountIdentity(
        uid: 'uid-alice',
        email: 'alice@example.com',
      );
      repo.registerAccountIdentity(uid: 'uid-bob', email: 'bob@example.com');

      final aliceUpdates = <List<Note>>[];
      final bobSharedUpdates = <List<Note>>[];

      final aliceSub = repo.watchNotes('uid-alice').listen(aliceUpdates.add);
      final bobSub = repo
          .watchSharedWithMe('uid-bob', email: 'bob@example.com')
          .listen(bobSharedUpdates.add);
      addTearDown(() async {
        await aliceSub.cancel();
        await bobSub.cancel();
      });

      await Future<void>.delayed(Duration.zero);

      final created = await repo.saveNote(
        'uid-alice',
        Note(
          id: 'note-collab',
          title: 'Architecture Spec',
          content: 'Initial draft by Alice',
          labels: const ['Engineering'],
          colorIndex: 0,
          updatedAt: DateTime(2026, 11, 26, 10),
        ),
      );

      // Self-share and unregistered email must be rejected.
      await expectLater(
        () => repo.shareNote(
          'uid-alice',
          created.id,
          recipientEmail: 'alice@example.com',
          permission: NoteSharePermission.readOnly,
          ownerEmail: 'alice@example.com',
        ),
        throwsA(isA<NoteFailure>()),
      );
      await expectLater(
        () => repo.shareNote(
          'uid-alice',
          created.id,
          recipientEmail: 'unknown@example.com',
          permission: NoteSharePermission.readOnly,
          ownerEmail: 'alice@example.com',
        ),
        throwsA(isA<NoteFailure>()),
      );

      // Share with Bob as Read-only.
      await repo.shareNote(
        'uid-alice',
        created.id,
        recipientEmail: 'bob@example.com',
        permission: NoteSharePermission.readOnly,
        ownerEmail: 'alice@example.com',
      );
      await Future<void>.delayed(Duration.zero);

      expect(bobSharedUpdates.last, hasLength(1));
      expect(bobSharedUpdates.last.single.title, 'Architecture Spec');

      // Duplicate share is rejected.
      await expectLater(
        () => repo.shareNote(
          'uid-alice',
          created.id,
          recipientEmail: 'bob@example.com',
          permission: NoteSharePermission.edit,
          ownerEmail: 'alice@example.com',
        ),
        throwsA(isA<NoteFailure>()),
      );

      // Read-only recipient cannot modify or delete note via repository!
      final bobView = bobSharedUpdates.last.single;
      await expectLater(
        () => repo.saveNote(
          'uid-bob',
          bobView.copyWith(content: 'Bob unauthorized edit'),
        ),
        throwsA(isA<NoteFailure>()),
      );
      await expectLater(
        () => repo.deleteNote('uid-bob', bobView.id),
        throwsA(isA<NoteFailure>()),
      );

      // Alice upgrades Bob's permission to Editable.
      await repo.updateSharePermission(
        'uid-alice',
        created.id,
        recipientEmail: 'bob@example.com',
        permission: NoteSharePermission.edit,
      );
      await Future<void>.delayed(Duration.zero);

      // Now Bob's edit succeeds and streams in real time to both Alice and Bob!
      final bobEditable = bobSharedUpdates.last.single;
      await repo.saveNote(
        'uid-bob',
        bobEditable.copyWith(
          content: 'Real-time edit by Bob',
          updatedAt: DateTime(2026, 11, 26, 11),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(aliceUpdates.last.single.content, 'Real-time edit by Bob');
      expect(bobSharedUpdates.last.single.content, 'Real-time edit by Bob');

      // Alice revokes Bob's access -> Bob's shared stream immediately empties.
      await repo.revokeShare(
        'uid-alice',
        created.id,
        recipientEmail: 'bob@example.com',
      );
      await Future<void>.delayed(Duration.zero);

      expect(bobSharedUpdates.last, isEmpty);
      await expectLater(
        () => repo.saveNote(
          'uid-bob',
          bobEditable.copyWith(content: 'Edit after revoke'),
        ),
        throwsA(isA<NoteFailure>()),
      );
    });

    testWidgets(
      'displays Shared with me section, R18 shared status indicators, share metadata, and read-only editor guard',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final ownNote = Note(
          id: 'own-1',
          title: 'Team Roadmap',
          content: 'Q4 deliverables',
          labels: const ['Work'],
          colorIndex: 0,
          updatedAt: DateTime(2026, 11, 26, 9),
        );
        final sharedReadOnlyNote = Note(
          id: 'shared-ro',
          title: 'Design Guidelines',
          content: 'Use solid pastel cards and formal typography.',
          labels: const ['Design'],
          colorIndex: 1,
          updatedAt: DateTime(2026, 11, 26, 10),
          ownerUid: 'uid-alice',
          ownerEmail: 'alice@example.com',
          shares: [
            NoteShareEntry(
              recipientEmail: 'bob@example.com',
              recipientUid: 'uid-bob',
              permission: NoteSharePermission.readOnly,
              sharedAt: DateTime(2026, 11, 26, 8),
              sharedByEmail: 'alice@example.com',
              sharedByUid: 'uid-alice',
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapWithTheme(
            NotesHomeScreen(
              initialNotes: [ownNote],
              sharedNotes: [sharedReadOnlyNote],
            ),
          ),
        );

        // 1. Open own note and share it via NoteShareDialog.
        await tester.tap(find.byKey(const Key('note-card-own-1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('note-editor-share-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('note-share-dialog')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('share-recipient-email-input')),
          'colleague@example.com',
        );
        await tester.tap(find.byKey(const Key('share-note-add-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('share-entry-colleague@example.com')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('share-dialog-close')));
        await tester.pumpAndSettle();

        // Own note card now shows the R18 shared status indicator.
        expect(
          find.byKey(const Key('note-shared-indicator-own-1')),
          findsOneWidget,
        );

        // 2. Switch to "Shared with me" section in sidebar.
        await tester.tap(find.byKey(const Key('nav-shared-with-me')));
        await tester.pumpAndSettle();

        expect(find.text('Design Guidelines'), findsOneWidget);
        expect(
          find.byKey(const Key('note-shared-indicator-shared-ro')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-share-permission-badge-shared-ro')),
          findsOneWidget,
        );
        expect(find.text('Read-only'), findsOneWidget);
        expect(find.textContaining('By alice@example.com'), findsOneWidget);

        // 3. Tap the read-only shared note -> opens NoteEditorPanel in read-only mode.
        await tester.tap(find.byKey(const Key('note-card-shared-ro')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('note-editor-readonly-banner')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('note-editor-save-button')), findsNothing);
        expect(find.byKey(const Key('note-editor-delete')), findsNothing);
      },
    );
  });
}
