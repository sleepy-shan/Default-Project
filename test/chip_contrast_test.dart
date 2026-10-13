import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikigai_project/core/theme/app_theme.dart';
import 'dart:math' as math;

double _lum(Color c) {
  double ch(double v) {
    v /= 255.0;
    if (v <= 0.03928) return v / 12.92;
    return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(c.r * 255.0) +
      0.7152 * ch(c.g * 255.0) +
      0.0722 * ch(c.b * 255.0);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a);
  final l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('chip labels contrast in dark and light mode', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final chip = theme.chipTheme;
      final bg = chip.backgroundColor!;
      final label = chip.labelStyle!.color!;
      final ratio = contrast(bg, label);
      // ignore: avoid_print
      print(
        '${theme.brightness} bg=$bg label=$label contrast=${ratio.toStringAsFixed(2)}',
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
      expect(chip.secondaryLabelStyle!.color, isNotNull);
      expect(chip.deleteIconColor, isNotNull);
      expect(chip.checkmarkColor, isNotNull);
    }
  });
}

