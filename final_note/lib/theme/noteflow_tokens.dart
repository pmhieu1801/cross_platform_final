import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design tokens for the NoteFlow formal workspace theme:
/// solid surfaces, subtle neutral shadows, and MINO pastel note/folder tokens.
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

  /// Solid-color linear gradient kept for backward compatibility (both stops identical).
  final LinearGradient brandGradient;

  /// Solid flat background gradient (both stops identical, no multi-color gradient).
  final LinearGradient backgroundGradient;

  /// Solid surface fill for panels and cards.
  final Color glassFill;

  /// Hairline border for panels and cards.
  final Color glassBorder;

  /// Blur sigma (0 for crisp formal cards).
  final double glassBlur;

  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Accent colours for notes, indexed by `Note.colorIndex`.
  final List<Color> noteAccents;

  /// Shadow opacity factor.
  final double glowOpacity;

  /// Neutral elevation shadow colour.
  final Color shadowColor;

  /// Returns the accent colour for a note, wrapping safely.
  Color noteAccent(int index) => noteAccents[index.abs() % noteAccents.length];

  /// Returns the solid pastel card background colour for a note (MINO palette).
  Color noteCardFill(int index) =>
      AppColors.noteCardPastels[index.abs() % AppColors.noteCardPastels.length];

  /// Subtle formal neutral shadow (replaces neon colored glow).
  List<BoxShadow> glow(Color color, {double strength = 1}) => [
    BoxShadow(
      color: shadowColor.withValues(alpha: (0.06 * strength).clamp(0.0, 0.16)),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
  ];

  /// Neutral elevation shadow.
  List<BoxShadow> get elevation => [
    BoxShadow(
      color: shadowColor,
      blurRadius: 24,
      spreadRadius: -8,
      offset: const Offset(0, 10),
    ),
  ];

  static const dark = NoteFlowTokens(
    brandGradient: LinearGradient(colors: [AppColors.indigo, AppColors.indigo]),
    backgroundGradient: LinearGradient(
      colors: [AppColors.darkBackground, AppColors.darkBackground],
    ),
    glassFill: AppColors.darkSurface,
    glassBorder: AppColors.darkBorder,
    glassBlur: 0,
    textMuted: AppColors.darkTextMuted,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
    noteAccents: AppColors.noteAccents,
    glowOpacity: 0.08,
    shadowColor: Color(0x40000000),
  );

  static const light = NoteFlowTokens(
    brandGradient: LinearGradient(
      colors: [AppColors.violetDeep, AppColors.violetDeep],
    ),
    backgroundGradient: LinearGradient(
      colors: [AppColors.lightBackground, AppColors.lightBackground],
    ),
    glassFill: AppColors.lightSurface,
    glassBorder: AppColors.lightBorder,
    glassBlur: 0,
    textMuted: AppColors.lightTextMuted,
    success: AppColors.mintDeep,
    warning: AppColors.warningDeep,
    danger: AppColors.dangerDeep,
    info: AppColors.indigoDeep,
    noteAccents: AppColors.noteAccents,
    glowOpacity: 0.06,
    shadowColor: Color(0x12111827),
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
      Theme.of(this).extension<NoteFlowTokens>() ?? NoteFlowTokens.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
