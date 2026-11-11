// A text field whose initialValue is fed back from its own `changed`
// reaction through a slow action (a script result, a delay) keeps what was
// typed since; a highlight range draws in its style.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/inputs.dart' show HighlightTextController;
import 'package:flutter/material.dart' hide Node;
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show reaction, v;

Future<(VariableScope, NodeTree)> show(WidgetTester tester, Map<String, Object?> field, List<Variable> vars) async {
  final doc = LayoutDocument.fromJson({'roots': ['f'], 'nodes': {'f': field}});
  final scope = VariableScope(vars);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
      child: NodeView(tree: tree, rootId: 'f', interactive: true)))));
  await tester.pump();
  return (scope, tree);
}

void main() {
  testWidgets('a lagging echo of an earlier keystroke does not undo later ones', (tester) async {
    final (scope, _) = await show(tester, {
      'type': 'textField', 'layout': {'width': 200, 'height': 40},
      'bind': {'props.initialValue': r'${t}'},
      'actions': [
        reaction('changed', [
          {'type': 'delay', 'ms': 100},
          {'type': 'setVariable', 'variable': 't', 'value': r'${result}'},
        ]),
      ],
    }, [v('t', 'y = ')]);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'y = x');
    await tester.pump(const Duration(milliseconds: 30));
    await tester.enterText(find.byType(TextField), 'y = x^');
    await tester.pump(const Duration(milliseconds: 30));
    await tester.enterText(find.byType(TextField), 'y = x^2');
    // The first echo ('y = x') arrives now, after two newer edits.
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'y = x^2');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'y = x^2');
    expect(scope.read('t'), 'y = x^2');
    // A value from elsewhere still replaces the text.
    scope.set('t', 'a = 2');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'a = 2');
  });

  testWidgets('the highlight range is drawn in its style', (tester) async {
    await show(tester, {
      'type': 'textField', 'layout': {'width': 200, 'height': 40},
      'props': {'initialValue': 'y = sin(x*x', 'highlightStart': 7, 'highlightEnd': 8,
        'highlightStyle': {'color': '#FFB3261E', 'backgroundColor': '#FFF7E3DC'}},
      'bind': {'props.highlightStart': r'${col}', 'props.highlightEnd': r'${= col + 1}'},
    }, [v('col', 7, api.VariableType.integer)]);
    final controller = tester.widget<TextField>(find.byType(TextField)).controller! as HighlightTextController;
    final span = controller.buildTextSpan(context: tester.element(find.byType(TextField)), withComposing: false);
    final parts = span.children!.cast<TextSpan>();
    expect(parts.map((p) => p.text), ['y = sin', '(', 'x*x']);
    expect(parts[1].style!.color, const Color(0xFFB3261E));
  });
}
