// A running app's list shows no items while its data is null (a script
// still answering), not its template with `${item...}` in it.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preview in [false, true]) {
    testWidgets('null list data in ${preview ? 'a design preview' : 'a running app'}', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['list'],
        'nodes': {
          'list': {
            'type': 'listView', 'children': ['row'], 'layout': {'width': 300, 'height': 300},
            'props': {'scrollable': false}, 'bind': {'data': r'${rows}'},
          },
          'row': {'type': 'text', 'props': {'text': r'${item.name}'}, 'layout': {'width': 200, 'height': 20}},
        },
      });
      final scope = VariableScope([Variable(id: 'rows', name: 'rows', type: VariableType.list, value: null)]);
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope, preview: preview));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'list', interactive: !preview)),
      ));
      expect(tree.boxOf('row') != null, preview, reason: 'the template shows only in a design preview');
      scope.set('rows', [{'name': 'Aquarium'}, {'name': 'Ashby Park'}]);
      await tester.pump();
      expect(tree.boxOf('row'), isNotNull);
    });
  }
}
