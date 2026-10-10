import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/media.dart';
import '../../data/models/media_entry.dart';
import 'poster_card.dart';
import 'state_views.dart';

/// Grid of posters for tracked entries, with a progress bar under each.
class MediaEntryGrid extends StatelessWidget {
  const MediaEntryGrid({required this.entries, super.key});

  final List<MediaEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = posterColumns(constraints.maxWidth);
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * Tokens.space12) / columns;
        final tileHeight = tileWidth / Tokens.posterAspect + 76;

        return GridView.builder(
          padding: const EdgeInsets.only(
            left: Tokens.space16,
            right: Tokens.space16,
            bottom: Tokens.space32,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: Tokens.space16,
            crossAxisSpacing: Tokens.space12,
            childAspectRatio: tileWidth / tileHeight,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) => _EntryTile(entry: entries[index]),
        );
      },
    );
  }
}

/// One tracked title: poster, progress bar, title and counters.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = entry.fraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            child: entry.coverUrl == null || entry.coverUrl!.isEmpty
                ? ColoredBox(
                    color: theme.disabledColor.withValues(alpha: 0.12),
                  )
                : Image.network(
                    entry.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: theme.disabledColor.withValues(alpha: 0.12),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Tokens.space8),
        Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          '${entry.progress}'
          '${entry.totalUnits != null ? '/${entry.totalUnits}' : ''}'
          ' ${entry.unit}${entry.progress == 1 ? '' : 's'}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (fraction != null) ...[
          const SizedBox(height: Tokens.space4),
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Adaptive poster grid with infinite-scroll support.
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    required this.items,
    this.onEndReached,
    this.hasMore = false,
    super.key,
  });

  final List<Media> items;
  final VoidCallback? onEndReached;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = posterColumns(constraints.maxWidth);
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * Tokens.space12) / columns;
        final tileHeight = tileWidth / Tokens.posterAspect + 52;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!hasMore || onEndReached == null) return false;
            final metrics = notification.metrics;
            if (metrics.maxScrollExtent > 0 &&
                metrics.pixels >= metrics.maxScrollExtent - 320) {
              onEndReached!();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.only(
              left: Tokens.space16,
              right: Tokens.space16,
              bottom: Tokens.space32,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: Tokens.space16,
              crossAxisSpacing: Tokens.space12,
              childAspectRatio: tileWidth / tileHeight,
            ),
            itemCount: items.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return PosterCard(media: items[index]);
            },
          ),
        );
      },
    );
  }
}

/// Horizontal rail used on the dashboard.
class MediaRailList extends StatelessWidget {
  const MediaRailList({required this.items, super.key});

  final List<Media> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: Tokens.space12),
        itemBuilder: (context, index) => MediaRailCard(media: items[index]),
      ),
    );
  }
}
