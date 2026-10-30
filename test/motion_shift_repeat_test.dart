import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, MotionModel motion, {Key? key}) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: NodeMotion(
            motion: motion,
            child: SizedBox(key: key ?? const Key('box'), width: 40, height: 30),
          ),
        ),
      ),
    );

Offset topLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('box')));

void main() {
  testWidgets('shift moves a node by its own size', (tester) async {
    await pump(tester, const MotionModel(shiftX: 3, shiftY: 2));
    expect(topLeft(tester), const Offset(120, 60));
  });

  testWidgets('shift adds to translate and animates', (tester) async {
    await pump(tester, const MotionModel(durationMs: 200, curve: MotionCurve.linear));
    await pump(tester, const MotionModel(shiftX: 2, translateX: 10, durationMs: 200, curve: MotionCurve.linear));
    await tester.pump(const Duration(milliseconds: 100));
    expect(topLeft(tester).dx, closeTo(45, 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(topLeft(tester).dx, 90);
  });

  testWidgets('taps follow a shifted node', (tester) async {
    var taps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: NodeMotion(
          motion: const MotionModel(shiftX: 2),
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox(width: 40, height: 30)),
        ),
      ),
    ));
    await tester.tapAt(const Offset(100, 15));
    expect(taps, 1);
  });

  testWidgets('scaleX stretches along the width only', (tester) async {
    await pump(tester, const MotionModel(scaleX: 3, originX: -1, originY: -1));
    final rect = tester.getRect(find.byKey(const Key('box')));
    expect(rect.width, 120);
    expect(rect.height, 30);
  });

  testWidgets('a counted loop plays its times and comes to rest', (tester) async {
    await pump(tester, const MotionModel(translateX: 9, durationMs: 50, loop: MotionLoop.reverse, repeat: 3, curve: MotionCurve.linear));
    await tester.pump(const Duration(milliseconds: 50));
    expect(topLeft(tester).dx, closeTo(9, 0.5));
    await tester.pump(const Duration(milliseconds: 260));
    expect(topLeft(tester).dx, 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a counted loop plays again when its values change', (tester) async {
    const rest = MotionModel(durationMs: 50, loop: MotionLoop.reverse, repeat: 2, curve: MotionCurve.linear);
    await pump(tester, rest);
    await tester.pumpAndSettle();
    await pump(tester, rest.copyWith(translateX: 9));
    await tester.pump(const Duration(milliseconds: 50));
    expect(topLeft(tester).dx, closeTo(9, 0.5));
    await tester.pumpAndSettle();
    expect(topLeft(tester).dx, 0);
  });

  test('durationMs, shift and scale bind through variables', () {
    final node = RectangleNode(id: 'r', name: 'r', basicBoxLocal: NodeBox(0, 0, 10, 10))
      ..motion = const MotionModel(durationMs: 260)
      ..variables.addAll({
        MotionModel.variableKey('shiftX'): r'${= 5 % 8}',
        MotionModel.variableKey('shiftY'): r'${= 2}',
        MotionModel.variableKey('scaleX'): r'${= 2.5}',
        MotionModel.variableKey(MotionModel.durationProperty): r'${= 1 > 0 ? 140 : 0}',
      });
    final m = WidgetNodeTransformerManager.resolveMotion(node, scopedValues: ScopedValues.empty())!;
    expect(m.shiftX, 5);
    expect(m.shiftY, 2);
    expect(m.scaleX, 2.5);
    expect(m.durationMs, 140);
  });

  test('new motion fields survive JSON and are left out at defaults', () {
    const m = MotionModel(shiftX: 1, scaleY: 2, repeat: 3, loop: MotionLoop.reverse);
    final json = m.toJson();
    expect(json, {'shiftX': 1.0, 'scaleY': 2.0, 'repeat': 3, 'loop': 'reverse'});
    expect(MotionModel.fromJson(json), m);
  });

  testWidgets('keepAspect keeps a stretching box at its ratio', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
            AdaptiveSizeFitBox(
              horizontalFit: SizeFit.expanded,
              verticalFit: SizeFit.fixed,
              size: SizeC(374, 374),
              keepAspect: 1,
              child: SizedBox.expand(key: Key('board')),
            ),
          ]),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const Key('board'))), const Size(300, 300));
  });

  test('ignorePointer and keepAspect survive JSON', () {
    final node = RectangleNode(id: 'r', name: 'r', basicBoxLocal: NodeBox(0, 0, 10, 10))
      ..ignorePointer = true
      ..keepAspect = 1;
    final back = RectangleNode.fromJson(node.toJson());
    expect(back.ignorePointer, isTrue);
    expect(back.keepAspect, 1);
    final plain = RectangleNode(id: 'p', name: 'p', basicBoxLocal: NodeBox(0, 0, 1, 1)).toJson();
    expect(plain.containsKey('ignorePointer'), isFalse);
    expect(plain.containsKey('keepAspect'), isFalse);
  });
}
