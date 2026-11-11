// An empty part of an undecorated stack lets pointers through to what's
// under it (Flutter's Stack): a full-screen overlay of floating panels over
// an interactive map.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('taps pass through an undecorated stack to the node under it', (tester) async {
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
}
