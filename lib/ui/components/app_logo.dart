import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Ikigai brand mark.
///
/// Concept: a minimalist ensō — a single ink brush ring with a small
/// vermilion core — on a deep sumi tile. Rendered as vector so it stays
/// crisp at any size and in both themes. No image asset required.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ikigai',
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
            color: Tokens.brand,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Text(
            'ANIME • MANGA',
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
          colors: [Color(0xFF2B2D42), Color(0xFF1E1E24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: Tokens.brand.withValues(alpha: 0.32),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: CustomPaint(painter: _EnsoPainter()),
    );
  }
}

/// Paints a minimalist ensō ring with a vermilion core.
class _EnsoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.52);
    final radius = w * 0.30;

    // Ensō ring: warm paper stroke with a gap (brush lift) at lower-right.
    final ringPaint = Paint()
      ..color = const Color(0xFFF5F1E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round;
    const startAngle = -0.35 * math.pi;
    const sweepAngle = 1.72 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      ringPaint,
    );

    // Vermilion core: the "reason for being" dot.
    canvas.drawCircle(
      center,
      w * 0.085,
      Paint()..color = const Color(0xFFE0684A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
