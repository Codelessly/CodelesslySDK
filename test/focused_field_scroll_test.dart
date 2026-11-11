// A focused text field in a scrolling column doesn't hold the column in
// place: after typing, the column still scrolls away from the field (the
// send sheet's note, then down to the Send button), as in any app.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/design_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final bound in [false, true]) {
    testWidgets('after typing, a column scrolls away from its focused field (bound text: $bound)', (tester) async {
      final scope = VariableScope([const Variable(name: 'msg', type: VariableType.text, value: '')]);
      final tree = NodeTree(
        DocumentSource(LayoutDocument.fromJson({
          'roots': ['col'],
          'nodes': {
            'col': {
              'type': 'column',
              'children': ['top', 'f', 'tail'],
              'layout': {'width': 300, 'height': 400},
              'props': {'scrollable': true},
            },
            'top': {'type': 'box', 'layout': {'width': 300, 'height': 120}},
            'f': {
              'type': 'textField',
              'layout': {'width': 300, 'height': {'hug': 48}},
              if (bound) 'bind': {'props.initialValue': r'${msg}'},
              if (bound)
                'actions': [
                  {
                    'trigger': {'type': 'changed'},
                    'actions': [
                      {'type': 'setVariable', 'variable': 'msg', 'value': r'${value}'},
                    ],
                  },
                ],
            },
            'tail': {'type': 'box', 'layout': {'width': 300, 'height': 800}},
          },
        })),
        binder: NodeBinder(scope: scope, logic: const LayoutLogic()),
      );
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: true)),
      ));
      await tester.pump();
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      // As the MCP's preview.type does: the keyboard's value, a few frames.
      final editable = tester.state<EditableTextState>(find.byType(EditableText));
      editable.updateEditingValue(const TextEditingValue(
        text: 'Thanks for pairing', selection: TextSelection.collapsed(offset: 18)));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      RenderDesignScroll? scroll;
      void visit(RenderObject o) {
        if (o is RenderDesignScroll && scroll == null) scroll = o;
        o.visitChildren(visit);
      }
      visit(tester.renderObject(find.byType(NodeView)));
      expect(scroll, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNotNull, reason: 'the field still has focus');
      // Scroll the field out of view, as a person reaching the Send button.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      scroll!.jumpBy(300);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(scroll!.offset, 300);
    });
  }
}
