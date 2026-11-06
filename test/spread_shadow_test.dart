import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the rounded rects drawn on it.
class _RecordingCanvas implements Canvas {
  final List<RRect> rrects = [];

  @override
  void drawRRect(RRect rrect, Paint paint) => rrects.add(rrect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('a spread shadow grows the corner radius with the box', () {
    final canvas = _RecordingCanvas();
    const SpreadShadowPainter(
      shadows: [BoxShadow(color: Color(0x66D2602A), spreadRadius: 3)],
      borderRadius: BorderRadius.all(Radius.circular(5)),
    ).paint(canvas, const Size(10, 10));

    final RRect glow = canvas.rrects.single;
    expect(glow.outerRect, const Rect.fromLTRB(-3, -3, 13, 13));
    // A circle stays a circle: radius 5 + 3 on a 16 px box.
    expect(glow.tlRadius, const Radius.circular(8));
    expect(glow.brRadius, const Radius.circular(8));
  });

  testWidgets('only spread shadows on rounded boxes use the painter', (
    tester,
  ) async {
    Future<CustomPaint?> painterFor(BorderRadius? radius, double spread) async {
      await tester.pumpWidget(
        Center(
          child: decorateWithShadows(
            boxShadow: [BoxShadow(spreadRadius: spread, blurRadius: 2)],
            borderRadius: radius,
            clipBehavior: Clip.none,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((p) => p.painter is SpreadShadowPainter)
          .firstOrNull;
    }

    const BorderRadius round = BorderRadius.all(Radius.circular(5));
    expect(await painterFor(round, 3), isNotNull);
    expect(await painterFor(round, 0), isNull);
    expect(await painterFor(null, 3), isNull);
  });

  testWidgets('shadows keep their order when one has a spread', (
    tester,
  ) async {
    // A crayon button's edge: a graphite shadow, then a coloured one inset
    // by 2 px over it. Both must be painted, graphite first.
    const BoxShadow edge = BoxShadow(
      color: Color(0xFF3A3530),
      offset: Offset(0, 5),
    );
    const BoxShadow fill = BoxShadow(
      color: Color(0xFFC19E3E),
      offset: Offset(0, 5),
      spreadRadius: -2,
    );
    await tester.pumpWidget(
      Center(
        child: decorateWithShadows(
          boxShadow: const [edge, fill],
          borderRadius: const BorderRadius.all(Radius.circular(19)),
          clipBehavior: Clip.none,
          child: const SizedBox(width: 100, height: 50),
        ),
      ),
    );
    final SpreadShadowPainter painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<SpreadShadowPainter>()
        .single;
    expect(painter.shadows, [edge, fill]);
    final BoxDecoration decoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .single;
    expect(decoration.boxShadow, isEmpty);

    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(100, 50));
    expect(canvas.rrects.map((r) => r.outerRect).toList(), const [
      Rect.fromLTRB(0, 5, 100, 55),
      Rect.fromLTRB(2, 7, 98, 53),
    ]);
  });
}
