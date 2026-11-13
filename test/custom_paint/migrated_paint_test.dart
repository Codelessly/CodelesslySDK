// 30.1.0's paint steps (codelessly_api's `paintSteps`, among the one-way
// steps that end `migrate2to3`) move a stroke path, a box drawn as a path and a path's
// per-shape colors onto `customPaint` and the path node. Each case draws a
// 30.0.0 node as the migration rewrites it and matches a golden image of
// it (goldens/). The goldens were taken while 30.0.0's painters still drew
// the node the old way too, and both agreed: pixel for pixel, or within the
// difference a case names (the largest channel difference, out of 255).
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' show Json, LayoutDocument, Node, Variable, VariableType, migrate2to3, readMap;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [node] (30.0.0's spellings, in a schema-2 document) and the node
/// `migrate2to3` makes of it.
(Json, Json) _migrate(Json node) {
  final doc = migrate2to3({
    'schema': 2,
    'nodes': {'n': node},
  });
  return (node, readMap(readMap(doc['nodes'])!['n'])!);
}

/// The RGBA pixels of node [json] at [size], its expressions read from
/// [variables].
/// With [golden], the drawing must match that image (test/custom_paint/goldens).
Future<List<int>> _shot(WidgetTester tester, Json json, Size size, {List<Variable> variables = const [], String? golden}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final node = Node.fromJson(json, id: 'n')!;
  final doc = LayoutDocument(roots: const ['n'], nodes: {'n': node});
  final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: VariableScope(variables)));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(size: size, child: ColoredBox(color: Colors.white, child: NodeView(tree: tree, rootId: 'n'))),
      ),
    ),
  ));
  await tester.pump();
  if (golden != null) await expectLater(find.byKey(key), matchesGoldenFile('goldens/$golden.png'));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  return data.buffer.asUint8List().toList();
}

/// How many pixels of [rgba] have ink (are not white).
int _ink(List<int> rgba) {
  var ink = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i] != 255 || rgba[i + 1] != 255 || rgba[i + 2] != 255) ink++;
  }
  return ink;
}

/// Draws [node] as the migration rewrote it at each of [sizes], matching
/// the golden `<name>-<width>x<height>`. [oldPainterDifference] records how far
/// 30.0.0's own drawing was from it when the golden was taken.
Future<Json> _same(WidgetTester tester, String name, Json node, List<Size> sizes,
    {int oldPainterDifference = 0, List<Variable> variables = const []}) async {
  final (before, after) = _migrate(node);
  expect(after, isNot(before));
  for (final size in sizes) {
    final drawn = await _shot(tester, after, size, variables: variables, golden: '$name-${size.width.round()}x${size.height.round()}');
    expect(_ink(drawn), greaterThan(0), reason: 'something is drawn at $size');
  }
  return after;
}

Json _box(Json more, {Object width = 160, Object height = 90}) => {
  'type': 'box',
  'layout': {'width': width, 'height': height},
  ...more,
};

const _sizes = [Size(160, 90), Size(233, 121)];

void main() {
  group('a migrated stroke path draws what the stroke path drew', () {
    testWidgets('straight, x in fractions of the box, at two sizes', (tester) async {
      final after = await _same(tester, 'stroke-straight', _box({
        'strokePath': {'points': [[0, 70], [0.15, 80], [0.35, 65], [0.6, 75], [1, 60]], 'color': '#FF1D2B2F', 'width': 3},
      }, width: {'fill': 160}, height: {'fill': 90}), _sizes);
      expect((after['customPaint'] as Map)['painter'], hasLength(1));
    });

    testWidgets('trimmed by its progress, dashed, with butt caps', (tester) async {
      await _same(tester, 'stroke-dashed', _box({
        'strokePath': {
          'points': [[0.05, 10], [0.9, 20], [0.4, 80]], 'progress': 0.55, 'dashPattern': [8, 0, 4], 'cap': 'butt',
          'color': '#FF0057B8', 'width': 4,
        },
      }), _sizes);
    });

    testWidgets('vertical and horizontal curves, both axes in fractions', (tester) async {
      for (final curve in ['vertical', 'horizontal']) {
        await _same(tester, 'stroke-curve-$curve', _box({
          'strokePath': {'points': [[0.1, 0.1], [0.5, 0.9], [0.9, 0.2]], 'xUnit': 'fraction', 'yUnit': 'fraction', 'curve': curve, 'color': '#FF7A1F5C'},
        }, width: {'fill': 160}, height: {'fill': 90}), _sizes);
      }
    });

    testWidgets('quadratic curves through pixel points, an odd point ruled straight', (tester) async {
      await _same(tester, 'stroke-quadratic', _box({
        'strokePath': {'points': [[5, 80], [40, 5], [80, 60], [120, 90], [150, 20], [155, 85]], 'xUnit': 'pixels', 'curve': 'quadratic', 'color': '#FF000000', 'width': 2},
      }), _sizes);
    });

    testWidgets('untilWidth stops at the first segment starting past the box', (tester) async {
      final points = [for (var x = 0; x <= 400; x += 23) [x, x.isEven ? 30 : 60]];
      await _same(tester, 'stroke-until-width-pixels', _box({
        'strokePath': {'points': points, 'xUnit': 'pixels', 'untilWidth': true, 'color': '#FF336699', 'width': 3},
      }, width: {'fill': 160}), _sizes);
      await _same(tester, 'stroke-until-width-fractions', _box({
        'strokePath': {'points': [[0, 10], [0.6, 80], [1.2, 10], [1.8, 80]], 'untilWidth': true, 'curve': 'horizontal', 'color': '#FF336699'},
      }, width: {'fill': 160}), _sizes);
    });

    testWidgets('a fill under the line, in front of the node\'s own fill', (tester) async {
      await _same(tester, 'stroke-fill-in-front', _box({
        'decoration': {'fills': [{'color': '#FFEFE6D2'}], 'radius': 12},
        'strokePath': {'points': [[0.1, 10], [0.9, 15], [0.8, 80], [0.15, 70]], 'fillColor': '#80FF8800', 'inFront': true, 'color': '#FF222222', 'width': 2},
      }), _sizes);
    });

    testWidgets('a fill fading with a progress below 1 is within one level of the fade', (tester) async {
      await _same(tester, 'stroke-fill-fading', _box({
        'strokePath': {'points': [[0.1, 10], [0.9, 15], [0.8, 80], [0.15, 70]], 'fillColor': '#C0FF8800', 'progress': 0.37, 'color': '#FF222222'},
      }), _sizes, oldPainterDifference: 1);
    });

    testWidgets('a progress bound to a variable', (tester) async {
      await _same(tester, 'stroke-bound-progress', _box({
        'strokePath': {'points': [[0, 20], [0.5, 80], [1, 20]], 'color': '#FF0A7D50', 'width': 5},
        'bind': {'strokePath.progress': r'${p}'},
      }), _sizes, variables: [Variable(name: 'p', type: VariableType.decimal, value: 0.4)]);
    });
  });

  group('a box drawn as a path draws as a path node', () {
    testWidgets('a stroked outline is the same', (tester) async {
      final after = await _same(tester, 'box-path-stroke', _box({
        'props': {'path': 'M10 9 L18 18 L18 29 L18 18 L27 9', 'strokeJoin': 'round'},
        'decoration': {'strokes': [{'color': '#FF173849'}], 'strokeWidth': 2},
      }, width: 37, height: 37), const [Size(37, 37)]);
      expect(after['type'], 'path');
      expect(after['props'], {'data': 'M10 9 L18 18 L18 29 L18 18 L27 9', 'strokeJoin': 'round'});
    });

    testWidgets('a filled, stroked and shadowed outline is the same', (tester) async {
      await _same(tester, 'box-path-shadow', _box({
        'props': {'path': 'M0 0 L100 0 L0 100 Z', 'strokeJoin': 'round'},
        'decoration': {
          'fills': [{'color': '#FFFF0000'}],
          'strokes': [{'color': '#FF000000'}],
          'strokeWidth': 4,
          'clip': 'hardEdge',
          'effects': [{'type': 'dropShadow', 'color': '#FF000000', 'blurRadius': 4}],
        },
      }, width: 100, height: 100), const [Size(120, 120)]);
    });

    testWidgets('a fill inside the box differs only in the edge\'s anti-aliasing', (tester) async {
      await _same(tester, 'box-path-fill', _box({
        'props': {'path': 'M0 30L3.5 15H10L6.5 30Z M10 30L15.3 7H21.8L16.5 30Z'},
        'decoration': {'fills': [{'color': '#FFB9F34C'}]},
      }, width: 34, height: 30), const [Size(34, 30)], oldPainterDifference: 3);
    });
  });

  group('per-shape colors draw as one custom paint path per color', () {
    testWidgets('shapes and a hole keep their colors, through a view box', (tester) async {
      const data = 'M10 10 H60 V60 H10 Z M20 20 H50 V50 H20 Z M70 10 A20 20 0 1 0 110 10 A20 20 0 1 0 70 10 Z '
          'm50 0 l20 0 l0 30 z M10 70 h140 v15 h-140 z';
      final after = await _same(tester, 'per-shape-colors', {
        'type': 'path',
        'layout': {'width': {'fill': 160}, 'height': {'fill': 90}},
        'props': {'data': data, 'viewBox': [160, 90], 'subpathColors': ['#FFAA0000', null, '#FF00AA00']},
        'decoration': {'fills': [{'color': '#FF0000AA'}]},
      }, _sizes);
      expect((after['customPaint'] as Map)['painter'], hasLength(3));
      expect(after['decoration'], isNull);
    });

    testWidgets('a gradient laid out in each shape is the same at its design size', (tester) async {
      final after = await _same(tester, 'per-shape-gradient', {
        'type': 'path',
        'layout': {'width': 160, 'height': 90},
        'props': {'data': 'M10 10 H70 V70 H10 Z M90 20 H150 V45 H90 Z M90 55 H133.3 V83.7 H90 Z'},
        'decoration': {
          'fills': [
            {'type': 'linear', 'gradientPerSubpath': true, 'stops': [{'position': 0, 'color': '#FFFF0000'}, {'position': 1, 'color': '#FF0000FF'}]},
          ],
        },
      }, const [Size(160, 90)]);
      expect((after['customPaint'] as Map)['painter'], hasLength(3));
    });
  });
}
