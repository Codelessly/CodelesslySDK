// A box ruled on one side paints as Flutter's Border(bottom: ...): the rule
// runs the box's whole width (the ends were half a stroke short).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final side in ['bottom', 'left']) {
    testWidgets('a $side rule paints like a Container border', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['b'],
        'nodes': {
          'b': {
            'type': 'box', 'layout': {'width': 40, 'height': 20},
            'decoration': {'fills': [{'color': '#FFFFFFFF'}], 'strokes': [{'color': '#FF000000'}], 'strokeWidth': 1.4, 'strokeSides': side},
          },
        },
      });
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
      addTearDown(tree.dispose);
      const s = BorderSide(width: 1.4);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Align(alignment: Alignment.topLeft, child: Column(children: [
        RepaintBoundary(key: const Key('sdk'), child: ColoredBox(color: const Color(0xFF808080), child: Padding(padding: const EdgeInsets.all(4), child: NodeView(tree: tree, rootId: 'b')))),
        RepaintBoundary(key: const Key('flutter'), child: ColoredBox(color: const Color(0xFF808080), child: Padding(padding: const EdgeInsets.all(4),
            child: Container(width: 40, height: 20, decoration: BoxDecoration(color: const Color(0xFFFFFFFF),
                border: side == 'bottom' ? const Border(bottom: s) : const Border(left: s)))))),
      ]))));
      await tester.pump();
      Future<Uint8List> shot(String k) async {
        late Uint8List bytes;
        await tester.runAsync(() async {
          final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(Key(k))).toImage(pixelRatio: 2);
          bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        });
        return bytes;
      }
      expect(await shot('sdk'), await shot('flutter'));
    });
  }
}
