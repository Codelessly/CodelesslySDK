import 'dart:typed_data';
import 'dart:ui' as ui;

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
}
