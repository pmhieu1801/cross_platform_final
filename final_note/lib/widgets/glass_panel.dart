import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Frosted-glass container used for cards, panels and dialogs.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.xlAll,
    this.blur = true,
    this.glowColor,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Disable for panels inside long scrolling lists (backdrop blur is costly).
  final bool blur;

  /// Optional coloured glow around the panel.
  final Color? glowColor;

  /// Whether to draw the neutral elevation shadow.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.glassFill,
        borderRadius: borderRadius,
        border: Border.all(color: tokens.glassBorder),
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          if (elevated) ...tokens.elevation,
          if (glowColor != null) ...tokens.glow(glowColor!),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: tokens.glassBlur,
                  sigmaY: tokens.glassBlur,
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}
