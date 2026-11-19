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
      'schema': 3,
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

// Painting and islands of the media group: image fills, SVG paths (the
// `path` widget and a box's path), icons, and the players' islands.

Map<String, Object?> _doc2(Map<String, Object?> nodes, {double w = 300, double h = 200}) => {
      'schema': 3,
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
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'schema': 3, 'roots': [root], 'nodes': nodes})));
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

  });

}
