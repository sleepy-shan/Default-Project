import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/media.dart';
import '../../data/models/media_entry.dart';
import '../../state/media_providers.dart';
import '../../state/my_lists_controller.dart';
import '../components/poster_card.dart';
import '../components/progress_editor.dart';
import '../components/state_views.dart';
import '../components/status_badge.dart';

/// Media detail page: metadata plus tracking controls.
class MediaDetailScreen extends ConsumerWidget {
  const MediaDetailScreen({
    required this.mediaId,
    required this.initialType,
    super.key,
  });

  final int mediaId;
  final MediaType initialType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaDetailProvider(mediaId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _DetailError(
        mediaId: mediaId,
        message: error is AppException
            ? error.userMessage
            : 'Could not load this title. Please try again.',
      ),
      data: (media) => _DetailBody(media: media),
    );
  }
}

class _DetailError extends ConsumerWidget {
  const _DetailError({required this.mediaId, required this.message});

  final int mediaId;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorView(
      message: message,
      onRetry: () => ref.invalidate(mediaDetailProvider(mediaId)),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.media});

  final Media media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(myListsControllerProvider);
    final entry = lists.entryFor(media.id);
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ---- Hero -------------------------------------------------------
        _Hero(media: media, entry: entry),
        Padding(
          padding: const EdgeInsets.all(Tokens.space16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Overview(media: media),
                          if (media.relations.isNotEmpty) ...[
                            const SizedBox(height: Tokens.space24),
                            _RelationStrip(relations: media.relations),
                          ],
                          if (media.recommendations.isNotEmpty) ...[
                            const SizedBox(height: Tokens.space24),
                            _RecommendationStrip(
                              recommendations: media.recommendations,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: Tokens.space24),
                    Expanded(
                      flex: 2,
                      child: _TrackingPanel(
                        media: media,
                        entry: entry,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TrackingPanel(media: media, entry: entry),
                    const SizedBox(height: Tokens.space24),
                    _Overview(media: media),
                    if (media.relations.isNotEmpty) ...[
                      const SizedBox(height: Tokens.space24),
                      _RelationStrip(relations: media.relations),
                    ],
                    if (media.recommendations.isNotEmpty) ...[
                      const SizedBox(height: Tokens.space24),
                      _RecommendationStrip(
                        recommendations: media.recommendations,
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: Tokens.space48),
      ],
    );
  }
}

/// Banner + poster + title block.
class _Hero extends StatelessWidget {
  const _Hero({required this.media, required this.entry});

  final Media media;
  final MediaEntry? entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusEntry = entry;
    return Stack(
      children: [
        if (media.bannerUrl != null && media.bannerUrl!.isNotEmpty)
          Image.network(
            media.bannerUrl!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox(height: 220),
          )
        else
          const SizedBox(height: 120),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.scaffoldBackgroundColor.withValues(alpha: 0.1),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16,
            96,
            Tokens.space16,
            Tokens.space8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                child: media.coverUrl.isEmpty
                    ? Container(
                        width: 132,
                        height: 190,
                        color: theme.disabledColor.withValues(alpha: 0.15),
                      )
                    : Image.network(
                        media.coverUrl,
                        width: 132,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 132,
                          height: 190,
                          color: theme.disabledColor.withValues(alpha: 0.15),
                        ),
                      ),
              ),
              const SizedBox(width: Tokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media.title,
                      style: theme.textTheme.headlineMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Tokens.space8),
                    Wrap(
                      spacing: Tokens.space8,
                      runSpacing: Tokens.space8,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(media.type.label),
                          avatar: Icon(
                            media.type == MediaType.anime
                                ? Icons.movie_outlined
                                : Icons.menu_book_outlined,
                            size: 16,
                          ),
                        ),
                        if (media.format != MediaFormat.unknown)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(media.format.label),
                          ),
                        if (statusEntry != null)
                          StatusBadge(
                            status: statusEntry.status,
                            type: media.type,
                          ),
                        if (media.averageScore != null &&
                            media.averageScore! > 0)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Tokens.warning,
                            ),
                            label: Text(Formatters.score(media.averageScore)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Synopsis + metadata table + genres.
class _Overview extends StatelessWidget {
  const _Overview({required this.media});

  final Media media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = Formatters.cleanDescription(media.description);
    final info = <String, String>{
      if (media.status != MediaStatus.unknown) 'Status': media.status.label,
      if (media.format != MediaFormat.unknown) 'Format': media.format.label,
      if (media.episodes != null) 'Episodes': '${media.episodes}',
      if (media.chapters != null) 'Chapters': '${media.chapters}',
      if (media.volumes != null) 'Volumes': '${media.volumes}',
      if (media.duration != null) 'Episode length': '${media.duration} min',
      if (media.seasonYear != null)
        'Season': media.season != MediaSeason.unknown
            ? '${media.season.label} ${media.seasonYear}'
            : '${media.seasonYear}',
      if (media.studios.isNotEmpty) 'Studio': media.studios.join(', '),
      if (media.source != null) 'Source': media.source!,
      if (media.startDate != null)
        'Aired': Formatters.date(media.startDate),
      if (media.popularity != null)
        'Popularity': Formatters.compactNumber(media.popularity),
      if (media.favourites != null)
        'Favorites': Formatters.compactNumber(media.favourites),
      if (media.nextAiringEpisode != null)
        'Next episode':
            'EP ${media.nextAiringEpisode!.episode} • '
                '${Formatters.timeUntil(media.nextAiringEpisode!.airingAt)}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.genres.isNotEmpty) ...[
          Wrap(
            spacing: Tokens.space8,
            runSpacing: Tokens.space8,
            children: [
              for (final genre in media.genres)
                ActionChip(
                  label: Text(genre),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {},
                ),
            ],
          ),
          const SizedBox(height: Tokens.space16),
        ],
        if (description.isNotEmpty)
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Text(
            'No synopsis available for this title.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: Tokens.space24),
        if (info.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space16),
              child: Column(
                children: [
                  for (final MapEntry(key: label, value: value) in info.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Tokens.space8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(
                              label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              value,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Tokens.space16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final url = media.siteUrl;
              if (url != null && url.isNotEmpty) {
                launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View on AniList'),
          ),
        ),
      ],
    );
  }
}

/// Add/update/remove controls for the tracking list.
class _TrackingPanel extends ConsumerWidget {
  const _TrackingPanel({required this.media, required this.entry});

  final Media media;
  final MediaEntry? entry;

  void _snack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Tokens.danger : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(myListsControllerProvider.notifier);
    final entry = this.entry;
    final total = media.totalUnits;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tracking', style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space4),
            Text(
              entry == null
                  ? 'Save this ${media.type.label.toLowerCase()} to your list to track '
                      'progress and score.'
                  : 'On your list • updated ${Formatters.timeAgo(entry.updatedAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Tokens.space16),
            if (entry == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text('Add to my list'),
                  onPressed: () async {
                    if (!context.mounted) return;
                    try {
                      await controller.addTo(
                        media: media,
                        status: ListStatus.planning,
                        progress: 0,
                      );
                      if (!context.mounted) return;
                      _snack(context, 'Added to your list');
                    } catch (error) {
                      if (!context.mounted) return;
                      _snack(context, 'Could not add title', isError: true);
                    }
                  },
                ),
              )
            else ...[
              StatusSelector(
                status: entry.status,
                type: media.type,
                onChanged: (status) async {
                  if (!context.mounted) return;
                  try {
                    await controller.setStatus(media.id, status);
                    if (!context.mounted) return;
                    _snack(context, 'Status updated');
                  } catch (error) {
                    if (!context.mounted) return;
                    _snack(context, 'Could not update status', isError: true);
                  }
                },
              ),
              const SizedBox(height: Tokens.space12),
              ProgressEditor(
                progress: entry.progress,
                total: total,
                unit: media.type.unit,
                onChanged: (progress) =>
                    controller.setProgress(media.id, progress),
              ),
              const SizedBox(height: Tokens.space8),
              Row(
                children: [
                  ScoreSelector(
                    score: entry.score,
                    onChanged: (score) =>
                        controller.setScore(media.id, score),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                    onPressed: () async {
                      if (!context.mounted) return;
                      try {
                        await controller.remove(media.id);
                        if (!context.mounted) return;
                        _snack(context, 'Removed from your list');
                      } catch (error) {
                        if (!context.mounted) return;
                        _snack(
                          context,
                          'Could not remove entry',
                          isError: true,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of sequels/prequels/side stories.
class _RelationStrip extends StatelessWidget {
  const _RelationStrip({required this.relations});

  final List<MediaEdge> relations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Relations', style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.space12),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: relations.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: Tokens.space12),
            itemBuilder: (context, index) {
              final edge = relations[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 148,
                    child: MediaRailCard(media: edge.media),
                  ),
                  const SizedBox(height: Tokens.space4),
                  SizedBox(
                    width: 148,
                    child: Text(
                      edge.relationType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip of AniList recommendations.
class _RecommendationStrip extends StatelessWidget {
  const _RecommendationStrip({required this.recommendations});

  final List<Media> recommendations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('You might also like', style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.space12),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: Tokens.space12),
            itemBuilder: (context, index) =>
                MediaRailCard(media: recommendations[index]),
          ),
        ),
      ],
    );
  }
}
