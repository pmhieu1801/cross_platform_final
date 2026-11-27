import 'dart:typed_data';

import 'package:final_note/features/notes/application/note_attachment_service.dart';
import 'package:final_note/features/notes/data/local_note_repository.dart';
import 'package:final_note/features/notes/domain/note_repository.dart';
import 'package:final_note/models/note.dart';
import 'package:final_note/screens/note_editor_sheet.dart';
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

  group('NoteAttachmentValidator unit tests (R15, R16)', () {
    test('accepts valid image, video, and document attachments with inferred MIME and inline preview', () {
      final pngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final imageResult = NoteAttachmentValidator.validate(
        PickedAttachmentCandidate(
          name: 'architecture.png',
          kind: NoteAttachmentKind.image,
          sizeBytes: pngBytes.length,
          bytes: pngBytes,
        ),
        ownerUid: 'uid-owner',
      );
      expect(imageResult.isValid, isTrue);
      expect(imageResult.attachment!.mimeType, 'image/png');
      expect(imageResult.attachment!.ownerUid, 'uid-owner');
      expect(imageResult.attachment!.previewBase64, isNotNull);

      final videoResult = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'demo.mp4',
          kind: NoteAttachmentKind.video,
          sizeBytes: 4 * 1024 * 1024,
        ),
        ownerUid: 'uid-owner',
      );
      expect(videoResult.isValid, isTrue);
      expect(videoResult.attachment!.mimeType, 'video/mp4');

      final fileResult = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'report.pdf',
          kind: NoteAttachmentKind.file,
          sizeBytes: 512 * 1024,
        ),
        ownerUid: 'uid-owner',
      );
      expect(fileResult.isValid, isTrue);
      expect(fileResult.attachment!.mimeType, 'application/pdf');
    });

    test('rejects empty files, oversized files, mismatched extensions, and executable files', () {
      final emptyResult = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'empty.png',
          kind: NoteAttachmentKind.image,
          sizeBytes: 0,
        ),
      );
      expect(emptyResult.isValid, isFalse);
      expect(emptyResult.error, contains('empty'));

      final oversizedImage = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'huge.jpg',
          kind: NoteAttachmentKind.image,
          sizeBytes: 6 * 1024 * 1024,
        ),
      );
      expect(oversizedImage.isValid, isFalse);
      expect(oversizedImage.error, contains('5 MB'));

      final oversizedVideo = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'huge_movie.mp4',
          kind: NoteAttachmentKind.video,
          sizeBytes: 16 * 1024 * 1024,
        ),
      );
      expect(oversizedVideo.isValid, isFalse);
      expect(oversizedVideo.error, contains('15 MB'));

      final wrongImageExt = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'notes.pdf',
          kind: NoteAttachmentKind.image,
          sizeBytes: 1024,
        ),
      );
      expect(wrongImageExt.isValid, isFalse);
      expect(wrongImageExt.error, contains('Unsupported image format'));

      final blockedExe = NoteAttachmentValidator.validate(
        const PickedAttachmentCandidate(
          name: 'installer.exe',
          kind: NoteAttachmentKind.file,
          sizeBytes: 2048,
        ),
      );
      expect(blockedExe.isValid, isFalse);
      expect(blockedExe.error, contains('Executable files'));
    });

    test('enforces account authorization on attachment access and repository writes', () async {
      final attachment = NoteAttachment(
        id: 'att-1',
        name: 'private.pdf',
        kind: NoteAttachmentKind.file,
        localPath: 'local://private.pdf',
        sizeBytes: 1024,
        ownerUid: 'uid-alice',
      );
      final note = Note(
        id: 'note-1',
        title: 'Alice Note',
        content: 'Confidential',
        labels: const [],
        colorIndex: 0,
        updatedAt: DateTime(2026, 11, 20),
        ownerUid: 'uid-alice',
        attachments: [attachment],
      );

      expect(
        NoteAttachmentValidator.canAccessAttachment(
          note: note,
          attachment: attachment,
          viewerUid: 'uid-alice',
        ),
        isTrue,
      );
      expect(
        NoteAttachmentValidator.canAccessAttachment(
          note: note,
          attachment: attachment,
          viewerUid: 'uid-bob',
        ),
        isFalse,
      );
      expect(
        NoteAttachmentValidator.canAccessAttachment(
          note: note,
          attachment: attachment,
          viewerUid: null,
        ),
        isFalse,
      );

      final repo = LocalNoteRepository.inMemory(seedDemoNotes: false);
      addTearDown(repo.dispose);
      await expectLater(
        () => repo.saveNote(
          'uid-bob',
          note.copyWith(ownerUid: 'uid-bob', attachments: [attachment]),
        ),
        throwsA(isA<NoteFailure>()),
      );
    });
  });

  group('NoteEditorPanel attachment workflow & R18 indicators', () {
    testWidgets(
      'handles picker cancellation, permission denial, validation error, and valid attachment preview/removal',
      (tester) async {
        final savedNotes = <Note>[];
        late AttachmentPickOutcome nextOutcome;

        await tester.pumpWidget(
          _wrapWithTheme(
            Scaffold(
              body: SingleChildScrollView(
                child: NoteEditorPanel(
                  debounceDuration: const Duration(milliseconds: 100),
                  attachmentPicker: (_) async => nextOutcome,
                  onSave: (draft, {required isAutosave}) async {
                    savedNotes.add(draft);
                    return draft;
                  },
                ),
              ),
            ),
          ),
        );

        // 1. Cancellation neither adds an attachment nor shows an error.
        nextOutcome = const AttachmentPickOutcome.cancelled();
        await tester.tap(find.byKey(const Key('editor-add-attachment-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('attach-menu-image')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('note-attachment-error')), findsNothing);
        expect(savedNotes, isEmpty);

        // 2. Denied permissions surface a clear error banner.
        nextOutcome = const AttachmentPickOutcome.permissionDenied(
          'Camera and gallery access denied.',
        );
        await tester.tap(find.byKey(const Key('editor-add-attachment-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('attach-menu-image')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('note-attachment-error')), findsOneWidget);
        expect(find.text('Camera and gallery access denied.'), findsOneWidget);

        // 3. Invalid file size/type is blocked and reported.
        nextOutcome = const AttachmentPickOutcome.picked([
          PickedAttachmentCandidate(
            name: 'too_big.png',
            kind: NoteAttachmentKind.image,
            sizeBytes: 8 * 1024 * 1024,
          ),
        ]);
        await tester.tap(find.byKey(const Key('editor-add-attachment-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('attach-menu-image')));
        await tester.pumpAndSettle();

        expect(find.textContaining('5 MB'), findsOneWidget);
        expect(savedNotes, isEmpty);

        // 4. Valid file attachment succeeds, clears error, auto-saves, and opens preview dialog.
        nextOutcome = const AttachmentPickOutcome.picked([
          PickedAttachmentCandidate(
            name: 'syllabus.pdf',
            kind: NoteAttachmentKind.file,
            sizeBytes: 128 * 1024,
          ),
        ]);
        await tester.tap(find.byKey(const Key('editor-add-attachment-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('attach-menu-file')));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('note-attachment-error')), findsNothing);
        expect(
          find.byKey(const Key('note-attachment-chip-syllabus.pdf')),
          findsOneWidget,
        );
        expect(savedNotes, isNotEmpty);
        expect(savedNotes.last.attachments.single.name, 'syllabus.pdf');

        // Open preview dialog and close it.
        await tester.tap(
          find.byKey(const Key('note-attachment-chip-syllabus.pdf')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('attachment-preview-dialog')),
          findsOneWidget,
        );
        expect(find.textContaining('application/pdf'), findsOneWidget);
        await tester.tap(find.byKey(const Key('attachment-preview-close')));
        await tester.pumpAndSettle();

        // Remove attachment.
        await tester.tap(
          find.byKey(const Key('remove-attachment-syllabus.pdf')),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('note-attachment-chip-syllabus.pdf')),
          findsNothing,
        );
        expect(savedNotes.last.attachments, isEmpty);
      },
    );

    testWidgets(
      'displays simultaneous special-note status indicators in both Grid and List views (R18)',
      (tester) async {
        final specialNote = Note(
          id: 'special-1',
          title: 'Milestone Review',
          content: 'Check all status indicators.',
          labels: const ['Work'],
          colorIndex: 0,
          updatedAt: DateTime(2026, 11, 20, 9),
          isPinned: true,
          pinnedAt: DateTime(2026, 11, 20, 9),
          status: NoteStatus.important,
          syncStatus: NoteSyncStatus.synced,
          attachments: const [
            NoteAttachment(
              id: 'att-img',
              name: 'chart.png',
              kind: NoteAttachmentKind.image,
              localPath: 'local://chart.png',
              mimeType: 'image/png',
              sizeBytes: 4096,
            ),
            NoteAttachment(
              id: 'att-doc',
              name: 'spec.pdf',
              kind: NoteAttachmentKind.file,
              localPath: 'local://spec.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 8192,
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapWithTheme(NotesHomeScreen(initialNotes: [specialNote])),
        );

        // Grid view indicators: pin, status badge, attachment count, sync status.
        expect(
          find.byKey(const Key('note-pin-indicator-special-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-status-badge-special-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-attachment-indicator-special-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-sync-status-synced')),
          findsOneWidget,
        );

        // Switch to List view and verify all indicators remain visible.
        await tester.tap(find.byTooltip('List view'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('note-tile-pin-indicator-special-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-tile-status-badge-special-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-tile-attachment-indicator-special-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('note-sync-status-synced')),
          findsOneWidget,
        );
      },
    );
  });
}
