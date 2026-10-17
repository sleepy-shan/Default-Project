import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/account.dart';

/// The Anime buckets the profile shows, mirroring AniList's statistics strip:
/// each list status plus Favourites, each with its own icon "logo" + colour.
enum ProfileStat {
  watching('Watching', Icons.play_circle_fill_rounded, Tokens.statusWatching),
  completed('Completed', Icons.check_circle_rounded, Tokens.statusCompleted),
  planning('Planning', Icons.calendar_month_rounded, Tokens.statusPlanning),
  paused('Paused', Icons.pause_circle_filled_rounded, Tokens.statusPaused),
  dropped('Dropped', Icons.cancel_rounded, Tokens.statusDropped),
  rewatching(
    'Rewatching',
    Icons.replay_circle_filled_rounded,
    Tokens.statusRewatching,
  ),
  favourites('Favourites', Icons.favorite_rounded, Tokens.statusFavourite);

  const ProfileStat(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// The count for this bucket, or 0 while the profile is still loading.
  int countIn(ViewerProfile? profile) => switch (this) {
    ProfileStat.watching => profile?.watching ?? 0,
    ProfileStat.completed => profile?.completed ?? 0,
    ProfileStat.planning => profile?.planning ?? 0,
    ProfileStat.paused => profile?.paused ?? 0,
    ProfileStat.dropped => profile?.dropped ?? 0,
    ProfileStat.rewatching => profile?.rewatching ?? 0,
    ProfileStat.favourites => profile?.favourites ?? 0,
  };
}

/// Card listing every [ProfileStat] with its logo and count.
///
/// Uses one column on phones and two from tablet width up so the list stays
/// readable without stretching rows edge to edge.
class ProfileStatsPanel extends StatelessWidget {
  const ProfileStatsPanel({required this.profile, super.key});

  final ViewerProfile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: Tokens.space8),
                Text(
                  'Anime list',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = Tokens.space12;
                final columns = constraints.maxWidth >= 560 ? 2 : 1;
                final itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: Tokens.space4,
                  children: [
                    for (final stat in ProfileStat.values)
                      SizedBox(
                        width: itemWidth,
                        child: _StatRow(
                          stat: stat,
                          count: stat.countIn(profile),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat, required this.count});

  final ProfileStat stat;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Light mode: saturated hues (esp. paused yellow) read poorly on a tinted
    // chip, so darken for contrast. Dark mode keeps the vivid hue.
    final isDark = theme.brightness == Brightness.dark;
    final base = stat.color;
    final color = isDark
        ? base
        : HSLColor.fromColor(base)
              .withLightness(
                (HSLColor.fromColor(base).lightness - 0.18).clamp(0.0, 1.0),
              )
              .toColor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(stat.icon, size: 18, color: color),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: Tokens.space8),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
