import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Primary call-to-action button using a formal solid colour (no gradient,
/// no neon glow). Supports hover/focus feedback and a loading state.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = AppSizes.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highlighted = _enabled && (_hovered || _focused);

    final foreground = _enabled || widget.loading
        ? Colors.white
        : colors.onSurface.withValues(alpha: 0.38);

    final backgroundColor = _enabled || widget.loading
        ? (highlighted ? const Color(0xFF262A30) : AppColors.charcoal)
        : colors.onSurface.withValues(alpha: 0.08);

    return Semantics(
      button: true,
      enabled: _enabled,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1,
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: AppCurves.standard,
          height: widget.height,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.pillAll,
            border: _focused
                ? Border.all(color: AppColors.brandRed, width: 2)
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: AppRadius.pillAll,
              onTap: _enabled ? widget.onPressed : null,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              mouseCursor: _enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              splashColor: Colors.white.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: widget.loading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: foreground,
                            semanticsLabel: 'Loading',
                          ),
                        )
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: context.text.labelLarge?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.icon != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                widget.icon,
                                size: AppSizes.iconSm,
                                color: foreground,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
