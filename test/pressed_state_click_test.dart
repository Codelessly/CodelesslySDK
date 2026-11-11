// A node's interaction states change how it's drawn while it's pressed or
// hovered; they must never take its taps away.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final states in <String, Map<String, Object?>>{
    'pressed scale': {'pressed': {'b': {'scale': 0.97}}},
    'pressed and hovered': {
      'pressed': {'b': {'scale': 0.97}},
      'hovered': {'b': {'decoration': {'fills': [{'color': '#FF00FF00'}]}}},
    },
    'pressed opacity': {'pressed': {'b': {'opacity': 0.8}}},
  }.entries) {
    testWidgets('a click runs while a ${states.key} state patch applies', (tester) async {
      final scope = VariableScope([const Variable(name: 'count', type: VariableType.integer, value: 0)]);
      final tree = NodeTree(
        DocumentSource(LayoutDocument.fromJson({
          'roots': ['root'],
          'nodes': {
            'root': {'type': 'stack', 'children': ['b'], 'layout': {'width': 300, 'height': 300}},
            'b': {
              'type': 'box',
              'layout': {'width': 120, 'height': 48, 'x': {'start': 20}, 'y': {'start': 20}},
              'decoration': {'fills': [{'color': '#FF9A3B22'}]},
              'states': states.value,
              'actions': [
                {'id': 'tap', 'trigger': {'type': 'click'}, 'actions': [
                  {'type': 'setVariable', 'variable': 'count', 'op': 'add', 'value': '1'},
                ]},
              ],
            },
          },
        })),
        binder: NodeBinder(scope: scope),
      );
      final reactions = TreeReactions(runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree));
      tree.interactions = reactions;
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root', interactive: true)),
      ));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        reactions.dispose();
        tree.dispose();
        scope.dispose();
      });
      await tester.tapAt(const Offset(60, 40));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tapAt(const Offset(60, 40));
      await tester.pump(const Duration(milliseconds: 200));
      expect(scope.read('count'), 2);
    });
  }
}
