import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/responsive.dart';
import '../../state/my_lists_controller.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../router/app_router.dart';

/// Settings: theme, data mode and storage controls.
///
/// Sliver version: single scrollable with a pinned title bar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const SmoothScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 120,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'Settings',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            titlePadding: EdgeInsets.only(left: 16, bottom: 14),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16,
            Tokens.space8,
            Tokens.space16,
            Tokens.space48,
          ),
          sliver: SliverList.list(
            children: const [
              RevealOnScroll(
                index: 0,
                child: _AppearanceCard(),
              ),
              SizedBox(height: Tokens.space16),
              RevealOnScroll(
                index: 1,
                child: _DataCard(),
              ),
              SizedBox(height: Tokens.space16),
              RevealOnScroll(
                index: 2,
                child: _AboutCard(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preference = ref.watch(
      settingsControllerProvider.select((p) => p),
    );
    final controller = ref.read(settingsControllerProvider.notifier);

    return Card(
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
            AnimatedThemeSegmented<ThemePreference>(
              values: ThemePreference.values,
              selected: preference,
              onSelected: controller.setThemePreference,
              labelFor: (p) => switch (p) {
                ThemePreference.system => 'System',
                ThemePreference.light => 'Light',
                ThemePreference.dark => 'Dark',
              },
              iconFor: (p) => switch (p) {
                ThemePreference.system => Icons.brightness_auto_outlined,
                ThemePreference.light => Icons.light_mode_outlined,
                ThemePreference.dark => Icons.dark_mode_outlined,
              },
            ),
            const SizedBox(height: Tokens.space16),
            Text(
              'Accent color',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Text(
              'Applies instantly to buttons, highlights, and glows — in both light and dark mode.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Tokens.space12),
            const _AccentPicker(),
          ],
        ),
      ),
    );
  }
}

class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentControllerProvider);
    final controller = ref.read(accentControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Tokens.space12,
      runSpacing: Tokens.space12,
      children: [
        for (final accent in AppAccent.values)
          _AccentDot(
            accent: accent,
            selected: accent == selected,
            focusColor: scheme.primary,
            onTap: () => controller.setAccent(accent),
          ),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.focusColor,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final Color focusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // White checks vanish on light seeds (amber) — pick the check color
    // by luminance so it reads on every accent in both modes.
    final checkColor = accent.seed.computeLuminance() > 0.45
        ? const Color(0xFF1F2230)
        : Colors.white;
    return Tooltip(
      message: accent.label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: selected ? 1.12 : 1.0,
            duration: Tokens.durationFast,
            curve: Tokens.curveSnap,
            child: AnimatedContainer(
              duration: Tokens.durationMedium,
              curve: Tokens.curveSmooth,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.seed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: selected ? 2.5 : 0,
                ),
                boxShadow: selected
                    ? Tokens.glowShadow(accent.seed)
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: AnimatedSwitcher(
                duration: Tokens.durationFast,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('check'),
                        color: checkColor,
                        size: 22,
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DataCard extends ConsumerWidget {
  const _DataCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entryCount = ref.watch(
      myListsControllerProvider.select((s) => s.entries.length),
    );
    final auth = ref.watch(authStateProvider);
    final accountLabel = switch (auth) {
      AsyncData(:final value) =>
        value == null ? 'Guest' : 'AniList: ${value.name}',
      AsyncError() => 'Guest',
      _ => 'Checking…',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data & storage', style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space12),
            _InfoRow(label: 'Account', value: accountLabel),
            _InfoRow(
              label: 'Tracked titles',
              value: AnimatedSwitcher(
                duration: Tokens.durationFast,
                child: Text(
                  '$entryCount',
                  key: ValueKey(entryCount),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const _InfoRow(
              label: 'Where lists are stored',
              value: 'This browser (localStorage)',
            ),
            const SizedBox(height: Tokens.space12),
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                onTap: entryCount == 0
                    ? null
                    : () => _confirmClear(context, ref),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear tracked titles'),
                  onPressed: entryCount == 0
                      ? null
                      : () => _confirmClear(context, ref),
                ),
              ),
            ),
            const SizedBox(height: Tokens.space8),
            Text(
              'Sign in with AniList on the connections page to identify '
              'your account. Lists stay on this device.',
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
        ),
      ),
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
    if (confirmed == true && context.mounted) {
      await ref.read(myListsControllerProvider.notifier).clearAll();
    }
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Narrow phones get a slimmer label column so values still fit.
    final labelWidth = context.isPhone ? 112.0 : 160.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: value is Widget
                ? value as Widget
                : Text(value.toString(), style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
