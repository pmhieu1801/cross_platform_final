import 'package:flutter/material.dart';

import 'screens/notes_home_screen.dart';

void main() {
  runApp(const NoteFlowApp());
}

class NoteFlowApp extends StatelessWidget {
  const NoteFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF315C4C);
    const ink = Color(0xFF202A26);

    return MaterialApp(
      title: 'NoteFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: forest,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: ink,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          titleLarge: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: TextStyle(color: Color(0xFF69736E), height: 1.5),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE7E9E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE7E9E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: forest, width: 1.5),
          ),
        ),
      ),
      home: const NotesHomeScreen(),
    );
  }
}
