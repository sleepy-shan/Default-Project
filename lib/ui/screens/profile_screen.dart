import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/account.dart';
import '../../data/models/media.dart';
import '../../data/models/media_entry.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/media_providers.dart';
import '../../state/my_lists_controller.dart';
import '../../state/profile_prefs.dart';
import '../../state/providers.dart';
import '../components/app_footer.dart';
import '../components/profile_banner.dart';
import '../components/profile_sections.dart';
import '../router/app_router.dart';

/// Profile page: animated banner, avatar, stats, list breakdown, favorites
/// and recent activity.
///
/// Guests get a working profile built from the list stored in this browser;
/// signing in with AniList swaps in the AniList avatar, banner, statistics
/// and favorites. Lists themselves stay in this browser.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final auth = ref.watch(authStateProvider);
    final AuthUser? user = switch (auth) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final profileAsync = user == null ? null : ref.watch(viewerProfileProvider);
    final profile = profileAsync?.value;

    final entries = ref.watch(
      myListsControllerProvider.select((s) => s.entries),
    );
    final localFavorites = ref.watch(localFavoritesProvider);
    final bannerPrefs = ref.watch(profileBannerProvider);

    // Which artwork to show: null means the animated komorebi canvas.
    final String? bannerUrl = switch (bannerPrefs.source) {
      BannerSource.anilist => profile?.bannerUrl,
      BannerSource.komorebi => null,
      BannerSource.custom =>
        bannerPrefs.hasValidUrl ? bannerPrefs.url!.trim() : null,
    };

    final stats = _computeStats(profile, entries);
    final slices = _computeSlices(profile, entries, scheme);
    final favorites = _mergeFavorites(profile, localFavorites);
    final recent = ([...entries]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        .take(5)
        .toList(growable: false);

    return CustomScrollView(
      physics: const SmoothScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: ResponsiveCenter(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Tokens.space16),
                _ProfileHero(
                  user: user,
                  avatarUrl: user?.avatarUrl ?? profile?.avatarUrl,
                  bannerUrl: bannerUrl,
                  isCustomLink: bannerPrefs.source == BannerSource.custom,
                ),
                const SizedBox(height: Tokens.space20),
                _StatsRow(
                  stats: stats,
                  signedIn: user != null,
                  onSignIn: () => showSignInDialog(context),
                  onSignOut: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out')),
                      );
                    }
                  },
                ),
                if (profileAsync != null && profileAsync.hasError) ...[
                  const SizedBox(height: Tokens.space12),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: scheme.error,
                      ),
                      const SizedBox(width: Tokens.space8),
                      Expanded(
                        child: Text(
                          'Could not load your AniList stats. Showing what is '
                          'saved on this device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(viewerProfileProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Tokens.space32),
                ProfileSectionTitle(
                  title: 'Your list',
                  caption: user == null
                      ? 'From the list saved in this browser'
                      : 'Anime on your AniList account',
                ),
                const SizedBox(height: Tokens.space16),
                StatusRibbon(slices: slices),
                const SizedBox(height: Tokens.space48),
                const ProfileSectionTitle(title: 'Favorites'),
                const SizedBox(height: Tokens.space16),
                FavoritesShelf(favorites: favorites),
                const SizedBox(height: Tokens.space48),
                ProfileSectionTitle(
                  title: 'Recent activity',
                  trailing: entries.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => context.go(Routes.lists),
                          child: Text('Open full list (${entries.length})'),
                        ),
                ),
                const SizedBox(height: Tokens.space8),
                RecentActivity(entries: recent),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Tokens.space48)),
        const SliverAppFooter(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Data shaping
// ---------------------------------------------------------------------------

class _Stats {
  const _Stats({this.watching, this.episodes, this.mean});

  final int? watching;
  final int? episodes;

  /// Mean score on AniList's 0-100 scale.
  final double? mean;
}

/// AniList numbers when signed in; otherwise derived from the local list.
_Stats _computeStats(ViewerProfile? profile, List<MediaEntry> entries) {
  if (profile != null) {
    final mean = profile.meanScore;
    return _Stats(
      watching: profile.watching,
      episodes: profile.episodesWatched,
      mean: mean == null || mean <= 0 ? null : mean,
    );
  }
  final anime = entries.where((e) => e.type == MediaType.anime).toList();
  final scored = anime.where((e) => (e.score ?? 0) > 0).toList();
  return _Stats(
    watching: anime.where((e) => e.status == ListStatus.watching).length,
    episodes: anime.fold<int>(0, (sum, e) => sum + e.progress),
    mean: scored.isEmpty
        ? null
        : scored.fold<int>(0, (sum, e) => sum + e.score!) /
              scored.length *
              10,
  );
}

List<StatusSlice> _computeSlices(
  ViewerProfile? profile,
  List<MediaEntry> entries,
  ColorScheme scheme,
) {
  if (profile != null) {
    final c = profile.statusCounts;
    return [
      StatusSlice('Watching', Tokens.statusWatching, c['CURRENT'] ?? 0),
      StatusSlice('Completed', Tokens.statusCompleted, c['COMPLETED'] ?? 0),
      StatusSlice('Planning', Tokens.statusPlanning, c['PLANNING'] ?? 0),
      StatusSlice('Paused', Tokens.statusPaused, c['PAUSED'] ?? 0),
      StatusSlice('Dropped', Tokens.statusDropped, c['DROPPED'] ?? 0),
      StatusSlice('Rewatching', scheme.tertiary, c['REPEATING'] ?? 0),
    ];
  }
  return [
    for (final status in ListStatus.values)
      StatusSlice(
        status == ListStatus.watching ? 'Watching' : status.label,
        switch (status) {
          ListStatus.watching => Tokens.statusWatching,
          ListStatus.planning => Tokens.statusPlanning,
          ListStatus.completed => Tokens.statusCompleted,
          ListStatus.paused => Tokens.statusPaused,
          ListStatus.dropped => Tokens.statusDropped,
        },
        entries.where((e) => e.status == status).length,
      ),
  ];
}

/// AniList favorites first, then on-device hearts not already listed.
List<ProfileFavorite> _mergeFavorites(
  ViewerProfile? profile,
  List<ProfileFavorite> local,
) {
  final seen = <String>{};
  final out = <ProfileFavorite>[];
  for (final f in [...?profile?.favorites, ...local]) {
    if (seen.add('${f.kind.name}:${f.id}')) out.add(f);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Hero: banner + avatar + name
// ---------------------------------------------------------------------------

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.isCustomLink,
  });

  final AuthUser? user;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool isCustomLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= Tokens.breakpointCompact;
    final avatarSize = wide ? 104.0 : 80.0;

    return ProfileBanner(
      height: wide ? 260 : 210,
      imageUrl: bannerUrl,
      isCustomLink: isCustomLink,
      child: Padding(
        padding: EdgeInsets.all(wide ? Tokens.space24 : Tokens.space16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Change banner',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.32),
                ),
                icon: const Icon(Icons.photo_size_select_actual_outlined),
                onPressed: () => showBannerEditor(context),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Avatar(size: avatarSize, url: avatarUrl),
                const SizedBox(width: Tokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? 'Guest',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: Tokens.space2),
                      Text(
                        user == null
                            ? 'Sign in to bring your AniList stats and '
                                  'favorites here'
                            : 'Signed in with AniList',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, required this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = url;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: size * 0.45,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusLg - 3),
        child: image == null || image.isEmpty
            ? placeholder
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => placeholder,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats as plain type, not cards
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stats,
    required this.signedIn,
    required this.onSignIn,
    required this.onSignOut,
  });

  final _Stats stats;
  final bool signedIn;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = NumberFormat.decimalPattern();

    Widget fact(String? value, String label) => Text.rich(
      TextSpan(
        text: value ?? '—',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        children: [
          TextSpan(
            text: '  $label',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final episodes = stats.episodes;
    String? timeLine;
    if (episodes != null && episodes > 0) {
      final hours = episodes * 24 / 60;
      timeLine = hours < 48
          ? 'About ${hours.round()} hours of anime, at 24 minutes an episode.'
          : 'About ${(hours / 24).round()} days of anime, at 24 minutes an '
                'episode.';
    }

    final action = signedIn
        ? OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          )
        : FilledButton.icon(
            onPressed: onSignIn,
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign in'),
          );

    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Tokens.space32,
          runSpacing: Tokens.space8,
          children: [
            fact(
              stats.watching == null ? null : number.format(stats.watching!),
              'watching',
            ),
            fact(
              episodes == null ? null : number.format(episodes),
              'episodes',
            ),
            fact(
              stats.mean?.toStringAsFixed(1),
              'mean score',
            ),
          ],
        ),
        if (timeLine != null) ...[
          const SizedBox(height: Tokens.space8),
          Text(
            timeLine,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: facts),
              const SizedBox(width: Tokens.space16),
              action,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [facts, const SizedBox(height: Tokens.space16), action],
        );
      },
    );
  }
}

/// Opens the sign-in dialog (AniList OAuth only — no manual token entry).
Future<void> showSignInDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _SignInDialog(),
  );
}

class _SignInDialog extends ConsumerStatefulWidget {
  const _SignInDialog();

  @override
  ConsumerState<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends ConsumerState<_SignInDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _loginWithAniList() async {
    if (!AppConfig.hasAnilistClient) {
      setState(
        () => _error =
            'Sign-in is not configured in this build — ask the app owner to '
            'rebuild with an AniList client ID.',
      );
      return;
    }
    // Must stay in the same tab so AniList can redirect back with
    // `#access_token=...` to this app (captured in main.dart).
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await launchUrl(
        AppConfig.anilistLoginUri(),
        webOnlyWindowName: '_self',
      );
      if (!ok && mounted) {
        setState(() => _error = 'Could not open AniList login.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Tokens.space16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusXl),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusXl),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogHero(
                  onClose: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.space24,
                    Tokens.space20,
                    Tokens.space24,
                    Tokens.space12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pick up where you left off',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Tokens.space4),
                      Text(
                        'Connect AniList to sync your list, scores and '
                        'progress. Free forever — your local settings stay put.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Tokens.space16),
                      const _PerkGrid(),
                      const SizedBox(height: Tokens.space16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _loginWithAniList,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Tokens.radiusMd,
                              ),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _AlBadge(),
                                    SizedBox(width: Tokens.space8),
                                    Text(
                                      'Continue with AniList',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Tokens.space8),
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: scheme.error,
                            ),
                            const SizedBox(width: Tokens.space8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: Tokens.space8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Tokens.space4),
                          Text(
                            'Secure OAuth · We never see your password',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Tokens.space4),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Maybe later',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient hero banner — abstract "komorebi lagoon" aurora, not a copy of
/// the reference's side-artwork split layout.
class _DialogHero extends StatelessWidget {
  const _DialogHero({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: Tokens.brandGradient),
      child: Stack(
        children: [
          // Soft decorative glows.
          Positioned(
            left: -48,
            top: -48,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            right: -32,
            bottom: -64,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            right: 72,
            top: 24,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Tokens.sun.withValues(alpha: 0.9),
              ),
            ),
          ),
          Positioned(
            right: 96,
            top: 52,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space24,
              Tokens.space12,
              Tokens.space12,
              Tokens.space20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Tokens.radiusMd),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '生',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.18),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: Tokens.space12),
                Text(
                  'Sign in to Ikigai',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: Tokens.space4),
                Text(
                  'Your anime, in harmony.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: Tokens.space12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(icon: Icons.bolt_outlined, label: 'Free'),
                    _HeroPill(icon: Icons.sync_rounded, label: 'Auto sync'),
                    _HeroPill(icon: Icons.shield_outlined, label: 'Private'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2×2 perk grid — compact alternative to the reference's vertical list.
class _PerkGrid extends StatelessWidget {
  const _PerkGrid();

  @override
  Widget build(BuildContext context) {
    const perks = [
      (
        icon: Icons.format_list_bulleted_rounded,
        title: 'List',
        body: 'Watching & planning in one place',
      ),
      (
        icon: Icons.devices_rounded,
        title: 'Sync',
        body: 'Progress follows every device',
      ),
      (
        icon: Icons.auto_awesome_outlined,
        title: 'Discover',
        body: 'Picks tuned to your taste',
      ),
      (
        icon: Icons.star_border_rounded,
        title: 'Track',
        body: 'Scores & full watch history',
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 92,
      ),
      itemCount: perks.length,
      itemBuilder: (context, index) {
        final perk = perks[index];
        final scheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(Tokens.space12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(perk.icon, size: 18, color: scheme.primary),
              const SizedBox(height: Tokens.space8),
              Text(
                perk.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                perk.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlBadge extends StatelessWidget {
  const _AlBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'AL',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
