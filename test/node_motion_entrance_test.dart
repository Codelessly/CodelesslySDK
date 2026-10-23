import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(
  WidgetTester tester,
  MotionModel motion, {
  bool animate = true,
}) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: NodeMotion(
        motion: motion,
        animate: animate,
        child: const SizedBox(width: 100, height: 100),
      ),
    ),
  ),
);

double opacityOf(WidgetTester tester) {
  final Finder finder = find.byType(Opacity);
  return finder.evaluate().isEmpty
      ? 1
      : tester.widget<Opacity>(finder.first).opacity;
}

double scaleOf(WidgetTester tester) {
  final Finder finder = find.descendant(
    of: find.byType(NodeMotion),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) return 1;
  return tester.widget<Transform>(finder.first).transform.getMaxScaleOnAxis();
}

/// A record that fades and settles in from slightly too big.
const MotionModel record = MotionModel(
  durationMs: 400,
  curve: MotionCurve.linear,
  enterFrom: MotionModel(scale: 1.15, opacity: 0),
);

void main() {
  testWidgets('An entrance starts from enterFrom and settles at rest', (
    tester,
  ) async {
    await pump(tester, record);
    expect(opacityOf(tester), 0);
    expect(scaleOf(tester), closeTo(1.15, 0.001));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester), closeTo(0.5, 0.01));
    expect(scaleOf(tester), closeTo(1.075, 0.001));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), 1);
    expect(scaleOf(tester), 1);
  });

  testWidgets('An entrance from values settles on the node values', (
    tester,
  ) async {
    await pump(
      tester,
      const MotionModel(
        opacity: 0.8,
        durationMs: 400,
        curve: MotionCurve.linear,
        enter: true,
        enterFrom: MotionModel(opacity: 0),
      ),
    );
    expect(opacityOf(tester), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester), closeTo(0.4, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), closeTo(0.8, 0.001));
  });

  testWidgets('Changing replayKey plays the entrance again', (tester) async {
    await pump(tester, record.copyWith(replayKey: 'a'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester), 1);

    // Same key: nothing moves.
    await pump(tester, record.copyWith(replayKey: 'a'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf(tester), 1);

    await pump(tester, record.copyWith(replayKey: 'b'));
    expect(opacityOf(tester), 0);
    expect(scaleOf(tester), closeTo(1.15, 0.001));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), 1);
  });

  testWidgets('A replay without enterFrom starts from rest', (tester) async {
    const MotionModel motion = MotionModel(
      opacity: 0.2,
      durationMs: 400,
      curve: MotionCurve.linear,
    );
    await pump(tester, motion.copyWith(replayKey: '1'));
    expect(opacityOf(tester), closeTo(0.2, 0.001), reason: 'no entrance');
    await pump(tester, motion.copyWith(replayKey: '2'));
    expect(opacityOf(tester), 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(tester), closeTo(0.6, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacityOf(tester), closeTo(0.2, 0.001));
  });

  testWidgets('The design canvas ignores entrances and replays', (
    tester,
  ) async {
    await pump(tester, record.copyWith(replayKey: 'a'), animate: false);
    expect(opacityOf(tester), 1);
    await pump(tester, record.copyWith(replayKey: 'b'), animate: false);
    expect(opacityOf(tester), 1);
  });

  test('enterFrom and replayKey survive JSON', () {
    final MotionModel motion = record.copyWith(replayKey: 'x');
    final Map json = motion.toJson();
    expect(json['enterFrom'], {'scale': 1.15, 'opacity': 0.0});
    expect(MotionModel.fromJson(json), motion);
    expect(motion.copyWith(clearEnterFrom: true).enterFrom, isNull);
    expect(MotionModel.none.toJson().containsKey('enterFrom'), isFalse);
  });

  test('motion.replayKey resolves from a variable to text', () {
    final RectangleNode node =
        RectangleNode(
            id: 'disc',
            name: 'Disc',
            basicBoxLocal: NodeBox(0, 0, 100, 100),
          )
          ..motion = record
          ..variables[MotionModel.variableKey(MotionModel.replayKeyProperty)] =
              r'${= 2 + 5}';
    final MotionModel resolved = WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
    )!;
    expect(resolved.replayKey, '7');
    expect(resolved.enterFrom, record.enterFrom);
  });
}
