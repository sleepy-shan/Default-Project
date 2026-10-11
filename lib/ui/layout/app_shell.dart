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

/// Responsive app chrome with the signature Aurora look:
/// aurora background blobs, glass top menu bar on desktop and a
/// floating pill bar on phones. Screens render inside [child].
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
        extendBody: true,
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

/// Soft violet/teal blobs that give every page the same unique ambience.
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

/// Desktop horizontal nav: pill tabs inside the top glass bar.
///
/// The active tab fills with the brand gradient + glow; inactive tabs are
/// ghost pills that light up on hover. collapses to icon-only when
/// [iconOnly] is true so 1000–1240px viewports don't overflow.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.dividerColor,
        ),
      ),
      child: Row(
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
      ),
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    return Tooltip(
      message: widget.destination.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : (selected || _hovering ? 1.03 : 1.0),
            duration: Tokens.durationFast,
            curve: Tokens.curveSnap,
            child: AnimatedContainer(
              duration: Tokens.durationMedium,
              curve: Tokens.curveSmooth,
              padding: EdgeInsets.symmetric(
                horizontal: widget.iconOnly ? 11 : 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: selected ? Tokens.brandGradient : null,
                color: selected
                    ? null
                    : (_hovering
                          ? scheme.surfaceContainerHighest.withValues(
                              alpha: 0.8,
                            )
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(Tokens.radiusPill),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.35)
                      : (_hovering
                            ? scheme.primary.withValues(alpha: 0.45)
                            : Colors.transparent),
                  width: 1,
                ),
                boxShadow: selected
                    ? Tokens.glowShadow(scheme.primary)
                    : (_hovering
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: Tokens.durationFast,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Tokens.curveSnap,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    ),
                    child: Icon(
                      key: ValueKey(selected),
                      selected
                          ? widget.destination.activeIcon
                          : widget.destination.icon,
                      size: 19,
                      color: selected ? Colors.white : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (!widget.iconOnly) ...[
                    const SizedBox(width: 6),
                    Text(
                      widget.destination.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: selected ? 0.2 : 0,
                        color: selected ? Colors.white : scheme.onSurfaceVariant,
                        shadows: selected
                            ? const [
                                Shadow(
                                  blurRadius: 6,
                                  color: Color(0x66000000),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass top bar.
///
/// - Desktop (>=1000px): logo + horizontal menu tabs + search + actions.
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

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, isCompact ? 8 : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: Tokens.appBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(Tokens.radiusXl),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : theme.dividerColor,
              ),
            ),
            child: Row(
              children: [
                AppLogo(
                  size: 34,
                  showWordmark: showWordmark && !isCompact ? true : !isCompact,
                  wordmarkScale: 0.95,
                  onTap: onLogoTap,
                ),
                if (!isCompact) ...[
                  const SizedBox(width: Tokens.space16),
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
                          constraints:
                              BoxConstraints(maxWidth: searchMaxWidth),
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

/// Top-bar lens search. Submitting navigates to the search results route
/// so the result is shareable via the URL. Visuals + motion live in the
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
    // Dismiss focus so the halo animates out on navigation.
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

/// Floating pill bottom bar for phones.
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
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF12141C).withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(Tokens.radiusXl),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : theme.dividerColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient hairline across the top of the arc dock.
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.0),
                          scheme.primary.withValues(alpha: 0.55),
                          scheme.secondary.withValues(alpha: 0.55),
                          scheme.secondary.withValues(alpha: 0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
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
                ],
              ),
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Notch dot above the active destination.
          AnimatedOpacity(
            opacity: selected ? 1.0 : 0.0,
            duration: Tokens.durationFast,
            child: AnimatedScale(
              scale: selected ? 1.0 : 0.4,
              duration: Tokens.durationFast,
              curve: Tokens.curveSnap,
              child: Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  gradient: Tokens.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: Tokens.glowShadow(scheme.primary),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: Tokens.durationMedium,
            curve: Tokens.curveSmooth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected ? Tokens.brandGradient : null,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              boxShadow: selected
                  ? Tokens.glowShadow(scheme.primary)
                  : null,
              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: Tokens.durationFast,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Tokens.curveSnap,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  ),
                  child: Icon(
                    key: ValueKey(selected),
                    selected ? destination.activeIcon : destination.icon,
                    size: 20,
                    color: selected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
                AnimatedSize(
                  duration: Tokens.durationMedium,
                  curve: Tokens.curveSmooth,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            destination.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  color: Color(0x66000000),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
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
