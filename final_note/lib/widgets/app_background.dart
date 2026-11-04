import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Clean, formal full-screen workspace background (solid tone, no neon glow orbs).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.scaffoldBackgroundColor,
      child: SizedBox.expand(child: child),
    );
  }
}
