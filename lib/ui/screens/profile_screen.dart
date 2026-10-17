import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/account.dart';
import '../../data/models/profile_banner.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/media_providers.dart';
import '../../state/my_lists_controller.dart';
import '../../state/profile_banner_controller.dart';
import '../../state/providers.dart';
import '../components/app_footer.dart';
import '../components/profile_banner.dart';
import '../components/profile_banner_picker.dart';
import '../components/profile_overview.dart';
import '../components/profile_stats.dart';
import '../router/app_router.dart';

/// Profile page: a customizable banner, the AniList identity, and the anime
/// list statistics (watching, completed, planning, paused, dropped,
/// rewatching, favourites).
///
/// Sign in / sign out live in the top bar (see `AccountButton`), so this page
/// focuses on identity, statistics and the locally tracked list.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryCount = ref.watch(
      myListsControllerProvider.select((s) => s.entries.length),
    );
    final user = ref.watch(authStateProvider).value;
    final ViewerProfile? profile = user == null
        ? null
        : ref.watch(viewerProfileProvider).value;

    return CustomScrollView(
      physics: const SmoothScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _ProfileHeader(user: user, profile: profile),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Tokens.space20)),
        if (user == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space16),
              child: _GuestCard(),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: _Panel(child: ProfileOverviewPanel(profile: profile)),
          ),
          SliverToBoxAdapter(
            child: _Panel(child: ProfileStatsPanel(profile: profile)),
          ),
          SliverToBoxAdapter(
            child: _Panel(child: ProfileGenresPanel(profile: profile)),
          ),
          const SliverToBoxAdapter(
            child: _Panel(child: ProfileActivityPanel()),
          ),
          const SliverToBoxAdapter(
            child: _Panel(child: ProfileNotificationsPanel()),
          ),
        ],
        if (entryCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space16,
                Tokens.space16,
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

/// Consistent horizontal padding for the stacked profile panels.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space16,
        Tokens.space16,
        0,
      ),
      child: child,
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user, required this.profile});

  final AuthUser? user;
  final ViewerProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final banner = ref.watch(profileBannerControllerProvider);
    final anilistBanner = profile?.bannerUrl;

    final name = user?.name ?? 'Guest';
    final subtitle = user == null
        ? 'Browsing as a guest'
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              user == null
                  ? Icons.person_outline_rounded
                  : Icons.verified_rounded,
              size: 15,
              color: scheme.primary,
            ),
            const SizedBox(width: Tokens.space4),
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        const pad = Tokens.space16;
        final avatarSize = wide ? 120.0 : 96.0;
        final bannerHeight = wide ? 208.0 : 156.0;
        // Left edge of the name/summary beside the avatar on wide layouts.
        final contentLeft = Tokens.space24 + avatarSize + Tokens.space20;

        final bannerCard = _BannerCard(
          height: bannerHeight,
          banner: banner,
          anilistBannerUrl: anilistBanner,
          onEdit: () => showProfileBannerPicker(
            context,
            anilistBannerUrl: anilistBanner,
          ),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bannerCard,
              SizedBox(
                height: avatarSize / 2 + Tokens.space12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: Tokens.space24,
                      top: -avatarSize / 2,
                      child: _Avatar(size: avatarSize, url: avatarUrl),
                    ),
                    if (wide)
                      Positioned.fill(
                        left: contentLeft,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: nameBlock,
                        ),
                      ),
                  ],
                ),
              ),
              if (!wide)
                Padding(
                  padding: const EdgeInsets.only(
                    top: Tokens.space4,
                    left: Tokens.space8,
                    right: Tokens.space8,
                  ),
                  child: nameBlock,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The banner with its "change banner" affordance in the top-right corner.
class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.height,
    required this.banner,
    required this.anilistBannerUrl,
    required this.onEdit,
  });

  final double height;
  final ProfileBanner banner;
  final String? anilistBannerUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfileBannerView(
              preset: banner.preset,
              fallbackImageUrl: anilistBannerUrl,
            ),
            // Bottom scrim so the overlapping avatar stays readable.
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: height * 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.34),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 10, right: 10, child: _EditBannerButton(onTap: onEdit)),
          ],
        ),
      ),
    );
  }
}

class _EditBannerButton extends StatelessWidget {
  const _EditBannerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Change banner',
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: Tokens.space8),
                Text(
                  'Banner',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, required this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusLg + 4),
        boxShadow: Tokens.cardShadow(theme.brightness),
      ),
      child: ClipRRect(
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
      ),
    );
  }
}

/// Shown to guests instead of the (account-only) statistics panel.
class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: Tokens.space8),
                Text(
                  'Your anime list',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              'Sign in with AniList from the top bar to see your watching, '
              'completed, planning, paused, dropped, rewatching and '
              'favourites counts here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
