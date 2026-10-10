import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/design_tokens.dart';
import '../../state/my_lists_controller.dart';
import '../../state/settings_controller.dart';
import '../router/app_router.dart';

/// Settings: theme, data mode and storage controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preference = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final entryCount = ref.watch(myListsControllerProvider).entries.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space48,
      ),
      children: [
        Text('Settings', style: theme.textTheme.headlineMedium),
        const SizedBox(height: Tokens.space24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: theme.textTheme.titleLarge),
                const SizedBox(height: Tokens.space4),
                Text(
                  'Choose a theme. "System" follows your device setting.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Tokens.space16),
                SegmentedButton<ThemePreference>(
                  segments: const [
                    ButtonSegment(
                      value: ThemePreference.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemePreference.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemePreference.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {preference},
                  onSelectionChanged: (selection) =>
                      controller.setThemePreference(selection.first),
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
                Text('Data & storage', style: theme.textTheme.titleLarge),
                const SizedBox(height: Tokens.space12),
                _InfoRow(
                  label: 'Mode',
                  value:
                      AppConfig.hasSupabase ? 'Supabase (cloud)' : 'Local demo',
                ),
                _InfoRow(label: 'Tracked titles', value: '$entryCount'),
                _InfoRow(
                  label: 'Where lists are stored',
                  value: AppConfig.hasSupabase
                      ? 'Supabase PostgreSQL (RLS-protected)'
                      : 'This browser (localStorage)',
                ),
                const SizedBox(height: Tokens.space12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear tracked titles'),
                    onPressed: entryCount == 0
                        ? null
                        : () => _confirmClear(context, ref),
                  ),
                ),
                if (!AppConfig.hasSupabase) ...[
                  const SizedBox(height: Tokens.space8),
                  Text(
                    'Connect a Supabase project with Google or email sign-in '
                    'to sync your list across devices.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Tokens.space8),
                  TextButton.icon(
                    onPressed: () => context.go(Routes.connections),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Go to connections'),
                  ),
                ],
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
                Text('About', style: theme.textTheme.titleLarge),
                const SizedBox(height: Tokens.space12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version and credits'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.about),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all tracked titles?'),
        content: const Text(
          'This removes every entry from your list. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(myListsControllerProvider.notifier).clearAll();
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
            width: 160,
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
