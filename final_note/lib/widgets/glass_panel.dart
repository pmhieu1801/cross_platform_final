import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Clean, formal surface container used for cards, auth forms and dialogs.
/// Replaces the old frosted-glass neon glow panel with a crisp solid surface.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.xlAll,
    this.blur = false,
    this.glowColor,
    this.elevated = true,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool blur;
  final Color? glowColor;
  final bool elevated;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.glassFill,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? tokens.glassBorder),
        boxShadow: elevated ? tokens.elevation : null,
      ),
      child: child,
    );
  }
}
