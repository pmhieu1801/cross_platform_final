import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/theme.dart';

void main() {
  runApp(const NoteFlowApp());
}

class NoteFlowApp extends StatelessWidget {
  const NoteFlowApp({super.key, this.themeMode = ThemeMode.dark});

  /// Dark ("Midnight Glow") is the default look. This will later be driven
  /// by the user's preferences (light / dark / system).
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const LoginScreen(),
    );
  }
}
