import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/media.dart';
import '../router/app_router.dart';

/// Standard poster card used in every grid.
class PosterCard extends StatelessWidget {
  const PosterCard({required this.media, this.width, super.key});

  final Media media;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: () => context.go(Routes.mediaDetail(media.type, media.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PosterImage(media: media),
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              media.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              _subtitle(media),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitle(Media media) {
    final bits = <String>[
      media.format != MediaFormat.unknown ? media.format.label : media.type.label,
      if (media.seasonYear != null) '${media.seasonYear}',
    ];
    return bits.join(' • ');
  }
}

/// Poster artwork with graceful handling for missing/broken images.
class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.media});

  final Media media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = media.coverUrl;
    if (url.isEmpty) {
      return _PosterPlaceholder(media: media);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return ColoredBox(
                color: theme.disabledColor.withValues(alpha: 0.12),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) =>
                _PosterPlaceholder(media: media),
          ),
          if (media.averageScore != null && media.averageScore! > 0)
            Positioned(
              left: Tokens.space4,
              top: Tokens.space4,
              child: _ScoreBadge(score: media.averageScore!),
            ),
          if (media.nextAiringEpisode != null)
            Positioned(
              right: Tokens.space4,
              bottom: Tokens.space4,
              child: _AiringBadge(
                episode: media.nextAiringEpisode!.episode,
                airingAt: media.nextAiringEpisode!.airingAt,
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.media});

  final Media media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.disabledColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: Tokens.space4),
              Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space8,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Tokens.warning),
          const SizedBox(width: Tokens.space4),
          Text(
            Formatters.score(score),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiringBadge extends StatelessWidget {
  const _AiringBadge({required this.episode, required this.airingAt});

  final int episode;
  final int airingAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space8,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Text(
        'EP ${Formatters.timeUntil(airingAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Horizontal rail card (bigger artwork, used on the home dashboard).
class MediaRailCard extends StatelessWidget {
  const MediaRailCard({required this.media, this.width = 148, super.key});

  final Media media;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: () => context.go(Routes.mediaDetail(media.type, media.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _PosterImage(media: media)),
            const SizedBox(height: Tokens.space8),
            Text(
              media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
