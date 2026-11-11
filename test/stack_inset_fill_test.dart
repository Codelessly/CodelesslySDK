// A stack child pinned to both edges (`{"start": a, "end": b}`) stretches
// between them (DESIGN.md §3), whatever its size mode says: the Strata v2
// photo viewer's drag area (y 64 → 128 from the bottom, height fill) was laid
// out at the top, the screen's full height.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _doc(Map<String, Object?> height) => LayoutDocument.fromJson({
      'roots': ['canvas'],
      'nodes': {
        'canvas': {
          'type': 'canvas',
          'slots': {'body': 'root'},
          'layout': {'width': 390, 'height': 844},
        },
        'root': {
          'type': 'stack',
          'children': ['viewer'],
          'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        },
        'viewer': {
          'type': 'stack',
          'children': ['area'],
          'layout': {'width': {'fill': 100}, 'height': {'fill': 100}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
        },
        'area': {
          'type': 'stack',
          'children': ['photo'],
          'layout': {'width': {'fill': 100}, 'height': height, 'x': {'start': 0, 'end': 0}, 'y': {'start': 64, 'end': 128}},
        },
        'photo': {
          'type': 'box',
          'layout': {'width': 100, 'height': 100, 'x': {'align': 0}, 'y': {'align': 0}},
        },
      },
    });

void main() {
  for (final height in [
    {'fill': 652},
    {'fill': 100},
  ]) {
    testWidgets('pinned to both edges stretches between them (height $height)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final doc = _doc(height);
      final tree = NodeTree(DocumentSource(doc));
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'canvas', interactive: true)));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
      });
      final view = tester.renderObject(find.byType(NodeView));
      expect(tree.boxOf('area')!.rectIn(view), const Rect.fromLTWH(0, 64, 390, 652));
      expect(tree.boxOf('photo')!.rectIn(view)!.center, const Offset(195, 64 + 326));
    });
  }
}
