import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Shared lens-search field used by the top bar and the search page.
///
/// One implementation guarantees both search bars share the exact same
/// look, motion, and — critically — explicit `ColorScheme` text colors in
/// light and dark mode (no framework-default text colors that can vanish
/// on a mode-colored surface).
///
/// Unique details:
/// - gradient halo border that ignites on hover/focus (hairline idle),
/// - lens-orb prefix (gradient circle, glows + magnifies on focus),
/// - optional kbd chip (`/` / `Ctrl K`) that focuses the field on tap,
/// - optional clear-X that swaps in when [showClear] is true,
/// - comet go-button with hover spring,
/// - hint shortens on narrow widths so text never clips.
class LensSearchField extends StatefulWidget {
  const LensSearchField({
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
    this.hintLong = 'Search anime & manga…  try "Frieren"',
    this.hintShort = 'Search anime & manga…',
    this.showKbdChip = true,
    this.onKbdTap,
    this.showClear = false,
    this.onClear,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final String hintLong;
  final String hintShort;

  /// When true, a tappable `/` / `Ctrl K` chip shows on wide layouts.
  final bool showKbdChip;
  final VoidCallback? onKbdTap;

  /// When true, a clear-X button appears before the go orb.
  final bool showClear;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LensSearchField> createState() => _LensSearchFieldState();
}

class _LensSearchFieldState extends State<LensSearchField> {
  bool _focused = false;
  bool _hovering = false;
  bool _hoverGo = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant LensSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lit = _focused || _hovering;
    // Unfocused ring stays visible on both modes: bright hairline in dark,
    // solid divider in light.
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.dividerColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // Fit the text: short hint on narrow, example on wide.
        final hint = maxW >= 400 ? widget.hintLong : widget.hintShort;
        final showKbd = widget.showKbdChip && maxW >= 300;
        final kbdLabel = maxW >= 440 ? 'Ctrl K' : '/';

        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: Tokens.durationMedium,
            curve: Tokens.curveSmooth,
            padding: EdgeInsets.all(lit ? 1.6 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              gradient: lit
                  ? LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: lit
                  ? null
                  : Border.all(color: idleBorder, width: 1.0),
              boxShadow: _focused
                  ? Tokens.glowShadow(scheme.primary)
                  : (_hovering
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            // Resting shadow so the field reads as a field
                            // on both modes, not flat glass-on-glass.
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.30)
                                  : const Color(
                                      0xFF1B1440,
                                    ).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]),
            ),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                // Solid-enough fill per mode so typed text always sits on a
                // contrasting surface: near-solid white in light, lifted
                // charcoal in dark.
                color: isDark ? const Color(0xFF1C2030) : Colors.white,
                borderRadius: BorderRadius.circular(Tokens.radiusPill - 1),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 5),
                  // Lens orb prefix.
                  AnimatedScale(
                    scale: _focused ? 1.1 : 1.0,
                    duration: Tokens.durationFast,
                    curve: Tokens.curveSnap,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: Tokens.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: _focused
                            ? Tokens.glowShadow(scheme.primary)
                            : null,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      autofocus: widget.autofocus,
                      textInputAction: TextInputAction.search,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      maxLines: 1,
                      textAlignVertical: TextAlignVertical.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                      cursorColor: scheme.primary,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintMaxLines: 1,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isDense: true,
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (widget.showClear)
                    Tooltip(
                      message: 'Clear',
                      child: AnimatedScale(
                        scale: 1.0,
                        duration: Tokens.durationFast,
                        child: IconButton(
                          tooltip: 'Clear',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          onPressed: widget.onClear,
                        ),
                      ),
                    ),
                  if (showKbd)
                    Tooltip(
                      message: 'Focus search ( /  or  Ctrl+K )',
                      child: GestureDetector(
                        onTap:
                            widget.onKbdTap ??
                            () => widget.focusNode.requestFocus(),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: Tokens.durationFast,
                            curve: Tokens.curveSmooth,
                            margin: const EdgeInsets.only(right: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _focused
                                  ? scheme.primary.withValues(alpha: 0.14)
                                  : scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.7,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _focused
                                    ? scheme.primary.withValues(alpha: 0.5)
                                    : scheme.outline.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              kbdLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: _focused
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  MouseRegion(
                    onEnter: (_) => setState(() => _hoverGo = true),
                    onExit: (_) => setState(() => _hoverGo = false),
                    child: AnimatedScale(
                      scale: _hoverGo ? 1.12 : 1.0,
                      duration: Tokens.durationFast,
                      curve: Tokens.curveSnap,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: Tokens.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: (_hoverGo || _focused)
                              ? Tokens.glowShadow(scheme.primary)
                              : null,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Search',
                          padding: EdgeInsets.zero,
                          icon: AnimatedSlide(
                            offset: Offset(_hoverGo ? 0.12 : 0, 0),
                            duration: Tokens.durationFast,
                            curve: Tokens.curveSmooth,
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () => widget.onSubmitted?.call(
                            widget.controller.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
