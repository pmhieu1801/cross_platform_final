import 'package:final_note/features/notes/application/note_password_security.dart';
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

  group('NotePasswordSecurity & Repository enforcement (R23, R24)', () {
    test('hashes passwords with unique salts and never stores plaintext', () {
      final salt1 = NotePasswordSecurity.generateSalt();
      final salt2 = NotePasswordSecurity.generateSalt();
      expect(salt1, isNot(equals(salt2)));

      final hash1 = NotePasswordSecurity.hashPassword(
        password: 'Secret#123',
        salt: salt1,
      );
      final hash2 = NotePasswordSecurity.hashPassword(
        password: 'Secret#123',
        salt: salt2,
      );

      expect(hash1, isNot(contains('Secret#123')));
      expect(hash1, isNot(equals(hash2)));
      expect(
        NotePasswordSecurity.verifyPassword(
          password: 'Secret#123',
          salt: salt1,
          expectedHash: hash1,
        ),
        isTrue,
      );
      expect(
        NotePasswordSecurity.verifyPassword(
          password: 'WrongPass',
          salt: salt1,
          expectedHash: hash1,
        ),
        isFalse,
      );
    });

    test('enforces password confirmation, repository lock checks, password change, and disable flow', () async {
      final repo = LocalNoteRepository.inMemory(seedDemoNotes: false);
      addTearDown(repo.dispose);

      final note = await repo.saveNote(
        'uid-a',
        Note(
          id: 'note-sec',
          title: 'Vault Note',
          content: 'Private recovery codes',
          labels: const ['Security'],
          colorIndex: 1,
          updatedAt: DateTime(2026, 11, 25),
        ),
      );
      expect(note.isPasswordProtected, isFalse);

      // Mismatched confirmation must fail.
      await expectLater(
        () => repo.enableNotePassword(
          'uid-a',
          note.id,
          password: 'pass1234',
          confirmPassword: 'different',
        ),
        throwsA(isA<NoteFailure>()),
      );

      // Enable protection with matching confirmation.
      final protectedNote = await repo.enableNotePassword(
        'uid-a',
        note.id,
        password: 'pass1234',
        confirmPassword: 'pass1234',
      );
      expect(protectedNote.isPasswordProtected, isTrue);
      expect(protectedNote.passwordHash, isNot(equals('pass1234')));

      // Lock session: direct saveNote and deleteNote must be rejected by repository!
      repo.lockNoteSession('uid-a', note.id);
      expect(repo.isNoteUnlocked('uid-a', note.id), isFalse);

      await expectLater(
        () => repo.saveNote(
          'uid-a',
          protectedNote.copyWith(content: 'Unauthorized overwrite'),
        ),
        throwsA(isA<NoteFailure>()),
      );
      await expectLater(
        () => repo.deleteNote('uid-a', note.id),
        throwsA(isA<NoteFailure>()),
      );

      // Wrong password verification fails; right password unlocks.
      await expectLater(
        () => repo.verifyNotePassword('uid-a', note.id, 'wrong'),
        throwsA(isA<NoteFailure>()),
      );
      expect(
        await repo.verifyNotePassword('uid-a', note.id, 'pass1234'),
        isTrue,
      );
      expect(repo.isNoteUnlocked('uid-a', note.id), isTrue);

      // Change password requires current password.
      await expectLater(
        () => repo.changeNotePassword(
          'uid-a',
          note.id,
          currentPassword: 'wrong-current',
          newPassword: 'newPass5678',
          confirmNewPassword: 'newPass5678',
        ),
        throwsA(isA<NoteFailure>()),
      );

      await repo.changeNotePassword(
        'uid-a',
        note.id,
        currentPassword: 'pass1234',
        newPassword: 'newPass5678',
        confirmNewPassword: 'newPass5678',
      );

      // Old password no longer works after re-locking.
      repo.lockNoteSession('uid-a', note.id);
      await expectLater(
        () => repo.verifyNotePassword('uid-a', note.id, 'pass1234'),
        throwsA(isA<NoteFailure>()),
      );
      expect(
        await repo.verifyNotePassword('uid-a', note.id, 'newPass5678'),
        isTrue,
      );

      // Disable protection requires current password.
      await expectLater(
        () => repo.disableNotePassword(
          'uid-a',
          note.id,
          currentPassword: 'pass1234',
        ),
        throwsA(isA<NoteFailure>()),
      );
      final unprotected = await repo.disableNotePassword(
        'uid-a',
        note.id,
        currentPassword: 'newPass5678',
      );
      expect(unprotected.isPasswordProtected, isFalse);
    });
  });

  group('UI flow for locking, unlocking, search masking, and changing password', () {
    testWidgets(
      'masks locked note content, hides locked content from search, and unlocks with password (R23, R24)',
      (tester) async {
        final salt = NotePasswordSecurity.generateSalt();
        final hash = NotePasswordSecurity.hashPassword(
          password: 'open1234',
          salt: salt,
        );
        final lockedNote = Note(
          id: 'locked-1',
          title: 'Tax Return',
          content: 'UltraSecretKeyword999',
          labels: const ['Finance'],
          colorIndex: 2,
          updatedAt: DateTime(2026, 11, 25, 10),
          passwordSalt: salt,
          passwordHash: hash,
        );

        await tester.pumpWidget(
          _wrapWithTheme(NotesHomeScreen(initialNotes: [lockedNote])),
        );

        // Content is masked and R18 lock indicator is visible in Grid view.
        expect(
          find.byKey(const Key('note-lock-indicator-locked-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-locked-placeholder-locked-1')),
          findsOneWidget,
        );
        expect(find.text('UltraSecretKeyword999'), findsNothing);

        // Searching for secret content while locked must NOT match the locked note!
        await tester.enterText(
          find.byKey(const Key('notes-search-input')),
          'UltraSecretKeyword999',
        );
        await tester.pumpAndSettle();
        expect(find.text('Tax Return'), findsNothing);

        // Clear search.
        await tester.enterText(find.byKey(const Key('notes-search-input')), '');
        await tester.pumpAndSettle();
        expect(find.text('Tax Return'), findsOneWidget);

        // Tap locked note card -> Unlock dialog appears.
        await tester.tap(find.byKey(const Key('note-card-locked-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('unlock-note-dialog')), findsOneWidget);

        // Enter wrong password first.
        await tester.enterText(
          find.byKey(const Key('unlock-note-password-input')),
          'wrongpass',
        );
        await tester.tap(find.byKey(const Key('unlock-note-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('Incorrect note password.'), findsOneWidget);

        // Enter correct password -> unlocks and opens editor with real content.
        await tester.enterText(
          find.byKey(const Key('unlock-note-password-input')),
          'open1234',
        );
        await tester.tap(find.byKey(const Key('unlock-note-confirm')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('note-title-input')), findsOneWidget);
        expect(find.text('UltraSecretKeyword999'), findsWidgets);
      },
    );
  });
}
