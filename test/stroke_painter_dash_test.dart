import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the lines painted.
class _Lines implements Canvas {
  final List<(Offset, Offset, double)> lines = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((p1, p2, paint.strokeWidth));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

List<(Offset, Offset, double)> paintRing(StrokePainter painter) {
  final _Lines canvas = _Lines();
  painter.paint(canvas, const Size(100, 100));
  return canvas.lines;
}

void main() {
  test('a dash pattern that never advances paints nothing instead of '
      'looping forever', () {
    for (final List<double> pattern in [
      [0.0],
      [0.0, 0.0],
      [-2.0, 1.0],
    ]) {
      final StrokePainter painter = StrokePainter(
        dashPattern: pattern,
        boxShape: BoxShape.circle,
        strokeWidth: 4,
      );
      expect(
        paintRing(painter).length,
        lessThanOrEqualTo(StrokePainter.maxDashes * 2),
      );
    }
  });

  test('every paint starts the dash pattern from its first entry', () {
    // An odd number of entries per lap: a pattern carried over between
    // paints would shift the dashes on every repaint.
    final StrokePainter painter = StrokePainter(
      dashPattern: [3, 7, 5],
      boxShape: BoxShape.circle,
      strokeWidth: 4,
    );
    final first = paintRing(painter);
    final second = paintRing(painter);
    expect(first, isNotEmpty);
    expect(second, first);
  });
}
