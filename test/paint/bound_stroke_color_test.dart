import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A stroke whose color is bound (`border={on ? '#FF545CEA' : '#00000000'}`)
// follows its variable both ways: set, then cleared to transparent or to
// another color, the old one is gone (it lingered: a ring around the
// reaction picked before, a pill's selected outline after it was cleared).

/// The stroke colors drawn under [root]: decorations' borders, and the
/// stroke layers drawn over a node's content.
List<Color> _strokes(RenderObject root) {
  final out = <Color>[];
  void visit(RenderObject o) {
    if (o is RenderDecoratedBox && o.decoration is BoxDecoration) {
      if ((o.decoration as BoxDecoration).border case final Border b) out.add(b.top.color);
    }
    if (o.runtimeType.toString() == 'RenderNodePaint') {
      final dynamic d = (o as dynamic).decoration;
      for (final dynamic s in d.visibleStrokes) {
        if (s.color != null) out.add(Color(s.color.value as int));
      }
    }
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

void main() {
  testWidgets('a bound stroke color changes back and forth', (tester) async {
    final scope = VariableScope([Variable(id: 'on', name: 'on', type: VariableType.boolean, value: true)]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'schema': 3,
        'roots': ['col'],
        'nodes': {
          'col': {'type': 'column', 'children': ['pill'], 'layout': {'width': 100, 'height': {'hug': 80}}},
          'pill': {
            'type': 'column',
            'layout': {'width': 80, 'height': 40},
            'decoration': {'radius': 20, 'fills': [{'color': '#FFFFFFFF'}], 'strokes': [{'color': '#00000000'}]},
            'bind': {'decoration.strokes[0].color': r"${= on ? '#FF545CEA' : '#00000000'}"},
          },
        },
      })),
      binder: NodeBinder(scope: scope),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col'))));
    List<Color> drawn() => [for (final c in _strokes(tester.renderObject(find.byType(NodeView)))) if (c.a > 0) c];

    expect(drawn(), [const Color(0xFF545CEA)]);
    scope.set('on', false);
    await tester.pumpAndSettle();
    expect(drawn(), isEmpty, reason: 'the outline is cleared');
    scope.set('on', true);
    await tester.pumpAndSettle();
    expect(drawn(), [const Color(0xFF545CEA)]);
  });
}
