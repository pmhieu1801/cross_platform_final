import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/local_preferences_repository.dart';
import '../domain/user_preferences.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => LocalPreferencesRepository(),
);

class AccountPreferencesState {
  const AccountPreferencesState({
    this.uid,
    this.value = UserPreferences.defaults,
    this.saving = false,
    this.recoveredCorruption = false,
    this.error,
    this.message,
  });
  final String? uid;
  final UserPreferences value;
  final bool saving;
  final bool recoveredCorruption;
  final String? error;
  final String? message;
}

final accountPreferencesProvider =
    AsyncNotifierProvider<AccountPreferences, AccountPreferencesState>(
      AccountPreferences.new,
    );

/// Every consumer, including MaterialApp, must use this safe current-account
/// projection rather than AsyncValue.value, which can retain A during B's load.
final effectivePreferencesProvider = Provider<UserPreferences>((ref) {
  final uid = ref.watch(authenticatedUidProvider);
  final snapshot = ref.watch(accountPreferencesProvider);
  if (uid == null ||
      snapshot.isLoading ||
      snapshot.hasError ||
      snapshot.asData?.value.uid != uid) {
    return UserPreferences.defaults;
  }
  return snapshot.asData!.value.value;
});

class AccountPreferences extends AsyncNotifier<AccountPreferencesState> {
  int _generation = 0;

  @override
  Future<AccountPreferencesState> build() async {
    final lease = ref.watch(accountSessionProvider);
    final repository = ref.watch(preferencesRepositoryProvider);
    _generation++;
    if (lease == null) return const AccountPreferencesState();
    final result = await repository.load(lease.uid);
    return AccountPreferencesState(
      uid: lease.uid,
      value: result.value,
      recoveredCorruption: result.recoveredCorruption,
    );
  }

  Future<bool> save(UserPreferences next) async {
    final lease = ref.read(accountSessionProvider);
    final current = state.asData?.value;
    if (lease == null ||
        state.isLoading ||
        state.hasError ||
        current == null ||
        current.uid != lease.uid ||
        current.saving) {
      return false;
    }
    final generation = _generation;
    bool owns() =>
        ref.mounted &&
        lease.isActive &&
        generation == _generation &&
        identical(ref.read(accountSessionProvider), lease);
    state = AsyncData(
      AccountPreferencesState(
        uid: lease.uid,
        value: current.value,
        recoveredCorruption: current.recoveredCorruption,
        saving: true,
      ),
    );
    try {
      await ref.read(preferencesRepositoryProvider).save(lease.uid, next);
      if (!owns()) return false;
      state = AsyncData(
        AccountPreferencesState(
          uid: lease.uid,
          value: next,
          message: 'Đã lưu cài đặt trên thiết bị này.',
        ),
      );
      return true;
    } catch (error) {
      if (!owns()) return false;
      state = AsyncData(
        AccountPreferencesState(
          uid: lease.uid,
          value: current.value,
          recoveredCorruption: current.recoveredCorruption,
          error: error is PreferencesFailure
              ? error.message
              : 'Chưa lưu được cài đặt. Hãy thử lại.',
        ),
      );
      return false;
    }
  }

  Future<bool> setViewMode(NotesViewMode mode) => save(
    (state.asData?.value.value ?? UserPreferences.defaults).copyWith(
      notesViewMode: mode,
    ),
  );

  Future<bool> setNoteFontScale(double scale) => save(
    (state.asData?.value.value ?? UserPreferences.defaults).copyWith(
      noteFontScale: scale.clamp(
        UserPreferences.minFontScale,
        UserPreferences.maxFontScale,
      ),
    ),
  );

  Future<bool> setThemeMode(PreferenceThemeMode mode) => save(
    (state.asData?.value.value ?? UserPreferences.defaults).copyWith(
      themeMode: mode,
    ),
  );
}
