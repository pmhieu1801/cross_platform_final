import 'package:flutter/material.dart';

/// Raw colour palette for the NoteFlow formal editorial design system
/// (inspired by the clean MINO workspace aesthetic).
///
/// Widgets should read colours through `Theme.of(context).colorScheme` or the
/// [NoteFlowTokens] theme extension so that light and dark modes stay consistent.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand (Formal solid tones — no neon purple gradients)
  // ---------------------------------------------------------------------------
  /// Formal deep navy blue (primary action & brand mark).
  static const violet = Color(0xFF1B3A6B);
  static const indigo = Color(0xFF2B528C);
  static const mint = Color(0xFF1F7A5A);

  /// Deep tones used on light backgrounds for high WCAG contrast.
  static const violetDeep = Color(0xFF1B3A6B);
  static const indigoDeep = Color(0xFF24477A);
  static const mintDeep = Color(0xFF186B4E);

  /// Formal charcoal ink used for badges and strong headings.
  static const charcoal = Color(0xFF111827);

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
  // MINO Pastel Note Card fills (indexed by `Note.colorIndex`)
  // Matches the soft yellow, coral rose, sky blue, ice blue, blush & cream cards.
  // ---------------------------------------------------------------------------
  static const noteCardPastels = <Color>[
    Color(0xFFEBE886), // Warm yellow (Mid test exam)
    Color(0xFFF1ACAC), // Soft coral rose (Mid test exam)
    Color(0xFF77BFE6), // Sky blue (Jonas's notes)
    Color(0xFFDDEEFF), // Pale ice blue (Movie Review)
    Color(0xFFFAD8D6), // Pale blush pink (Class Notes)
    Color(0xFFFBF9DF), // Soft buttercream (Book Lists)
    Color(0xFFD9F0E3), // Soft sage mint
    Color(0xFFEAECEF), // Warm neutral stone
  ];

  /// Deeper companion accents for dots, icons, and dark-mode indicators.
  static const noteAccents = <Color>[
    Color(0xFF9E991A), // Warm olive-gold
    Color(0xFFC85A5A), // Coral red
    Color(0xFF2B7CB3), // Cerulean blue
    Color(0xFF6E7BF2), // Periwinkle folder icon
    Color(0xFFB36B43), // Terracotta folder icon
    Color(0xFFC9C24B), // Citrine folder icon
    Color(0xFF2E8B63), // Forest sage
    Color(0xFF64748B), // Slate
  ];

  /// Folder card soft fills for the "Recent Folders" / Labels showcase.
  static const folderPastels = <Color>[
    Color(0xFFDDEEFF), // Soft blue folder card
    Color(0xFFFAD8D6), // Soft pink folder card
    Color(0xFFFBF9DF), // Soft yellow folder card
    Color(0xFFD9F0E3), // Soft mint folder card
  ];

  /// Folder icon colors matching the MINO reference.
  static const folderIconColors = <Color>[
    Color(0xFF7B83EB), // Periwinkle blue icon
    Color(0xFFB66E41), // Warm brown/terracotta icon
    Color(0xFFDED966), // Warm yellow icon
    Color(0xFF4A9B76), // Sage green icon
  ];

  /// Human readable names for [noteAccents] (used for tooltips / semantics).
  static const noteAccentNames = <String>[
    'Warm Yellow',
    'Coral Rose',
    'Sky Blue',
    'Ice Blue',
    'Blush Peach',
    'Soft Cream',
    'Sage Mint',
    'Slate',
  ];
}
