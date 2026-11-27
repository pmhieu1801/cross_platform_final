import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/note.dart';
import '../../routing/session_guard.dart';
import '../../screens/notes_home_screen.dart';
import '../auth/application/auth_providers.dart';
import '../auth/application/change_password_controller.dart';
import '../auth/presentation/verification_banner.dart';
import '../notes/application/note_providers.dart';
import '../preferences/application/preferences_providers.dart';

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
    final sharedNotesAsync = ref.watch(accountSharedNotesStreamProvider);
    final labelsAsync = ref.watch(accountLabelsStreamProvider);
    // Keep noteActionsProvider alive while HomeScreen is mounted so async saves
    // are never cancelled by autoDispose mid-flight.
    ref.watch(noteActionsProvider);
    final noteActions = ref.read(noteActionsProvider.notifier);
    final preferences = ref.watch(effectivePreferencesProvider);
    final preferencesSnapshot = ref.watch(accountPreferencesProvider);
    final preferencesState =
        !preferencesSnapshot.isLoading &&
            !preferencesSnapshot.hasError &&
            preferencesSnapshot.asData?.value.uid == user.uid
        ? preferencesSnapshot.asData!.value
        : null;

    final isLoading = notesAsync.isLoading;
    final hasError = notesAsync.hasError;
    final notes = (!isLoading && !hasError)
        ? (notesAsync.asData?.value ?? const <Note>[])
        : const <Note>[];
    final sharedNotes =
        (!sharedNotesAsync.isLoading && !sharedNotesAsync.hasError)
        ? (sharedNotesAsync.asData?.value ?? const <Note>[])
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
      authBusy: authAction.busy || ref.watch(changePasswordProvider).busy,
      authError:
          authAction.error ??
          (preferencesSnapshot.hasError && !preferencesSnapshot.isLoading
              ? 'Không thể tải cài đặt. Mở Settings để thử lại.'
              : null),
      onLogout: ref.read(authActionsProvider.notifier).signOut,
      onChangePassword: () => context.go(AppRoutes.changePassword),
      onProfile: () => context.go(AppRoutes.profile),
      onPreferences: () => context.go(AppRoutes.preferences),
      viewMode: preferences.notesViewMode,
      viewModeEnabled: preferencesState != null && !preferencesState.saving,
      preferencesError: preferencesState?.error,
      onViewModeChanged: ref
          .read(accountPreferencesProvider.notifier)
          .setViewMode,
      noteFontScale: preferences.noteFontScale,
      notes: notes,
      sharedNotes: sharedNotes,
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
      onEnableNotePassword: (noteId, password, confirmPassword) async {
        final updated = await noteActions.enableNotePassword(
          noteId,
          password: password,
          confirmPassword: confirmPassword,
        );
        return (
          note: updated,
          error: updated == null ? ref.read(noteActionsProvider).error : null,
        );
      },
      onVerifyNotePassword: (noteId, password) async {
        final ok = await noteActions.verifyNotePassword(noteId, password);
        return ok
            ? null
            : (ref.read(noteActionsProvider).error ??
                  'Incorrect note password.');
      },
      onChangeNotePassword:
          (noteId, currentPassword, newPassword, confirmNewPassword) async {
            final updated = await noteActions.changeNotePassword(
              noteId,
              currentPassword: currentPassword,
              newPassword: newPassword,
              confirmNewPassword: confirmNewPassword,
            );
            return (
              note: updated,
              error: updated == null
                  ? ref.read(noteActionsProvider).error
                  : null,
            );
          },
      onDisableNotePassword: (noteId, currentPassword) async {
        final updated = await noteActions.disableNotePassword(
          noteId,
          currentPassword: currentPassword,
        );
        return (
          note: updated,
          error: updated == null ? ref.read(noteActionsProvider).error : null,
        );
      },
      isNoteUnlocked: noteActions.isNoteUnlocked,
      onLockNoteSession: noteActions.lockNoteSession,
      onShareNote: (noteId, recipientEmail, permission) async {
        final updated = await noteActions.shareNote(
          noteId,
          recipientEmail: recipientEmail,
          permission: permission,
        );
        return (
          note: updated,
          error: updated == null ? ref.read(noteActionsProvider).error : null,
        );
      },
      onUpdateSharePermission: (noteId, recipientEmail, permission) async {
        final updated = await noteActions.updateSharePermission(
          noteId,
          recipientEmail: recipientEmail,
          permission: permission,
        );
        return (
          note: updated,
          error: updated == null ? ref.read(noteActionsProvider).error : null,
        );
      },
      onRevokeShare: (noteId, recipientEmail) async {
        final updated = await noteActions.revokeShare(
          noteId,
          recipientEmail: recipientEmail,
        );
        return (
          note: updated,
          error: updated == null ? ref.read(noteActionsProvider).error : null,
        );
      },
      onSynchronizeNotes: ({bool simulateOfflineFailure = false}) => noteActions
          .synchronizeNotes(simulateOfflineFailure: simulateOfflineFailure),
    );
  }
}
