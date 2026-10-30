import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Path and 3D primitives of node motion: moving along an SVG path, hiding a
/// face turned away (flip cards), and the spring curves.
void main() {
  group('motion paths', () {
    test('a point is found by arc length, relative to the start', () {
      final (Offset start, _) = pointOnMotionPath('M10 10 L110 10', 0)!;
      expect(start, Offset.zero);
      final (Offset mid, double angle) = pointOnMotionPath('M10 10 L110 10', 0.5)!;
      expect(mid.dx, closeTo(50, 0.01));
      expect(mid.dy, closeTo(0, 0.01));
      expect(angle, closeTo(0, 1e-6));
      // Two segments: halfway along an L is at its corner.
      final (Offset corner, double down) =
          pointOnMotionPath('M0 0 L100 0 L100 100', 0.75)!;
      expect(corner.dx, closeTo(100, 0.01));
      expect(corner.dy, closeTo(50, 0.01));
      expect(down, closeTo(math.pi / 2, 1e-6), reason: 'heading down');
    });

    test('curves and bad data', () {
      final (Offset end, _) =
          pointOnMotionPath('M0 0 C 80 -160 240 -200 300 -40', 1)!;
      expect(end.dx, closeTo(300, 0.5));
      expect(end.dy, closeTo(-40, 0.5));
      expect(pointOnMotionPath('not a path', 0.5), isNull);
      expect(pointOnMotionPath('M0 0', 0.5), isNull);
    });

    testWidgets('a node is drawn at its progress along the path', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: NodeMotion(
              motion: MotionModel(
                path: 'M0 0 L200 0 L200 100',
                pathProgress: 0.5,
                orientToPath: true,
              ),
              child: SizedBox(width: 20, height: 20, child: Text('star')),
            ),
          ),
        ),
      );
      final Transform t = tester.widget(
        find.ancestor(of: find.text('star'), matching: find.byType(Transform)),
      );
      expect(t.transform.getTranslation().x, closeTo(150, 0.01));
      expect(t.transform.getTranslation().y, closeTo(0, 0.01));
    });

    testWidgets('changing progress glides along the curve', (tester) async {
      Widget at(double p) => Directionality(
        textDirection: TextDirection.ltr,
        child: NodeMotion(
          motion: MotionModel(
            path: 'M0 0 L100 0 L100 100',
            pathProgress: p,
            durationMs: 1000,
            curve: MotionCurve.linear,
          ),
          child: const SizedBox(width: 10, height: 10),
        ),
      );
      await tester.pumpWidget(at(0));
      await tester.pumpWidget(at(1));
      await tester.pump(const Duration(milliseconds: 750));
      final Transform t = tester.widget(find.byType(Transform));
      // 75% of the way is past the corner, on the way down: not a straight
      // line from start to end.
      expect(t.transform.getTranslation().x, closeTo(100, 0.5));
      expect(t.transform.getTranslation().y, closeTo(50, 0.5));
      await tester.pumpAndSettle();
    });
  });

  group('backface', () {
    test('a box faces the viewer until turned past 90°', () {
      Matrix4 turned(double degrees) => Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(degrees * math.pi / 180);
      const size = Size(200, 300);
      expect(RenderBackface.facesViewer(turned(0), size), isTrue);
      expect(RenderBackface.facesViewer(turned(80), size), isTrue);
      expect(RenderBackface.facesViewer(turned(100), size), isFalse);
      expect(RenderBackface.facesViewer(turned(180), size), isFalse);
      // A back face pre-turned 180° inside a card turned 180° faces us.
      expect(
        RenderBackface.facesViewer(turned(180)..rotateY(math.pi), size),
        isTrue,
      );
    });

    testWidgets('a flip card shows one face at a time', (tester) async {
      Widget card(double rotateY) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: NodeMotion(
            motion: MotionModel(rotateY: rotateY),
            child: const SizedBox(
              width: 200,
              height: 300,
              child: Stack(
                children: [
                  NodeMotion(
                    motion: MotionModel(backfaceHidden: true),
                    child: SizedBox.expand(child: Text('question')),
                  ),
                  NodeMotion(
                    motion: MotionModel(rotateY: 180, backfaceHidden: true),
                    child: SizedBox.expand(child: Text('answer')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      bool painted(String text) {
        final RenderBackface face = tester.renderObject(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(BackfaceHidden),
          ),
        );
        return RenderBackface.facesViewer(face.getTransformTo(null), face.size);
      }

      await tester.pumpWidget(card(0));
      expect(painted('question'), isTrue);
      expect(painted('answer'), isFalse);
      await tester.pumpWidget(card(180));
      expect(painted('question'), isFalse);
      expect(painted('answer'), isTrue);
      // Hidden faces take no taps.
      expect(
        tester.hitTestOnBinding(tester.getCenter(find.byType(Stack))).path.any(
          (e) => e.target == tester.renderObject(find.text('question')),
        ),
        isFalse,
      );
    });
  });

  test('spring curves start at 0, overshoot and settle on 1', () {
    for (final MotionCurve curve in [
      MotionCurve.spring,
      MotionCurve.elasticOut,
      MotionCurve.bounceOut,
      MotionCurve.fastOutSlowIn,
    ]) {
      final Curve c = flutterCurveOf(curve);
      expect(c.transform(0), closeTo(0, 1e-9), reason: curve.name);
      expect(c.transform(1), closeTo(1, 1e-9), reason: curve.name);
    }
    final Curve spring = flutterCurveOf(MotionCurve.spring);
    final double peak = [
      for (int i = 0; i <= 100; i++) spring.transform(i / 100),
    ].reduce(math.max);
    expect(peak, greaterThan(1.03));
    expect(peak, lessThan(1.25));
  });
}
