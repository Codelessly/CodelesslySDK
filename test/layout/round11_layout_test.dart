import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Layout that round 11's direct writes (30 briefs from the grammar alone)
// drew wrongly: a list's hidden copies still took its gap (a staircase of
// kanban lanes), a capped fill in a stack was nothing wide (a headline one
// letter per line), a ring that fills its place drew nothing.

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root, {Map<String, Object?> variables = const {}}) async {
  final scope = VariableScope([for (final e in variables.entries) Variable(name: e.key, type: VariableType.list, value: e.value)]);
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'schema': 3, 'roots': [root], 'nodes': nodes})), binder: NodeBinder(scope: scope));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  testWidgets('a list\'s copies an if hides take no gap: the shown ones start at the top', (tester) async {
    final (tree, view) = await _show(
      tester,
      {
        'lane': {'type': 'column', 'children': ['list'], 'layout': {'width': 200, 'height': {'hug': 0}}},
        'list': {
          'type': 'listView',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'scrollable': false, 'spacing': 8},
          'bind': {'data': r'${cards}'},
          'children': ['item'],
        },
        'item': {'type': 'column', 'layout': {'width': {'fill': 0}, 'height': {'hug': 0}}, 'children': ['card']},
        'card': {
          'type': 'box',
          'layout': {'width': {'fill': 0}, 'height': 40},
          'bind': {'visible': r'${item.lane == "b"}'},
        },
      },
      'lane',
      variables: {
        'cards': [
          {'lane': 'a'},
          {'lane': 'a'},
          {'lane': 'b'},
          {'lane': 'a'},
          {'lane': 'b'},
        ],
      },
    );
    await tester.pump();
    final list = tree.boxOf('list')!.rectIn(view)!;
    // Two cards shown, one gap between them; the first at the list's top.
    expect(list.height, 40 + 8 + 40);
  });

  testWidgets('a fill with the most it gets, in a stack: as wide as the stack up to that', (tester) async {
    final (tree, view) = await _show(tester, {
      's': {'type': 'stack', 'children': ['col'], 'layout': {'width': 1000, 'height': 300}},
      'col': {
        'type': 'column',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'constraints': {'maxWidth': 730}},
        'children': ['t'],
      },
      't': {'type': 'text', 'layout': {'width': {'fill': 0}, 'height': {'hug': 0}}, 'props': {'text': 'A headline'}},
    }, 's');
    expect(tree.boxOf('col')!.rectIn(view)!.width, 730);
    final (tree2, view2) = await _show(tester, {
      's': {'type': 'stack', 'children': ['col'], 'layout': {'width': 400, 'height': 300}},
      'col': {'type': 'column', 'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'constraints': {'maxWidth': 730}}, 'children': []},
    }, 's');
    expect(tree2.boxOf('col')!.rectIn(view2)!.width, 400);
  });

  testWidgets('a ring that fills its place is a circle of its shortest side', (tester) async {
    final (tree, view) = await _show(tester, {
      's': {'type': 'stack', 'children': ['ring'], 'layout': {'width': 132, 'height': 132}},
      'ring': {
        'type': 'circularProgressIndicator',
        'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'x': {'align': 0}, 'y': {'align': 0}},
        'props': {'value': 0.6, 'strokeWidth': 10},
      },
    }, 's');
    expect(tree.boxOf('ring')!.rectIn(view)!.size, const Size(132, 132));
    // The drawn square inside it is the ring's, not nothing.
    final drawn = <RenderBox>[];
    void visit(RenderObject o) {
      if (o is RenderAspectRatio) drawn.add(o);
      o.visitChildren(visit);
    }

    visit(view);
    expect(drawn.single.size, const Size(132, 132));
  });
}
