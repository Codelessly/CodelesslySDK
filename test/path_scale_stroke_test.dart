// `scaleStroke`: a path's stroke in its viewBox's units grows with the
// drawing, as in SVG (Strata v2's figures are drawn in 320x180 and shown
// wider; their lines thickened with them in the reference). Without it the
// stroke stays in the box's pixels.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/path_paint.dart' show pathStrokeScale;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  test('the stroke scale: the mean of the two scales, or 1', () {
    expect(pathStrokeScale(const Size(320, 180), const Size(640, 360), scaleStroke: true), 2);
    expect(pathStrokeScale(const Size(10, 10), const Size(40, 10), scaleStroke: true), 2);
    expect(pathStrokeScale(const Size(320, 180), const Size(640, 360), scaleStroke: false), 1);
    expect(pathStrokeScale(null, const Size(640, 360), scaleStroke: true), 1);
  });

  testWidgets('scaled, a 1-unit line in a 10-unit viewBox at 100 px is 10 px thick', (tester) async {
    expect(await _alphaAt(tester, true, const Offset(50, 53)), greaterThan(200));
  });

  testWidgets('not scaled, it stays 1 px thick', (tester) async {
    expect(await _alphaAt(tester, false, const Offset(50, 53)), lessThan(40));
  });
}
