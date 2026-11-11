// A slider drawn as a drafting ruler (trackShape: ruler) with a pointer
// thumb: the ruler spans the whole width, so a tap at a fraction of the
// width is that fraction of the range; the fill runs from zero.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<NodeTree> show(WidgetTester tester, {double value = 5}) async {
    final doc = LayoutDocument.fromJson({'roots': ['s'], 'nodes': {
      's': {'type': 'slider', 'layout': {'width': 200, 'height': 30}, 'props': {
        'min': -10, 'max': 10, 'value': value, 'trackShape': 'ruler', 'thumbShape': 'pointer', 'padding': 0,
        'activeTrackColor': '#FFFF0000', 'inactiveTrackColor': '#FFFFFFFF', 'thumbColor': '#FF0000FF',
        'overlayColor': '#00000000', 'rulerTickColor': '#FF000000',
      }},
    }});
    final tree = NodeTree(NodeValues(DocumentSource(doc)));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
        child: RepaintBoundary(key: const ValueKey('b'), child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pump();
    return tree;
  }

  testWidgets('a tap at three quarters of the ruler is three quarters of the range', (tester) async {
    await show(tester);
    await tester.tapAt(const Offset(150, 15));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(5, 0.2));
    await tester.tapAt(const Offset(1, 15));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(-10, 0.2));
  });

  testWidgets('ticks on the baseline, the fill from zero, the pointer under the value', (tester) async {
    await show(tester, value: 5);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('b')));
    late ByteData bytes;
    late int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    Color at(int x, int y) {
      final i = (y * width + x) * 4;
      return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    }

    // The baseline is at y = 16; a long tick rises from it at x = 50 (−5).
    final tick = [for (var x = 49; x <= 51; x++) at(x, 10).r * 255].reduce((a, b) => a < b ? a : b);
    expect(tick, lessThan(100), reason: 'a long tick at x ≈ 50');
    expect(at(60, 10).r * 255, greaterThan(200), reason: 'no tick between');
    // Fill from zero (x = 100) to the value (x = 150), just under the baseline.
    expect(at(125, 18), const Color(0xFFFF0000));
    expect(at(80, 18), isNot(const Color(0xFFFF0000)));
    // The pointer's triangle under the value.
    expect(at(150, 25), const Color(0xFF0000FF));
  });
}
