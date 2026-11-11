// A deep prop path binding (props.decoration.enabledBorder.borderSide.color)
// on a list item follows its item when the item changes, as plain prop
// bindings do.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final interactive in [false, true]) {
    testWidgets('the border follows the item (interactive: $interactive)', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['l'],
        'nodes': {
          'l': {'type': 'listView', 'children': ['f'], 'layout': {'width': 220, 'height': {'hug': 40}}, 'props': {'scrollable': false}, 'bind': {'data': r'${rows}'}},
          'f': {
            'type': 'textField',
            'layout': {'width': {'fill': 100}, 'height': 34},
            'props': {'maxLines': 1, 'decoration': {'enabledBorder': {'borderRadius': 0, 'borderSide': {'color': '#FF00FF00'}}}},
            'bind': {
              'props.initialValue': r'${item.tag}',
              'props.decoration.enabledBorder.borderSide.color': r"${= item.error != '' ? '#FFFF0000' : '#FF0000FF'}",
            },
          },
        },
      });
      final scope = VariableScope([
        Variable(name: 'rows', type: api.VariableType.list, value: [{'tag': 'x', 'error': 'bad'}]),
      ]);
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
          child: NodeView(tree: tree, rootId: 'l', interactive: interactive)))));
      await tester.pump();
      Color side() => tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration.enabledBorder!.borderSide.color;
      expect(side(), const Color(0xFFFF0000));
      scope.set('rows', [{'tag': 'x', 'error': ''}]);
      await tester.pump();
      await tester.pump();
      expect(side(), const Color(0xFF0000FF));
    });
  }
}
