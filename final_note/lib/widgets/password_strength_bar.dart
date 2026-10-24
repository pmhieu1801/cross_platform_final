import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/validators.dart';

/// Visual password strength meter (Weak / Fair / Good / Strong).
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.empty) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final text = context.text;

    final (color, label, fraction) = switch (strength) {
      PasswordStrength.empty => (Colors.transparent, '', 0.0),
      PasswordStrength.weak => (tokens.danger, 'Weak', 0.25),
      PasswordStrength.fair => (tokens.warning, 'Fair', 0.5),
      PasswordStrength.good => (tokens.info, 'Good', 0.75),
      PasswordStrength.strong => (tokens.success, 'Strong', 1.0),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password strength',
                style: text.labelSmall?.copyWith(color: tokens.textMuted),
              ),
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: context.colors.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
