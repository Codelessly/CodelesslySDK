// A text node paints its glyphs (and glow shadow) pixel for pixel as
// Flutter's Text does in the reference app's setting (a WidgetsApp whose
// DefaultTextStyle is the body).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

void main() {
  for (final shadow in [false, true]) {
    testWidgets('a text paints as Flutter\'s Text${shadow ? ', with a glow' : ''}', (tester) async {
      final bytes = File('../references/lantern_v2/assets/fonts/IMFellEnglishSC-Regular.ttf').readAsBytesSync();
      await tester.runAsync(() => (FontLoader('FellSCP')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))))).load());
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['t'],
        'nodes': {
          't': {'type': 'text', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
                'props': {'text': 'Lantern', 'style': {'fontSize': 58, 'letterSpacing': 3, 'fontFamily': 'FellSCP', 'height': 1.1, 'color': '#FFE9D9B4',
                  if (shadow) 'shadows': [{'type': 'dropShadow', 'color': '#99FFB54A', 'offset': [0, 0], 'blurRadius': 24}]}}},
        },
      })));
      addTearDown(tree.dispose);
      final a = GlobalKey(), b = GlobalKey();
      // As the reference app: a WidgetsApp whose DefaultTextStyle is the body.
      await tester.pumpWidget(WidgetsApp(color: const Color(0xFF000000), textStyle: const TextStyle(fontFamily: 'FellSCP', fontSize: 17, height: 1.45),
          builder: (context, _) => DefaultTextStyle(style: const TextStyle(fontFamily: 'FellSCP', fontSize: 17, height: 1.45, color: Color(0xFF2A1C10)), child: ColoredBox(color: const Color(0xFF2A1C10), child: Align(alignment: Alignment.topLeft, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(key: a, child: SizedBox(width: 300, height: 80, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't')))),
          RepaintBoundary(key: b, child: SizedBox(width: 300, height: 80, child: Align(alignment: Alignment.topLeft, child: Text('Lantern',
              style: TextStyle(fontSize: 58, letterSpacing: 3, fontFamily: 'FellSCP', height: 1.1, color: const Color(0xFFE9D9B4),
                  shadows: shadow ? const [Shadow(color: Color(0x99FFB54A), blurRadius: 24)] : null))))),
        ],
      ))))));
      final pa = await _pixels(tester, a), pb = await _pixels(tester, b);
      var differ = 0;
      for (var i = 0; i < pa.length; i += 4) {
        if ((pa[i] - pb[i]).abs() > 40 || (pa[i + 1] - pb[i + 1]).abs() > 40 || (pa[i + 2] - pb[i + 2]).abs() > 40) differ++;
      }
      expect(differ, 0);
    });
  }
}
