// A hidden child of a row (by a binding or a media rule; or hidden in its
// own data while a media rule shows it at other sizes) takes no room and no slot: the row lays out as the
// Flutter Row without it (`if (visible) child`, or Visibility's default
// SizedBox.shrink for the room), for every main-axis alignment.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> doc(String align) => {
      'roots': ['frame'],
      'nodes': {
        'frame': {
          'type': 'stack',
          'children': ['row'],
          'layout': {'width': 600, 'height': 100},
        },
        'row': {
          'type': 'row',
          'children': ['a', 'h1', 'b', 'h2', 'c', 'h3'],
          'layout': {'width': 600, 'height': 40},
          'props': {'mainAxisAlignment': align, 'spacing': 10},
        },
        'a': {'type': 'box', 'layout': {'width': 50, 'height': 20}},
        'b': {'type': 'box', 'layout': {'width': 80, 'height': 20}},
        'c': {'type': 'box', 'layout': {'width': 30, 'height': 20}},
        'h1': {
          'type': 'box',
          'visible': false,
          'layout': {'width': 28, 'height': 28},
          'media': [
            {'maxWidth': 'mobile', 'patch': {'visible': true}},
          ],
        },
        'h2': {'type': 'box', 'layout': {'width': 28, 'height': 28}, 'bind': {'visible': r'${= show}'}},
        'h3': {
          'type': 'box',
          'layout': {'width': 28, 'height': 28},
          'media': [
            {'minWidth': 'tablet', 'patch': {'visible': false}},
          ],
        },
      },
    };

void main() {
  for (final align in MainAxisAlignment.values) {
    testWidgets('hidden children of a flex take no space when it aligns ${align.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 100);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 40,
            child: Row(mainAxisAlignment: align, spacing: 10, children: const [
              SizedBox(key: ValueKey('a'), width: 50, height: 20),
              SizedBox(key: ValueKey('b'), width: 80, height: 20),
              SizedBox(key: ValueKey('c'), width: 30, height: 20),
            ]),
          ),
        ),
      ));
      final want = {for (final k in ['a', 'b', 'c']) k: tester.getRect(find.byKey(ValueKey(k)))};

      final scope = VariableScope([Variable(name: 'show', type: VariableType.boolean, value: false)]);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc(align.name))), binder: NodeBinder(scope: scope))
        ..responsive = ResponsiveWidth(Breakpoints.defaults, 1440);
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
      final view = tester.renderObject(find.byType(NodeView));
      for (final k in want.keys) {
        expect(tree.boxOf(k)!.rectIn(view), want[k], reason: '$k (${align.name})');
      }
    });
  }
}
