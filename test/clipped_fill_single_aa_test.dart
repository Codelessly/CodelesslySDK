// A rounded node that clips itself (antiAlias) and paints its fills in a
// layer (more than one fill) anti-aliases its edge once, as Flutter's
// ClipRRect around a filled box does: its rounded corners at a fractional
// position match the reference's, not fainter.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _column(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(color: Colors.black, padding: const EdgeInsets.only(top: 10.5, left: 10), width: 120, height: 80, child: child),
      ),
    ),
  ));
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  // The red channel, every pixel.
  return [for (var i = 0; i < 120 * 80; i++) data.getUint8(i * 4)];
}

void main() {
  testWidgets('a self-clipped layered fill anti-aliases its edge once', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.reset);
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['b'],
      'nodes': {
        'b': {
          'type': 'box',
          'layout': {'width': 100, 'height': 50},
          'decoration': {
            'radius': 6,
            'clip': 'antiAlias',
            // Two fills: painted in a layer, not as a native decoration.
            'fills': [
              {'color': '#FFFF0000'},
              {'type': 'linear', 'stops': [{'position': 0, 'color': '#00000000'}, {'position': 1, 'color': '#00000000'}]},
            ],
          },
        },
      },
    })));
    final sdk = await _column(tester, NodeView(tree: tree, rootId: 'b'));
    tree.dispose();
    final ref = await _column(
      tester,
      ClipRRect(borderRadius: BorderRadius.circular(6), child: const SizedBox(width: 100, height: 50, child: ColoredBox(color: Color(0xFFFF0000)))),
    );
    var worst = 0;
    for (var i = 0; i < sdk.length; i++) {
      final d = (sdk[i] - ref[i]).abs();
      if (d > worst) worst = d;
    }
    // ignore: avoid_print
    print('largest difference $worst');
    expect(worst, lessThanOrEqualTo(3));
  });
}
