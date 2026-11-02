import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/note.dart';
import '../../screens/notes_home_screen.dart';
import '../auth/application/auth_providers.dart';
import '../auth/presentation/verification_banner.dart';
import '../notes/application/note_providers.dart';

/// Account-scoped Notes destination for `/home`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authenticatedUserProvider);
    // Block the frame before the router processes a redirect.
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    final account = ref.watch(accountSessionProvider);
    if (account == null || !account.isActive) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final authAction = ref.watch(authActionsProvider);
    final notesAsync = ref.watch(accountNotesStreamProvider);
    final labelsAsync = ref.watch(accountLabelsStreamProvider);
    final noteActions = ref.read(noteActionsProvider.notifier);

    final isLoading = notesAsync.isLoading;
    final hasError = notesAsync.hasError;
    final notes = (!isLoading && !hasError)
        ? (notesAsync.asData?.value ?? const <Note>[])
        : const <Note>[];
    final labels = (!labelsAsync.isLoading && !labelsAsync.hasError)
        ? (labelsAsync.asData?.value ?? const <String>[])
        : const <String>[];

    return NotesHomeScreen(
      key: ValueKey(account.uid),
      user: user,
      verificationBanner: !user.emailVerified
          ? VerificationBanner(key: ValueKey(user.uid), uid: user.uid)
          : null,
      authBusy: authAction.busy,
      authError: authAction.error,
      onLogout: ref.read(authActionsProvider.notifier).signOut,
      notes: notes,
      labels: labels,
      isLoading: isLoading,
      errorMessage: hasError ? 'Không thể tải danh sách ghi chú.' : null,
      onRetry: () => ref.invalidate(accountNotesStreamProvider),
      onSaveNote: (draft, {required isAutosave}) =>
          noteActions.saveNote(draft, isAutosave: isAutosave),
      onDeleteNote: noteActions.deleteNote,
      onTogglePin: noteActions.togglePin,
      onAddLabel: (name) async {
        final ok = await noteActions.addLabel(name);
        return ok ? null : ref.read(noteActionsProvider).error;
      },
      onRenameLabel: (oldName, newName) async {
        final ok = await noteActions.renameLabel(
          oldLabel: oldName,
          newLabel: newName,
        );
        return ok ? null : ref.read(noteActionsProvider).error;
      },
      onDeleteLabel: (name) async {
        final ok = await noteActions.deleteLabel(name);
        return ok ? null : ref.read(noteActionsProvider).error;
      },
    );
  }
}
