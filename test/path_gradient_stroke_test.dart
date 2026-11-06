import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A rectangle with a `path` strokes the path with any paint: a linear or
// angular gradient is laid out over the node's box, as a box's gradient
// is, and a bound stop colour (`stroke-paint-<id>-stop-<i>`) recolours it.
// The Lamplight kelvin arc slider is an open 240° arc with round caps and
// an angular gradient of the four kelvin stops.

Map<String, dynamic> _stop(double position, String hex) => {
  'position': position,
  'color': ColorRGBA.fromHex(hex)!.toJson(),
};

/// A 200x200 box with an open 240° arc (radius 80, centred), stroked 16 px
/// with [stroke].
RectangleNode _arc(
  Map<String, dynamic> stroke, {
  Map<String, String> variables = const {},
}) => RectangleNode.fromJson({
  'id': 'arc',
  'name': 'arc',
  'type': 'rectangle',
  'basicBoxLocal': [0, 0, 200, 200],
  // From 240° (lower left) clockwise through the top to 120° (lower right).
  'path': 'M30.72 140 A80 80 0 1 1 169.28 140',
  'fills': <Object>[],
  'strokes': [stroke],
  'strokeWeight': 16,
  'strokeCap': 'round',
  'variables': variables,
})..parentID = kRootNode;

Map<String, dynamic> _linear() => {
  'id': 's1',
  'type': 'gradientLinear',
  'gradientTransform': [1, 0, 0, 0, 1, 0],
  'gradientStops': [_stop(0, '#FF0000'), _stop(1, '#0000FF')],
};

/// The four kelvin stops, around the box centre.
Map<String, dynamic> _angular() => {
  'id': 's1',
  'type': 'gradientAngular',
  'gradientTransform': [1, 0, 0, 0, 1, 0],
  'gradientStops': [
    _stop(0, '#FF8A3D'),
    _stop(0.33, '#FFD27F'),
    _stop(0.66, '#FFFFFF'),
    _stop(1, '#9FC8FF'),
  ],
};

/// Pumps [node] and returns the painted pixels of its 200x200 box.
Future<(ByteData, int)> _paint(
  WidgetTester tester,
  BaseNode node, {
  CodelesslyContext? codelesslyContext,
}) async {
  final GlobalKey key = GlobalKey();
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.black,
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
  expect(tester.takeException(), isNull);
  late ByteData data;
  late int width;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    width = image.width;
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return (data, width);
}

/// The (r, g, b) at ([x], [y]).
(int, int, int) _rgb((ByteData, int) image, int x, int y) {
  final (ByteData data, int width) = image;
  final int o = (y * width + x) * 4;
  return (data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
}

void main() {
  testWidgets('a linear gradient stroke runs across the box along the path', (
    tester,
  ) async {
    final image = await _paint(tester, _arc(_linear()));
    final SvgPathStrokePainter painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<SvgPathStrokePainter>()
        .single;
    expect(painter.gradient, isA<LinearGradient>());
    // Left side of the arc (x = 20, y = 100): mostly red.
    final (int lr, _, int lb) = _rgb(image, 20, 100);
    expect(lr, greaterThan(180));
    expect(lb, lessThan(80));
    // Right side (x = 180): mostly blue.
    final (int rr, _, int rb) = _rgb(image, 180, 100);
    expect(rb, greaterThan(180));
    expect(rr, lessThan(80));
    // Top (x = 100, y = 20): halfway.
    final (int tr, _, int tb) = _rgb(image, 100, 20);
    expect(tr, inInclusiveRange(90, 170));
    expect(tb, inInclusiveRange(90, 170));
    // Off the path stays the background.
    expect(_rgb(image, 100, 100), (0, 0, 0));
  });

  testWidgets('an angular gradient stroke goes round the box centre', (
    tester,
  ) async {
    final image = await _paint(tester, _arc(_angular()));
    // Angle 0 is to the right (3 o'clock): the first stop, orange.
    final (int r0, int g0, int b0) = _rgb(image, 180, 100);
    expect(r0, greaterThan(230));
    expect(g0, inInclusiveRange(110, 170));
    expect(b0, lessThan(100));
    // 90° clockwise is the bottom; the arc is open there. At 180° (left,
    // 0.5 of the way round) it is between pale yellow and white.
    final (int r1, int g1, int b1) = _rgb(image, 20, 100);
    expect(r1, greaterThan(230));
    expect(g1, greaterThan(200));
    expect(b1, greaterThan(130));
    // At 270° (top, 0.75): between white and the blue.
    final (int r2, int g2, int b2) = _rgb(image, 100, 20);
    expect(b2, greaterThan(240));
    expect(r2, lessThan(250));
    expect(g2, greaterThan(190));
  });

  testWidgets('a bound stop recolours a path stroke', (tester) async {
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['warm'] = Observable(
        VariableData(
          id: 'warm',
          name: 'warm',
          type: VariableType.color,
          value: '#00FF00',
        ),
      );
    final image = await _paint(
      tester,
      _arc(_linear(), variables: {'stroke-paint-s1-stop-0': r'${warm}'}),
      codelesslyContext: codelesslyContext,
    );
    // The left end is now green.
    final (int r, int g, int b) = _rgb(image, 20, 100);
    expect(g, greaterThan(180));
    expect(r, lessThan(60));
    expect(b, lessThan(80));
  });

  testWidgets('a notched box strokes with its gradient', (tester) async {
    final RectangleNode node = RectangleNode.fromJson({
      'id': 'notched',
      'name': 'notched',
      'type': 'rectangle',
      'basicBoxLocal': [0, 0, 200, 200],
      'fills': <Object>[],
      'strokes': [_linear()],
      'strokeWeight': 8,
      'notches': [
        {'edge': 'top', 'offset': 0.5, 'radius': 20},
      ],
    })..parentID = kRootNode;
    final image = await _paint(tester, node);
    expect(notchesOf(node), isNotEmpty);
    final (int lr, _, int lb) = _rgb(image, 3, 100);
    expect(lr, greaterThan(180));
    expect(lb, lessThan(80));
    final (int rr, _, int rb) = _rgb(image, 196, 100);
    expect(rb, greaterThan(180));
    expect(rr, lessThan(80));
  });
}
