import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A hexagon in a 100 x 100 box, pointy at the top and bottom: the shape of
/// an Apiary hex button.
const String _hexagon = 'M50 0 L100 25 L100 75 L50 100 L0 75 L0 25 Z';

const ColorRGBA _amber = ColorRGBA(r: 1, g: 0.75, b: 0, a: 1);
const ColorRGBA _brown = ColorRGBA(r: 0.4, g: 0.2, b: 0, a: 1);

PaintModel _linear() => PaintModel(
  id: 'amber',
  type: PaintType.gradientLinear,
  gradientStops: [
    const ColorStop(position: 0, color: _amber),
    const ColorStop(position: 1, color: _brown),
  ],
  // Left to right.
  gradientTransform: [1, 0, 0, 0, 1, 0],
);

Effect _drop({double blur = 0, double spread = 0}) => Effect(
  id: 'drop',
  type: EffectType.dropShadow,
  radius: blur,
  spread: spread,
  offset: const Vec(0, 10),
  color: const ColorRGBA(r: 0, g: 0, b: 0, a: 1),
);

PathNode _hex({
  List<PaintModel>? fills,
  List<PaintModel> strokes = const [],
  List<Effect> effects = const [],
}) => PathNode(
  id: 'hex',
  name: 'Hex',
  basicBoxLocal: NodeBox(0, 0, 100, 100),
  pathData: _hexagon,
  viewBoxWidth: 100,
  viewBoxHeight: 100,
  fills: fills ?? [_linear()],
  strokes: strokes,
  effects: effects,
)..parentID = kRootNode;

Future<void> _pump(
  WidgetTester tester,
  BaseNode node, {
  WidgetBuildSettings settings = const WidgetBuildSettings(debugLabel: 't'),
}) async {
  final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Center(
          child: Builder(
            builder: (context) =>
                manager.buildWidgetFromNode(node, context, settings: settings),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

List<T> _painters<T>(WidgetTester tester) => [
  for (final CustomPaint paint in tester.widgetList<CustomPaint>(
    find.byType(CustomPaint),
  )) ...[
    if (paint.painter case final T painter) painter,
    if (paint.foregroundPainter case final T painter) painter,
  ],
];

/// Paints [painter] for a 100 x 100 box into a 140 x 140 image, the box at
/// (20, 20), and returns its RGBA bytes.
Future<ByteData> _render(WidgetTester tester, CustomPainter painter) async {
  final ByteData? bytes = await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..translate(20, 20);
    painter.paint(canvas, const Size(100, 100));
    final ui.Image image = await recorder.endRecording().toImage(140, 140);
    return (await image.toByteData())!;
  });
  return bytes!;
}

/// The colour at ([x], [y]) of the box painted by [_render].
Color _pixel(ByteData bytes, int x, int y) {
  final int i = ((y + 20) * 140 + (x + 20)) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  group('path node fills', () {
    testWidgets('a linear gradient fill paints a shader across the hexagon', (
      tester,
    ) async {
      await _pump(tester, _hex());
      final PathNodePainter painter = _painters<PathNodePainter>(tester).single;
      expect(painter.fills, hasLength(1));
      expect(painter.fills.single.gradient, isA<LinearGradient>());
      final Paint paint = painter.fills.single.toPaint(
        const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(paint.shader, isNotNull);

      final ByteData bytes = await _render(tester, painter);
      final Color left = _pixel(bytes, 5, 50), right = _pixel(bytes, 95, 50);
      expect(left.a, 1);
      expect(right.a, 1);
      // Amber on the left, brown on the right.
      expect(left.r, greaterThan(0.9));
      expect(left.g, greaterThan(0.6));
      expect(right.r, lessThan(0.5));
      expect(right.g, lessThan(0.3));
      // Outside the hexagon (a corner of its box) stays clear.
      expect(_pixel(bytes, 3, 3).a, 0);
    });

    testWidgets('a radial gradient keeps its centre and radius', (
      tester,
    ) async {
      await _pump(
        tester,
        _hex(
          fills: [
            PaintModel(
              id: 'glow',
              type: PaintType.gradientRadial,
              gradientStops: [
                const ColorStop(position: 0, color: _amber),
                const ColorStop(position: 1, color: _brown),
              ],
              gradientCenterX: -0.5,
              gradientCenterY: 0.25,
              gradientRadius: 0.8,
            ),
          ],
        ),
      );
      final RadialGradient gradient =
          _painters<PathNodePainter>(tester).single.fills.single.gradient!
              as RadialGradient;
      expect(gradient.center, const Alignment(-0.5, 0.25));
      expect(gradient.radius, 0.8);
    });

    testWidgets('fills paint in order with their opacity and blend mode', (
      tester,
    ) async {
      await _pump(
        tester,
        _hex(
          fills: [
            PaintModel.solid(id: 'base', color: ColorRGB.white),
            _linear(),
            PaintModel.solid(
              id: 'tint',
              color: ColorRGB.black,
              opacity: 0.5,
              blendMode: BlendModeC.multiply,
            ),
          ],
        ),
      );
      final List<PathFill> fills = _painters<PathNodePainter>(tester)
          .single
          .fills;
      expect(fills, hasLength(3));
      expect(fills[0].color, const Color(0xFFFFFFFF));
      expect(fills[1].gradient, isA<LinearGradient>());
      expect(fills[2].color!.a, closeTo(0.5, 0.01));
      expect(fills[2].blendMode, BlendMode.multiply);
    });

    testWidgets('an image fill is laid out clipped to the path', (
      tester,
    ) async {
      await _pump(
        tester,
        _hex(
          fills: [
            PaintModel.image(
              id: 'honey',
              downloadUrl: 'https://example.com/honey.png',
              fit: Fit.cover,
              sourceWidth: 100,
              sourceHeight: 100,
            ),
          ],
          effects: [_drop()],
        ),
        settings: const WidgetBuildSettings(
          debugLabel: 't',
          obscureImages: true,
        ),
      );
      final ClipPath clip = tester.widget<ClipPath>(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PathNodeClipper,
        ),
      );
      expect(
        clip.clipper!
            .getClip(const Size(100, 100))
            .contains(const Offset(50, 50)),
        isTrue,
      );
      // Shadows below the image, strokes above it.
      final List<PathNodePainter> painters = _painters<PathNodePainter>(tester);
      expect(painters.map((p) => p.layer), [
        PathNodeLayer.below,
        PathNodeLayer.above,
      ]);
      expect(painters.first.filled, isTrue);
      expect(painters.first.shadows, hasLength(1));
    });
  });

  group('path node shadows', () {
    testWidgets('a drop shadow follows the hexagon, not its box', (
      tester,
    ) async {
      await _pump(tester, _hex(effects: [_drop()]));
      final PathNodePainter painter = _painters<PathNodePainter>(tester).single;
      expect(painter.shadows.single.offset, const Offset(0, 10));

      final ByteData bytes = await _render(tester, painter);
      // Below the bottom point, the shadow (shifted 10 down) shows.
      expect(_pixel(bytes, 50, 105).a, 1);
      expect(_pixel(bytes, 50, 105).r, 0);
      // Under the bottom-left corner of the box a box shadow would paint;
      // the hexagon's doesn't reach it.
      expect(_pixel(bytes, 3, 105).a, 0);
    });

    testWidgets('a stroke-only open path casts a line-shaped shadow', (
      tester,
    ) async {
      final PathNode node = PathNode(
        id: 'line',
        name: 'Line',
        basicBoxLocal: NodeBox(0, 0, 100, 100),
        pathData: 'M0 50 L100 50',
        strokeWeight: 4,
        strokes: [PaintModel.solid(id: 's', color: ColorRGB.white)],
        effects: [_drop()],
      )..parentID = kRootNode;
      await _pump(tester, node);
      final ByteData bytes = await _render(
        tester,
        _painters<PathNodePainter>(tester).single,
      );
      // The white line at y = 50 and its black shadow at y = 60.
      expect(_pixel(bytes, 50, 50), const Color(0xFFFFFFFF));
      expect(_pixel(bytes, 50, 60), const Color(0xFF000000));
      expect(_pixel(bytes, 50, 70).a, 0);
    });

    testWidgets('a spread grows the shadow around the outline', (tester) async {
      await _pump(tester, _hex(effects: [_drop(spread: 6)]));
      final ByteData bytes = await _render(
        tester,
        _painters<PathNodePainter>(tester).single,
      );
      // 4px past the shifted bottom point.
      expect(_pixel(bytes, 50, 114).a, 1);
    });

    testWidgets('an inner shadow darkens the inside of the edge', (
      tester,
    ) async {
      await _pump(
        tester,
        _hex(
          fills: [PaintModel.solid(id: 'w', color: ColorRGB.white)],
          effects: [
            Effect(
              id: 'inner',
              type: EffectType.innerShadow,
              radius: 0,
              offset: const Vec(0, 10),
              color: const ColorRGBA(r: 0, g: 0, b: 0, a: 1),
            ),
          ],
        ),
      );
      final PathNodePainter painter = _painters<PathNodePainter>(tester).single;
      expect(painter.innerShadows, hasLength(1));
      final ByteData bytes = await _render(tester, painter);
      // The top 10px inside the hexagon are in shadow, the middle isn't.
      expect(_pixel(bytes, 50, 5), const Color(0xFF000000));
      expect(_pixel(bytes, 50, 50), const Color(0xFFFFFFFF));
    });
  });

  group('rectangle drawn as a path', () {
    RectangleNode rect({List<PaintModel>? fills}) => RectangleNode.fromJson({
      'id': 'hexbox',
      'name': 'hexbox',
      'type': 'rectangle',
      'basicBoxLocal': [0, 0, 100, 100],
      'path': _hexagon,
      'fills': [
        for (final PaintModel paint
            in fills ?? [PaintModel.solid(id: 'f', color: ColorRGB.white)])
          paint.toJson(),
      ],
      'effects': [_drop().toJson()],
    })..parentID = kRootNode;

    testWidgets('its drop shadow follows the path, not the box', (
      tester,
    ) async {
      await _pump(tester, rect());
      // No box shadow on the box.
      for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      )) {
        final Decoration decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.boxShadow ?? const [], isEmpty);
        }
      }
      final PathShadowPainter painter = _painters<PathShadowPainter>(tester)
          .single;
      expect(painter.shape.data, _hexagon);
      expect(painter.shape.filled, isTrue);
      expect(painter.shadows.single.offset, const Offset(0, 10));

      final ByteData bytes = await _render(tester, painter);
      expect(_pixel(bytes, 50, 105).a, 1);
      expect(_pixel(bytes, 3, 105).a, 0);
    });

    testWidgets('a blurred shadow with spread keeps to the outline', (
      tester,
    ) async {
      const PathShadowPainter painter = PathShadowPainter(
        shape: PathShadowShape(data: _hexagon),
        shadows: [
          BoxShadow(
            offset: Offset(0, 10),
            blurRadius: 4,
            spreadRadius: 3,
            color: Color(0x80000000),
          ),
        ],
      );
      final ByteData bytes = await _render(tester, painter);
      // Under the middle: the full shadow colour (translucent, once).
      expect(_pixel(bytes, 50, 60).a, closeTo(0.5, 0.02));
      // Past the box's corner: nothing.
      expect(_pixel(bytes, 1, 108).a, 0);
    });

    testWidgets('a stroke-only path casts the stroke shadow', (tester) async {
      final RectangleNode node = RectangleNode.fromJson({
        'id': 'bracket',
        'name': 'bracket',
        'type': 'rectangle',
        'basicBoxLocal': [0, 0, 30, 30],
        'path': 'M2 30 V10 Q2 2 10 2 H30',
        'fills': <Object>[],
        'strokes': [
          {'id': 's1', 'type': 'solid', 'color': '#FFFFFF'},
        ],
        'strokeWeight': 4,
        'strokeCap': 'round',
        'strokeJoin': 'round',
        'effects': [_drop().toJson()],
      })..parentID = kRootNode;
      await _pump(tester, node);
      final PathShadowShape shape = _painters<PathShadowPainter>(tester)
          .single
          .shape;
      expect(shape.filled, isFalse);
      expect(shape.strokeWidth, 4);
      expect(shape.cap, StrokeCap.round);
    });
  });
}
