import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// MotionModel.arc: a change of position travels along a curve (players
/// sweeping to their spots in a new formation) instead of a straight line.
void main() {
  Widget at(double x, double y, {double arc = 0.25, MotionCurve curve = MotionCurve.linear}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: NodeMotion(
            motion: MotionModel(translateX: x, translateY: y, durationMs: 1000, curve: curve, arc: arc),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

  Offset shown(WidgetTester tester) {
    final Transform t = tester.widget(find.byType(Transform));
    return Offset(t.transform.getTranslation().x, t.transform.getTranslation().y);
  }

  testWidgets('halfway, the node is a quarter of arc × distance off the line, to the right of travel', (tester) async {
    await tester.pumpWidget(at(0, 0));
    await tester.pumpWidget(at(100, 0));
    await tester.pump(const Duration(milliseconds: 500));
    // Moving right (east) on screen: right of travel is down (+y). The
    // quadratic's control point is 0.25 × 100 off; halfway the curve is half
    // of that out: 12.5.
    expect(shown(tester).dx, closeTo(50, 0.01));
    expect(shown(tester).dy, closeTo(12.5, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    // At t = 0.75: 2 × 0.75 × 0.25 × 0.25 × 100 = 9.375.
    expect(shown(tester).dx, closeTo(75, 0.01));
    expect(shown(tester).dy, closeTo(9.375, 0.01));
    await tester.pumpAndSettle();
    expect(shown(tester), const Offset(100, 0), reason: 'it lands exactly on the new spot');
  });

  testWidgets('a negative arc bends the other way', (tester) async {
    await tester.pumpWidget(at(0, 0, arc: -0.5));
    await tester.pumpWidget(at(0, 80, arc: -0.5));
    await tester.pump(const Duration(milliseconds: 500));
    // Moving down: right of travel is -x; a negative arc goes to +x.
    expect(shown(tester).dx, closeTo(20, 0.01)); // 2 × .5 × .5 × .5 × 80
    expect(shown(tester).dy, closeTo(40, 0.01));
    await tester.pumpAndSettle();
  });

  testWidgets('arc 0 is a straight line', (tester) async {
    await tester.pumpWidget(at(0, 0, arc: 0));
    await tester.pumpWidget(at(100, 0, arc: 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(shown(tester).dy, closeTo(0, 0.01));
  });

  testWidgets('the curve follows the easing (as the reference: a Bézier at the eased time)', (tester) async {
    await tester.pumpWidget(at(0, 0, curve: MotionCurve.easeInOutCubic));
    await tester.pumpWidget(at(100, 0, curve: MotionCurve.easeInOutCubic));
    await tester.pump(const Duration(milliseconds: 250));
    final double t = Curves.easeInOutCubic.transform(0.25);
    expect(shown(tester).dx, closeTo(100 * t, 0.01));
    expect(shown(tester).dy, closeTo(100 * 0.25 * 2 * t * (1 - t), 0.01));
  });

  test('arc round-trips through JSON and binds as a setting', () {
    const MotionModel m = MotionModel(translateX: 4, arc: 0.3);
    expect(MotionModel.fromJson(m.toJson()).arc, 0.3);
    expect(const MotionModel().toJson().containsKey('arc'), isFalse);
    expect(MotionModel.settings, contains('arc'));
    expect(const MotionModel().withSetting('arc', '0.4').arc, 0.4);
  });
}
