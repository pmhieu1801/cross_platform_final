import 'package:flutter/material.dart';

/// Type scale for NoteFlow.
///
/// * Display / headline / title-large → **Plus Jakarta Sans** (brand voice)
/// * Everything else → **Inter** (highly legible UI text)
///
/// Both families are bundled in `assets/fonts` and support Vietnamese.
abstract final class AppTypography {
  static const display = 'PlusJakartaSans';
  static const body = 'Inter';

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    TextStyle d(double size, FontWeight w, double spacing, [double? h]) =>
        TextStyle(
          fontFamily: display,
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          height: h,
          color: primary,
        );

    TextStyle b(
      double size,
      FontWeight w, {
      double spacing = 0,
      double? height,
      Color? color,
    }) => TextStyle(
      fontFamily: body,
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      height: height,
      color: color ?? primary,
    );

    return TextTheme(
      displayLarge: d(52, FontWeight.w800, -1.6, 1.1),
      displayMedium: d(42, FontWeight.w800, -1.2, 1.1),
      displaySmall: d(34, FontWeight.w700, -1.0, 1.15),
      headlineLarge: d(30, FontWeight.w700, -0.8, 1.2),
      headlineMedium: d(26, FontWeight.w700, -0.6, 1.2),
      headlineSmall: d(22, FontWeight.w700, -0.4, 1.25),
      titleLarge: d(18, FontWeight.w700, -0.2, 1.3),
      titleMedium: b(15, FontWeight.w600, height: 1.35),
      titleSmall: b(13, FontWeight.w600, height: 1.35),
      bodyLarge: b(16, FontWeight.w400, height: 1.6),
      bodyMedium: b(14, FontWeight.w400, height: 1.55, color: secondary),
      bodySmall: b(12, FontWeight.w400, height: 1.5, color: secondary),
      labelLarge: b(14, FontWeight.w600, spacing: 0.1),
      labelMedium: b(12, FontWeight.w600, spacing: 0.2),
      labelSmall: b(11, FontWeight.w600, spacing: 0.8, color: secondary),
    );
  }
}
