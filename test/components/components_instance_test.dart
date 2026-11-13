// Per-instance correctness of components by reference (docs/design/06,
// "Not done" of phase 1): set value acts on the instance it runs in; slot
// content placed inside a list of the definition shows once per item, in the
// caller's scope; per-instance scopes are released when their instance leaves
// the tree; `persist` on a component variable keeps a value per instance path.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A definition whose button sets its own label's text (set value).
Json toggle() => {
      'schema': 2,
      'id': 'Toggle',
      'roots': ['t'],
      'widget': {'type': 'Toggle', 'props': <Json>[]},
      'nodes': {
        't': {'type': 'row', 'children': ['label', 'hit'], 'layout': {'width': 200, 'height': 30}},
        'label': {'type': 'text', 'props': {'text': 'off'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        'hit': {
          'type': 'box',
          'layout': {'width': 30, 'height': 30},
          'decoration': {'fills': [{'color': '#FF2196F3'}]},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setValue', 'node': 'label', 'values': [{'path': 'props.text', 'value': 'on'}]},
              ],
            },
          ],
        },
      },
    };

/// A definition that repeats its `children` slot once per item of a list.
Json repeater() => {
      'schema': 2,
      'id': 'Repeater',
      'roots': ['r'],
      'widget': {
        'type': 'Repeater',
        'children': 'list',
        'props': [
          {'key': 'items', 'type': {'kind': 'list'}, 'default': <Object?>[]},
        ],
      },
      'nodes': {
        'r': {'type': 'column', 'children': ['list'], 'layout': {'width': 300, 'height': {'hug': 200}}},
        'list': {
          'type': 'listView',
          'children': ['row'],
          'bind': {'data': r'${props.items}'},
          'layout': {'width': {'fill': 300}, 'height': 200},
        },
        'row': {'type': 'row', 'children': ['n', 'kids'], 'layout': {'width': {'fill': 300}, 'height': 30}},
        'n': {'type': 'text', 'props': {'text': r'${item}'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        'kids': {'type': 'slot'},
      },
    };

/// A definition with a persisted counter.
Json counter() => {
      'schema': 2,
      'id': 'Counter',
      'roots': ['c'],
      'widget': {'type': 'Counter', 'props': <Json>[]},
      'variables': {
        'c': [
          {'name': 'n', 'type': 'integer', 'value': 0, 'persist': true},
        ],
      },
      'nodes': {
        'c': {
          'type': 'row',
          'children': ['v'],
          'layout': {'width': 100, 'height': 30},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setVariable', 'variable': 'n', 'op': 'add', 'value': '1'},
              ],
            },
          ],
        },
        'v': {'type': 'text', 'props': {'text': r'${n}'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
      },
    };

Json page(Map<String, Json> nodes, List<String> children, {List<Json> variables = const []}) => {
      'schema': 2,
      'roots': ['col'],
      'nodes': {
        'col': {'type': 'column', 'children': children, 'layout': {'width': 400, 'height': {'hug': 600}}},
        ...nodes,
      },
    };

class Shown {
  Shown(this.tree, this.scope, this.binder);
  final NodeTree tree;
  final VariableScope scope;
  final NodeBinder binder;

  String text(String path) {
    final box = tree.boxAtPath(path);
    expect(box, isNotNull, reason: 'no box at $path: ${tree.boxes.map((b) => tree.pathOf(b.id, b.instance)).toList()}');
    RenderParagraph? found;
    void visit(RenderObject o) {
      if (o is RenderParagraph) found ??= o;
      o.visitChildren(visit);
    }

    visit(box!);
    return found!.text.toPlainText();
  }

  Offset center(String path) {
    final box = tree.boxAtPath(path)!;
    final content = box.contentBox ?? box;
    return content.localToGlobal(content.size.center(Offset.zero));
  }
}

Future<Shown> show(WidgetTester tester, Json pageJson, List<Json> definitions,
    {List<Variable> variables = const [], NodeBinder Function(VariableScope scope, VariableScope app)? binder}) async {
  final registry = ComponentRegistry([for (final d in definitions) LayoutDocument.fromJson(d)]);
  final doc = LayoutDocument.fromJson(pageJson, catalog: standardCatalog + registry.catalog);
  final app = VariableScope(const []);
  final scope = VariableScope(variables, parent: VariableScope(const [], parent: app));
  final b = binder?.call(scope, app) ?? NodeBinder(scope: scope, projectScope: app);
  final tree = NodeTree(DocumentSource(doc), binder: b, components: registry);
  final context = RuntimeActionContext(scope: scope, tree: tree, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
    b.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: true))),
  ));
  await tester.pump();
  return Shown(tree, scope, b);
}

void main() {
  testWidgets('set value acts on the instance it runs in, not on every instance (nor the page node of that id)', (tester) async {
    final s = await show(
        tester,
        page({
          'a': {'type': 'Toggle', 'layout': {'width': 200, 'height': 30}},
          'b': {'type': 'Toggle', 'layout': {'width': 200, 'height': 30}},
          'label': {'type': 'text', 'props': {'text': 'page'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        }, ['a', 'b', 'label']),
        [toggle()]);
    expect(s.text('a/label'), 'off');
    await tester.tapAt(s.center('b/hit'));
    await tester.pumpAndSettle();
    expect(s.text('b/label'), 'on');
    expect(s.text('a/label'), 'off');
    expect(s.text('label'), 'page');
  });

  testWidgets("slot content inside the definition's list shows once per item, in the caller's scope", (tester) async {
    final s = await show(
        tester,
        page({
          'rep': {
            'type': 'Repeater',
            'children': ['note'],
            'props': {'items': ['x', 'y', 'z']},
            'layout': {'width': 300, 'height': {'hug': 200}},
          },
          'note': {'type': 'text', 'props': {'text': r'${who}'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        }, ['rep']),
        [repeater()],
        variables: [Variable(name: 'who', type: VariableType.text, value: 'caller')]);
    final notes = s.tree.boxesOf('note').toList();
    expect(notes, hasLength(3), reason: 'one copy per item');
    for (final n in notes) {
      expect(n.attached, isTrue);
    }
    expect(s.text('rep/n#2'), 'z');
    expect(s.text('note#2'), 'caller', reason: "read in the caller's scope; named by the caller's path");
    s.scope.set('who', 'changed');
    await tester.pump();
    expect([for (var i = 0; i < 3; i++) s.text('note#$i')], ['changed', 'changed', 'changed']);
  });

  testWidgets('instance scopes are released when their instances leave the tree: 1,000 mounted and unmounted', (tester) async {
    Json card() => {
          'schema': 2,
          'id': 'Card',
          'roots': ['k'],
          'widget': {
            'type': 'Card',
            'props': [
              {'key': 'v', 'type': {'kind': 'string'}, 'default': ''},
            ],
          },
          'variables': {
            'k': [
              {'name': 'local', 'type': 'integer', 'value': 0},
            ],
          },
          'nodes': {
            'k': {'type': 'row', 'children': ['t'], 'layout': {'width': 100, 'height': 20}},
            't': {'type': 'text', 'props': {'text': r'${props.v} ${local}'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
          },
        };
    final s = await show(
        tester,
        page({
          'list': {
            'type': 'listView',
            'children': ['item'],
            'bind': {'data': r'${items}'},
            'layout': {'width': 300, 'height': 400},
          },
          'item': {'type': 'Card', 'bind': {'props.v': r'${item}'}, 'layout': {'width': 100, 'height': 20}},
        }, ['list']),
        [card()],
        variables: [Variable(name: 'items', type: VariableType.list, value: const [])]);
    for (var round = 0; round < 100; round++) {
      s.scope.set('items', [for (var i = 0; i < 10; i++) '$round-$i']);
      await tester.pump();
      await tester.pump();
      expect(s.text('item#9'), '$round-9 0');
      s.scope.set('items', const []);
      await tester.pump();
      await tester.pump();
    }
    expect(s.binder.componentScopeCount, lessThanOrEqualTo(1), reason: 'the scopes of 1,000 instances that left');
    expect(s.tree.instanceSourceCount, lessThanOrEqualTo(1));
  });

  testWidgets('persist on a component variable keeps a value per instance path', (tester) async {
    final storage = MemoryLocalStorage();
    NodeBinder binder(VariableScope scope, VariableScope app) => NodeBinder(
        scope: scope,
        projectScope: app,
        persistComponentVariable: (variables, variable, key) => PersistedVariable.attach(variables, variable, storage, key: key).dispose);
    Json pageJson() => page({
          'one': {'type': 'Counter', 'layout': {'width': 100, 'height': 30}},
          'two': {'type': 'Counter', 'layout': {'width': 100, 'height': 30}},
        }, ['one', 'two']);
    var s = await show(tester, pageJson(), [counter()], binder: binder);
    await tester.tapAt(s.center('two'));
    await tester.pump();
    await tester.tapAt(s.center('two'));
    await tester.pump();
    await tester.tapAt(s.center('one'));
    await tester.pump();
    expect(s.text('one/v'), '1');
    expect(s.text('two/v'), '2');
    expect(storage.getAll().keys, containsAll(['codelessly.component.Counter.one.n', 'codelessly.component.Counter.two.n']));
    // The next run: each instance starts from its own value.
    await tester.pumpWidget(const SizedBox());
    s = await show(tester, pageJson(), [counter()], binder: binder);
    expect(s.text('one/v'), '1');
    expect(s.text('two/v'), '2');
  });
}
