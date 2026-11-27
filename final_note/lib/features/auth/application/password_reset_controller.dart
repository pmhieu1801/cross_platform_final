import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'auth_providers.dart';

final passwordResetProvider =
    NotifierProvider.autoDispose<PasswordResetController, AsyncValue<void>?>(
      PasswordResetController.new,
    );

class PasswordResetController extends Notifier<AsyncValue<void>?> {
  @override
  AsyncValue<void>? build() {
    ref.watch(authSessionProvider.select(sessionPhase));
    return null;
  }

  void clearResult() {
    if (state?.isLoading != true) state = null;
  }

  Future<void> submit(String email) async {
    if (state?.isLoading == true ||
        sessionPhase(ref.read(authSessionProvider)) != SessionPhase.signedOut) {
      return;
    }
    // A route exit or session change invalidates this request's UI state.
    final requestRef = ref;
    state = const AsyncLoading();
    try {
      final repository = await requestRef.read(authRepositoryProvider.future);
      if (!requestRef.mounted) return;
      await repository.requestPasswordReset(email.trim());
      if (requestRef.mounted) state = const AsyncData(null);
    } catch (error) {
      if (!requestRef.mounted) return;
      state = AsyncError(
        error is AuthFailure
            ? error
            : const AuthFailure('Không thể gửi yêu cầu. Vui lòng thử lại.'),
        StackTrace.empty,
      );
    }
  }
}
