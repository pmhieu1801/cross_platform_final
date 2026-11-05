import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Formal NoteFlow brand mark with a dominant Red & White color palette:
/// two overlapping geometric circles in crimson red and crisp white.
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
    final circleSize = size * 0.64;

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
                decoration: const BoxDecoration(
                  color: AppColors.brandRed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: circleSize * 0.34,
                  height: circleSize * 0.34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: size - circleSize,
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandRed, width: 2.5),
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
