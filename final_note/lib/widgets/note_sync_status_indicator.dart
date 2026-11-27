import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/theme.dart';

class NoteSyncStatusIndicator extends StatelessWidget {
  const NoteSyncStatusIndicator({
    required this.status,
    this.showLabel = false,
    super.key,
  });

  final NoteSyncStatus status;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final (icon, color) = switch (status) {
      NoteSyncStatus.pending => (Icons.cloud_upload_outlined, tokens.warning),
      NoteSyncStatus.synced => (Icons.cloud_done_outlined, tokens.success),
      NoteSyncStatus.failed => (Icons.cloud_off_outlined, tokens.danger),
    };

    return Semantics(
      container: true,
      label: status.label,
      liveRegion: showLabel,
      child: Tooltip(
        message: status.label,
        child: Row(
          key: Key('note-sync-status-${status.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (showLabel) ...[
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
