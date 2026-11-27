import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'auth_providers.dart';
import 'change_password_controller.dart';

class ProfileState {
  const ProfileState({
    this.saving = false,
    this.refreshing = false,
    this.message,
    this.error,
  });
  final bool saving;
  final bool refreshing;
  final String? message;
  final String? error;
  bool get busy => saving || refreshing;
}

final profileActionsProvider =
    NotifierProvider.autoDispose<ProfileActions, ProfileState>(
      ProfileActions.new,
    );

/// Coordinates requests; the visible profile always comes from the SDK stream.
class ProfileActions extends Notifier<ProfileState> {
  int _generation = 0;

  @override
  ProfileState build() {
    ref.watch(accountSessionProvider);
    _generation++;
    return const ProfileState();
  }

  void clearFeedback() {
    if (!state.busy) state = const ProfileState();
  }

  Future<bool> saveName(String value) => _run(name: value.trim());
  Future<bool> refresh() => _run();

  Future<bool> _run({String? name}) async {
    final lease = ref.read(accountSessionProvider);
    if (lease == null ||
        state.busy ||
        ref.read(authActionsProvider).busy ||
        ref.read(changePasswordProvider).busy) {
      return false;
    }
    if (name != null && name.isEmpty) {
      state = const ProfileState(error: 'Tên hiển thị không được để trống.');
      return false;
    }
    final generation = _generation;
    bool current() =>
        ref.mounted &&
        generation == _generation &&
        lease.isActive &&
        identical(ref.read(accountSessionProvider), lease);
    state = ProfileState(saving: name != null, refreshing: name == null);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!current()) return false;
      if (name == null) {
        await repository.refreshCurrentUser(lease.uid);
      } else {
        await repository.updateDisplayName(
          expectedUid: lease.uid,
          displayName: name,
        );
      }
      if (!current()) return false;
      state = ProfileState(
        message: name == null ? 'Đã tải lại hồ sơ.' : 'Đã lưu tên hiển thị.',
      );
      return true;
    } catch (error) {
      if (!current()) return false;
      state = ProfileState(
        error: error is AuthFailure
            ? error.message
            : 'Không thể cập nhật hoặc tải lại hồ sơ. Hãy thử lại.',
      );
      return false;
    }
  }
}
