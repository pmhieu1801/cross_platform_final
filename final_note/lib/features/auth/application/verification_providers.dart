import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'auth_providers.dart';

class VerificationState {
  const VerificationState({
    this.sending = false,
    this.refreshing = false,
    this.retryAt,
    this.message,
    this.error,
  });
  final bool sending;
  final bool refreshing;
  final DateTime? retryAt;
  final String? message;
  final String? error;
  bool get busy => sending || refreshing;
  bool get coolingDown => retryAt?.isAfter(DateTime.now()) ?? false;
}

final verificationActionsProvider =
    NotifierProvider.family<VerificationActions, VerificationState, String>(
      VerificationActions.new,
    );

class VerificationActions extends Notifier<VerificationState> {
  VerificationActions(this.uid);
  final String uid;
  Timer? _cooldown;
  int _generation = 0;

  @override
  VerificationState build() {
    ref.onDispose(() => _cooldown?.cancel());
    ref.listen(accountSessionProvider, (previous, next) {
      if (previous?.uid == uid && !identical(previous, next)) {
        // Even A -> null -> A invalidates callbacks from A's previous lease.
        _generation++;
        _cooldown?.cancel();
        state = const VerificationState();
      }
    });
    return const VerificationState();
  }

  void registrationCompleted(RegistrationResult result) {
    final currentUid = ref.read(authenticatedUidProvider);
    if (currentUid != null && currentUid != uid) return;
    state = VerificationState(
      message: result.verificationSent
          ? 'Đã yêu cầu gửi email xác minh. Kiểm tra hộp thư và thư rác.'
          : null,
      error: result.warning,
    );
    if (result.verificationSent) _startCooldown();
  }

  void _startCooldown() {
    // 60 seconds is a UX choice; Firebase independently enforces its rate limits.
    final retryAt = DateTime.now().add(const Duration(seconds: 60));
    state = VerificationState(
      retryAt: retryAt,
      message: state.message,
      error: state.error,
    );
    _cooldown?.cancel();
    _cooldown = Timer(const Duration(seconds: 60), () {
      if (!ref.mounted) return;
      state = VerificationState(
        sending: state.sending,
        refreshing: state.refreshing,
        message: state.message,
        error: state.error,
      );
    });
  }

  Future<void> resend() => _run(send: true);
  Future<void> refresh() => _run(send: false);

  Future<void> _run({required bool send}) async {
    final lease = ref.read(accountSessionProvider);
    final user = ref.read(authenticatedUserProvider);
    if (lease == null ||
        lease.uid != uid ||
        user == null ||
        user.emailVerified ||
        state.busy ||
        (send && state.coolingDown) ||
        ref.read(authActionsProvider).busy) {
      return;
    }
    final generation = _generation;
    final retryAt = state.retryAt;
    state = VerificationState(
      sending: send,
      refreshing: !send,
      retryAt: retryAt,
    );
    bool current() =>
        ref.mounted &&
        lease.isActive &&
        generation == _generation &&
        identical(ref.read(accountSessionProvider), lease);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!current()) return;
      if (send) {
        await repository.sendVerificationEmail(uid);
      } else {
        await repository.refreshCurrentUser(uid);
      }
      if (!current()) return;
      state = VerificationState(
        retryAt: retryAt,
        message: send
            ? 'Đã yêu cầu gửi email xác minh. Kiểm tra hộp thư và thư rác.'
            : 'Đã kiểm tra với Firebase. Nếu chưa xác minh, hãy mở link trong email rồi kiểm tra lại.',
      );
      if (send) _startCooldown();
    } catch (error) {
      if (!current()) return;
      state = VerificationState(
        retryAt: retryAt,
        error: error is AuthFailure
            ? error.message
            : 'Không thể kiểm tra hoặc gửi email xác minh. Hãy thử lại.',
      );
    }
  }
}
