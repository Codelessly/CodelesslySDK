import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A node's `transitionMs` eases its bound gradient stops (the page
// background following the palette) and its stroke colours (card and pill
// outlines) as it eases a solid fill: Day/Dusk/Night shifts every colour
// over 900 ms. Under muted tickers (the design canvas, captures) they jump.

const Color dusk = Color(0xFFF4ECE3);
const Color night = Color(0xFF16171B);

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Observable<VariableData> bg(Color color) => Observable(
  VariableData(id: 'bg', name: 'bg', type: VariableType.text, value: hex(color)),
);

/// A box with a two-stop gradient whose first stop is bound to `bg`, and an
/// outline (solid, or [gradientStroke]) bound to `bg` too.
FrameNode box({
  int transitionMs = 900,
  bool gradientStroke = false,
  List<double> dash = const [],
}) {
  final PaintModel fill = PaintModel(
    id: 'g',
    type: PaintType.gradientLinear,
    gradientStops: [
      ColorStop(position: 0, color: ColorRGBA.fromHex('#FF9E9E9E')!),
      ColorStop(position: 1, color: ColorRGBA.fromHex('#FF000000')!),
    ],
    gradientTransform: const [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
  );
  final PaintModel stroke = gradientStroke
      ? PaintModel(
          id: 's',
          type: PaintType.gradientLinear,
          gradientStops: [
            ColorStop(position: 0, color: ColorRGBA.fromHex('#FF9E9E9E')!),
            ColorStop(position: 1, color: ColorRGBA.fromHex('#FF000000')!),
          ],
          gradientTransform: const [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        )
      : PaintModel.solid(id: 's', color: ColorRGB.fromHex('#9E9E9E'));
  return FrameNode(
      id: 'box',
      name: 'Box',
      basicBoxLocal: NodeBox(0, 0, 200, 100),
      fills: [fill],
      strokes: [stroke],
      strokeWeight: 2,
      dashPattern: dash,
      children: const [],
    )
    ..parentID = kRootNode
    ..variables.addAll({
      StyleBindings.paintStop('fill-g', 0): r'${bg}',
      if (gradientStroke)
        StyleBindings.paintStop('stroke-paint-s', 0): r'${bg}'
      else
        'stroke-paint-s': r'${bg}',
    })
    ..transitionMs = transitionMs;
}

Future<Observable<VariableData>> pump(
  WidgetTester tester,
  FrameNode node, {
  bool ticking = true,
}) async {
  final Observable<VariableData> variable = bg(dusk);
  final context = CodelesslyContext.empty()..variables['bg'] = variable;
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    TickerMode(
      enabled: ticking,
      child: ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return variable;
}

Color? fillStop(WidgetTester tester) => [
  for (final Ink ink in tester.widgetList<Ink>(find.byType(Ink)))
    ink.decoration,
  for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  ))
    box.decoration,
].whereType<BoxDecoration>().map((d) => d.gradient).whereType<Gradient>()
    .firstOrNull
    ?.colors
    .first;

Color? borderColor(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.border)
    .whereType<Border>()
    .firstOrNull
    ?.top
    .color;

Color? painterColor(WidgetTester tester) {
  for (final CustomPaint paint in tester.widgetList<CustomPaint>(
    find.byType(CustomPaint),
  )) {
    final CustomPainter? p = paint.painter;
    if (p is StrokePainter) return p.gradient?.colors.first ?? p.color;
  }
  return null;
}

bool between(Color? c, Color a, Color b) {
  if (c == null) return false;
  bool inRange(double v, double x, double y) =>
      v > (x < y ? x : y) + 0.01 && v < (x < y ? y : x) - 0.01;
  return inRange(c.r, a.r, b.r) && inRange(c.g, a.g, b.g);
}

void main() {
  testWidgets('a bound gradient stop and a stroke colour ease to new '
      'colours', (tester) async {
    final variable = await pump(tester, box());
    expect(fillStop(tester), dusk);
    expect(borderColor(tester), dusk);

    variable.value = variable.value.copyWith(value: hex(night));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(between(fillStop(tester), dusk, night), isTrue,
        reason: '${fillStop(tester)}');
    expect(between(borderColor(tester), dusk, night), isTrue,
        reason: '${borderColor(tester)}');

    await tester.pumpAndSettle();
    expect(fillStop(tester), night);
    expect(borderColor(tester), night);
  });

  testWidgets('a gradient stroke\'s bound stops and a dashed stroke ease', (
    tester,
  ) async {
    for (final (bool gradient, List<double> dash) in [
      (true, const <double>[]),
      (false, const <double>[4, 4]),
    ]) {
      final variable = await pump(
        tester,
        box(gradientStroke: gradient, dash: dash),
      );
      expect(painterColor(tester), dusk);
      variable.value = variable.value.copyWith(value: hex(night));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(between(painterColor(tester), dusk, night), isTrue,
          reason: 'gradient: $gradient, ${painterColor(tester)}');
      await tester.pumpAndSettle();
      expect(painterColor(tester), night);
      // A fresh tree for the next case.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('without transitionMs they jump', (tester) async {
    final variable = await pump(tester, box(transitionMs: 0));
    variable.value = variable.value.copyWith(value: hex(night));
    await tester.pump();
    expect(fillStop(tester), night);
    expect(borderColor(tester), night);
  });

  testWidgets('under muted tickers (the design canvas) they jump', (
    tester,
  ) async {
    final variable = await pump(tester, box(), ticking: false);
    variable.value = variable.value.copyWith(value: hex(night));
    await tester.pump();
    await tester.pump();
    expect(fillStop(tester), night);
    expect(borderColor(tester), night);
  });
}
