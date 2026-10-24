import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_config.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/auth_repository.dart';

final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) async {
  final options = FirebaseConfig.fromEnvironment();
  if (Firebase.apps.isNotEmpty) return Firebase.app();
  return Firebase.initializeApp(options: options);
});

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final app = await ref.watch(firebaseAppProvider.future);
  // Preserve the Firebase SDK default persistent session on Web and Android.
  return FirebaseAuthRepository(FirebaseAuth.instanceFor(app: app));
});

final authSessionProvider = StreamProvider<AuthUser?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  // userChanges includes authStateChanges plus profile/reload/token events.
  yield* repository.watchSession();
});

enum SessionPhase { checking, signedOut, signedIn, unavailable }

SessionPhase sessionPhase(AsyncValue<AuthUser?> session) {
  if (session.isLoading) return SessionPhase.checking;
  if (session.hasError) return SessionPhase.unavailable;
  return session.asData?.value == null
      ? SessionPhase.signedOut
      : SessionPhase.signedIn;
}

/// Never expose stale AsyncValue data during session loading or error.
final authenticatedUserProvider = Provider<AuthUser?>((ref) {
  final session = ref.watch(authSessionProvider);
  return sessionPhase(session) == SessionPhase.signedIn
      ? session.asData!.value
      : null;
});

final authenticatedUidProvider = Provider<String?>(
  (ref) => ref.watch(authenticatedUserProvider)?.uid,
);

/// M2/M3 watch this provider and use ref.onDispose for their own resources.
final accountSessionProvider = Provider<AccountSession?>((ref) {
  final uid = ref.watch(authenticatedUidProvider);
  if (uid == null) return null;
  final session = AccountSession(uid);
  ref.onDispose(session.close);
  return session;
});

class AccountSession {
  AccountSession(this.uid);
  final String uid;
  bool _active = true;
  bool get isActive => _active;
  void close() => _active = false;
}

class AuthActionState {
  const AuthActionState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

final authActionsProvider = NotifierProvider<AuthActions, AuthActionState>(
  AuthActions.new,
);

class AuthActions extends Notifier<AuthActionState> {
  @override
  AuthActionState build() {
    ref.listen(authenticatedUidProvider, (previous, next) {
      if (previous != next && !state.busy) state = const AuthActionState();
    });
    return const AuthActionState();
  }

  Future<void> signIn(String email, String password) => _run(
    (repository) => repository.signIn(email: email.trim(), password: password),
  );

  Future<void> register(String email, String name, String password) => _run(
    (repository) => repository.register(
      email: email.trim(),
      displayName: name.trim(),
      password: password,
    ),
  );

  Future<void> signOut() => _run((repository) => repository.signOut());

  void clearError() {
    if (!state.busy) state = const AuthActionState();
  }

  Future<void> _run(Future<void> Function(AuthRepository) action) async {
    if (state.busy) return;
    state = const AuthActionState(busy: true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      await action(repository);
      if (ref.mounted) state = const AuthActionState();
    } on AuthFailure catch (error) {
      if (ref.mounted) state = AuthActionState(error: error.message);
    } catch (_) {
      // Do not print SDK errors or user credentials.
      if (ref.mounted) {
        state = const AuthActionState(
          error: 'Không thể hoàn tất xác thực. Vui lòng thử lại.',
        );
      }
    }
  }
}
