// Core row/column layout beyond what parity samples: wrapping rows, and
// what a squeezing row can take from its children.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Object?> _box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

void main() {
  testWidgets('a wrapping row puts its children on runs', (tester) async {
    final (tree, view) = await _show(tester, {
      'r': {
        'type': 'row',
        'children': ['a', 'b', 'c', 'fill'],
        'layout': {'width': 200, 'height': {'hug': 0}},
        'props': {'wrap': true, 'spacing': 10, 'runSpacing': 5, 'mainAxisAlignment': 'center'},
      },
      'a': _box(80, 20),
      'b': _box(80, 30),
      'c': _box(80, 20),
      // Fill means nothing in a run: a box keeps its design width.
      'fill': {'type': 'box', 'layout': {'width': {'fill': 60}, 'height': 10}},
    }, 'r');
    Rect r(String id) => tree.boxOf(id)!.rectIn(view)!;
    // Runs: [a, b] (170 of 200, centred), [c, fill]; centred across each
    // run (crossAxisAlignment defaults to center).
    expect(r('a'), const Rect.fromLTWH(15, 5, 80, 20));
    expect(r('b'), const Rect.fromLTWH(105, 0, 80, 30));
    expect(r('c'), const Rect.fromLTWH(25, 35, 80, 20));
    expect(r('fill'), const Rect.fromLTWH(115, 40, 60, 10));
    expect(r('r'), const Rect.fromLTWH(0, 0, 200, 55));
  });

  testWidgets('a row short of room squeezes a list viewport and an ink box to nothing', (tester) async {
    final (tree, view) = await _show(tester, {
      'r': {
        'type': 'row',
        'children': ['list', 'ink', 'fixed'],
        'layout': {'width': 300, 'height': 40},
      },
      'list': {
        'type': 'listView',
        'children': ['item'],
        'layout': {'width': {'hug': 200}, 'height': 40},
        'props': {'scrollDirection': 'horizontal'},
      },
      'item': _box(50, 40),
      // A box with ink: its content fills it, giving it no min size.
      'ink': {
        'type': 'stack',
        'children': ['icon'],
        'layout': {'width': 100, 'height': 40},
        'inkWell': {'splashColor': '#1F000000'},
      },
      'icon': {'type': 'box', 'layout': {'width': 24, 'height': 24, 'x': {'align': 0}, 'y': {'align': 0}}},
      'fixed': _box(100, 40),
    }, 'r');
    double w(String id) => tree.boxOf(id)!.rectIn(view)!.width;
    // 400 into 300: each gives up in proportion to its own width.
    expect(w('list'), closeTo(150, 0.01));
    expect(w('ink'), closeTo(75, 0.01));
    expect(w('fixed'), closeTo(75, 0.01));
  });
}
