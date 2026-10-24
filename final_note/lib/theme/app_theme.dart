import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';
import 'noteflow_tokens.dart';

/// Builds the light and dark [ThemeData] for NoteFlow.
abstract final class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.violet,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF2D2366),
      onPrimaryContainer: Color(0xFFE3DCFF),
      secondary: AppColors.indigo,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF1D2B5C),
      onSecondaryContainer: Color(0xFFD9E2FF),
      tertiary: AppColors.mint,
      onTertiary: Color(0xFF00391F),
      tertiaryContainer: Color(0xFF0E3D2B),
      onTertiaryContainer: Color(0xFFB4F5D6),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFF4A1422),
      onErrorContainer: Color(0xFFFFD9DF),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: Color(0xFF131729),
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceHigh,
      surfaceContainerHighest: AppColors.darkSurfaceHighest,
      outline: Color(0x33FFFFFF),
      outlineVariant: AppColors.darkBorder,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.darkTextPrimary,
      onInverseSurface: AppColors.darkBackground,
      inversePrimary: AppColors.violetDeep,
    ),
    background: AppColors.darkBackground,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    tokens: NoteFlowTokens.dark,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.violetDeep,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE8E2FF),
      onPrimaryContainer: Color(0xFF22106B),
      secondary: AppColors.indigoDeep,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDDE6FF),
      onSecondaryContainer: Color(0xFF0D1F5C),
      tertiary: AppColors.mintDeep,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFCFF7E5),
      onTertiaryContainer: Color(0xFF00391F),
      error: AppColors.dangerDeep,
      onError: Colors.white,
      errorContainer: Color(0xFFFFE0E6),
      onErrorContainer: Color(0xFF5C0A1C),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: Color(0xFFF8F9FD),
      surfaceContainer: AppColors.lightSurfaceHigh,
      surfaceContainerHigh: AppColors.lightSurfaceHigh,
      surfaceContainerHighest: AppColors.lightSurfaceHighest,
      outline: Color(0xFFC9CDDD),
      outlineVariant: AppColors.lightBorder,
      shadow: Color(0xFF1B1F3B),
      scrim: Colors.black,
      inverseSurface: AppColors.darkSurface,
      onInverseSurface: AppColors.darkTextPrimary,
      inversePrimary: AppColors.violet,
    ),
    background: AppColors.lightBackground,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    tokens: NoteFlowTokens.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required Color textPrimary,
    required Color textSecondary,
    required NoteFlowTokens tokens,
  }) {
    final textTheme = AppTypography.textTheme(
      primary: textPrimary,
      secondary: textSecondary,
    );
    final isDark = brightness == Brightness.dark;
    final inputFill = isDark
        ? const Color(0x0DFFFFFF) // white 5%
        : AppColors.lightSurface;

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: color, width: width),
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: AppRadius.mdAll,
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.body,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [tokens],

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: textSecondary, size: AppSizes.iconMd),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? scheme.primary
              : tokens.textMuted,
        ),
        suffixIconColor: tokens.textMuted,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        disabledBorder: inputBorder(
          scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.buttonHeight),
          padding: buttonPadding,
          shape: buttonShape,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.buttonHeight),
          padding: buttonPadding,
          shape: buttonShape,
          elevation: 0,
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.buttonHeight),
          padding: buttonPadding,
          shape: buttonShape,
          foregroundColor: textPrimary,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
          minimumSize: const Size.square(AppSizes.minTapTarget),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        showCheckmark: false,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: textSecondary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        iconColor: textSecondary,
        textColor: textPrimary,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelMedium),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: textPrimary,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: textSecondary,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHigh),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll,
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        elevation: 0,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),

      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppRadius.pill),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.all(
          scheme.onSurface.withValues(alpha: 0.2),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
