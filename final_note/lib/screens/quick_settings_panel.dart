part of 'notes_home_screen.dart';

/// Compact popover shown from the gear button: Dark mode switch, notes view,
/// and note text size. Changes apply and persist immediately per account.
class _QuickSettingsPanel extends StatefulWidget {
  const _QuickSettingsPanel({
    required this.isDark,
    required this.layout,
    required this.fontScale,
    this.onDarkChanged,
    this.onLayoutChanged,
    this.onFontScaleChanged,
    this.onOpenAllSettings,
  });

  final bool isDark;
  final _NotesLayout layout;
  final double fontScale;
  final ValueChanged<bool>? onDarkChanged;
  final ValueChanged<_NotesLayout>? onLayoutChanged;
  final ValueChanged<double>? onFontScaleChanged;
  final VoidCallback? onOpenAllSettings;

  @override
  State<_QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<_QuickSettingsPanel> {
  late bool _isDark = widget.isDark;
  late double _fontScale = widget.fontScale.clamp(0.85, 1.5).toDouble();

  @override
  void didUpdateWidget(covariant _QuickSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) _isDark = widget.isDark;
    if (oldWidget.fontScale != widget.fontScale) {
      _fontScale = widget.fontScale.clamp(0.85, 1.5).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final tokens = context.tokens;

    Widget sectionLabel(String label) => Text(
      label,
      style: text.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );

    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: colors.onSurface),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Quick settings',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    _isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 20,
                    color: colors.onSurface,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Dark mode',
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _isDark ? 'Dark theme is on' : 'White theme is on',
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('quick-dark-mode-switch'),
                    value: _isDark,
                    onChanged: widget.onDarkChanged == null
                        ? null
                        : (value) {
                            setState(() => _isDark = value);
                            widget.onDarkChanged!(value);
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            sectionLabel('NOTES VIEW'),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<_NotesLayout>(
              key: const Key('quick-view-mode'),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _NotesLayout.grid,
                  icon: Icon(Icons.grid_view_rounded, size: 16),
                  label: Text('Grid'),
                ),
                ButtonSegment(
                  value: _NotesLayout.list,
                  icon: Icon(Icons.view_list_rounded, size: 16),
                  label: Text('List'),
                ),
              ],
              selected: {widget.layout},
              onSelectionChanged: widget.onLayoutChanged == null
                  ? null
                  : (selection) => widget.onLayoutChanged!(selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                sectionLabel('NOTE TEXT SIZE'),
                const Spacer(),
                Text(
                  '${(_fontScale * 100).round()}%',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              key: const Key('quick-font-scale'),
              value: _fontScale,
              min: 0.85,
              max: 1.5,
              divisions: 13,
              onChanged: widget.onFontScaleChanged == null
                  ? null
                  : (value) => setState(() => _fontScale = value),
              onChangeEnd: widget.onFontScaleChanged,
            ),
            if (widget.onOpenAllSettings != null) ...[
              Divider(color: colors.outlineVariant, height: AppSpacing.lg),
              TextButton.icon(
                key: const Key('open-preferences'),
                onPressed: widget.onOpenAllSettings,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined, size: 17),
                label: const Text('All settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
