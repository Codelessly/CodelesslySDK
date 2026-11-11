// A list item with a pressed state (scale 0.99) still runs its click
// actions: the press restyles the item while the tap is in flight.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(id: name, name: name, type: type, value: value);

void main() {
  for (final withStates in [false, true]) {
    testWidgets('a tap on a list item ${withStates ? 'with' : 'without'} a pressed state runs its actions', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['list'],
        'nodes': {
          'list': {
            'type': 'listView',
            'children': ['card'],
            'layout': {'width': 300, 'height': 300},
            'props': {'scrollable': false},
            'bind': {'data': r'${items}'},
          },
          'card': {
            'type': 'box',
            'layout': {'width': {'fill': 300}, 'height': 50},
            'decoration': {'fills': [{'color': '#FF0000FF'}]},
            'actions': [
              {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'picked', 'value': r'${item}'}]},
            ],
            if (withStates) 'states': {'pressed': {'card': {'scale': 0.99}}},
          },
        },
      });
      final scope = VariableScope([v('picked', ''), v('items', ['a', 'b', 'c'], VariableType.list)]);
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
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'list', interactive: true)),
      ));
      await tester.tapAt(const Offset(150, 75));
      await tester.pumpAndSettle();
      expect(scope.read('picked'), 'b');
    });
  }
}
