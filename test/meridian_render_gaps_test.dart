import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// Rendering a boarding-pass app needs: gradients that run corner to corner
// on a wide band, a past trip's band dimmed over its text, tilted columns,
// motion values given as plain numbers, and oval stamps.

const ColorRGBA _red = ColorRGBA(r: 1, g: 0, b: 0, a: 1);
const ColorRGBA _blue = ColorRGBA(r: 0, g: 0, b: 1, a: 1);

PaintModel _linear({
  List<num>? transform,
  double? beginX,
  double? beginY,
  double? endX,
  double? endY,
}) => PaintModel(
  id: 'g',
  type: PaintType.gradientLinear,
  gradientTransform: transform,
  gradientBeginX: beginX,
  gradientBeginY: beginY,
  gradientEndX: endX,
  gradientEndY: endY,
  gradientStops: const [
    ColorStop(position: 0, color: _red),
    ColorStop(position: 1, color: _blue),
  ],
);

/// The RGBA of the pixel at [x], [y] of what [key]'s boundary painted.
Future<List<int>> Function(int x, int y) _sampler(
  WidgetTester tester,
  GlobalKey key,
) {
  ByteData? data;
  int width = 0;
  return (x, y) async {
    if (data == null) {
      await tester.runAsync(() async {
        final RenderRepaintBoundary boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage();
        width = image.width;
        data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      });
    }
    final int offset = (y * width + x) * 4;
    return [for (int i = 0; i < 4; i++) data!.getUint8(offset + i)];
  };
}

Future<void> _pumpNodes(
  WidgetTester tester,
  Map<String, BaseNode> nodes,
  String rootId, {
  GlobalKey? key,
  CodelesslyContext? codelesslyContext,
}) async {
  final registry = NodeRegistry()..setNodes(nodes);
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
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                nodes[rootId]!,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('linear gradient handles', () {
    test('handles place the gradient corner to corner', () {
      final LinearGradient gradient =
          retrieveGradient(_linear(beginX: -1, beginY: -1, endX: 1, endY: 1))!
              as LinearGradient;
      const Rect box = Rect.fromLTWH(0, 0, 300, 100);
      expect(gradient.transform, isA<GradientHandlesTransform>());
      final Matrix4 m = gradient.transform!.transform(box)!;
      Offset map(Offset p) {
        final v = m.transform3(Vector3(p.dx, p.dy, 0));
        return Offset(v.x, v.y);
      }

      Matcher at(Offset p) => isA<Offset>()
          .having((o) => o.dx, 'dx', closeTo(p.dx, 1e-9))
          .having((o) => o.dy, 'dy', closeTo(p.dy, 1e-9));
      // The default gradient's start and end land on the two corners.
      expect(map(box.centerLeft), at(box.topLeft));
      expect(map(box.centerRight), at(box.bottomRight));
      // Its middle band runs along the other diagonal.
      final Offset mid = map(box.center);
      expect(mid, at(box.center));
      final Offset band = map(box.center + const Offset(0, 300)) - mid;
      expect(band.dy / band.dx, closeTo(-100 / 300, 1e-9));
    });

    test('a gradient without handles still turns by its transform', () {
      final LinearGradient gradient =
          retrieveGradient(_linear(transform: applyGradientRotation(null, 45)))!
              as LinearGradient;
      expect(gradient.begin, Alignment.centerLeft);
      expect(gradient.end, Alignment.centerRight);
      expect(gradient.transform, isA<GradientRotation>());
      expect(
        (gradient.transform! as GradientRotation).radians,
        closeTo(math.pi / 4, 1e-9),
      );
    });

    testWidgets('corner to corner on a 300x100 box hits both corners', (
      tester,
    ) async {
      final GlobalKey key = GlobalKey();
      final RectangleNode band = RectangleNode(
        id: 'band',
        name: 'band',
        basicBoxLocal: NodeBox(0, 0, 300, 100),
        fills: [_linear(beginX: -1, beginY: -1, endX: 1, endY: 1)],
      )..parentID = kRootNode;
      await _pumpNodes(tester, {band.id: band}, band.id, key: key);
      final sample = _sampler(tester, key);
      final List<int> topLeft = await sample(0, 0);
      final List<int> bottomRight = await sample(299, 99);
      expect(topLeft[0], greaterThan(245), reason: 'red at the top left');
      expect(topLeft[2], lessThan(10));
      expect(bottomRight[2], greaterThan(245), reason: 'blue at the end');
      expect(bottomRight[0], lessThan(10));
      // The other two corners sit on the middle band: half and half.
      final List<int> topRight = await sample(299, 0);
      expect(topRight[0], inInclusiveRange(100, 155));
      expect(topRight[2], inInclusiveRange(100, 155));

      // A 45° rotation about the centre doesn't follow the box: its middle
      // band misses the other diagonal of a wide box.
      await _pumpNodes(
        tester,
        {
          band.id: RectangleNode(
            id: 'band',
            name: 'band',
            basicBoxLocal: NodeBox(0, 0, 300, 100),
            fills: [_linear(transform: applyGradientRotation(null, 45))],
          )..parentID = kRootNode,
        },
        band.id,
        key: key,
      );
      final rotated = _sampler(tester, key);
      expect((await rotated(299, 0))[0], lessThan(100));
    });
  });

  group('foreground fills', () {
    FrameNode band({Map<String, String> variables = const {}}) {
      final FrameNode frame = FrameNode.fromJson({
        ...FrameNode(
          id: 'band',
          name: 'band',
          basicBoxLocal: NodeBox(0, 0, 100, 40),
          children: ['ink'],
          fills: [PaintModel.solid(id: 'bg', color: ColorRGB.white)],
        ).toJson(),
        'foregroundFills': [
          {
            'id': 'dim',
            'type': 'solid',
            'color': {'r': 0, 'g': 0, 'b': 0},
            'opacity': 0.5,
          },
        ],
        'variables': variables,
      })..parentID = kRootNode;
      return frame;
    }

    RectangleNode ink() => RectangleNode(
      id: 'ink',
      name: 'ink',
      basicBoxLocal: NodeBox(0, 0, 50, 40),
      fills: [
        PaintModel.solid(id: 'red', color: const ColorRGB(r: 1, g: 0, b: 0)),
      ],
    )..parentID = 'band';

    testWidgets('dims the whole box, children included', (tester) async {
      final GlobalKey key = GlobalKey();
      await _pumpNodes(
        tester,
        {'band': band(), 'ink': ink()},
        'band',
        key: key,
      );
      final sample = _sampler(tester, key);
      final List<int> child = await sample(25, 20);
      final List<int> background = await sample(75, 20);
      expect(child[0], inInclusiveRange(120, 135), reason: 'red, dimmed');
      expect(child[1], lessThan(5));
      expect(
        background[0],
        inInclusiveRange(120, 135),
        reason: 'white, dimmed',
      );
      expect(background[1], inInclusiveRange(120, 135));
      // It takes no taps.
      expect(
        find.descendant(
          of: find.byType(IgnorePointer),
          matching: find.byType(DecoratedBox),
        ),
        findsWidgets,
      );
    });

    testWidgets('a bound foreground colour follows its formula', (
      tester,
    ) async {
      final Observable<VariableData> past = Observable(
        VariableData(
          id: 'past',
          name: 'past',
          type: VariableType.boolean,
          value: false,
        ),
      );
      final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
        ..variables['past'] = past;
      final GlobalKey key = GlobalKey();
      await _pumpNodes(
        tester,
        {
          'band': band(
            variables: {
              'foreground-dim': r"${= past ? '#80000000' : '#00000000'}",
            },
          ),
          'ink': ink(),
        },
        'band',
        key: key,
        codelesslyContext: codelesslyContext,
      );
      expect((await _sampler(tester, key)(75, 20))[0], greaterThan(250));

      past.set(past.value.copyWith(value: true));
      await tester.pump();
      expect(
        (await _sampler(tester, key)(75, 20))[0],
        inInclusiveRange(120, 135),
      );
    });
  });

  group('rotation and motion', () {
    double? angleOf(WidgetTester tester) {
      for (final Transform t in tester.widgetList<Transform>(
        find.byType(Transform),
      )) {
        final double a = math.atan2(
          t.transform.entry(1, 0),
          t.transform.entry(0, 0),
        );
        if (a.abs() > 1e-9) return a * 180 / math.pi;
      }
      return null;
    }

    BaseNode column(Map<String, dynamic> extra) =>
        NodeJsonConverter().fromJson({
          ...RowColumnNode(
            id: 'col',
            name: 'col',
            basicBoxLocal: NodeBox(0, 0, 40, 40),
            rowColumnType: RowColumnType.column,
            children: [],
          ).toJson(),
          ...extra,
        })!..parentID = kRootNode;

    testWidgets('a column draws its rotation', (tester) async {
      final BaseNode node = column({'rotation': -3.4});
      await _pumpNodes(tester, {node.id: node}, node.id);
      expect(angleOf(tester), closeTo(-3.4, 1e-6));
    });

    testWidgets('a zero-duration motion with a plain value is a static pose', (
      tester,
    ) async {
      final BaseNode node = column({
        'motion': {'durationMs': 0},
        'variables': {'motion.rotate': '-3.4'},
      });
      expect(node.motion, isNotNull);
      expect(node.toJson()['motion'], isA<Map>());
      await _pumpNodes(tester, {node.id: node}, node.id);
      expect(angleOf(tester), closeTo(-3.4, 1e-6));
    });
  });

  testWidgets('an ellipse (elliptical linked corners) clips to an oval', (
    tester,
  ) async {
    final GlobalKey key = GlobalKey();
    final RectangleNode oval = RectangleNode(
      id: 'oval',
      name: 'oval',
      basicBoxLocal: NodeBox(0, 0, 120, 60),
      fills: [
        PaintModel.solid(id: 'f', color: const ColorRGB(r: 1, g: 0, b: 0)),
      ],
      cornerRadius: const CornerRadius.all(
        RadiusModel.elliptical(120, 60),
        linked: true,
        type: RadiusType.elliptical,
      ),
    )..parentID = kRootNode;
    await _pumpNodes(tester, {oval.id: oval}, oval.id, key: key);
    final sample = _sampler(tester, key);
    expect((await sample(60, 30))[0], greaterThan(250), reason: 'centre');
    expect((await sample(2, 2))[3], lessThan(10), reason: 'corner is empty');
    // Outside the ellipse but inside a stadium (a pill with radius 30).
    expect((await sample(30, 1))[3], lessThan(10));
  });
}
