import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../application/preferences_providers.dart';
import '../domain/user_preferences.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key, required this.uid});
  final String uid;
  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  UserPreferences? _draft;

  Future<void> _save(UserPreferences value) async {
    if (ref.read(authenticatedUidProvider) != widget.uid) return;
    final saved = await ref
        .read(accountPreferencesProvider.notifier)
        .save(value);
    if (saved && mounted && ref.read(authenticatedUidProvider) == widget.uid) {
      setState(() => _draft = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authenticatedUidProvider) != widget.uid) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final snapshot = ref.watch(accountPreferencesProvider);
    final data =
        !snapshot.isLoading &&
            !snapshot.hasError &&
            snapshot.asData?.value.uid == widget.uid
        ? snapshot.asData!.value
        : null;
    final busy = data?.saving ?? false;
    final draft = _draft ?? data?.value ?? UserPreferences.defaults;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    glowColor: context.colors.primary,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Settings', style: context.text.headlineMedium),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Saved separately for your account on this device or browser. Changes apply after saving.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (snapshot.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (snapshot.hasError || data == null) ...[
                          const Text('Không thể tải cài đặt. Hãy thử lại.'),
                          OutlinedButton(
                            key: const Key('preferences-retry'),
                            onPressed: () =>
                                ref.invalidate(accountPreferencesProvider),
                            child: const Text('Try again'),
                          ),
                        ] else ...[
                          if (data.recoveredCorruption) ...[
                            const Text(
                              'Dữ liệu cài đặt không hợp lệ. Đang dùng mặc định; bấm Save để khôi phục.',
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Theme',
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<PreferenceThemeMode>(
                                key: const Key('preferences-theme'),
                                isExpanded: true,
                                value: draft.themeMode,
                                onChanged: busy
                                    ? null
                                    : (mode) {
                                        if (mode != null) {
                                          setState(
                                            () => _draft = draft.copyWith(
                                              themeMode: mode,
                                            ),
                                          );
                                        }
                                      },
                                items: const [
                                  DropdownMenuItem(
                                    value: PreferenceThemeMode.dark,
                                    child: Text('Dark'),
                                  ),
                                  DropdownMenuItem(
                                    value: PreferenceThemeMode.light,
                                    child: Text('Light'),
                                  ),
                                  DropdownMenuItem(
                                    value: PreferenceThemeMode.system,
                                    child: Text('System'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Notes view',
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<NotesViewMode>(
                                key: const Key('preferences-view'),
                                isExpanded: true,
                                value: draft.notesViewMode,
                                onChanged: busy
                                    ? null
                                    : (mode) {
                                        if (mode != null) {
                                          setState(
                                            () => _draft = draft.copyWith(
                                              notesViewMode: mode,
                                            ),
                                          );
                                        }
                                      },
                                items: const [
                                  DropdownMenuItem(
                                    value: NotesViewMode.grid,
                                    child: Text('Grid'),
                                  ),
                                  DropdownMenuItem(
                                    value: NotesViewMode.list,
                                    child: Text('List'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Note text size: ${(draft.noteFontScale * 100).round()}%',
                          ),
                          Slider(
                            key: const Key('preferences-font'),
                            value: draft.noteFontScale,
                            min: UserPreferences.minFontScale,
                            max: UserPreferences.maxFontScale,
                            divisions: 13,
                            semanticFormatterCallback: (value) =>
                                '${(value * 100).round()}%',
                            onChanged: busy
                                ? null
                                : (value) => setState(
                                    () => _draft = draft.copyWith(
                                      noteFontScale: value,
                                    ),
                                  ),
                          ),
                          Text(
                            'Your note text',
                            key: const Key('preferences-font-preview'),
                            style: TextStyle(
                              fontSize: 16 * draft.noteFontScale,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (data.error != null ||
                              (_draft == null && data.message != null)) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(data.error ?? data.message!),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          GradientButton(
                            key: const Key('preferences-save'),
                            label: 'Save settings',
                            loading: busy,
                            onPressed: busy ? null : () => _save(draft),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                            key: const Key('preferences-reset'),
                            onPressed: busy
                                ? null
                                : () => _save(UserPreferences.defaults),
                            child: const Text('Restore defaults'),
                          ),
                        ],
                        TextButton(
                          key: const Key('preferences-back'),
                          onPressed: busy
                              ? null
                              : () => context.go(AppRoutes.home),
                          child: const Text('Back to notes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
