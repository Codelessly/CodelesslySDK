import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// An empty part of an undecorated stack lets pointers through to what's
// under it (Flutter's Stack): a full-screen overlay of floating panels over
// an interactive map.

// A row laid over others (a piano's black keys over its white keys) takes
// pointers only where one of its children does: its gaps (spacers) let a
// finger through to the white key underneath, as Flutter's Row does.

void main() {
  group('taps through empty space', () {
    testWidgets('a tap passes through an undecorated stack to the node under it', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['screen'],
        'nodes': {
          'screen': {'type': 'stack', 'children': ['under', 'overlay'], 'layout': {'width': 400, 'height': 400}},
          'under': {
            'type': 'box',
            'layout': {'width': 400, 'height': 400, 'x': {'start': 0}, 'y': {'start': 0}},
            'decoration': {'fills': [{'color': '#FFEEEEEE'}]},
            'actions': [
              {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'hit', 'value': 'under'}]},
            ],
          },
          // Fills the screen; only its panel is solid.
          'overlay': {'type': 'stack', 'children': ['panel'], 'layout': {'width': {'fill': 400}, 'height': {'fill': 400}, 'x': {'start': 0}, 'y': {'start': 0}}},
          'panel': {
            'type': 'box',
            'layout': {'width': 400, 'height': 100, 'x': {'start': 0}, 'y': {'start': 0}},
            'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
            'actions': [
              {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'hit', 'value': 'panel'}]},
            ],
          },
        },
      });
      final scope = VariableScope([Variable(id: 'hit', name: 'hit', type: VariableType.text, value: '')]);
      final values = NodeValues(DocumentSource(doc));
      final tree = NodeTree(values, binder: NodeBinder(scope: scope));
      final reactions = TreeReactions(
        runner: const CodelesslyActions(),
        context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values),
      );
      tree.interactions = reactions;
      addTearDown(() {
        reactions.dispose();
        tree.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'screen', interactive: true)),
      ));
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(scope.read('hit'), 'under');
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();
      expect(scope.read('hit'), 'panel');
    });

    testWidgets('a tap passes through the gaps of a row drawn over other nodes', (tester) async {
      Json key(String id, String counter, double x) => {
            'type': 'column', 'children': ['${id}gap'],
            'layout': {'width': {'fill': 100}, 'height': {'fill': 200}},
            'decoration': {'fills': [{'color': '#FFF3E8CF'}]},
            'actions': [harness.reaction('pointerDown', [harness.add(counter)])],
          };
      final s = await harness.show(tester, {
        'col': {'type': 'stack', 'children': ['whites', 'blacks'], 'layout': {'width': 300, 'height': 200}},
        'whites': {'type': 'row', 'children': ['w0', 'w1', 'w2'], 'layout': {'width': {'fill': 300}, 'height': {'fill': 200}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}},
        'w0': key('w0', 'c0', 0), 'w0gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
        'w1': key('w1', 'c1', 0), 'w1gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
        'w2': key('w2', 'c2', 0), 'w2gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
        // Black layer: a gap, one black key, a gap, over the top 62%.
        'blacks': {'type': 'row', 'children': ['g1', 'b', 'g2'], 'layout': {'width': {'fill': 300}, 'height': 124, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0}}},
        'g1': {'type': 'spacer', 'layout': {'width': {'fill': 10}, 'height': 1, 'flex': 69}},
        'b': {'type': 'column', 'layout': {'width': {'fill': 62}, 'height': {'fill': 124}, 'flex': 62}, 'decoration': {'fills': [{'color': '#FF1B1714'}]},
              'actions': [harness.reaction('pointerDown', [harness.add('cb')])]},
        'g2': {'type': 'spacer', 'layout': {'width': {'fill': 10}, 'height': 1, 'flex': 169}},
      }, variables: [harness.v('c0', 0, VariableType.integer), harness.v('c1', 0, VariableType.integer), harness.v('c2', 0, VariableType.integer), harness.v('cb', 0, VariableType.integer)]);
      final origin = tester.getTopLeft(find.byType(NodeView));
      // White key 0, high up (under the black layer's gap).
      await tester.tapAt(origin + const Offset(30, 40));
      await tester.pump();
      expect(s['c0'], 1, reason: 'the gap lets the pointer through to the white key');
      // The black key itself.
      await tester.tapAt(origin + const Offset(100, 40));
      await tester.pump();
      expect(s['cb'], 1);
      expect(s['c1'], 0, reason: 'the black key covers the white one under it');
    });
  });
}
