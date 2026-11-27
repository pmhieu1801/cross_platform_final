import 'package:flutter/material.dart';

/// Raw colour palette for the NoteFlow formal editorial design system
/// (inspired by the clean MINO workspace aesthetic).
///
/// Widgets should read colours through `Theme.of(context).colorScheme` or the
/// [NoteFlowTokens] theme extension so that light and dark modes stay consistent.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand (Formal solid tones — black CTA, red & white brand mark)
  // ---------------------------------------------------------------------------
  /// Formal solid black-charcoal used for primary CTA buttons.
  static const violet = Color(0xFF141619);
  static const indigo = Color(0xFF24292F);
  static const mint = Color(0xFF1F7A5A);

  /// Deep tones used on light backgrounds for high WCAG contrast.
  static const violetDeep = Color(0xFF141619);
  static const indigoDeep = Color(0xFF24292F);
  static const mintDeep = Color(0xFF186B4E);

  /// Dominant red accent for the NoteFlow brand mark (Red & White logo).
  static const brandRed = Color(0xFFE04F4F);
  static const brandRedDeep = Color(0xFFD63B3B);

  /// Formal charcoal ink used for buttons, badges, and strong headings.
  static const charcoal = Color(0xFF141619);

  // ---------------------------------------------------------------------------
  // Light surfaces (default formal workspace)
  // ---------------------------------------------------------------------------
  static const lightBackground = Color(0xFFF6F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFF1F3F6);
  static const lightSurfaceHighest = Color(0xFFE5E8EE);
  static const lightBorder = Color(0xFFE4E7EC);
  static const lightTextPrimary = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF4B5563);
  static const lightTextMuted = Color(0xFF8C94A4);

  // ---------------------------------------------------------------------------
  // Dark surfaces (clean neutral slate)
  // ---------------------------------------------------------------------------
  static const darkBackground = Color(0xFF111418);
  static const darkSurface = Color(0xFF181C22);
  static const darkSurfaceHigh = Color(0xFF20262E);
  static const darkSurfaceHighest = Color(0xFF2A313C);
  static const darkBorder = Color(0xFF2E3642);
  static const darkTextPrimary = Color(0xFFF3F4F6);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkTextMuted = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------
  static const success = Color(0xFF18794E);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF1B3A6B);

  static const dangerDeep = Color(0xFFB91C1C);
  static const warningDeep = Color(0xFFB45309);

  // ---------------------------------------------------------------------------
  // Pastel Note Card fills (indexed by `Note.colorIndex`)
  // Matches the "Notes / Memo Writing" pastel palette:
  // Mint Green, Periwinkle Lavender, Rose Pink, Butter Cream, Aqua Teal, Mauve.
  // ---------------------------------------------------------------------------
  static const noteCardPastels = <Color>[
    Color(0xFFD4EDC9), // 0: Soft Mint Green (Today's Tasks)
    Color(0xFFCCCBE6), // 1: Soft Periwinkle Lavender (Shopping List)
    Color(0xFFF6C2D4), // 2: Soft Rose Pink (Trend Lists)
    Color(0xFFFAF5C8), // 3: Soft Butter Cream (Homework)
    Color(0xFFB8E3E9), // 4: Soft Aqua Teal (Social Posts)
    Color(0xFFE8C5DF), // 5: Soft Mauve Orchid (Workout)
    Color(0xFFFAD9C8), // 6: Soft Peach Apricot
    Color(0xFFCFE2F8), // 7: Soft Ice Blue
  ];

  /// Deeper companion accents for dots, icons, and indicators.
  static const noteAccents = <Color>[
    Color(0xFF3E8E53), // Mint Green accent
    Color(0xFF6B67B2), // Periwinkle Lavender accent
    Color(0xFFC95B82), // Rose Pink accent
    Color(0xFFB59F26), // Butter Cream Gold accent
    Color(0xFF348D9B), // Aqua Teal accent
    Color(0xFF9E588C), // Mauve Orchid accent
    Color(0xFFC9734C), // Peach Apricot accent
    Color(0xFF4A7BB8), // Ice Blue accent
  ];

  /// Folder card soft fills for the "Recent Folders" / Labels showcase.
  static const folderPastels = <Color>[
    Color(0xFFD4EDC9), // Soft Mint folder card
    Color(0xFFCCCBE6), // Soft Lavender folder card
    Color(0xFFF6C2D4), // Soft Rose folder card
    Color(0xFFFAF5C8), // Soft Butter Cream folder card
  ];

  /// Folder icon colors matching the pastel note palette.
  static const folderIconColors = <Color>[
    Color(0xFF3E8E53), // Mint green icon
    Color(0xFF6B67B2), // Periwinkle lavender icon
    Color(0xFFC95B82), // Rose pink icon
    Color(0xFFB59F26), // Warm butter gold icon
  ];

  /// Human readable names for [noteAccents] (used for tooltips / semantics).
  static const noteAccentNames = <String>[
    'Mint Green',
    'Soft Lavender',
    'Rose Pink',
    'Butter Cream',
    'Aqua Teal',
    'Mauve Orchid',
    'Soft Peach',
    'Ice Blue',
  ];
}
