// What the dropdown and the menu need beyond the kit (render/controls/kit.dart)
// and the field frame (field_frame.dart): SSUI's stroke glyphs drawn as paths
// (the select's chevron and the menu's check mark, Lucide's `chevron-down`
// and `check` as SSUI draws them, no icon font or SVG to load) and the
// tokens the select and its menu read that `ControlTokens` has no getter
// for.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../convert.dart';
import 'tokens.dart';

/// SSUI's tokens for selects and menus.
extension SelectTokens on ControlTokens {
  Color _named(String name, Color fallback) => theme.color(name)?.flutter ?? fallback;

  /// Hints, placeholders and the select's chevron (SSUI's `tertiaryText`).
  Color get tertiaryText => _named('tertiaryText', onSurface.withValues(alpha: .4));

  /// Fields, cards, menus (SSUI's `primaryBackground`).
  Color get primaryBackground => _named('primaryBackground', surface);
}

/// A stroke glyph on Lucide's 24 × 24 grid: polylines in [points], stroked
/// 2 units wide with round caps and joins (as Lucide's icons are).
class StrokeGlyph {
  const StrokeGlyph(this.lines);

  /// Each polyline's points, on the 24 grid.
  final List<List<Offset>> lines;

  /// Lucide `chevron-down` (SSUI's select affordance).
  static const chevronDown = StrokeGlyph([
    [Offset(6, 9), Offset(12, 15), Offset(18, 9)],
  ]);

  /// Lucide `check` (SSUI's selected menu row).
  static const check = StrokeGlyph([
    [Offset(20, 6), Offset(9, 17), Offset(4, 12)],
  ]);

  /// Paints it in [rect] (a square: the glyph's size) in [color], turned
  /// [turns] (0.5: upside down) about its centre.
  void paint(Canvas canvas, Rect rect, Color color, {double turns = 0}) {
    if (color.a == 0 || rect.isEmpty) return;
    final s = math.min(rect.width, rect.height) / 24;
    final origin = rect.center - const Offset(12, 12) * s;
    final path = Path();
    for (final line in lines) {
      for (var i = 0; i < line.length; i++) {
        final p = origin + line[i] * s;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = color;
    if (turns == 0) {
      canvas.drawPath(path, paint);
      return;
    }
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..rotate(turns * 2 * math.pi)
      ..translate(-rect.center.dx, -rect.center.dy)
      ..drawPath(path, paint)
      ..restore();
  }
}

/// SSUI's field side padding at a step of the scale (its `paddingX`:
/// 6/8/10/10/12), as the field frame pads its content (the frame keeps its
/// own copy private).
double fieldSidePadding(ControlScale s) => switch (s.name) {
      'xs' => 6,
      'compact' => 8,
      'small' || 'medium' => 10,
      _ => 12,
    };

/// SSUI's menu row height for a control of step [s]: 28 up to `small`,
/// 32 at `medium`, 36 at `large` (`softSaaSMenuRowHeight`).
double menuRowHeight(ControlScale s) => switch (s.name) {
      'medium' => 32,
      'large' => 36,
      _ => 28,
    };
