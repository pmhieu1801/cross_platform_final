import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design tokens that don't fit in Material's [ColorScheme]:
/// brand gradient, glass surfaces, glow shadows, note accents, etc.
///
/// Usage:
/// ```dart
/// final tokens = context.tokens;
/// Container(decoration: BoxDecoration(gradient: tokens.brandGradient));
/// ```
@immutable
class NoteFlowTokens extends ThemeExtension<NoteFlowTokens> {
  const NoteFlowTokens({
    required this.brandGradient,
    required this.backgroundGradient,
    required this.glassFill,
    required this.glassBorder,
    required this.glassBlur,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.noteAccents,
    required this.glowOpacity,
    required this.shadowColor,
  });

  /// Primary call-to-action gradient (violet → indigo).
  final LinearGradient brandGradient;

  /// Very subtle app background gradient (adds depth behind glass panels).
  final LinearGradient backgroundGradient;

  /// Translucent fill used for glassmorphism panels.
  final Color glassFill;

  /// Hairline border for glass panels and cards.
  final Color glassBorder;

  /// Backdrop blur sigma for glass panels.
  final double glassBlur;

  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Accent colours for notes, indexed by `Note.colorIndex`.
  final List<Color> noteAccents;

  /// How strong coloured glows are (higher in dark mode).
  final double glowOpacity;

  /// Neutral elevation shadow colour.
  final Color shadowColor;

  /// Returns the accent colour for a note, wrapping safely.
  Color noteAccent(int index) => noteAccents[index.abs() % noteAccents.length];

  /// Soft coloured glow used on cards, focused inputs and primary buttons.
  List<BoxShadow> glow(Color color, {double strength = 1}) => [
    BoxShadow(
      color: color.withValues(alpha: glowOpacity * strength),
      blurRadius: 24,
      spreadRadius: -6,
      offset: const Offset(0, 8),
    ),
  ];

  /// Neutral elevation shadow.
  List<BoxShadow> get elevation => [
    BoxShadow(
      color: shadowColor,
      blurRadius: 32,
      spreadRadius: -12,
      offset: const Offset(0, 16),
    ),
  ];

  static const dark = NoteFlowTokens(
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.violet, AppColors.indigo],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF141831), AppColors.darkBackground, Color(0xFF0B0E1A)],
    ),
    glassFill: Color(0x14FFFFFF), // white 8%
    glassBorder: Color(0x1FFFFFFF), // white 12%
    glassBlur: 18,
    textMuted: AppColors.darkTextMuted,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
    noteAccents: AppColors.noteAccents,
    glowOpacity: 0.35,
    shadowColor: Color(0x66000000),
  );

  static const light = NoteFlowTokens(
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.violetDeep, AppColors.indigoDeep],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF7F5FF), AppColors.lightBackground, Color(0xFFEFF3FF)],
    ),
    glassFill: Color(0xB3FFFFFF), // white 70%
    glassBorder: Color(0x1A14172A), // ink 10%
    glassBlur: 18,
    textMuted: AppColors.lightTextMuted,
    success: AppColors.mintDeep,
    warning: AppColors.warningDeep,
    danger: AppColors.dangerDeep,
    info: AppColors.indigoDeep,
    noteAccents: AppColors.noteAccents,
    glowOpacity: 0.18,
    shadowColor: Color(0x1F1B1F3B),
  );

  @override
  NoteFlowTokens copyWith({
    LinearGradient? brandGradient,
    LinearGradient? backgroundGradient,
    Color? glassFill,
    Color? glassBorder,
    double? glassBlur,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    List<Color>? noteAccents,
    double? glowOpacity,
    Color? shadowColor,
  }) {
    return NoteFlowTokens(
      brandGradient: brandGradient ?? this.brandGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBlur: glassBlur ?? this.glassBlur,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      noteAccents: noteAccents ?? this.noteAccents,
      glowOpacity: glowOpacity ?? this.glowOpacity,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  NoteFlowTokens lerp(ThemeExtension<NoteFlowTokens>? other, double t) {
    if (other is! NoteFlowTokens) return this;
    return NoteFlowTokens(
      brandGradient: LinearGradient.lerp(
        brandGradient,
        other.brandGradient,
        t,
      )!,
      backgroundGradient: LinearGradient.lerp(
        backgroundGradient,
        other.backgroundGradient,
        t,
      )!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      noteAccents: t < 0.5 ? noteAccents : other.noteAccents,
      glowOpacity: lerpDouble(glowOpacity, other.glowOpacity, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

extension NoteFlowThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  NoteFlowTokens get tokens =>
      Theme.of(this).extension<NoteFlowTokens>() ?? NoteFlowTokens.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
