import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../state/settings_controller.dart';
import '../components/app_logo.dart';
import '../components/search_field.dart';
import '../router/app_router.dart';

/// A destination in the top-level navigation.
class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon, this.path);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
}

const List<_Destination> _destinations = [
  _Destination('Home', Icons.home_outlined, Icons.home_rounded, Routes.home),
  _Destination('Anime', Icons.movie_outlined, Icons.movie_rounded, Routes.anime),
  _Destination(
    'Manga',
    Icons.menu_book_outlined,
    Icons.menu_book_rounded,
    Routes.manga,
  ),
  _Destination(
    'Calendar',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
    Routes.calendar,
  ),
  _Destination(
    'My List',
    Icons.format_list_bulleted_outlined,
    Icons.format_list_bulleted_rounded,
    Routes.lists,
  ),
];

/// Responsive app chrome with a calm lagoon look:
/// soft teal background blobs, a docked hairline top bar on desktop
/// (Linear/Vercel-style, not a floating pill) and a docked bottom tab
/// bar on phones. Screens render inside [child].
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Command-palette shortcut: "/" or Ctrl/Cmd+K jumps to search from
    // anywhere — unless the user is already typing in a text field (then
    // "/" must type literally instead of navigating away).
    bool isTyping() {
      final focus = FocusManager.instance.primaryFocus;
      final widget = focus?.context?.widget;
      return widget is EditableText;
    }

    void goSearch() {
      if (isTyping()) return;
      context.push(Routes.search);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): goSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            goSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): goSearch,
      },
      child: Scaffold(
        extendBody: false,
        body: Stack(
          children: [
            // ---- Aurora background --------------------------------------
            Positioned.fill(child: _AuroraBackground(isDark: isDark)),
            // ---- Content -------------------------------------------------
            // Desktop (>=1000px): top horizontal menu bar + content.
            // Phones (<1000px): top utility bar + content + floating pill bar.
            Column(
              children: [
                _GlassTopBar(
                  isCompact: isCompact,
                  selectedIndex: selectedIndex,
                  onDestinationTap: (i) => context.go(_destinations[i].path),
                  onLogoTap: () => context.go(Routes.home),
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Tokens.curveSmooth,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) {
                        final fade = CurvedAnimation(
                          parent: animation,
                          curve: Tokens.curveSmooth,
                        );
                        final slide =
                            Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(fade);
                        final scale =
                            Tween<double>(begin: 0.98, end: 1.0).animate(fade);
                        return FadeTransition(
                          opacity: fade,
                          child: SlideTransition(
                            position: slide,
                            child: ScaleTransition(
                              scale: scale,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(GoRouterState.of(context).uri.path),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: isCompact
            ? _FloatingBottomBar(
                selectedIndex: selectedIndex,
                onTap: (i) => context.go(_destinations[i].path),
              )
            : null,
      ),
    );
  }
}

/// Soft ember/ink blobs that give every page the same calm ambience.
///
/// Isolated in a [RepaintBoundary] so the gradient blobs paint once and
/// are cached — they do not repaint on every content frame.
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Stack(
        children: [
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        Positioned(
          top: -140,
          left: -80,
          child: Container(
            width: 460,
            height: 340,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  // Tints with the selected accent via the color scheme.
                  scheme.primary.withValues(
                    alpha: isDark ? 0.28 : 0.14,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -60,
          child: Container(
            width: 420,
            height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  scheme.secondary.withValues(alpha: isDark ? 0.20 : 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          left: MediaQuery.sizeOf(context).width * 0.25,
          child: Container(
            width: 560,
            height: 320,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.tertiary.withValues(
                    alpha: isDark ? 0.14 : 0.08,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

/// Desktop horizontal nav: quiet text tabs with an underline indicator.
///
/// The active tab uses primary-colored icon + text and a short 20px
/// underline bar; inactive tabs are ghost buttons with a subtle hover
/// wash. No pill fill, gradient, or glow — calm by design. Collapses to
/// icon-only when [iconOnly] is true so 1000–1240px viewports don't
/// overflow.
class _DesktopNav extends StatelessWidget {
  const _DesktopNav({
    required this.selectedIndex,
    required this.onTap,
    required this.iconOnly,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _destinations.length; i++)
          _TopNavItem(
            destination: _destinations[i],
            selected: i == selectedIndex,
            iconOnly: iconOnly,
            onTap: () => onTap(i),
          ),
      ],
    );
  }
}

class _TopNavItem extends StatefulWidget {
  const _TopNavItem({
    required this.destination,
    required this.selected,
    required this.iconOnly,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  State<_TopNavItem> createState() => _TopNavItemState();
}

class _TopNavItemState extends State<_TopNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final textColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Tooltip(
      message: widget.destination.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Tokens.durationFast,
            curve: Tokens.curveSmooth,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.iconOnly ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _hovering && !selected
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? widget.destination.activeIcon
                          : widget.destination.icon,
                      size: 18,
                      color: iconColor,
                    ),
                    if (!widget.iconOnly) ...[
                      const SizedBox(width: 7),
                      Text(
                        widget.destination.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 0,
                          color: textColor,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: Tokens.durationMedium,
                  curve: Tokens.curveSmooth,
                  height: 2.5,
                  width: selected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
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

/// Docked hairline top bar (no floating pill, square edges).
///
/// - Desktop (>=1000px): logo + underline tabs + search + actions.
/// - Phones (<1000px): logo + search + actions (nav lives in the bottom bar).
class _GlassTopBar extends ConsumerWidget {
  const _GlassTopBar({
    required this.isCompact,
    required this.selectedIndex,
    required this.onDestinationTap,
    required this.onLogoTap,
  });

  final bool isCompact;
  final int selectedIndex;
  final ValueChanged<int> onDestinationTap;
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final showSearchField = width >= Tokens.breakpointCompact;

    // Desktop breakpoints: keep the single bar overflow-safe.
    // 1000–1240: icon-only tabs + compact search.
    // 1240+: full tabs + wider search.
    final bool iconOnlyNav = width < 1240;
    final bool showWordmark = isCompact || width >= 1120;
    final double searchMaxWidth = width >= 1400
        ? 460
        : (width >= 1240 ? 340 : 260);
    final bool showConnections =
        isCompact ? width >= 700 : width >= 1300;
    final bool showAbout = isCompact ? width >= 800 : width >= 1400;
    final showOverflowMenu =
        isCompact ? (!showConnections || !showAbout) : (!showConnections || !showAbout);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: Tokens.appBarHeight,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0E1515).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Tokens.maxContentWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space16,
                ),
                child: Row(
                  children: [
                    AppLogo(
                      size: 32,
                      showWordmark: showWordmark && !isCompact ? true : !isCompact,
                      wordmarkScale: 0.95,
                      onTap: onLogoTap,
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: Tokens.space20),
                      _DesktopNav(
                        selectedIndex: selectedIndex,
                        onTap: onDestinationTap,
                        iconOnly: iconOnlyNav,
                      ),
                      const Spacer(),
                      if (showSearchField)
                        Flexible(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: searchMaxWidth,
                              ),
                              child: _SearchField(),
                            ),
                          ),
                        ),
                      const SizedBox(width: Tokens.space8),
                    ] else ...[
                      const SizedBox(width: Tokens.space16),
                      if (showSearchField)
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _SearchField(),
                          ),
                        )
                      else
                        const Spacer(),
                      const Spacer(),
                      if (!showSearchField)
                        IconButton(
                          tooltip: 'Search',
                          icon: const Icon(Icons.search),
                          onPressed: () => context.push(Routes.search),
                        ),
                    ],
                    _ThemeToggle(compact: false),
                    if (showConnections)
                      _TopIcon(
                        tooltip: 'Connections',
                        icon: Icons.link_outlined,
                        onPressed: () => context.go(Routes.connections),
                      ),
                    _TopIcon(
                      tooltip: 'Settings',
                      icon: Icons.settings_outlined,
                      onPressed: () => context.go(Routes.settings),
                    ),
                    if (showAbout)
                      _TopIcon(
                        tooltip: 'About',
                        icon: Icons.info_outline,
                        onPressed: () => context.go(Routes.about),
                      ),
                    if (showOverflowMenu)
                      _OverflowMenu(
                        showConnections: !showConnections,
                        showAbout: !showAbout,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.showConnections, required this.showAbout});

  final bool showConnections;
  final bool showAbout;

  @override
  Widget build(BuildContext context) {
    if (!showConnections && !showAbout) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        switch (value) {
          case 'connections':
            context.go(Routes.connections);
          case 'about':
            context.go(Routes.about);
        }
      },
      itemBuilder: (context) => [
        if (showConnections)
          const PopupMenuItem(
            value: 'connections',
            child: Row(
              children: [
                Icon(Icons.link_outlined, size: 18),
                SizedBox(width: 8),
                Text('Connections'),
              ],
            ),
          ),
        if (showAbout)
          const PopupMenuItem(
            value: 'about',
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Text('About'),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed);
  }
}

/// Top-bar minimalist search. Submitting navigates to the search results
/// route so the result is shareable via the URL. Visuals live in the
/// shared [LensSearchField] so both search bars stay identical.
class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    context.go(Routes.searchWith(query));
  }

  @override
  Widget build(BuildContext context) {
    return LensSearchField(
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: _submit,
    );
  }
}

/// Docked bottom tab bar for phones — full-width hairline, square edges.
class _FloatingBottomBar extends StatelessWidget {
  const _FloatingBottomBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0E1515).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  _BottomItem(
                    destination: _destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Tokens.durationFast,
              curve: Tokens.curveSmooth,
              height: 3,
              width: selected ? 20 : 0,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 5),
            Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 21,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: TextStyle(
                color: color,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light/dark theme toggle that follows the current mode.
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: AnimatedSwitcher(
        duration: Tokens.durationMedium,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(isDark),
          size: compact ? 20 : null,
        ),
      ),
      onPressed: () =>
          ref.read(settingsControllerProvider.notifier).toggleDark(!isDark),
    );
  }
}
