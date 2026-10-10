import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/media_entry.dart';
import '../../state/media_providers.dart';
import '../../state/my_lists_controller.dart';
import '../components/media_grid.dart';
import '../components/section_header.dart';
import '../components/state_views.dart';
import '../router/app_router.dart';

/// Dashboard: continue rail plus trending rails from AniList.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueEntries = ref.watch(continueWatchingProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: Tokens.space32),
      children: [
        if (continueEntries.isNotEmpty) ...[
          SectionHeader(
            title: 'Continue watching / reading',
            subtitle: 'Jump back into what you were tracking',
            actionLabel: 'My List',
            actionPath: Routes.lists,
          ),
          _ContinueRail(entries: continueEntries),
        ],
        _RailSection(
          title: 'Trending anime',
          subtitle: 'What AniList users are watching this week',
          rail: MediaRail.trendingAnime,
          seeAllPath: Routes.anime,
        ),
        _RailSection(
          title: 'Popular this year',
          subtitle: 'The hottest anime releases of ${DateTime.now().year}',
          rail: MediaRail.popularThisSeason,
          seeAllPath: Routes.anime,
        ),
        _RailSection(
          title: 'Trending manga',
          subtitle: 'What AniList users are reading this week',
          rail: MediaRail.trendingManga,
          seeAllPath: Routes.manga,
        ),
      ],
    );
  }
}

/// Inline rail that loads its own data and handles every state.
class _RailSection extends ConsumerWidget {
  const _RailSection({
    required this.title,
    required this.subtitle,
    required this.rail,
    required this.seeAllPath,
  });

  final String title;
  final String subtitle;
  final MediaRail rail;
  final String seeAllPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaRailProvider(rail));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: 'See all',
          actionPath: seeAllPath,
        ),
        SizedBox(
          height: 232,
          child: async.when(
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
              itemCount: 5,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: Tokens.space12),
              itemBuilder: (context, index) =>
                  const SizedBox(width: 148, child: SkeletonTile(height: 232)),
            ),
            error: (error, stack) => _RailError(
              onRetry: () => ref.invalidate(mediaRailProvider(rail)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return const EmptyView(
                  message: 'No titles available right now.',
                  icon: Icons.movie_filter_outlined,
                );
              }
              return MediaRailList(items: page.items);
            },
          ),
        ),
      ],
    );
  }
}

class _RailError extends StatelessWidget {
  const _RailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            "Couldn't load titles. AniList may be rate-limiting.",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// "Continue" rail: entry poster + progress + a one-tap increment.
class _ContinueRail extends ConsumerWidget {
  const _ContinueRail({required this.entries});

  final List<MediaEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: Tokens.space12),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _ContinueCard(entry: entry);
        },
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.entry});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fraction = entry.fraction;
    final width = 280.0;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                child: SizedBox(
                  width: 56,
                  height: 84,
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
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                      ' ${entry.unit}s',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (fraction != null) ...[
                      const SizedBox(height: Tokens.space4),
                      LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                        backgroundColor: theme.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Mark one more ${entry.unit} watched',
                icon: const Icon(Icons.add, size: 18),
                onPressed: () async {
                  await ref
                      .read(myListsControllerProvider.notifier)
                      .incrementProgress(entry.mediaId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
