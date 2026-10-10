import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../state/settings_controller.dart';
import '../router/app_router.dart';

/// A destination in the top-level navigation.
class _Destination {
  const _Destination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const List<_Destination> _destinations = [
  _Destination('Home', Icons.home_outlined, Routes.home),
  _Destination('Anime', Icons.movie_outlined, Routes.anime),
  _Destination('Manga', Icons.menu_book_outlined, Routes.manga),
  _Destination('Calendar', Icons.calendar_month_outlined, Routes.calendar),
  _Destination('My List', Icons.format_list_bulleted, Routes.lists),
];

/// Responsive app chrome: a navigation rail on tablet/desktop, a bottom
/// navigation bar on phones, plus the top bar with search and quick
/// actions. Scre render inside [child].
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _destinations.length; i++) {
      final path = _destinations[i].path;
      if (path == Routes.home) {
        if (location == Routes.home) return i;
      } else if (location.startsWith(path)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < Tokens.breakpointMedium;
    final selectedIndex = _selectedIndex(context);

    final navigation = isCompact
        ? NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                context.go(_destinations[index].path),
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  label: destination.label,
                ),
            ],
          )
        : null;

    final rail = isCompact
        ? null
        : NavigationRail(
            selectedIndex: selectedIndex,
            groupAlignment: 0,
            labelType: width >= Tokens.breakpointExpanded
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.space12),
              child: _BrandMark(compact: width < Tokens.breakpointExpanded),
            ),
            onDestinationSelected: (index) =>
                context.go(_destinations[index].path),
            destinations: [
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Tooltip(
                    message: destination.label,
                    child: Icon(destination.icon),
                  ),
                  label: Text(destination.label),
                ),
            ],
          );

    return Scaffold(
      appBar: isCompact
          ? PreferredSize(
              preferredSize: const Size.fromHeight(Tokens.appBarHeight),
              child: const _TopBar(),
            )
          : null,
      body: Row(
        children: [
          ?rail,
          Expanded(
            child: Column(
              children: [
                if (!isCompact) const _TopBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: navigation,
    );
  }
}

/// Brand lockup: a rounded square mark plus the wordmark.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, Tokens.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: const Icon(
        Icons.bolt,
        size: 20,
        color: Colors.white,
      ),
    );
    if (compact) {
      return Center(child: mark);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: Tokens.space8),
          Text(
            'Dartotsu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Top bar with the wordmark, search and quick actions.
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final showSearchField = width >= Tokens.breakpointCompact;
    final scheme = theme.colorScheme;

    return Container(
      height: Tokens.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, Tokens.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            child: const Icon(Icons.bolt, size: 16, color: Colors.white),
          ),
          const SizedBox(width: Tokens.space8),
          Text(
            'Dartotsu',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Tokens.space24),
          if (showSearchField) ...[
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _SearchField(),
              ),
            ),
          ] else
            const Spacer(),
          const Spacer(),
          if (!showSearchField)
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => context.push(Routes.search),
            ),
          _ThemeToggle(),
          IconButton(
            tooltip: 'Connections',
            icon: const Icon(Icons.link_outlined),
            onPressed: () => context.go(Routes.connections),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.go(Routes.about),
          ),
        ],
      ),
    );
  }
}

/// Compact search field in the top bar. Submitting navigates to the
/// search results route so the result is shareable via the URL.
class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    context.go(Routes.searchWith(query));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: 'Search anime & manga…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.arrow_forward, size: 18),
          onPressed: _submit,
        ),
        isDense: true,
      ),
    );
  }
}

/// Light/dark theme toggle that follows the current mode.
class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref
          .read(settingsControllerProvider.notifier)
          .toggleDark(!isDark),
    );
  }
}
