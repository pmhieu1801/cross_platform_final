import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'features/preferences/application/preferences_providers.dart';
import 'features/preferences/domain/user_preferences.dart';
import 'theme/theme.dart';

class NoteFlowApp extends ConsumerWidget {
  const NoteFlowApp({super.key, this.themeMode});

  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'NoteFlow',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode:
        themeMode ??
        switch (ref.watch(effectivePreferencesProvider).themeMode) {
          PreferenceThemeMode.dark => ThemeMode.dark,
          PreferenceThemeMode.light => ThemeMode.light,
          PreferenceThemeMode.system => ThemeMode.system,
        },
    routerConfig: ref.watch(appRouterProvider),
  );
}
