import 'package:final_note/app.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/data/local_avatar_repository.dart';
import 'package:final_note/features/notes/data/local_note_repository.dart';
import 'package:final_note/features/notes/domain/note_repository.dart';
import 'package:final_note/models/note.dart';
import 'package:final_note/screens/notes_home_screen.dart';
import 'package:final_note/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/avatar_test_images.dart';
import 'support/fake_auth_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R06 Avatar Picker, Validation & Account-Scoped Persistence', () {
    test('LocalAvatarRepository validates PNG/JPEG, isolates by UID, and deletes receipts safely', () async {
      final repo = LocalAvatarRepository();
      final savedA = await repo.validateAndSaveAvatar(
        expectedUid: 'uid-A',
        rawBytes: avatarPng(),
        declaredMimeType: 'image/png',
      );
      expect(savedA.image.contentType, 'image/png');
      expect(savedA.receipt.ownerUid, 'uid-A');

      final loadedA = await repo.loadAvatar('uid-A');
      expect(loadedA, isNotNull);
      expect(loadedA!.bytes, avatarPng());

      // Account B has no avatar.
      expect(await repo.loadAvatar('uid-B'), isNull);

      // Account B cannot delete Account A's receipt.
      expect(
        () =>
            repo.deleteUploaded(expectedUid: 'uid-B', receipt: savedA.receipt),
        throwsArgumentError,
      );

      await repo.deleteUploaded(expectedUid: 'uid-A', receipt: savedA.receipt);
      expect(await repo.loadAvatar('uid-A'), isNull);
    });

    testWidgets(
      'ProfileScreen allows choosing a validated preset avatar and resetting to default (R06)',
      (tester) async {
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith((ref) async => fakeAuth),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await fakeAuth.dispose();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const NoteFlowApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        fakeAuth.events.add(userA);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('open-profile')));
        await tester.tap(find.byKey(const Key('open-profile')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile-default-avatar')), findsOneWidget);

        // Open avatar dialog and pick Crimson Red PNG preset.
        await tester.ensureVisible(
          find.byKey(const Key('profile-change-avatar')),
        );
        await tester.tap(find.byKey(const Key('profile-change-avatar')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile-avatar-dialog')), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('avatar-preset-crimson')));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile-custom-avatar')), findsOneWidget);
        expect(find.text('Đã cập nhật ảnh đại diện.'), findsOneWidget);
      },
    );
  });

  group('R31 Offline Persistence, Synchronization & Conflict Resolution', () {
    test('synchronizeNotes transitions pending/failed notes to synced or failed when offline', () async {
      final repo = LocalNoteRepository.inMemory(seedDemoNotes: false);
      final note = await repo.saveNote(
        'uid-1',
        Note(
          id: 'sync-1',
          title: 'Offline Draft',
          content: 'Written on airplane mode',
          labels: const ['Travel'],
          colorIndex: 0,
          updatedAt: DateTime(2026, 11, 20, 9),
        ),
      );
      expect(note.syncStatus, NoteSyncStatus.pending);

      // Simulated offline failure marks note as failed.
      await expectLater(
        repo.synchronizeNotes('uid-1', simulateOfflineFailure: true),
        throwsA(isA<NoteFailure>()),
      );
      final afterFailure = (await repo.listNotes('uid-1')).single;
      expect(afterFailure.syncStatus, NoteSyncStatus.failed);

      // Reconnect and sync succeeds.
      final synced = await repo.synchronizeNotes('uid-1');
      expect(synced.single.syncStatus, NoteSyncStatus.synced);
    });

    test('resolveConflict uses Last-Write-Wins (LWW) by updatedAt and preserves diverging content', () async {
      final repo = LocalNoteRepository.inMemory(seedDemoNotes: false);
      final olderLocal = Note(
        id: 'conflict-1',
        title: 'Sprint Retrospective (Local)',
        content: 'Local bullet points from offline laptop.',
        labels: const ['Sprint'],
        colorIndex: 1,
        updatedAt: DateTime(2026, 11, 20, 10, 0),
        syncStatus: NoteSyncStatus.pending,
      );
      final newerRemote = Note(
        id: 'conflict-1',
        title: 'Sprint Retrospective (Remote)',
        content: 'Remote action items from mobile device.',
        labels: const ['Team'],
        colorIndex: 2,
        updatedAt: DateTime(2026, 11, 20, 10, 5),
        syncStatus: NoteSyncStatus.synced,
      );

      final resolved = await repo.resolveConflict(
        'uid-1',
        localNote: olderLocal,
        remoteNote: newerRemote,
      );

      expect(resolved.title, 'Sprint Retrospective (Remote)');
      expect(resolved.syncStatus, NoteSyncStatus.synced);
      expect(
        resolved.content,
        contains('Remote action items from mobile device.'),
      );
      expect(
        resolved.content,
        contains('Local bullet points from offline laptop.'),
      );
      expect(resolved.labels, containsAll(['Sprint', 'Team']));
    });

    testWidgets(
      'NotesHomeScreen offline toggle and Sync now button update note sync statuses (R31)',
      (tester) async {
        final pendingNote = Note(
          id: 'n-pending',
          title: 'Pending Note',
          content: 'Waiting to sync',
          labels: const [],
          colorIndex: 0,
          updatedAt: DateTime(2026, 11, 20),
          syncStatus: NoteSyncStatus.pending,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: NotesHomeScreen(initialNotes: [pendingNote]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sync-notes-now-button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('sync-notes-now-button')));
        await tester.pumpAndSettle();

        // Once synced and online, the pending count button disappears.
        expect(find.byKey(const Key('sync-notes-now-button')), findsNothing);
      },
    );
  });
}
