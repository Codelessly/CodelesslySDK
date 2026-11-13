// A running screen for tests: nodes shown interactive, with their variables
// and reactions.
import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';


Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

Json reaction(String trigger, List<Json> actions, {Json extra = const {}}) => {
      'trigger': {'type': trigger, ...extra},
      'actions': actions,
    };

Json add(String name, [String by = '1']) => {'type': 'setVariable', 'variable': name, 'op': 'add', 'value': by};

class Screen {
  Screen(this.tree, this.scope, this.context, this.reactions);
  final NodeTree tree;
  final VariableScope scope;
  final RuntimeActionContext context;
  final TreeReactions reactions;

  Object? operator [](String name) => scope.read(name);

  Offset center(String id) {
    final box = tree.boxOf(id)!;
    final content = box.contentBox ?? box;
    return content.localToGlobal(content.size.center(Offset.zero));
  }
}

Future<Screen> show(
  WidgetTester tester,
  Map<String, Json> nodes, {
  List<Variable> variables = const [],
  String root = 'col',
  ActionUi ui = const NoActionUi(),
  bool interactive = true,
  Services? services,
}) async {
  final doc = LayoutDocument.fromJson({'roots': [root], 'nodes': nodes});
  final scope = VariableScope(variables);
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
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root, interactive: interactive))),
  ));
  return Screen(tree, scope, context, reactions);
}

/// A column with a counter text and a 100×40 button box.
Map<String, Json> counter({List<Json> actions = const [], Json? extraNodes}) => {
      'col': {
        'type': 'column',
        'children': ['label', 'button', 'other'],
        'layout': {'width': 200, 'height': {'hug': 120}},
      },
      'label': {
        'type': 'text',
        'layout': {'width': 200, 'height': 20},
        'props': {'text': r'Count ${count}'},
      },
      'button': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'decoration': {'fills': [{'color': '#FF2196F3'}]},
        'actions': actions,
      },
      'other': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'decoration': {'fills': [{'color': '#FF000000'}]},
      },
      ...?extraNodes?.cast<String, Json>(),
    };

String textOf(NodeTree tree, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!.text.toPlainText();
}
