// A radial gradient's `radius` (a share of the box's shortest side, as
// Flutter's RadialGradient) instead of the transform's reach to the box's
// edge across its width: a landscape box's vignette darkens as Flutter's.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _doc(double? radius) => LayoutDocument.fromJson({
      'roots': ['canvas'],
      'nodes': {
        'canvas': {'type': 'canvas', 'slots': {'body': 'box'}, 'layout': {'width': 200, 'height': 100}},
        'box': {
          'type': 'box',
          'layout': {'width': 200, 'height': 100},
          'decoration': {
            'fills': [
              {
                'type': 'radial',
                'radius': ?radius,
                'stops': [
                  {'position': 0, 'color': '#00000000'},
                  {'position': 1, 'color': '#FF000000'},
                ],
              },
            ],
          },
        },
      },
    });

Future<int> _alphaAt(WidgetTester tester, double? radius, Offset at) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(200, 100);
  addTearDown(tester.view.reset);
  final tree = NodeTree(DocumentSource(_doc(radius)));
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
  return bytes.getUint8((at.dy.toInt() * 200 + at.dx.toInt()) * 4 + 3);
}

void main() {
  testWidgets('radius is a share of the shortest side; without it the gradient spans half the width', (tester) async {
    // 50 px right of the center: the whole radius at 0.5 (half the 100 px
    // tall box, Flutter's default), half of the 100 px the transform's
    // radius reaches.
    final withRadius = await _alphaAt(tester, 0.5, const Offset(150, 50));
    final without = await _alphaAt(tester, null, const Offset(150, 50));
    expect(withRadius, greaterThan(240));
    expect(without, inInclusiveRange(100, 155));
  });
}
