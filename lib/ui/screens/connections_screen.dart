import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/design_tokens.dart';
import '../../state/my_lists_controller.dart';
import '../router/app_router.dart';

/// Account connections page: which services are linked, their status and
/// what each integration can do.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(myListsControllerProvider).entries;
    final cloud = AppConfig.hasSupabase;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space48,
      ),
      children: [
        Text('Account & connections', style: theme.textTheme.headlineMedium),
        const SizedBox(height: Tokens.space4),
        Text(
          cloud
              ? 'Signed in with your Dartotsu account. Tracking data syncs through Supabase.'
              : 'You are using local demo mode: lists are stored in this browser only.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Tokens.space24),
        _SectionCard(
          title: 'Dartotsu account',
          children: [
            _StatusRow(
              icon: Icons.person_outline,
              label: cloud ? 'Supabase session active' : 'Local guest session',
              connected: cloud,
              trailing: cloud ? 'Synced' : 'Local only',
            ),
            if (!cloud) ...[
              const SizedBox(height: Tokens.space8),
              Text(
                'To enable accounts, build with Supabase credentials:\n'
                'flutter run -d chrome '
                '--dart-define=SUPABASE_URL=... '
                '--dart-define=SUPABASE_ANON_KEY=...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Tokens.space16),
        _SectionCard(
          title: 'Tracking services',
          children: [
            _StatusRow(
              icon: Icons.hub_outlined,
              label: 'AniList (metadata + tracking)',
              connected: true,
              trailing: 'Public API',
            ),
            const Divider(height: Tokens.space24),
            _StatusRow(
              icon: Icons.playlist_add_check_outlined,
              label: 'MyAnimeList',
              connected: false,
              trailing: 'Not connected',
            ),
            const Divider(height: Tokens.space24),
            _StatusRow(
              icon: Icons.tv_outlined,
              label: 'Simkl',
              connected: false,
              trailing: 'Not connected',
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              'Additional services are added one at a time behind the same '
              'internal tracking interface, so the app keeps working if a '
              'service is unavailable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        _SectionCard(
          title: 'What your list can do right now',
          children: [
            _CapabilityRow('Titles tracked', '${entries.length}'),
            _CapabilityRow(
              'Statuses',
              'Planning / Watching / Completed / Paused / Dropped',
            ),
            _CapabilityRow(
              'Progress',
              'Episode & chapter counters saved per title',
            ),
            _CapabilityRow('Scores', 'Personal 0–10 score per title'),
            _CapabilityRow(
              'Storage',
              cloud ? 'Supabase (PostgreSQL + RLS)' : 'This browser only',
            ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(Routes.settings),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open settings'),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.connected,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final bool connected;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = connected ? Tokens.success : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: Tokens.space12),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space8,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Text(
            connected ? 'Connected' : trailing,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
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
            child: Text(value, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
