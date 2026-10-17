import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/profile_banner.dart';

/// Renders the profile header banner: an AniList image, a custom image URL,
/// or one of the app's animated styles.
///
/// This is a website-only feature — AniList has no banner picker. It fills its
/// parent, so callers size it (usually with a [SizedBox] or [AspectRatio]).
class ProfileBannerView extends StatelessWidget {
  const ProfileBannerView({
    required this.preset,
    this.imageUrl,
    this.fallbackImageUrl,
    super.key,
  });

  final BannerPreset preset;

  /// Custom image URL chosen by the user ([BannerPreset.image]).
  final String? imageUrl;

  /// The signed-in user's AniList banner, used by [BannerPreset.auto].
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final url = switch (preset) {
      BannerPreset.auto => _clean(fallbackImageUrl),
      BannerPreset.image => _clean(imageUrl),
      _ => null,
    };
    if (url != null) {
      return _ImageBanner(
        url: url,
        fallback: _AnimatedBanner(builder: _aurora),
      );
    }
    return switch (preset) {
      BannerPreset.gradient => _AnimatedBanner(builder: _gradient),
      BannerPreset.starfield => _AnimatedBanner(builder: _starfield),
      BannerPreset.grid => _AnimatedBanner(builder: _grid),
      // Aurora is both the explicit choice and the graceful fallback.
      _ => _AnimatedBanner(builder: _aurora),
    };
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

/// Three drifting radial glows over a deep lagoon base — "komorebi aurora".
Widget _aurora(BuildContext context, double t) {
  final scheme = Theme.of(context).colorScheme;
  final angle = t * 2 * math.pi;
  return Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF06201E)),
      _glow(
        Alignment(
          -0.7 + 0.5 * math.sin(angle),
          -0.6 + 0.4 * math.cos(angle),
        ),
        scheme.primary.withValues(alpha: 0.85),
        1.15,
      ),
      _glow(
        Alignment(
          0.9 - 0.4 * math.cos(angle * 1.3),
          0.8 - 0.3 * math.sin(angle * 0.9),
        ),
        scheme.tertiary.withValues(alpha: 0.55),
        1.0,
      ),
      _glow(
        Alignment(-0.3 + 0.6 * math.sin(angle * 0.7 + 1), 1.1),
        Tokens.sun.withValues(alpha: 0.4),
        0.9,
      ),
    ],
  );
}

Widget _glow(Alignment center, Color color, double radius) {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: center,
        radius: radius,
        colors: [color, color.withValues(alpha: 0)],
      ),
    ),
  );
}

/// A brand-colour sweep that flows by rotating its gradient axis.
Widget _gradient(BuildContext context, double t) {
  final angle = t * 2 * math.pi;
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment(-1 + 2 * math.sin(angle), -1),
        end: Alignment(1, 1 - 2 * math.cos(angle)),
        colors: const [
          Color(0xFF5EEAD4),
          Color(0xFF0E7C6B),
          Color(0xFF0B4F46),
          Color(0xFFB98A2E),
          Color(0xFFE9C46A),
        ],
      ),
    ),
  );
}

/// Twinkling, slowly drifting stars.
Widget _starfield(BuildContext context, double t) {
  final scheme = Theme.of(context).colorScheme;
  return CustomPaint(
    size: Size.infinite,
    painter: _StarfieldPainter(t, scheme.secondary),
  );
}

/// Faint grid with a highlight band travelling across it.
Widget _grid(BuildContext context, double t) {
  final scheme = Theme.of(context).colorScheme;
  return CustomPaint(
    size: Size.infinite,
    painter: _GridPainter(
      t,
      line: Colors.white.withValues(alpha: 0.07),
      glow: scheme.primary,
      background: const Color(0xFF0B1F1C),
    ),
  );
}

// ---------------------------------------------------------------------------
// Animated host
// ---------------------------------------------------------------------------

/// Drives a slow looping clock and hands it to [builder]. Motion is disabled
/// when the platform asks for reduced animation, leaving a still frame.
class _AnimatedBanner extends StatefulWidget {
  const _AnimatedBanner({required this.builder});

  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _controller.value),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image banner
// ---------------------------------------------------------------------------

class _ImageBanner extends StatelessWidget {
  const _ImageBanner({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scheme.surfaceContainerHigh),
        Image.network(
          url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => fallback,
        ),
        // Scrim so overlaid avatar / name / buttons stay legible.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.42),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Deterministic pseudo-random in [0, 1) — no state, stable across repaints.
double _unit(int i, int salt) =>
    ((i * 2654435761 + salt * 40503) % 1000003) / 1000003.0;

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter(this.t, this.tint);

  final double t;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF071626),
    );
    final paint = Paint();
    for (var i = 0; i < 110; i++) {
      final x = _unit(i, 1) * size.width;
      final speed = 0.04 + _unit(i, 2) * 0.14;
      final y = ((_unit(i, 3) + t * speed) % 1.0) * size.height;
      final radius = 0.6 + _unit(i, 4) * 1.9;
      final twinkle =
          0.35 +
          0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + _unit(i, 5) * 12));
      paint.color = Color.lerp(
        Colors.white,
        tint,
        _unit(i, 6),
      )!.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.tint != tint;
}

class _GridPainter extends CustomPainter {
  const _GridPainter(
    this.t, {
    required this.line,
    required this.glow,
    required this.background,
  });

  final double t;
  final Color line;
  final Color glow;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    const step = 28.0;
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Highlight band sweeping left -> right.
    final bandWidth = size.width * 0.38;
    final left = t * (size.width + bandWidth) - bandWidth;
    final band = Rect.fromLTWH(left, 0, bandWidth, size.height);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        glow.withValues(alpha: 0),
        glow.withValues(alpha: 0.32),
        glow.withValues(alpha: 0),
      ],
    ).createShader(band);
    canvas.drawRect(band, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.line != line ||
      oldDelegate.glow != glow ||
      oldDelegate.background != background;
}
