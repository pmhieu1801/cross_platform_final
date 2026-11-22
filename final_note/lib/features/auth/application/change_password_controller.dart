import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'auth_providers.dart';

enum PasswordChangePhase {
  idle,
  updating,
  signingOut,
  signOutFailed,
  completed,
}

class PasswordChangeState {
  const PasswordChangeState({
    this.phase = PasswordChangePhase.idle,
    this.uid,
    this.error,
  });
  final PasswordChangePhase phase;
  final String? uid;
  final String? error;
  bool get busy =>
      phase == PasswordChangePhase.updating ||
      phase == PasswordChangePhase.signingOut;
  bool get passwordChanged =>
      phase == PasswordChangePhase.signingOut ||
      phase == PasswordChangePhase.signOutFailed ||
      phase == PasswordChangePhase.completed;
}

// The non-secret result survives the private screen being removed by sign-out.
final changePasswordProvider =
    NotifierProvider<ChangePasswordController, PasswordChangeState>(
      ChangePasswordController.new,
    );

class ChangePasswordController extends Notifier<PasswordChangeState> {
  int _generation = 0;
  AccountSession? _lease;
  String? _signingOutUid;

  @override
  PasswordChangeState build() {
    final previous = _lease;
    _lease = ref.watch(accountSessionProvider);
    _generation++;
    // Return the next state from build rather than writing from a listener:
    // a lazy account refresh can happen while a widget is building.
    final completed =
        _signingOutUid != null &&
        previous?.uid == _signingOutUid &&
        _lease == null &&
        sessionPhase(ref.read(authSessionProvider)) == SessionPhase.signedOut;
    _signingOutUid = null;
    // SDK sign-out can arrive before the signOut Future completes.
    return PasswordChangeState(
      phase: completed
          ? PasswordChangePhase.completed
          : PasswordChangePhase.idle,
    );
  }

  bool _owns(AccountSession lease, int generation) =>
      ref.mounted &&
      generation == _generation &&
      lease.isActive &&
      identical(ref.read(accountSessionProvider), lease);

  void clearCompleted() {
    if (state.phase == PasswordChangePhase.completed) {
      state = const PasswordChangeState();
    }
  }

  Future<void> submit(String currentPassword, String newPassword) async {
    final lease = ref.read(accountSessionProvider);
    if (lease == null ||
        state.busy ||
        state.passwordChanged ||
        ref.read(authActionsProvider).busy) {
      return;
    }
    final generation = _generation;
    state = PasswordChangeState(
      phase: PasswordChangePhase.updating,
      uid: lease.uid,
    );
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!_owns(lease, generation)) return;
      await repository.changePassword(
        expectedUid: lease.uid,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!_owns(lease, generation)) return;
      _signingOutUid = lease.uid;
      state = PasswordChangeState(
        phase: PasswordChangePhase.signingOut,
        uid: lease.uid,
      );
      await _signOut(repository, lease, generation);
    } catch (error) {
      if (!_owns(lease, generation)) return;
      state = PasswordChangeState(
        uid: lease.uid,
        error: error is AuthFailure
            ? error.message
            : 'Không thể đổi mật khẩu. Vui lòng thử lại.',
      );
    }
  }

  Future<void> retrySignOut() async {
    final lease = ref.read(accountSessionProvider);
    if (lease == null ||
        lease.uid != state.uid ||
        state.phase != PasswordChangePhase.signOutFailed ||
        ref.read(authActionsProvider).busy) {
      return;
    }
    final generation = _generation;
    _signingOutUid = lease.uid;
    state = PasswordChangeState(
      phase: PasswordChangePhase.signingOut,
      uid: lease.uid,
    );
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!_owns(lease, generation)) return;
      await _signOut(repository, lease, generation);
    } catch (_) {
      if (_owns(lease, generation)) _signOutFailed(lease.uid);
    }
  }

  Future<void> _signOut(
    AuthRepository repository,
    AccountSession lease,
    int generation,
  ) async {
    try {
      await repository.signOut(expectedUid: lease.uid);
      // The SDK stream owns the route and the completion notice. A successful
      // Future alone cannot imply the private session has already been removed.
    } catch (_) {
      if (_owns(lease, generation)) _signOutFailed(lease.uid);
    }
  }

  void _signOutFailed(String uid) {
    _signingOutUid = null;
    state = PasswordChangeState(
      phase: PasswordChangePhase.signOutFailed,
      uid: uid,
      error:
          'Mật khẩu đã được đổi, nhưng chưa đăng xuất được. '
          'Hãy thử đăng xuất lại. Lần đăng nhập tiếp theo dùng mật khẩu mới.',
    );
  }
}
