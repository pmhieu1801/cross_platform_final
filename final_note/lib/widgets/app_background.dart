import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Full-screen app background: subtle gradient plus soft coloured glow orbs.
///
/// Wrap a screen's body with this to get the "Midnight Glow" atmosphere.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final orbOpacity = tokens.glowOpacity * 0.8;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: tokens.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -180,
            left: -140,
            child: _GlowOrb(
              color: colors.primary,
              size: 460,
              opacity: orbOpacity,
            ),
          ),
          Positioned(
            bottom: -200,
            right: -160,
            child: _GlowOrb(
              color: colors.secondary,
              size: 520,
              opacity: orbOpacity,
            ),
          ),
          Align(
            alignment: const Alignment(0.55, -0.35),
            child: _GlowOrb(
              color: colors.tertiary,
              size: 240,
              opacity: orbOpacity * 0.45,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
