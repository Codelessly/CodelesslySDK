import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final manager = PassiveNodeTransformerManager(
    (id) => throw StateError(id),
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );

  RectangleNode pad() => RectangleNode(
    id: 'pad',
    name: 'Pad',
    basicBoxLocal: NodeBox(0, 0, 44, 30),
  );

  Future<void> pump(WidgetTester tester, RectangleNode node) =>
      tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => manager.applyWidgetOpacity(
                node,
                manager.applyWidgetMotion(
                  context,
                  node,
                  const SizedBox(key: Key('pad'), width: 44, height: 30),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a bound draw scale eases in over the transition', (
    tester,
  ) async {
    final RectangleNode node = pad()
      ..transitionMs = 200
      ..variables = {'drawScale': r'${= 2 > 1 ? 1.15 : 1}'};
    await pump(tester, node);
    final AnimatedScale scale = tester.widget(find.byType(AnimatedScale));
    expect(scale.scale, 1.15);
    expect(scale.duration, const Duration(milliseconds: 200));
  });

  testWidgets('without a transition a draw scale applies at once', (
    tester,
  ) async {
    await pump(tester, pad()..drawScale = 1.08);
    expect(find.byType(AnimatedScale), findsNothing);
    final Transform transform = tester.widget(
      find.ancestor(
        of: find.byKey(const Key('pad')),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.08, 1e-9));
  });

  testWidgets('with a transition, opacity eases back to full too', (
    tester,
  ) async {
    await pump(tester, pad()..transitionMs = 200);
    final AnimatedOpacity opacity = tester.widget(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);
  });

  testWidgets('a pulse loops opacity and scale between its values', (
    tester,
  ) async {
    await pump(
      tester,
      pad()
        ..pulse = const MotionPulseModel(
          periodMs: 1000,
          opacityFrom: 0.5,
          opacityTo: 1,
          scaleFrom: 1,
          scaleTo: 1.4,
        ),
    );
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(NodePulse),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacity(), closeTo(0.5, 1e-6));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(opacity(), closeTo(1, 1e-6));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(opacity(), closeTo(0.5, 1e-6));
    await tester.pumpWidget(const SizedBox());
  });
}
