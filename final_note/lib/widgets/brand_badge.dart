import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// NoteFlow logo mark with a soft gradient and icon.
class BrandBadge extends StatelessWidget {
  const BrandBadge({
    super.key,
    this.size = 44,
    this.showText = true,
    this.textStyle,
  });

  final double size;
  final bool showText;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: tokens.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: tokens.glow(colors.primary, strength: 0.8),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: AppSpacing.md),
          Text(
            'NoteFlow',
            style:
                textStyle ??
                text.titleLarge?.copyWith(
                  fontFamily: AppTypography.display,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
          ),
        ],
      ],
    );
  }
}
