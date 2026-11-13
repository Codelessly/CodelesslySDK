// A spacer with no size along its row's or column's main axis is Flutter's
// Spacer(): it takes the free space (by its flex), as Expanded(flex: 1).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final row in [true, false]) {
    testWidgets('in a ${row ? 'row' : 'column'}, as Flutter\'s Spacer', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 800);
      addTearDown(tester.view.reset);
      Widget box(String k) => SizedBox(key: ValueKey(k), width: 50, height: 50);
      final children = [box('a'), const Spacer(), box('b'), const Spacer(flex: 2), box('c')];
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, height: 400, child: row ? Row(children: children) : Column(children: children)),
        ),
      ));
      final want = {for (final k in ['a', 'b', 'c']) k: tester.getRect(find.byKey(ValueKey(k)))};
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['frame'],
        'nodes': {
          'frame': {'type': 'stack', 'children': ['f'], 'layout': {'width': 800, 'height': 800}},
          'f': {'type': row ? 'row' : 'column', 'children': ['a', 's1', 'b', 's2', 'c'], 'layout': {'width': 400, 'height': 400}},
          'a': {'type': 'box', 'layout': {'width': 50, 'height': 50}},
          'b': {'type': 'box', 'layout': {'width': 50, 'height': 50}},
          'c': {'type': 'box', 'layout': {'width': 50, 'height': 50}},
          's1': {'type': 'spacer'},
          's2': {'type': 'spacer', 'layout': {'flex': 2}},
        },
      })));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
      final view = tester.renderObject(find.byType(NodeView));
      for (final k in want.keys) {
        expect(tree.boxOf(k)!.rectIn(view), want[k], reason: k);
      }
    });
  }
}
