import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart';
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

Future<List<int>> _rgbaAt(WidgetTester tester, api.StrokePath path, List<Offset> at) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(key: key, child: CustomPaint(size: const Size(100, 60), painter: StrokePathPainter(path))),
    ),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  }))!;
  return [for (final p in at) ...[for (var c = 0; c < 4; c++) bytes.getUint8((p.dy.toInt() * 100 + p.dx.toInt()) * 4 + c)]];
}

api.StrokePath _box({double progress = 1, String? fill = '#FFFF0000'}) => api.StrokePath.fromJson({
      'points': [[10, 10], [90, 12], [88, 50], [12, 48]],
      'xUnit': 'pixels',
      'yUnit': 'pixels',
      'color': '#FF000000',
      'width': 2,
      'progress': progress,
      'fillColor': ?fill,
    })!;

// PathCurve.quadratic: after the first point, (control, end) pairs drawn
// with quadraticBezierTo, so a hand-drawn outline matches a painter's
// curves exactly instead of a polyline sampled from them.

Path _path(List<api.Offset> points) => StrokePathPainter(api.StrokePath(
      points: points,
      xUnit: api.PathUnit.pixels,
      yUnit: api.PathUnit.pixels,
      curve: api.PathCurve.quadratic,
    )).pathFor(const Size(200, 200));

double _length(Path p) => p.computeMetrics().fold(0.0, (l, m) => l + m.length);

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
    testWidgets('a drawn path with a fill color paints its inside and leaves its outside clear', (tester) async {
      final px = await _rgbaAt(tester, _box(), const [Offset(50, 30), Offset(5, 5), Offset(95, 55)]);
      expect(px.sublist(0, 4), [255, 0, 0, 255], reason: 'inside');
      expect(px[7], 0, reason: 'outside, top left');
      expect(px[11], 0, reason: 'outside, bottom right');
    });

    test('curved segments read their points in pairs: a control point and an end point', () {
      final got = _path(const [api.Offset(0, 0), api.Offset(50, 100), api.Offset(100, 0), api.Offset(150, -100), api.Offset(200, 0)]);
      final want = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(50, 100, 100, 0)
        ..quadraticBezierTo(150, -100, 200, 0);
      expect(_length(got), closeTo(_length(want), 1e-6));
      // Through (50, 50) at the first curve's middle, not the control point.
      final m = got.computeMetrics().first;
      final mid = m.getTangentForOffset(m.length / 4)!.position;
      expect(mid.dx, closeTo(50, 0.5));
      expect(mid.dy, closeTo(50, 0.5));
    });

    test(
      'a partly drawn stroke, solid or dashed, paints nothing past where it has reached',
      () async {
        for (final dash in [
          <double>[],
          <double>[8, 4],
        ]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          StrokePathPainter(
            api.StrokePath(
              points: const [api.Offset(0, 10), api.Offset(1, 10)],
              color: api.Color.white,
              width: 2,
              cap: api.StrokeCap.butt,
              progress: .5,
              dashPattern: dash,
            ),
          ).paint(canvas, const Size(100, 20));
          final picture = recorder.endRecording();
          final image = await picture.toImage(100, 20);
          final bytes = (await image.toByteData())!;
          expect(bytes.getUint8((10 * 100 + 4) * 4 + 3), greaterThan(0));
          expect(bytes.getUint8((10 * 100 + 75) * 4 + 3), 0);
          image.dispose();
          picture.dispose();
        }
      },
    );
  

    test('a partly drawn stroke measures its progress along the path\'s length, curves included', () {
      for (final curve in api.PathCurve.values) {
        StrokePathPainter painter(double p) => StrokePathPainter(
          api.StrokePath(
            points: const [
              api.Offset(0, 0),
              api.Offset(.3, 30),
              api.Offset(1, 10),
            ],
            curve: curve,
            progress: p,
          ),
        );
        final full = painter(1)
            .pathFor(const Size(100, 40))
            .computeMetrics()
            .fold(0.0, (double sum, m) => sum + m.length);
        final half = painter(.5)
            .visiblePathFor(const Size(100, 40))
            .computeMetrics()
            .fold(0.0, (double sum, m) => sum + m.length);
        expect(half, closeTo(full * .5, 0.3));
        expect(
          painter(0).visiblePathFor(const Size(100, 40)).computeMetrics(),
          isEmpty,
        );
      }
    });
  
  });

  group('path nodes', () {

    test('an SVG path parses, trims and dashes', () {
      expect(parseSvgPath(''), isNull);
      expect(parseSvgPath('M0 0 L'), isNull);
      final line = parseSvgPath('M0 0 H100')!;
      expect(line.getBounds(), const Rect.fromLTRB(0, 0, 100, 0));
      expect(trimPath(line, 0.25, 0.5).getBounds(), const Rect.fromLTRB(25, 0, 50, 0));
      final dashed = dashPath(line, 10, 30);
      expect(dashed.computeMetrics().length, 3);
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

    testWidgets('a box shaped by a path fills inside the path and strokes along it', (tester) async {
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
      final box = tree.boxOf('b')!;
      expect(box, isNot(paints..something((m, _) => m == #drawShadow || m == #clipRect)));
      expect(
          box,
          paints
            ..clipPath(pathMatcher: isPathThat(includes: const [Offset(10, 10)], excludes: const [Offset(90, 90)]))
            ..rrect(color: const Color(0xFFFF0000))
            ..path(color: const Color(0xFF000000), style: PaintingStyle.stroke, strokeWidth: 4));
    });

    testWidgets('a path colors its shapes in turn and casts its shadow', (tester) async {
      final (_, root) = await show(tester, {
        'p': {
          'type': 'path',
          'layout': {'width': 30, 'height': 10},
          'props': {
            'data': 'M0 0 H10 V10 H0 Z M20 0 H30 V10 H20 Z',
            'subpathColors': ['#FFFF0000', '#FF0000FF'],
          },
          'decoration': {
            'fills': [{'color': '#80FFFFFF'}],
            'effects': [{'type': 'dropShadow', 'color': '#40000000', 'blurRadius': 2}],
          },
        },
      }, 'p');
      final shape = renderOf<RenderShapePath>(root).single;
      expect(
          shape,
          paints
            ..path(color: const Color(0x40000000))
            ..path(color: const Color(0x80FF0000))
            ..path(color: const Color(0x800000FF)));
    });

    testWidgets('a per-shape gradient is laid out in each shape', (tester) async {
      final (_, root) = await show(tester, {
        'p': {
          'type': 'path',
          'layout': {'width': 30, 'height': 10},
          'props': {'data': 'M0 0 H10 V10 H0 Z M20 0 H30 V10 H20 Z'},
          'decoration': {
            'fills': [
              {'type': 'linear', 'gradientPerSubpath': true, 'stops': [
                {'position': 0, 'color': '#FF000000'}, {'position': 1, 'color': '#FFFFFFFF'}]},
            ],
          },
        },
      }, 'p');
      final shape = renderOf<RenderShapePath>(root).single;
      // Each shape drawn at the origin of its own box, moved to it.
      expect(shape, paints..save()..translate(x: 0, y: 0)..path()..restore()..save()..translate(x: 20, y: 0)..path());
    });
  
  });

}
