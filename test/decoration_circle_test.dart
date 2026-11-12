// A decoration shaped as a circle paints as Flutter's BoxShape.circle: its
// fill and its stroke as circles (drawCircle), not a rounded rectangle; at a
// fractional position pixel for pixel a painter's two drawCircle calls.
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Dot extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFFE8772E));
    canvas.drawCircle(c, 5.5, Paint()
      ..color = const Color(0xFF2A1C10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(_Dot old) => false;
}

Future<List<int>> _shot(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(color: Colors.white, width: 30, height: 30, padding: const EdgeInsets.only(left: 7.3, top: 8.6), alignment: Alignment.topLeft, child: child),
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
  return [for (var i = 0; i < 30 * 30 * 4; i++) data.getUint8(i)];
}

void main() {
  testWidgets('a circle decoration paints as drawCircle', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(200, 200);
    addTearDown(tester.view.reset);
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['b'],
      'nodes': {
        'b': {
          'type': 'box',
          'layout': {'width': 11, 'height': 11},
          'decoration': {
            'shape': 'circle',
            'fills': [
              {'color': '#FFE8772E'},
            ],
            'strokes': [
              {'color': '#FF2A1C10'},
            ],
            'strokeWidth': 1.4,
            'strokeAlign': 'center',
          },
        },
      },
    })));
    final sdk = await _shot(tester, NodeView(tree: tree, rootId: 'b'));
    tree.dispose();
    final ref = await _shot(tester, SizedBox(width: 11, height: 11, child: CustomPaint(painter: _Dot())));
    var worst = 0;
    for (var i = 0; i < sdk.length; i++) {
      final d = (sdk[i] - ref[i]).abs();
      if (d > worst) worst = d;
    }
    expect(worst, lessThanOrEqualTo(1));
  });

  test('shape round-trips', () {
    const d = api.Decoration(shape: api.DecorationShape.circle);
    expect(api.Decoration.fromJson(d.toJson()).shape, api.DecorationShape.circle);
    expect(api.Decoration.fromJson(const api.Decoration().toJson()).shape, api.DecorationShape.rectangle);
  });
}
