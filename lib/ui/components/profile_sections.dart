import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/account.dart';
import '../../data/models/media.dart';
import '../../data/models/media_entry.dart';
import '../router/app_router.dart';
import 'status_badge.dart';

/// Section heading used on the profile: plain title, optional trailing action.
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({
    required this.title,
    this.trailing,
    this.caption,
    super.key,
  });

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status ribbon
// ---------------------------------------------------------------------------

class StatusSlice {
  const StatusSlice(this.label, this.color, this.count);

  final String label;
  final Color color;
  final int count;
}

/// One horizontal ribbon whose segment widths are the list's status split,
/// with a legend underneath. Empty statuses are left out.
class StatusRibbon extends StatelessWidget {
  const StatusRibbon({required this.slices, super.key});

  final List<StatusSlice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = slices.where((s) => s.count > 0).toList();
    final total = shown.fold<int>(0, (sum, s) => sum + s.count);

    if (total == 0) {
      return Text(
        'Nothing tracked yet. Add a title and its status shows up here.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
          child: SizedBox(
            height: 12,
            child: Row(
              spacing: 2,
              children: [
                for (final slice in shown)
                  Expanded(
                    flex: slice.count,
                    child: Tooltip(
                      message: '${slice.label}: ${slice.count}',
                      child: ColoredBox(color: slice.color),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.space12),
        Wrap(
          spacing: Tokens.space20,
          runSpacing: Tokens.space8,
          children: [
            for (final slice in shown)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Tokens.space8,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: slice.label,
                      children: [
                        TextSpan(
                          text: '  ${slice.count}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Favorites shelf
// ---------------------------------------------------------------------------

/// Tabbed shelf of favorite anime, manga and characters. The first item of a
/// tab is shown larger as that tab's top pick on roomy screens.
class FavoritesShelf extends StatefulWidget {
  const FavoritesShelf({required this.favorites, super.key});

  final List<ProfileFavorite> favorites;

  @override
  State<FavoritesShelf> createState() => _FavoritesShelfState();
}

class _FavoritesShelfState extends State<FavoritesShelf> {
  FavoriteKind? _picked;

  List<ProfileFavorite> _of(FavoriteKind kind) =>
      widget.favorites.where((f) => f.kind == kind).toList(growable: false);

  /// The picked tab, or the first tab that has something in it.
  FavoriteKind get _kind =>
      _picked ??
      FavoriteKind.values.firstWhere(
        (k) => _of(k).isNotEmpty,
        orElse: () => FavoriteKind.anime,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = _kind;
    final items = _of(kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Tokens.space8,
          runSpacing: Tokens.space8,
          children: [
            for (final k in FavoriteKind.values)
              ChoiceChip(
                selected: k == kind,
                label: Text('${k.label}  ${_of(k).length}'),
                onSelected: (_) => setState(() => _picked = k),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        if (items.isEmpty)
          Text(
            switch (kind) {
              FavoriteKind.character =>
                'Favorite characters come from your AniList account. Sign in '
                    'to see them here.',
              _ =>
                'No favorite ${kind.label.toLowerCase()} yet. Tap the heart '
                    'on a title page to add one.',
            },
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final roomy = constraints.maxWidth >= 720;
              final tile = roomy ? 128.0 : 108.0;
              final lead = roomy ? 192.0 : tile;
              return Wrap(
                spacing: Tokens.space16,
                runSpacing: Tokens.space20,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _FavoriteTile(
                      favorite: items[i],
                      width: i == 0 ? lead : tile,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.favorite, required this.width});

  final ProfileFavorite favorite;
  final double width;

  void _open(BuildContext context) {
    final path = switch (favorite.kind) {
      FavoriteKind.anime => Routes.mediaDetail(MediaType.anime, favorite.id),
      FavoriteKind.manga => Routes.mediaDetail(MediaType.manga, favorite.id),
      FavoriteKind.character => Routes.characterWorks(favorite.id),
    };
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final url = favorite.imageUrl;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Icon(Icons.image_not_supported_outlined, color: scheme.outline),
    );
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: url == null || url.isEmpty
                    ? placeholder
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stack) => placeholder,
                      ),
              ),
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              favorite.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (favorite.subtitle != null)
              Text(
                favorite.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity
// ---------------------------------------------------------------------------

/// The most recently touched entries of the on-device list.
class RecentActivity extends StatelessWidget {
  const RecentActivity({required this.entries, super.key});

  final List<MediaEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (entries.isEmpty) {
      return Text(
        'Updates to your list appear here as you track.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
          _ActivityRow(entry: entries[i]),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cover = entry.coverUrl;
    final total = entry.totalUnits;
    final progressText = total == null
        ? '${entry.unit} ${entry.progress}'
        : '${entry.unit} ${entry.progress} of $total';
    return InkWell(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      onTap: () =>
          context.go(Routes.mediaDetail(entry.type, entry.mediaId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: SizedBox(
                width: 44,
                height: 64,
                child: cover == null || cover.isEmpty
                    ? ColoredBox(color: scheme.surfaceContainerHigh)
                    : Image.network(
                        cover,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stack) =>
                            ColoredBox(color: scheme.surfaceContainerHigh),
                      ),
              ),
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    progressText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (entry.fraction != null) ...[
                    const SizedBox(height: Tokens.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tokens.radiusPill),
                      child: LinearProgressIndicator(
                        value: entry.fraction,
                        minHeight: 4,
                        color: statusColor(entry.status),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Tokens.space12),
            StatusBadge(status: entry.status, type: entry.type),
          ],
        ),
      ),
    );
  }
}
