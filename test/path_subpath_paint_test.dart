import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Two 40 x 40 squares in a 100 x 100 box: top left and bottom right.
const String _twoSquares = 'M0 0 H40 V40 H0 Z M60 60 H100 V100 H60 Z';

/// Three 30 x 30 squares along the top of a 100 x 100 box.
const String _threeSquares =
    'M0 0 H30 V30 H0 Z M35 0 H65 V30 H35 Z M70 0 H100 V30 H70 Z';

const ColorRGBA _white = ColorRGBA(r: 1, g: 1, b: 1, a: 1);
const ColorRGBA _black = ColorRGBA(r: 0, g: 0, b: 0, a: 1);

PaintModel _radial({
  bool perSubpath = true,
  double centerX = 0,
  double centerY = 0,
}) => PaintModel(
  id: 'glow',
  type: PaintType.gradientRadial,
  gradientStops: const [
    ColorStop(position: 0, color: _white),
    ColorStop(position: 1, color: _black),
  ],
  gradientCenterX: centerX,
  gradientCenterY: centerY,
  gradientRadius: 0.5,
  gradientPerSubpath: perSubpath,
);

PathNode _path(
  String data, {
  required List<PaintModel> fills,
  List<String> subpathColors = const [],
}) => PathNode(
  id: 'comb',
  name: 'Comb',
  basicBoxLocal: NodeBox(0, 0, 100, 100),
  pathData: data,
  viewBoxWidth: 100,
  viewBoxHeight: 100,
  fills: fills,
  subpathColors: subpathColors,
)..parentID = kRootNode;

final GlobalKey _boundary = GlobalKey();

/// Builds [node] at the top left of the screen inside a [RepaintBoundary]
/// and returns the boundary's pixels (100 x 100, RGBA).
Future<ByteData> _paint(
  WidgetTester tester,
  BaseNode node, {
  CodelesslyContext? codelessly,
}) async {
  final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelessly ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundary,
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
  );
  expect(tester.takeException(), isNull);
  final RenderRepaintBoundary render =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ByteData? bytes = await tester.runAsync(() async {
    final ui.Image image = await render.toImage();
    expect(image.width, 100);
    return (await image.toByteData())!;
  });
  return bytes!;
}

Color _pixel(ByteData bytes, int x, int y) {
  final int i = (y * 100 + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

/// Brightness of a grey pixel, 0 to 1.
double _light(ByteData bytes, int x, int y) => _pixel(bytes, x, y).r;

void main() {
  group('gradient per subpath', () {
    testWidgets('each square gets its own radial centre', (tester) async {
      final ByteData bytes = await _paint(
        tester,
        _path(_twoSquares, fills: [_radial()]),
      );
      // White at each square's own centre, dark towards its corners.
      expect(_light(bytes, 20, 20), greaterThan(0.95));
      expect(_light(bytes, 80, 80), greaterThan(0.95));
      expect(_light(bytes, 1, 1), lessThan(0.25));
      expect(_light(bytes, 61, 61), lessThan(0.25));
      // Both squares are shaded alike.
      expect(
        (_light(bytes, 10, 30) - _light(bytes, 70, 90)).abs(),
        lessThan(0.02),
      );
      // Between the squares nothing is painted.
      expect(_pixel(bytes, 50, 50).a, 0);
    });

    testWidgets('a box gradient is centred on the node, not the squares', (
      tester,
    ) async {
      final ByteData bytes = await _paint(
        tester,
        _path(_twoSquares, fills: [_radial(perSubpath: false)]),
      );
      // The box centre (50, 50) is between the squares, so their centres
      // are dark and their inner corners lightest.
      expect(_light(bytes, 20, 20), lessThan(0.25));
      expect(_light(bytes, 39, 39), greaterThan(_light(bytes, 20, 20)));
    });

    testWidgets('an off-centre highlight sits in each square', (tester) async {
      final ByteData bytes = await _paint(
        tester,
        _path(_twoSquares, fills: [_radial(centerX: -0.5, centerY: -0.5)]),
      );
      // (-0.5, -0.5) of a 40 px square is 10 px in from its top left.
      expect(_light(bytes, 10, 10), greaterThan(0.95));
      expect(_light(bytes, 70, 70), greaterThan(0.95));
      expect(_light(bytes, 10, 10), greaterThan(_light(bytes, 30, 30)));
      expect(_light(bytes, 70, 70), greaterThan(_light(bytes, 90, 90)));
    });

    testWidgets('a hole inside a shape stays part of it', (tester) async {
      // A ring: the inner square winds the other way and lies inside the
      // outer one's bounds, so it is a hole of the same shape.
      final ByteData bytes = await _paint(
        tester,
        _path('M0 0 H100 V100 H0 Z M30 30 V70 H70 V30 Z', fills: [_radial()]),
      );
      expect(_pixel(bytes, 50, 50).a, 0);
      expect(_pixel(bytes, 15, 50).a, 1);
    });
  });

  group('subpath colours', () {
    PaintModel solid() =>
        PaintModel.solid(id: 'f', color: const ColorRGB(r: 0, g: 0, b: 0));

    testWidgets('colour each subpath by index', (tester) async {
      final ByteData bytes = await _paint(
        tester,
        _path(
          _threeSquares,
          fills: [solid()],
          subpathColors: ['#FF0000', '#00FF00', '#0000FF'],
        ),
      );
      expect(_pixel(bytes, 15, 15), const Color(0xFFFF0000));
      expect(_pixel(bytes, 50, 15), const Color(0xFF00FF00));
      expect(_pixel(bytes, 85, 15), const Color(0xFF0000FF));
      expect(_pixel(bytes, 50, 60).a, 0);
    });

    testWidgets('a shorter list repeats; a non-colour keeps the fill', (
      tester,
    ) async {
      final ByteData bytes = await _paint(
        tester,
        _path(
          _threeSquares,
          fills: [solid()],
          subpathColors: ['#FF0000', 'none'],
        ),
      );
      expect(_pixel(bytes, 15, 15), const Color(0xFFFF0000));
      expect(_pixel(bytes, 50, 15), const Color(0xFF000000));
      expect(_pixel(bytes, 85, 15), const Color(0xFFFF0000));
    });

    testWidgets('the fill opacity applies to the shape colours', (
      tester,
    ) async {
      final ByteData bytes = await _paint(
        tester,
        _path(
          _threeSquares,
          fills: [
            PaintModel.solid(
              id: 'f',
              color: const ColorRGB(r: 0, g: 0, b: 0),
              opacity: 0.5,
            ),
          ],
          subpathColors: ['#FF0000'],
        ),
      );
      expect(_pixel(bytes, 15, 15).a, closeTo(0.5, 0.02));
    });

    testWidgets('bound subpathColors read a list variable', (tester) async {
      final PathNode node = _path(_threeSquares, fills: [solid()])
        ..variables['subpathColors'] = r'${cellColors}';
      final Observable<VariableData> colors = Observable(
        VariableData(
          id: 'cellColors',
          name: 'cellColors',
          type: VariableType.list,
          value: ['#0000FF', '#FF0000', '#00FF00'],
        ),
      );
      final ByteData bytes = await _paint(
        tester,
        node,
        codelessly: CodelesslyContext.empty()..variables['cellColors'] = colors,
      );
      expect(_pixel(bytes, 15, 15), const Color(0xFF0000FF));
      expect(_pixel(bytes, 50, 15), const Color(0xFFFF0000));
      expect(_pixel(bytes, 85, 15), const Color(0xFF00FF00));
    });

    testWidgets('a per-shape gradient over shape colours shades each', (
      tester,
    ) async {
      final ByteData bytes = await _paint(
        tester,
        _path(
          _threeSquares,
          fills: [
            solid(),
            PaintModel(
              id: 'shade',
              type: PaintType.gradientRadial,
              gradientStops: const [
                ColorStop(
                  position: 0,
                  color: ColorRGBA(r: 1, g: 1, b: 1, a: 0),
                ),
                ColorStop(position: 1, color: _black),
              ],
              gradientPerSubpath: true,
            ),
          ],
          subpathColors: ['#FF0000', '#00FF00', '#0000FF'],
        ),
      );
      // Pure colour at each centre, darker at its corners.
      expect(_pixel(bytes, 15, 15).r, greaterThan(0.95));
      expect(_pixel(bytes, 50, 15).g, greaterThan(0.95));
      expect(_pixel(bytes, 85, 15).b, greaterThan(0.95));
      expect(_pixel(bytes, 1, 1).r, lessThan(0.3));
      expect(_pixel(bytes, 36, 1).g, lessThan(0.3));
    });
  });

  group('shapes', () {
    test('split by M, holes kept with their shape, cached', () {
      final PathShapes shapes = PathNodePainter.shapes(
        'M0 0 H10 V10 H0 Z M2 2 V8 H8 V2 Z M20 0 H30 V10 H20 Z M40 0',
        const Size(100, 100),
        const Size(200, 100),
      )!;
      expect(shapes.shapes, hasLength(2));
      expect(shapes.shapes[0].bounds, const Rect.fromLTRB(0, 0, 20, 10));
      expect(shapes.shapes[1].bounds, const Rect.fromLTRB(40, 0, 60, 10));
      expect(
        identical(
          PathNodePainter.shapes(
            'M0 0 H10 V10 H0 Z M2 2 V8 H8 V2 Z M20 0 H30 V10 H20 Z M40 0',
            const Size(100, 100),
            const Size(200, 100),
          ),
          shapes,
        ),
        isTrue,
      );
    });

    test('colours read from lists, JSON and comma-separated text', () {
      expect(PathNodePainter.colorsOf(['#FF0000', 0xFF00FF00, null]), [
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        null,
      ]);
      expect(PathNodePainter.colorsOf('#FF0000, #8000FF00'), [
        const Color(0xFFFF0000),
        const Color(0x8000FF00),
      ]);
      expect(PathNodePainter.colorsOf('["#0000FF"]'), [
        const Color(0xFF0000FF),
      ]);
      expect(PathNodePainter.colorsOf(null), isEmpty);
    });

    test('JSON: gradientPerSubpath, gradientUnits and subpathColors', () {
      final PaintModel paint = PaintModel.fromJson({
        'id': 'p',
        'type': 'gradientRadial',
        'gradientUnits': 'subpath',
        'gradientStops': [],
      });
      expect(paint.gradientPerSubpath, isTrue);
      expect(paint.toJson()['gradientPerSubpath'], isTrue);
      expect(
        PaintModel.fromJson({...paint.toJson()}).gradientPerSubpath,
        isTrue,
      );
      expect(
        _radial(perSubpath: false).toJson().containsKey('gradientPerSubpath'),
        isFalse,
      );
      expect(paint.sanitize().gradientPerSubpath, isTrue);
      expect(
        paint.copyWith(gradientPerSubpath: false).gradientPerSubpath,
        isFalse,
      );

      final PathNode node = _path(
        _twoSquares,
        fills: [],
        subpathColors: ['#E8762C', '#D9452B'],
      );
      expect(node.toJson()['subpathColors'], ['#E8762C', '#D9452B']);
      expect(PathNode.fromJson(node.toJson()).subpathColors, [
        '#E8762C',
        '#D9452B',
      ]);
      expect(
        _path(_twoSquares, fills: []).toJson().containsKey('subpathColors'),
        isFalse,
      );
    });
  });
}
