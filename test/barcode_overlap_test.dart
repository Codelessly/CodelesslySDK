import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as bc;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The darkness (0..255 per pixel, summed by column) of a barcode node
/// drawn black on white, and the image width.
Future<(int, List<int>)> _columns(WidgetTester tester, Map<String, Object?> props, {double width = 101, double height = 40}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['n'],
    'nodes': {
      'n': {'type': 'barcode', 'layout': {'width': width, 'height': height}, 'props': props},
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: ColoredBox(color: Colors.white, child: NodeView(tree: tree, rootId: 'n'))))));
  late (int, List<int>) out;
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    final ByteData data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final cols = List<int>.filled(img.width, 0);
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        cols[x] += 255 - data.getUint8((y * img.width + x) * 4);
      }
    }
    out = (img.width, cols);
  });
  tree.dispose();
  return out;
}

void main() {
  testWidgets('overlap widens each dark bar to the right; 0 keeps the exact bars', (tester) async {
    const props = {'data': 'DL-424973', 'symbology': 'code128', 'drawText': false};
    final (w, exact) = await _columns(tester, props);
    final (_, overlapped) = await _columns(tester, {...props, 'overlap': 0.4});
    int sum(List<int> c) => c.fold<int>(0, (a, b) => a + b);
    // More ink, and only where a bar's right edge meets light: the first
    // dark column (a left edge) is the same.
    expect(sum(overlapped), greaterThan(sum(exact)));
    final firstDark = exact.indexWhere((c) => c > 0);
    expect(overlapped.indexWhere((c) => c > 0), firstDark);
    expect(overlapped[firstDark], exact[firstDark]);
    expect(w, 101);
  });

  testWidgets('overlap applies to QR modules too', (tester) async {
    const props = {'data': 'DL-424973', 'errorCorrection': 'low'};
    final (_, exact) = await _columns(tester, props, width: 107, height: 107);
    final (_, overlapped) = await _columns(tester, {...props, 'overlap': 0.4}, width: 107, height: 107);
    expect(overlapped.fold<int>(0, (a, b) => a + b), greaterThan(exact.fold<int>(0, (a, b) => a + b)));
  });

  testWidgets('with overlap a code draws exactly as Flutter code drawing it rect by rect', (tester) async {
    const data = 'DL-424973';
    const w = 264.0, h = 39.0;
    Future<List<int>> pixels(Widget child) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(key: key, child: ColoredBox(color: Colors.white, child: child)))));
      late List<int> out;
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List().toList();
      });
      return out;
    }

    final doc = LayoutDocument.fromJson({
      'roots': ['n'],
      'nodes': {
        'n': {
          'type': 'barcode',
          'layout': {'width': w, 'height': h},
          'props': {'data': data, 'symbology': 'code128', 'drawText': false, 'overlap': 0.4, 'color': '#FF0E0E10'},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    final node = await pixels(NodeView(tree: tree, rootId: 'n'));
    tree.dispose();
    final reference = await pixels(SizedBox(width: w, height: h, child: CustomPaint(painter: _RectByRect(data))));
    expect(node, reference);
  });
}

/// A Code 128 drawn the way app code commonly draws one: each bar a rect,
/// a hair wider and taller so neighbours overlap.
class _RectByRect extends CustomPainter {
  _RectByRect(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0E0E10);
    for (final e in bc.Barcode.code128().make(data, width: size.width, height: size.height, drawText: false)) {
      if (e is bc.BarcodeBar && e.black) canvas.drawRect(Rect.fromLTWH(e.left, e.top, e.width + 0.4, e.height + 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_RectByRect old) => false;
}
