import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/account.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/media_providers.dart';
import '../../state/my_lists_controller.dart';
import '../../state/providers.dart';
import '../components/app_footer.dart';
import '../router/app_router.dart';

/// Profile page: banner, avatar, name and anime stats.
///
/// Guests see an empty profile with a Sign in button; signing in with
/// AniList fills in the avatar, banner and stats. Lists stay in this browser.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryCount = ref.watch(
      myListsControllerProvider.select((s) => s.entries.length),
    );
    return CustomScrollView(
      physics: const SmoothScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _ProfileHeader()),
        if (entryCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space16,
                Tokens.space24,
                Tokens.space16,
                0,
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.format_list_bulleted),
                  title: const Text('My list'),
                  subtitle: Text(
                    '$entryCount tracked ${entryCount == 1 ? 'title' : 'titles'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.lists),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: Tokens.space48)),
        const SliverAppFooter(),
      ],
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = ref.watch(authStateProvider);
    final AuthUser? user = switch (auth) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final ViewerProfile? profile = user == null
        ? null
        : ref.watch(viewerProfileProvider).value;

    final name = user?.name ?? 'Profile';
    final subtitle = user == null
        ? 'Guest — sign in to sync your library'
        : 'Signed in with AniList';
    final avatarUrl = user?.avatarUrl ?? profile?.avatarUrl;

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Tokens.space4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.primary,
          ),
        ),
      ],
    );

    final mean = profile?.meanScore;
    final stats = [
      _Stat(
        icon: Icons.schedule_outlined,
        value: profile == null ? '—' : '${profile.watching}',
        label: 'Watching',
      ),
      _Stat(
        icon: Icons.star_rounded,
        value: profile?.episodesWatched == null
            ? '—'
            : '${profile!.episodesWatched}',
        label: 'Episodes',
      ),
      _Stat(
        icon: Icons.favorite_border,
        value: mean == null || mean <= 0 ? '—' : mean.toStringAsFixed(1),
        label: 'Mean Score',
      ),
    ];

    final Widget action = user == null
        ? FilledButton.icon(
            onPressed: () => showSignInDialog(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign in'),
          )
        : OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        const pad = Tokens.space16;
        final avatarSize = wide ? 128.0 : 104.0;
        final bannerHeight = wide ? 220.0 : 150.0;

        final banner = _Banner(
          height: bannerHeight,
          imageUrl: profile?.bannerUrl,
        );
        final avatar = _Avatar(size: avatarSize, url: avatarUrl);

        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(pad, pad, pad, 0),
            child: Column(
              children: [
                banner,
                SizedBox(
                  height: 96,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: Tokens.space24,
                        top: -avatarSize / 2,
                        child: avatar,
                      ),
                      Positioned.fill(
                        left: Tokens.space24 + avatarSize + Tokens.space20,
                        right: Tokens.space24,
                        child: Row(
                          children: [
                            Expanded(child: nameBlock),
                            for (final stat in stats) ...[
                              stat,
                              const SizedBox(width: Tokens.space24),
                            ],
                            action,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              banner,
              SizedBox(
                height: avatarSize / 2 + Tokens.space12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: Tokens.space16,
                      top: -avatarSize / 2,
                      child: avatar,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    nameBlock,
                    const SizedBox(height: Tokens.space16),
                    Wrap(
                      spacing: Tokens.space24,
                      runSpacing: Tokens.space12,
                      children: stats,
                    ),
                    const SizedBox(height: Tokens.space16),
                    action,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.height,
    required this.imageUrl,
  });

  final double height;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHigh),
            if (url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox(),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: SizedBox(
        width: size,
        height: size,
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Tokens.space8,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
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
