import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

Json reaction(String trigger, List<Json> actions, {Json extra = const {}}) => {
      'trigger': {'type': trigger, ...extra},
      'actions': actions,
    };

/// A running screen of [nodes] (its root [root]).
class Screen {
  Screen(this.tree, this.scope, this.context, this.reactions);
  final NodeTree tree;
  final VariableScope scope;
  final RuntimeActionContext context;
  final TreeReactions reactions;

  Object? operator [](String name) => scope.read(name);

  Offset center(String id, {Object? instance}) {
    final box = tree.boxOf(id, instance: instance)!;
    final content = box.contentBox ?? box;
    return content.localToGlobal(content.size.center(Offset.zero));
  }
}

Future<Screen> show(
  WidgetTester tester,
  Map<String, Json> nodes, {
  List<Variable> variables = const [],
  String root = 'col',
  bool interactive = true,
  CodelesslyServices? services,
  ActionUi ui = const NoActionUi(),
}) async {
  final doc = LayoutDocument.fromJson({'roots': [root], 'nodes': nodes});
  final scope = VariableScope(variables);
  declarePaginationVariables(scope, doc.nodes.values);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, ui: ui, tree: tree, nodeValues: values, services: services ?? Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root, interactive: interactive)),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return Screen(tree, scope, context, reactions);
}

/// The texts painted under [root] (a render object), in paint order.
List<String> textsUnder(RenderObject root) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}
