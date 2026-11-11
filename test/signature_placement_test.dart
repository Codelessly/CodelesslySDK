// A signature pad's sign line and placeholder where the design puts them:
// a line 16 px in from the sides and 28 px up, no ×, "Sign here" under it.
import 'package:codelessly_sdk/src/widgets/inputs_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SignaturePainter painter({required bool below, bool mark = true}) => SignaturePainter(
        strokes: const [],
        inkColor: Colors.black,
        inkWidth: 2,
        placeholder: 'Sign here',
        placeholderColor: Colors.grey,
        placeholderFontSize: 12,
        showSignLine: true,
        signLineColor: Colors.grey,
        textDirection: TextDirection.ltr,
        signLineMark: mark,
        signLineInset: 16,
        signLineBottom: 28,
        placeholderBelowLine: below,
        placeholderFontWeight: 500,
        placeholderLetterSpacing: 0,
      );

  testWidgets('the sign line and a placeholder under it', (tester) async {
    await tester.pumpWidget(Center(
      child: SizedBox(width: 300, height: 110, child: CustomPaint(painter: painter(below: true, mark: false))),
    ));
    final box = tester.renderObject(find.byType(CustomPaint).last);
    expect(box, paints..line(p1: const Offset(16, 82), p2: const Offset(284, 82)));
    // Only the placeholder: no × beside the line.
    expect(box, paintsExactlyCountTimes(#drawParagraph, 1));
  });

  testWidgets('by default the × marks the line and the placeholder is centered', (tester) async {
    await tester.pumpWidget(Center(
      child: SizedBox(width: 300, height: 110, child: CustomPaint(painter: painter(below: false))),
    ));
    expect(tester.renderObject(find.byType(CustomPaint).last), paintsExactlyCountTimes(#drawParagraph, 2));
  });

  test('strokes are curves, or straight segments when not smooth', () {
    const pts = [Offset(0, 0), Offset(10, 10), Offset(20, 0)];
    double length(Path p) => p.computeMetrics().fold(0.0, (a, m) => a + m.length);
    // Through the middle point: 2 × √200; the curve cuts the corner.
    expect(length(SignaturePainter.linePath(pts)), closeTo(28.28, 0.01));
    expect(length(SignaturePainter.smoothPath(pts)), lessThan(28.2));
  });
}
