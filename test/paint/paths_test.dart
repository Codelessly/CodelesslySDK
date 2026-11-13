import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/path_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// `scaleStroke`: a path's stroke in its viewBox's units grows with the
// drawing, as in SVG (Strata v2's figures are drawn in 320x180 and shown
// wider; their lines thickened with them in the reference). Without it the
// stroke stays in the box's pixels.

LayoutDocument _doc(bool scale) => LayoutDocument.fromJson({
      'roots': ['canvas'],
      'nodes': {
        'canvas': {'type': 'canvas', 'slots': {'body': 'line'}, 'layout': {'width': 100, 'height': 100}},
        'line': {
          'type': 'path',
          'layout': {'width': 100, 'height': 100},
          'props': {'data': 'M0 5 L10 5', 'viewBox': [10, 10], if (scale) 'scaleStroke': true},
          'decoration': {
            'strokes': [{'color': '#FF000000'}],
            'strokeWidth': 1,
          },
        },
      },
    });

Future<int> _alphaAt(WidgetTester tester, bool scale, Offset at) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(100, 100);
  addTearDown(tester.view.reset);
  final tree = NodeTree(DocumentSource(_doc(scale)));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'canvas'))),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data;
  }))!;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  final i = (at.dy.toInt() * 100 + at.dx.toInt()) * 4;
  // The stroke on a transparent background: its alpha.
  return bytes.getUint8(i + 3);
}

// strokePath.fillColor fills the shape its points enclose, behind the line
// (a hand-drawn box with its own wobble), fading in as the line draws.

Map<String, Object?> _strokeBox({double progress = 1, String? fill = '#FFFF0000'}) => {
      'points': [[10, 10], [90, 12], [88, 50], [12, 48]],
      'xUnit': 'pixels',
      'yUnit': 'pixels',
      'color': '#FF000000',
      'width': 2,
      'progress': progress,
      'fillColor': ?fill,
    };

/// A box of [size] with 30.0.0's stroke path [strokePath], as a schema-2
/// document loads it (migrated to its custom paint op), drawn by a running app's
/// binder (a migrated line's fractions of the box are formulas of its size).
Future<RenderRepaintBoundary> _showStroke(WidgetTester tester, Map<String, Object?> strokePath, Size size) =>
    _showNode(tester, {'type': 'box', 'layout': {'width': size.width, 'height': size.height}, 'strokePath': strokePath}, size);

/// [node] (30.0.0's spellings) in a schema-2 document of its own, loaded
/// (migrated) and drawn at [size] by a running app's binder.
Future<RenderRepaintBoundary> _showNode(WidgetTester tester, Map<String, Object?> node, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final doc = LayoutDocument.fromJson({
    'schema': 2,
    'roots': ['n'],
    'nodes': {'n': node},
  });
  final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: VariableScope(const [])));
  addTearDown(tree.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'n'))),
  ));
  return key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
}

/// The RGBA of each of [at] in what [boundary] draws.
Future<List<int>> _pixels(WidgetTester tester, RenderRepaintBoundary boundary, List<Offset> at) async {
  final width = boundary.size.width.toInt();
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  }))!;
  return [for (final p in at) ...[for (var c = 0; c < 4; c++) bytes.getUint8((p.dy.toInt() * width + p.dx.toInt()) * 4 + c)]];
}

/// Every RGBA byte of what [boundary] draws.
Future<List<int>> _image(WidgetTester tester, RenderRepaintBoundary boundary) async {
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  }))!;
  return bytes.buffer.asUint8List().toList();
}

/// Every RGBA byte of [path] stroked as a migrated stroke path's default
/// line (4 px, white, round caps and joins) on a transparent [size].
Future<List<int>> _stroked(WidgetTester tester, Path path, Size size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
  final picture = recorder.endRecording();
  final bytes = (await tester.runAsync(() async {
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  }))!;
  picture.dispose();
  return bytes.buffer.asUint8List().toList();
}

/// [path]'s first [share] of its length.
Path _head(Path path, double share) {
  final m = path.computeMetrics().single;
  return m.extractPath(0, m.length * share);
}

// Painting and islands of the media group: image fills, SVG paths (the
// `path` widget and a box's path), icons, and the players' islands.

Map<String, Object?> _doc2(Map<String, Object?> nodes, {double w = 300, double h = 200}) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': [for (final k in nodes.keys) k], 'layout': {'width': w, 'height': h}},
        ...nodes,
      },
    };

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> json, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(json)));
  await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive))));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return tree;
}

// Runtime of the widgets area's features.

Future<(NodeTree, RenderObject)> show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root,
    {double width = 800, double height = 600}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

/// The render objects of type [T] under [root].
List<T> renderOf<T>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o as T);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

Map<String, Object?> box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

void main() {
  group('stroke width of a scaled path', () {
    testWidgets('a path that scales its stroke draws a 1-unit line 10 px thick at ten times its size', (tester) async {
      expect(await _alphaAt(tester, true, const Offset(50, 53)), greaterThan(200));
    });

    testWidgets('a path that does not scale its stroke keeps it 1 px thick', (tester) async {
      expect(await _alphaAt(tester, false, const Offset(50, 53)), lessThan(40));
    });
  });

  group('a path drawn along its points', () {
    testWidgets('migrated to a custom paint, a drawn path with a fill color paints its inside and leaves its outside clear', (tester) async {
      final b = await _showStroke(tester, _strokeBox(), const Size(100, 60));
      final px = await _pixels(tester, b, const [Offset(50, 30), Offset(5, 5), Offset(95, 55)]);
      expect(px.sublist(0, 4), [255, 0, 0, 255], reason: 'inside');
      expect(px[7], 0, reason: 'outside, top left');
      expect(px[11], 0, reason: 'outside, bottom right');
    });

    testWidgets('migrated to Path calls, curved segments read their points in pairs: a control point and an end point', (tester) async {
      const size = Size(200, 200);
      final b = await _showStroke(tester, {
        'points': [[0, 100], [50, 200], [100, 100], [150, 0], [200, 100]],
        'xUnit': 'pixels',
        'curve': 'quadratic',
      }, size);
      final want = Path()
        ..moveTo(0, 100)
        ..quadraticBezierTo(50, 200, 100, 100)
        ..quadraticBezierTo(150, 0, 200, 100);
      // Through (50, 150) at the first curve's middle, not the control point.
      final m = want.computeMetrics().first;
      final mid = m.getTangentForOffset(m.length / 4)!.position;
      expect(mid.dx, closeTo(50, 0.5));
      expect(mid.dy, closeTo(150, 0.5));
      expect(await _image(tester, b), await _stroked(tester, want, size));
    });

    testWidgets('migrated to a trimmed path op, a partly drawn stroke, solid or dashed, paints nothing past where it has reached', (tester) async {
      for (final dash in [<double>[], <double>[8, 4]]) {
        final b = await _showStroke(tester, {
          'points': [[0, 10], [1, 10]],
          'color': '#FFFFFFFF',
          'width': 2,
          'cap': 'butt',
          'progress': .5,
          'dashPattern': dash,
        }, const Size(100, 20));
        final px = await _pixels(tester, b, const [Offset(4, 10), Offset(75, 10)]);
        expect(px[3], greaterThan(0));
        expect(px[7], 0);
      }
    });

    testWidgets('migrated to a trimmed path op, a partly drawn stroke measures its progress along the path\'s length, curves included', (tester) async {
      const size = Size(100, 40);
      // The line through (0, 0), (30, 30), (100, 10) as each curve joins it.
      final lines = {
        'straight': Path()
          ..moveTo(0, 0)
          ..lineTo(30, 30)
          ..lineTo(100, 10),
        'vertical': Path()
          ..moveTo(0, 0)
          ..cubicTo(0, 15, 30, 15, 30, 30)
          ..cubicTo(30, 20, 100, 20, 100, 10),
        'horizontal': Path()
          ..moveTo(0, 0)
          ..cubicTo(15, 0, 15, 30, 30, 30)
          ..cubicTo(65, 30, 65, 10, 100, 10),
        'quadratic': Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(30, 30, 100, 10),
      };
      for (final MapEntry(key: curve, value: line) in lines.entries) {
        Future<List<int>> drawn(double p) async => _image(tester, await _showStroke(tester, {
              'points': [[0, 0], [.3, 30], [1, 10]],
              'curve': curve,
              'progress': p,
            }, size));
        expect(await drawn(.5), await _stroked(tester, _head(line, .5), size), reason: curve);
        expect((await drawn(0)).every((b) => b == 0), isTrue, reason: curve);
      }
    });

  });

  group('path nodes', () {

    test('an SVG path parses and trims', () {
      expect(parseSvgPath(''), isNull);
      expect(parseSvgPath('M0 0 L'), isNull);
      final line = parseSvgPath('M0 0 H100')!;
      expect(line.getBounds(), const Rect.fromLTRB(0, 0, 100, 0));
      expect(trimPath(line, 0.25, 0.5).getBounds(), const Rect.fromLTRB(25, 0, 50, 0));
    });

    testWidgets('a path fills and strokes its shape, scaled from its view box', (tester) async {
      final tree = await _show(tester, _doc2({
        'p': {
          'type': 'path',
          'layout': {'width': 100, 'height': 100, 'x': {'start': 10}, 'y': {'start': 10}},
          'decoration': {
            'fills': [{'color': '#FFFF0000'}],
            'strokes': [{'color': '#FF0000FF'}],
            'strokeWidth': 2,
          },
          'props': {'data': 'M0 0 H10 V10 H0 Z', 'viewBox': [10, 10]},
        },
      }));
      expect(tree.boxOf('p')!.rectIn(tester.renderObject(find.byType(NodeView))), const Rect.fromLTWH(10, 10, 100, 100));
      expect(
          tree.boxOf('p')!,
          paints
            ..path(color: const Color(0xFFFF0000), includes: const [Offset(50, 50), Offset(95, 95)], excludes: const [Offset(105, 50)])
            ..path(color: const Color(0xFF0000FF), style: PaintingStyle.stroke, strokeWidth: 2));
    });

    testWidgets('a box shaped by a path is a path node: it fills inside the path and strokes along it, unclipped', (tester) async {
      final tree = await _show(tester, _doc2({
        'b': {
          'type': 'box',
          'layout': {'width': 100, 'height': 100},
          'decoration': {
            'fills': [{'color': '#FFFF0000'}],
            'strokes': [{'color': '#FF000000'}],
            'strokeWidth': 4,
            'clip': 'hardEdge',
            'effects': [{'type': 'dropShadow', 'color': '#FF000000', 'blurRadius': 4}],
          },
          'props': {'path': 'M0 0 L100 0 L0 100 Z', 'strokeJoin': 'round'},
        },
      }));
      expect((tree.source as DocumentSource).document.nodes['b']!.type, 'path');
      final shape = renderOf<RenderShapePath>(tree.boxOf('b')!).single;
      expect(shape, isNot(paints..something((m, _) => m == #drawShadow || m == #clipRect || m == #clipPath)));
      expect(
          shape,
          paints
            ..path(color: const Color(0xFF000000))
            ..path(color: const Color(0xFF000000), style: PaintingStyle.stroke, strokeWidth: 4)
            ..path(color: const Color(0xFFFF0000), includes: const [Offset(10, 10)], excludes: const [Offset(90, 90)])
            ..path(color: const Color(0xFF000000), style: PaintingStyle.stroke, strokeWidth: 4));
    });

    // With shadows the per-shape colors have no exact custom paint form: the
    // migration keeps them as `legacy.props.subpathColors` and reports it.
    testWidgets('a path\'s shapes colored in turn are custom paint path ops, each color times the fill\'s alpha', (tester) async {
      final b = await _showNode(tester, {
        'type': 'path',
        'layout': {'width': 30, 'height': 10},
        'props': {
          'data': 'M0 0 H10 V10 H0 Z M20 0 H30 V10 H20 Z',
          'subpathColors': ['#FFFF0000', '#FF0000FF'],
        },
        'decoration': {'fills': [{'color': '#80FFFFFF'}]},
      }, const Size(30, 10));
      final px = await _pixels(tester, b, const [Offset(5, 5), Offset(15, 5), Offset(25, 5)]);
      expect(px.sublist(0, 4), [128, 0, 0, 128], reason: 'the first shape');
      expect(px.sublist(4, 8), [0, 0, 0, 0], reason: 'between the shapes');
      expect(px.sublist(8, 12), [0, 0, 128, 128], reason: 'the second shape');
    });

    testWidgets('a per-shape gradient is a custom paint path op per shape, laid out in that shape', (tester) async {
      final b = await _showNode(tester, {
        'type': 'path',
        'layout': {'width': 30, 'height': 10},
        'props': {'data': 'M0 0 H10 V10 H0 Z M20 0 H30 V10 H20 Z'},
        'decoration': {
          'fills': [
            {'type': 'linear', 'gradientPerSubpath': true, 'stops': [
              {'position': 0, 'color': '#FF000000'}, {'position': 1, 'color': '#FFFFFFFF'}]},
          ],
        },
      }, const Size(30, 10));
      final px = await _pixels(tester, b, const [Offset(0, 5), Offset(9, 5), Offset(20, 5), Offset(29, 5)]);
      // Each shape runs from dark at its left to light at its right.
      expect(px[0], lessThan(30));
      expect(px[4], greaterThan(220));
      expect(px[8], lessThan(30));
      expect(px[12], greaterThan(220));
    });
  });

}
