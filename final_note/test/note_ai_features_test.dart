import 'package:final_note/features/notes/application/note_ai_service.dart';
import 'package:final_note/features/notes/application/note_password_security.dart';
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

  group('NoteAiService unit tests (R27, R28)', () {
    const aiService = NoteAiService();

    test('R27: generates concise summary, supports regeneration variations, and rejects locked notes', () async {
      final salt = NotePasswordSecurity.generateSalt();
      final hash = NotePasswordSecurity.hashPassword(
        password: 'lock1234',
        salt: salt,
      );
      final note = Note(
        id: 'note-ai-1',
        title: 'Distributed Systems Study',
        content: 'Consensus algorithms like Raft and Paxos ensure fault tolerance across replicas. Leader election and log replication are the two primary phases.',
        labels: const ['CS', 'Systems'],
        colorIndex: 0,
        updatedAt: DateTime(2026, 11, 26),
        passwordSalt: salt,
        passwordHash: hash,
      );

      // Locked note must be rejected.
      await expectLater(
        () => aiService.summarizeNote(note, isUnlocked: false),
        throwsA(isA<NoteFailure>()),
      );

      // Unlocked note produces summary variation 0, 1, 2 without mutating note.
      final v0 = await aiService.summarizeNote(
        note,
        isUnlocked: true,
        variationIndex: 0,
      );
      final v1 = await aiService.summarizeNote(
        note,
        isUnlocked: true,
        variationIndex: 1,
      );
      final v2 = await aiService.summarizeNote(
        note,
        isUnlocked: true,
        variationIndex: 2,
      );

      expect(v0.summary, contains('Raft'));
      expect(v0.summary, isNot(equals(v1.summary)));
      expect(v1.summary, isNot(equals(v2.summary)));
      expect(
        note.content,
        'Consensus algorithms like Raft and Paxos ensure fault tolerance across replicas. Leader election and log replication are the two primary phases.',
      );
    });

    test('R28: retrieves only authorized & unlocked notes, synthesizes grounded answers with references, and reports insufficient info', () async {
      final salt = NotePasswordSecurity.generateSalt();
      final hash = NotePasswordSecurity.hashPassword(
        password: 'pass1234',
        salt: salt,
      );

      final aliceGroceryNote = Note(
        id: 'alice-grocery',
        title: 'Grocery list',
        content: 'Buy oat milk, fresh basil, cherry tomatoes, and pasta.',
        labels: const ['Personal'],
        colorIndex: 0,
        updatedAt: DateTime(2026, 11, 26, 9),
        ownerUid: 'uid-alice',
      );
      final aliceLockedNote = Note(
        id: 'alice-locked',
        title: 'Secret Gift Ideas',
        content: 'Buy a mechanical keyboard and vintage watch for birthday.',
        labels: const ['Personal'],
        colorIndex: 1,
        updatedAt: DateTime(2026, 11, 26, 10),
        ownerUid: 'uid-alice',
        passwordSalt: salt,
        passwordHash: hash,
      );
      final bobPrivateNote = Note(
        id: 'bob-private',
        title: 'Bob Private Budget',
        content: 'Buy treasury bonds and index funds.',
        labels: const ['Finance'],
        colorIndex: 2,
        updatedAt: DateTime(2026, 11, 26, 11),
        ownerUid: 'uid-bob',
      );

      final allCandidates = [aliceGroceryNote, aliceLockedNote, bobPrivateNote];

      // 1. Alice asks about food/groceries -> matches alice-grocery, never leaks bob-private.
      final groceryAnswer = await aiService.answerQuestion(
        question: 'What food items should I buy at the market?',
        candidateNotes: allCandidates,
        viewerUid: 'uid-alice',
        viewerEmail: 'alice@example.com',
        isNoteUnlocked: (_) => false,
      );
      expect(groceryAnswer.hasSufficientInfo, isTrue);
      expect(groceryAnswer.answer, contains('oat milk'));
      expect(groceryAnswer.sources.map((s) => s.noteId), ['alice-grocery']);

      // 2. Alice asks about birthday gift while alice-locked is LOCKED -> insufficient info!
      final lockedAnswer = await aiService.answerQuestion(
        question: 'What birthday gift keyboard should I get?',
        candidateNotes: allCandidates,
        viewerUid: 'uid-alice',
        viewerEmail: 'alice@example.com',
        isNoteUnlocked: (_) => false,
      );
      expect(lockedAnswer.hasSufficientInfo, isFalse);
      expect(lockedAnswer.excludedLockedCount, 1);
      expect(lockedAnswer.sources, isEmpty);

      // 3. After Alice unlocks alice-locked, the same question succeeds with source reference!
      final unlockedAnswer = await aiService.answerQuestion(
        question: 'What birthday gift keyboard should I get?',
        candidateNotes: allCandidates,
        viewerUid: 'uid-alice',
        viewerEmail: 'alice@example.com',
        isNoteUnlocked: (note) => note.id == 'alice-locked',
      );
      expect(unlockedAnswer.hasSufficientInfo, isTrue);
      expect(unlockedAnswer.answer, contains('mechanical keyboard'));
      expect(
        unlockedAnswer.sources.map((s) => s.noteId),
        contains('alice-locked'),
      );

      // 4. Alice asks about Bob's treasury bonds -> forbidden note is excluded -> insufficient info.
      final forbiddenAnswer = await aiService.answerQuestion(
        question: 'What about treasury bonds?',
        candidateNotes: allCandidates,
        viewerUid: 'uid-alice',
        viewerEmail: 'alice@example.com',
        isNoteUnlocked: (_) => true,
      );
      expect(forbiddenAnswer.hasSufficientInfo, isFalse);
      expect(forbiddenAnswer.sources, isEmpty);
    });
  });

  group('AI Summary & AI Q&A Widget integration tests (R27, R28)', () {
    testWidgets(
      'generates and regenerates AI Summary without overwriting note content, and opens source note from AI Q&A dialog',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final notes = [
          Note(
            id: 'note-kickoff',
            title: 'Project kickoff',
            content: 'Align on the first milestone, share the design references, and leave space for questions.',
            labels: const ['Work'],
            colorIndex: 1,
            updatedAt: DateTime(2026, 11, 26, 9),
          ),
          Note(
            id: 'note-grocery',
            title: 'Grocery list',
            content: 'Oat milk, lemons, cherry tomatoes, fresh basil, pasta.',
            labels: const ['Personal'],
            colorIndex: 4,
            updatedAt: DateTime(2026, 11, 26, 8),
          ),
        ];

        await tester.pumpWidget(
          _wrapWithTheme(NotesHomeScreen(initialNotes: notes)),
        );

        // 1. Open Project kickoff note and generate AI Summary (R27).
        await tester.tap(find.byKey(const Key('note-card-note-kickoff')));
        await tester.pumpAndSettle();

        final originalContent = tester
            .widget<TextField>(find.byKey(const Key('note-content-input')))
            .controller!
            .text;

        await tester.tap(
          find.byKey(const Key('note-editor-ai-summary-button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('note-ai-summary-card')), findsOneWidget);
        final firstSummary = tester
            .widget<SelectableText>(
              find.byKey(const Key('note-ai-summary-text')),
            )
            .data;
        expect(firstSummary, isNotEmpty);

        // Tap Regenerate -> summary updates, original note content is untouched!
        await tester.tap(find.byKey(const Key('note-ai-summary-regenerate')));
        await tester.pumpAndSettle();

        final secondSummary = tester
            .widget<SelectableText>(
              find.byKey(const Key('note-ai-summary-text')),
            )
            .data;
        expect(secondSummary, isNot(equals(firstSummary)));
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('note-content-input')))
              .controller!
              .text,
          originalContent,
        );

        // 2. Open Ask AI dialog (R28), ask about grocery items, and click the source reference!
        await tester.tap(find.byKey(const Key('open-ai-qa-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('note-ai-qa-dialog')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('ai-qa-question-input')),
          'What items are on my grocery list?',
        );
        await tester.tap(find.byKey(const Key('ai-qa-submit-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ai-qa-answer-card')), findsOneWidget);
        expect(
          find.byKey(const Key('ai-qa-source-note-grocery')),
          findsOneWidget,
        );

        // Tap the source-note reference -> closes dialog and opens Grocery list in editor!
        await tester.tap(find.byKey(const Key('ai-qa-source-note-grocery')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.byKey(const Key('note-title-input')))
              .controller!
              .text,
          'Grocery list',
        );
      },
    );
  });
}
