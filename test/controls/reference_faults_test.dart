// What the NOCD rebuild found missing or misdrawn in the controls, each fixed
// where the control reads it: a field's border worked out (the notation
// binds it on the field's own border now, where `focused.border=` is), the
// keyboard's suggestions turned off, and a scroll's pull past its ends.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:codelessly_sdk/src/render/layout/design_scroll.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderTextField _field(RenderTree tree, String id) => textFieldIn(tree.boxOf(id)!)!;

Future<(NodeTree, VariableScope)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, [List<Variable> variables = const []]) async {
  final scope = VariableScope(variables);
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(columnDoc(nodes, height: 400))),
      binder: NodeBinder(scope: scope), environment: const IslandEnvironment(interactive: true));
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, scope);
}

void main() {
  testWidgets('a field\'s border color worked out is drawn on the field\'s own border, and follows it', (tester) async {
    final (tree, scope) = await _show(tester, {
      'pw': hugging('textField', {
        'decoration': {
          'hintText': 'Password',
          'border': {'type': 'outline', 'borderSide': <String, Object?>{}},
        },
      }, {
        'bind': {'props.decoration.border.borderSide.color': r'${= bad ? "#FFEF5350" : "#FF00A3AD"}'},
      }),
    }, [const Variable(name: 'bad', type: VariableType.boolean, value: true)]);
    expect(_field(tree, 'pw').currentBorder.side.color, const Color(0xFFEF5350));
    scope.set('bad', false);
    await tester.pump();
    expect(_field(tree, 'pw').currentBorder.side.color, const Color(0xFF00A3AD));
  });

  testWidgets('enableSuggestions=false turns the keyboard\'s suggestions off; on by default', (tester) async {
    final (tree, _) = await _show(tester, {
      'off': hugging('textField', {'enableSuggestions': false}),
      'on': hugging('textField'),
    });
    expect(_field(tree, 'off').inputConfiguration.enableSuggestions, isFalse);
    expect(_field(tree, 'on').inputConfiguration.enableSuggestions, isTrue);
  });

  testWidgets('a scroll\'s result says how far it is pulled past an end (0 within)', (tester) async {
    final (tree, _) = await _show(tester, {
      'list': {
        'type': 'column',
        'layout': {'width': 200, 'height': 100},
        'props': {'scrollable': true},
        'children': ['a', 'b'],
      },
      'a': {'type': 'box', 'layout': {'width': 200, 'height': 120}},
      'b': {'type': 'box', 'layout': {'width': 200, 'height': 120}},
    });
    final scrolls = <RenderDesignScroll>[];
    void visit(RenderObject o) {
      if (o is RenderDesignScroll) scrolls.add(o);
      o.visitChildren(visit);
    }

    visit(tree.boxOf('col')!);
    // (A scroll may wrap the node's box from outside it.)
    for (RenderObject? o = tree.boxOf('list'); o != null; o = o.parent) {
      if (o is RenderDesignScroll) scrolls.add(o);
    }
    expect(scrolls, isNotEmpty);
    final scroll = scrolls.first;
    expect(scroll.metrics['overscroll'], 0.0);
    scroll.jumpTo(scroll.maxScrollExtent);
    expect(scroll.metrics['overscroll'], 0.0);
  });
}
