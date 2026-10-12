import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../components/app_footer.dart';
import '../components/app_logo.dart';

/// About / credits page.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      physics: const SmoothScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space48,
      ),
      children: [
        RevealOnScroll(
          child: Text(
            'About',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: Tokens.space16),
        RevealOnScroll(
          index: 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      AppLogo(size: 48, showWordmark: true),
                      Spacer(),
                      _VersionPill(),
                    ],
                  ),
                  const SizedBox(height: Tokens.space16),
                  Text(
                    'A responsive web app for discovering anime and manga and '
                    'tracking your personal watching/reading progress. '
                    'Titles, artwork, ratings and airing schedules come from '
                    'the public AniList API; this app does not host any media, '
                    'and it is not affiliated with AniList.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: Tokens.space12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    ),
                    child: Text(
                      'Architecture: Flutter web + AniList (metadata + account, local list storage)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Tokens.space16),
        RevealOnScroll(
          index: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Tokens.space12),
                  _CreditRow(
                    label: 'sleepy-shan',
                    detail: 'Project owner (sleepy-shan/Default-Project)',
                    url: 'https://github.com/sleepy-shan/Default-Project',
                  ),
                  _CreditRow(
                    label: 'AniList API',
                    detail: 'Anime & manga metadata',
                    url: 'https://docs.anilist.co/',
                  ),
                  _CreditRow(
                    label: 'Flutter',
                    detail: 'Cross-platform UI framework',
                    url: 'https://flutter.dev',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Tokens.space16),
        Text(
          'This is an independent project built for learning and personal '
          'use. Please respect the terms of the services it connects to, and '
          'support official releases.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const AppFooter(),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: Tokens.brandGradient,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: const Text(
        'v${AboutScreen.version} • WEB',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          shadows: [
            Shadow(blurRadius: 6, color: Color(0x66000000)),
          ],
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({
    required this.label,
    required this.detail,
    required this.url,
  });

  final String label;
  final String detail;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(detail),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new, size: 18),
        tooltip: 'Open link',
        onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
      ),
      onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
    );
  }
}
