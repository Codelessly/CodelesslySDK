// A fixed-size stack child pinned to both edges stretches between them
// too: Wireless's tablet rail (a column 900 tall at design size, pinned
// top and bottom, a fill spacer above its last button) stopped at 900 on
// a taller screen, its button three-quarters of the way down.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _doc() => LayoutDocument.fromJson({
      'roots': ['canvas'],
      'nodes': {
        'canvas': {
          'type': 'canvas',
          'slots': {'body': 'root'},
          'layout': {'width': 834, 'height': 900},
        },
        'root': {
          'type': 'stack',
          'children': ['rail'],
          'layout': {'width': {'fill': 834}, 'height': {'fill': 900}},
        },
        'rail': {
          'type': 'column',
          'children': ['spacer', 'button'],
          'layout': {'width': 92, 'height': 900, 'y': {'start': 0, 'end': 0}},
        },
        'spacer': {
          'type': 'row',
          'layout': {'width': 10, 'height': {'fill': 862}},
        },
        'button': {
          'type': 'box',
          'layout': {'width': 38, 'height': 38},
        },
      },
    });

void main() {
  for (final height in [1194.0, 700.0]) {
    testWidgets('a fixed-size child pinned to both edges stretches between them ($height tall)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(834, height);
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(_doc()));
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'canvas', interactive: true)));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
      });
      final view = tester.renderObject(find.byType(NodeView));
      expect(tree.boxOf('rail')!.rectIn(view), Rect.fromLTWH(0, 0, 92, height));
      expect(tree.boxOf('button')!.rectIn(view)!.bottom, height);
    });
  }
}
