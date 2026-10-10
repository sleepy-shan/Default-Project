import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/design_tokens.dart';

/// About / credits page.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space48,
      ),
      children: [
        Text('About', style: theme.textTheme.headlineMedium),
        const SizedBox(height: Tokens.space16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Tokens.brand, Tokens.accent],
                        ),
                        borderRadius: BorderRadius.circular(Tokens.radiusMd),
                      ),
                      child: const Icon(Icons.bolt, color: Colors.white),
                    ),
                    const SizedBox(width: Tokens.space12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dartotsu Web', style: theme.textTheme.titleLarge),
                        Text(
                          'Version $_version • Flutter web build',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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
                Text(
                  'Architecture: ${AppConfig.hasSupabase ? 'Flutter web + Supabase (PostgreSQL, Auth, RLS) + AniList' : 'Flutter web + AniList (local demo tracking)'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.space16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Credits', style: theme.textTheme.titleLarge),
                const SizedBox(height: Tokens.space12),
                _CreditRow(
                  label: 'Dartotsu project',
                  detail: 'Feature reference (aayush2622/Dartotsu)',
                  url: 'https://github.com/aayush2622/Dartotsu',
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
                if (AppConfig.hasSupabase)
                  _CreditRow(
                    label: 'Supabase',
                    detail: 'Auth, database and row-level security',
                    url: 'https://supabase.com',
                  ),
              ],
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
      ],
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
