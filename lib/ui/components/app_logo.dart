import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Sandwich brand mark.
///
/// Concept: a stacked sandwich — golden top bread with sesame, dripping
/// cheese, wavy lettuce, tomato slice and a thick bottom bread — on a warm
/// amber-to-ember gradient tile. Rendered as vector so it stays crisp at
/// any size and in both themes. No image asset required.
class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 36,
    this.showWordmark = false,
    this.wordmarkScale = 1.0,
    this.onTap,
    super.key,
  });

  final double size;
  final bool showWordmark;
  final double wordmarkScale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = _LogoMark(size: size);
    if (!showWordmark && onTap == null) return mark;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        if (showWordmark) ...[
          SizedBox(width: Tokens.space8 * wordmarkScale),
          _Wordmark(scale: wordmarkScale),
        ],
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(Tokens.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: content,
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sandwich',
          style: TextStyle(
            fontSize: 18 * scale,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.0,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 7 * scale,
            vertical: 2 * scale,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Tokens.brand, Tokens.accent],
            ),
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Text(
            isDark ? 'DISCOVER • TRACK' : 'ANIME • MANGA',
            style: TextStyle(
              fontSize: 8.5 * scale,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB627), Color(0xFFFF7A1A), Color(0xFFFF5C38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A1A).withValues(alpha: 0.38),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: CustomPaint(painter: _SandwichPainter()),
    );
  }
}

/// Paints the stacked sandwich: top bread + sesame, cheese, lettuce wave,
/// tomato slice and bottom bread.
class _SandwichPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top bread: golden triangle with a flat base.
    final breadPaint = Paint()..color = const Color(0xFFFFE3A6);
    final topBread = Path()
      ..moveTo(w * 0.18, h * 0.50)
      ..lineTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.82, h * 0.50)
      ..lineTo(w * 0.78, h * 0.535)
      ..lineTo(w * 0.22, h * 0.535)
      ..close();
    canvas.drawPath(topBread, breadPaint);

    // Sesame seeds.
    final sesamePaint = Paint()..color = const Color(0xFFFFFBEC);
    for (final s in [
      (0.42, 0.395, -0.4),
      (0.54, 0.355, 0.3),
      (0.62, 0.44, -0.2),
    ]) {
      canvas.save();
      canvas.translate(w * s.$1, h * s.$2);
      canvas.rotate(s.$3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: w * 0.075,
          height: h * 0.045,
        ),
        sesamePaint,
      );
      canvas.restore();
    }

    // Cheese slice with a drip.
    final cheesePaint = Paint()..color = const Color(0xFFFFC93C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.535, w * 0.56, h * 0.075),
        Radius.circular(w * 0.035),
      ),
      cheesePaint,
    );
    final drip = Path()
      ..moveTo(w * 0.60, h * 0.605)
      ..lineTo(w * 0.68, h * 0.605)
      ..lineTo(w * 0.66, h * 0.675)
      ..quadraticBezierTo(w * 0.64, h * 0.70, w * 0.62, h * 0.675)
      ..close();
    canvas.drawPath(drip, cheesePaint);

    // Lettuce: wavy green stroke.
    final lettucePaint = Paint()
      ..color = const Color(0xFF2FBF71)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    final lettuce = Path()..moveTo(w * 0.20, h * 0.655);
    const bumps = 5;
    final span = w * 0.60 / bumps;
    for (var i = 0; i < bumps; i++) {
      final x = w * 0.20 + span * i;
      lettuce.quadraticBezierTo(
        x + span / 2,
        h * (i.isEven ? 0.605 : 0.705),
        x + span,
        h * 0.655,
      );
    }
    canvas.drawPath(lettuce, lettucePaint);

    // Tomato slice.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.235, h * 0.705, w * 0.53, h * 0.065),
        Radius.circular(w * 0.033),
      ),
      Paint()..color = const Color(0xFFFF5C5C),
    );

    // Bottom bread: thick trapezoid.
    final bottomPaint = Paint()..color = const Color(0xFFB85C0B);
    final bottom = Path()
      ..moveTo(w * 0.25, h * 0.79)
      ..lineTo(w * 0.75, h * 0.79)
      ..lineTo(w * 0.69, h * 0.875)
      ..quadraticBezierTo(w * 0.68, h * 0.895, w * 0.65, h * 0.895)
      ..lineTo(w * 0.35, h * 0.895)
      ..quadraticBezierTo(w * 0.32, h * 0.895, w * 0.31, h * 0.875)
      ..close();
    canvas.drawPath(bottom, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
