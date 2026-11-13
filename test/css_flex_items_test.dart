// The CSS flex-item model in a wrapping row/column/flex (`layout.basis`,
// grow by `flex`), and grid auto-fit columns (`minCrossAxisExtent`). Flutter
// has no flex-basis or auto-fit, so the expected rects are the ones the CSS
// specs give for the same markup; each case cites the rule.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';

Future<NodeTree> pump(WidgetTester tester, Map<String, Object?> nodes, {double width = 1000}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['frame'],
    'nodes': {
      'frame': {'type': 'stack', 'children': ['w'], 'layout': {'width': width, 'height': 1000}},
      ...nodes,
    },
  })))
    ..responsive = ResponsiveWidth(Breakpoints.defaults, width);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
  return tree;
}

Map<String, Object?> cards(double width, {List<int> grow = const [1, 1, 1], double gap = 20}) => {
      'w': {
        'type': 'row',
        'children': ['c0', 'c1', 'c2'],
        'layout': {'width': width, 'height': {'hug': 10}},
        'props': {'wrap': true, 'spacing': gap, 'runSpacing': 10, 'crossAxisAlignment': 'start'},
      },
      for (var i = 0; i < 3; i++)
        'c$i': {
          'type': 'box',
          'layout': {'width': {'fill': 100}, 'height': 50, 'basis': 280, 'flex': grow[i]},
        },
    };

void main() {
  Rect r(NodeTree t, WidgetTester tester, String id) => t.boxOf(id)!.rectIn(tester.renderObject(find.byType(NodeView)))!;

  // CSS Flexbox §9.3 (collect items into lines by their hypothetical main
  // size = flex-basis) and §9.7 (resolve flexible lengths per line):
  // `display:flex; flex-wrap:wrap; gap:20px` with three `flex: 1 1 280px`.
  testWidgets('flex: 1 1 280px, 1000 wide: one line, each (1000 - 40) / 3', (tester) async {
    final t = await pump(tester, cards(1000));
    expect(r(t, tester, 'c0'), const Rect.fromLTWH(0, 0, 320, 50));
    expect(r(t, tester, 'c1'), const Rect.fromLTWH(340, 0, 320, 50));
    expect(r(t, tester, 'c2'), const Rect.fromLTWH(680, 0, 320, 50));
  });

  testWidgets('flex: 1 1 280px, 700 wide: two on the first line, the third grows to the whole second', (tester) async {
    final t = await pump(tester, cards(700));
    expect(r(t, tester, 'c0'), const Rect.fromLTWH(0, 0, 340, 50));
    expect(r(t, tester, 'c1'), const Rect.fromLTWH(360, 0, 340, 50));
    expect(r(t, tester, 'c2'), const Rect.fromLTWH(0, 60, 700, 50));
  });

  testWidgets('flex: 1 1 280px, 250 wide: one per line, shrunk to the line (flex-shrink)', (tester) async {
    final t = await pump(tester, cards(250));
    expect(r(t, tester, 'c0'), const Rect.fromLTWH(0, 0, 250, 50));
    expect(r(t, tester, 'c2'), const Rect.fromLTWH(0, 120, 250, 50));
  });

  testWidgets('grow factors share the free space: flex 2 1 1 at 1000 wide', (tester) async {
    // Free space 1000 - 3*280 - 40 = 120: 60, 30, 30.
    final t = await pump(tester, cards(1000, grow: [2, 1, 1]));
    expect(r(t, tester, 'c0').width, 340);
    expect(r(t, tester, 'c1').width, 310);
    expect(r(t, tester, 'c2').width, 310);
  });

  testWidgets('a fixed-width child with a basis keeps its basis (flex-grow 0)', (tester) async {
    final nodes = cards(1000);
    (nodes['c1'] as Map)['layout'] = {'width': 100, 'height': 50, 'basis': 280};
    final t = await pump(tester, nodes);
    // Free 120 shared by c0 and c2 only.
    expect(r(t, tester, 'c0').width, 340);
    expect(r(t, tester, 'c1').width, 280);
    expect(r(t, tester, 'c2').width, 340);
  });

  testWidgets('CSS order: children laid out by ascending order, equal orders as listed', (tester) async {
    final nodes = cards(1000);
    ((nodes['c2'] as Map)['layout'] as Map)['order'] = -1;
    final t = await pump(tester, nodes);
    expect(r(t, tester, 'c2').left, 0);
    expect(r(t, tester, 'c0').left, 340);
    expect(r(t, tester, 'c1').left, 680);
  });

  testWidgets('a row without wrap: children keep their own sizes (basis is a wrapping flex\'s)', (tester) async {
    // Flutter Row: a fill child is Expanded; basis plays no part.
    final nodes = cards(1000);
    (nodes['w'] as Map)['props'] = {'spacing': 20};
    final t = await pump(tester, nodes);
    expect(r(t, tester, 'c0').width, closeTo(320, 0.01));
  });

  group('grid auto-fit (CSS grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px)', () {
    Map<String, Object?> grid(double width, int items) => {
          'w': {
            'type': 'gridView',
            'children': ['cell'],
            'layout': {'width': width, 'height': {'hug': 100}},
            'props': {
              'minCrossAxisExtent': 280,
              'crossAxisSpacing': 20,
              'mainAxisSpacing': 20,
              'mainAxisExtent': 50,
              'itemCount': items,
              'physics': 'never',
            },
          },
          'cell': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': {'fill': 10}}},
        };
    for (final (width, items, columns) in [(1000.0, 6, 3), (700.0, 6, 2), (500.0, 6, 1), (1400.0, 2, 2)]) {
      testWidgets('$width wide, $items items: $columns columns', (tester) async {
        final t = await pump(tester, grid(width, items), width: width);
        final cell = (width - 20 * (columns - 1)) / columns;
        expect(t.boxOf('w')!.rectIn(tester.renderObject(find.byType(NodeView)))!.width, width);
        final boxes = t.boxesOf('cell').map((b) => b.rectIn(tester.renderObject(find.byType(NodeView)))!).toList()
          ..sort((a, b) => a.top != b.top ? a.top.compareTo(b.top) : a.left.compareTo(b.left));
        expect(boxes.first, Rect.fromLTWH(0, 0, cell, 50));
        if (columns > 1) expect(boxes[1], Rect.fromLTWH(cell + 20, 0, cell, 50));
        if (items > columns) expect(boxes[columns].top, 70);
      });
    }
  });
}
