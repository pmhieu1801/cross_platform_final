import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Formal NoteFlow brand mark inspired by the MINO workspace header:
/// two clean overlapping geometric circles in solid navy and charcoal typography.
class BrandBadge extends StatelessWidget {
  const BrandBadge({
    super.key,
    this.size = 36,
    this.showText = true,
    this.textStyle,
  });

  final double size;
  final bool showText;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final circleSize = size * 0.62;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: circleSize,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Positioned(
                left: size - circleSize,
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary, width: 2.2),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: AppSpacing.sm + 2),
          Text(
            'NoteFlow',
            style:
                textStyle ??
                text.titleLarge?.copyWith(
                  fontFamily: AppTypography.display,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: colors.onSurface,
                ),
          ),
        ],
      ],
    );
  }
}
