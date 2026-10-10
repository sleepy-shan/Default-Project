import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/media.dart';
import '../../data/models/media_entry.dart';

/// Color used for each list status.
Color statusColor(ListStatus status) => switch (status) {
      ListStatus.watching => Tokens.statusWatching,
      ListStatus.planning => Tokens.statusPlanning,
      ListStatus.completed => Tokens.statusCompleted,
      ListStatus.paused => Tokens.statusPaused,
      ListStatus.dropped => Tokens.statusDropped,
    };

/// Small colored chip describing a list status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, this.type, super.key});

  final ListStatus status;

  /// Media type, so "Watching" can render as "Reading" for manga.
  final MediaType? type;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final label = type != null ? status.labelFor(type!) : status.label;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space8,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
