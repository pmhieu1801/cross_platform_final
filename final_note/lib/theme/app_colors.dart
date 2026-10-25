import 'package:flutter/material.dart';

/// Raw colour palette for the NoteFlow "Midnight Glow" design system.
///
/// Widgets should NOT use these constants directly. Read colours through
/// `Theme.of(context).colorScheme` or the [NoteFlowTokens] theme extension
/// so that light and dark modes stay consistent.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------
  static const violet = Color(0xFF7C5CFF);
  static const indigo = Color(0xFF4F7CFF);
  static const mint = Color(0xFF3DDC97);

  /// Slightly deeper brand tones used on light backgrounds for WCAG contrast.
  static const violetDeep = Color(0xFF5B3DF5);
  static const indigoDeep = Color(0xFF2F5BEA);
  static const mintDeep = Color(0xFF14A86C);

  // ---------------------------------------------------------------------------
  // Dark surfaces (default)
  // ---------------------------------------------------------------------------
  static const darkBackground = Color(0xFF0F1220);
  static const darkSurface = Color(0xFF161A2C);
  static const darkSurfaceHigh = Color(0xFF1E2338);
  static const darkSurfaceHighest = Color(0xFF272D46);
  static const darkBorder = Color(0x1FFFFFFF); // white 12%
  static const darkTextPrimary = Color(0xFFECEEF8);
  static const darkTextSecondary = Color(0xFFA3A9C2);
  static const darkTextMuted = Color(0xFF6E7591);

  // ---------------------------------------------------------------------------
  // Light surfaces
  // ---------------------------------------------------------------------------
  static const lightBackground = Color(0xFFF4F5FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFF0F1F8);
  static const lightSurfaceHighest = Color(0xFFE6E8F3);
  static const lightBorder = Color(0xFFE1E4EF);
  static const lightTextPrimary = Color(0xFF14172A);
  static const lightTextSecondary = Color(0xFF545A73);
  static const lightTextMuted = Color(0xFF8A90A8);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------
  static const success = Color(0xFF3DDC97);
  static const warning = Color(0xFFFFB547);
  static const danger = Color(0xFFFF5C7A);
  static const info = Color(0xFF4F7CFF);

  static const dangerDeep = Color(0xFFD92D50);
  static const warningDeep = Color(0xFFB7791F);

  // ---------------------------------------------------------------------------
  // Note accent palette (index is stored on each note as `colorIndex`).
  // Each accent is used for the card glow / border / label tint.
  // ---------------------------------------------------------------------------
  static const noteAccents = <Color>[
    Color(0xFF8B6CFF), // violet
    Color(0xFF3DDC97), // mint
    Color(0xFF5B8CFF), // blue
    Color(0xFFFF7A8A), // coral
    Color(0xFFFFB547), // amber
    Color(0xFFE478FF), // orchid
    Color(0xFF3BC9DB), // cyan
    Color(0xFF9AA3BF), // slate (neutral)
  ];

  /// Human readable names for [noteAccents] (used for tooltips / semantics).
  static const noteAccentNames = <String>[
    'Violet',
    'Mint',
    'Blue',
    'Coral',
    'Amber',
    'Orchid',
    'Cyan',
    'Slate',
  ];
}
