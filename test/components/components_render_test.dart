// Components by reference in the render tree: a call renders as ordinary
// boxes of its definition, keyed by (node id, ComponentInstance); parameters
// read as ${props.x} in the caller's scope; per-instance variables;
// `variable` parameters; slots in the caller's scope; events to the call's
// reactions; lists of components; components in components; editing a
// definition updates every instance incrementally; missing definitions.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Json chip({String text = r'${props.label}', List<Json> extraActions = const []}) => {
      'schema': 2,
      'id': 'Chip',
      'roots': ['chip'],
      'widget': {
        'type': 'Chip',
        'children': 'list',
        'slots': ['trailing'],
        'props': [
          {'key': 'label', 'type': {'kind': 'string', 'flutter': 'String'}, 'default': 'Chip'},
          {'key': 'width', 'type': {'kind': 'number', 'flutter': 'double'}, 'default': 50},
          {'key': 'on', 'type': {'kind': 'variable', 'of': {'kind': 'boolean'}}, 'default': ''},
        ],
        'events': [
          {'key': 'onPick', 'payload': {'kind': 'string'}},
        ],
      },
      'variables': {
        'chip': [
          {'name': 'taps', 'type': 'integer', 'value': 0},
          {'name': 'shout', 'type': 'text', 'formula': "props.label + '!'"},
        ],
      },
      'nodes': {
        'chip': {
          'type': 'row',
          'children': ['label', 'count', 'kids', 'tail', 'hit'],
          'layout': {'width': 300, 'height': {'hug': 40}, 'padding': 4},
        },
        'label': {'type': 'text', 'props': {'text': text}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        'count': {'type': 'text', 'props': {'text': r'${taps} ${shout} ${title}'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        'kids': {'type': 'slot', 'children': ['empty']},
        'empty': {'type': 'text', 'props': {'text': 'nothing'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 20}}},
        'tail': {'type': 'slot', 'props': {'name': 'trailing'}},
        'hit': {
          'type': 'box',
          'layout': {'width': 30, 'height': 30},
          'bind': {'layout.width': r'${props.width}'},
          'decoration': {'fills': [{'color': '#FF2196F3'}]},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
                {'type': 'setVariable', 'variable': 'props.on', 'op': 'toggle'},
                {'type': 'componentEvent', 'event': 'onPick', 'value': r'${props.label}'},
                ...extraActions,
              ],
            },
          ],
        },
      },
    };

Json page(Map<String, Json> calls, {List<String>? order, Map<String, Json> more = const {}}) => {
      'schema': 2,
      'roots': ['col'],
      'nodes': {
        'col': {
          'type': 'column',
          'children': order ?? calls.keys.toList(),
          'layout': {'width': 400, 'height': {'hug': 600}},
        },
        ...calls,
        ...more,
      },
    };

class Shown {
  Shown(this.tree, this.scope, this.registry, this.binder);
  final NodeTree tree;
  final VariableScope scope;
  final ComponentRegistry registry;
  final NodeBinder binder;

  String text(String path) {
    final box = tree.boxAtPath(path);
    expect(box, isNotNull, reason: 'no box at $path; boxes: ${tree.boxes.map((b) => tree.pathOf(b.id, b.instance)).toList()}');
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
    {List<Variable> variables = const [], List<Variable> project = const [], bool interactive = true}) async {
  final registry = ComponentRegistry([for (final d in definitions) LayoutDocument.fromJson(d)]);
  final doc = LayoutDocument.fromJson(pageJson, catalog: standardCatalog + registry.catalog);
  final app = VariableScope(project);
  final scope = VariableScope(variables, parent: VariableScope(const [], parent: app));
  final binder = NodeBinder(scope: scope, projectScope: app);
  final tree = NodeTree(DocumentSource(doc), binder: binder, components: registry);
  final context = RuntimeActionContext(scope: scope, tree: tree, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
    binder.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: interactive))),
  ));
  return Shown(tree, scope, registry, binder);
}

Json call(String type, {Json props = const {}, Json bind = const {}, Json layout = const {'width': 300, 'height': {'hug': 40}}, List<String>? children, Json? slots, List<Json> actions = const []}) => {
      'type': type,
      'layout': layout,
      if (props.isNotEmpty) 'props': props,
      if (bind.isNotEmpty) 'bind': bind,
      'children': ?children,
      'slots': ?slots,
      if (actions.isNotEmpty) 'actions': actions,
    };

const listInteractive = bool.fromEnvironment('LI', defaultValue: true);

void main() {
  testWidgets('a call renders its definition as ordinary boxes, keyed by instance', (tester) async {
    final s = await show(tester, page({'a': call('Chip', props: {'label': 'Alpha'}), 'b': call('Chip', props: {'label': 'Beta'})}), [chip()],
        project: [const Variable(name: 'title', type: VariableType.text, value: 'T')]);
    expect(s.text('a/label'), 'Alpha');
    expect(s.text('b/label'), 'Beta');
    expect(s.text('a/count'), '0 Alpha! T', reason: 'own variables, a formula over props, a project variable');
    // The call's box is the definition root's, in the instance.
    final root = s.tree.boxOf('a')!;
    expect(root.id, 'chip');
    expect(root.instance, isA<ComponentInstance>());
    expect((root.instance! as ComponentInstance).call, 'a');
    expect(s.tree.boxOf('label', instance: root.instance), same(s.tree.boxAtPath('a/label')));
    expect(s.tree.pathOf(root.id, root.instance), 'a');
    // No island: every definition node is a NodeBox of this tree.
    expect(s.tree.boxes.where((b) => b.id == 'label'), hasLength(2));
    // The default slot content shows (the call passes no children).
    expect(s.text('a/empty'), 'nothing');
  });

  testWidgets('the call sizes the root; the root keeps its padding', (tester) async {
    final s = await show(tester, page({'a': call('Chip', layout: {'width': 222, 'height': 60})}), [chip()]);
    final root = s.tree.boxOf('a')!;
    expect(root.size, const Size(222, 60));
    expect(root.node!.layout.padding.left, 4);
  });

  testWidgets('a definition never reads the caller\'s variables', (tester) async {
    final s = await show(tester, page({'a': call('Chip', props: {'label': 'A'})}), [chip(text: r'${secret}|${props.label}')],
        variables: [const Variable(name: 'secret', type: VariableType.text, value: 'leak')]);
    expect(s.text('a/label'), '|A');
  });

  testWidgets('bound parameters follow the caller; only the instance\'s readers re-apply', (tester) async {
    final s = await show(
      tester,
      page({
        'a': call('Chip', bind: {'props.label': r'${name}'}),
        'b': call('Chip', props: {'label': 'B'}),
        'other': {'type': 'text', 'props': {'text': r'${other}'}, 'layout': {'width': 50, 'height': 20}},
      }),
      [chip()],
      variables: [
        const Variable(name: 'name', type: VariableType.text, value: 'One'),
        const Variable(name: 'other', type: VariableType.integer, value: 0),
      ],
    );
    expect(s.text('a/label'), 'One');
    NodeBox.debugApplyCounts.clear();
    NodeBox.debugInPlaceCounts.clear();
    NodeBox.debugCountApplies = true;
    addTearDown(() => NodeBox.debugCountApplies = false);
    s.scope.set('other', 1);
    await tester.pump();
    final touched = {...NodeBox.debugApplyCounts.keys, ...NodeBox.debugInPlaceCounts.keys};
    expect(touched, {'other'}, reason: 'an unrelated variable re-applies no instance box');
    NodeBox.debugApplyCounts.clear();
    NodeBox.debugInPlaceCounts.clear();
    s.scope.set('name', 'Two');
    await tester.pump();
    expect(s.text('a/label'), 'Two');
    expect(s.text('b/label'), 'B');
    final again = {...NodeBox.debugApplyCounts.keys, ...NodeBox.debugInPlaceCounts.keys};
    expect(again, isNot(contains('col')));
    expect(again.difference({'label', 'count', 'chip'}), isEmpty, reason: 'only readers of props: $again');
  });

  testWidgets('slots graft the caller\'s nodes, read in the caller\'s scope', (tester) async {
    final s = await show(
      tester,
      page({
        'a': call('Chip', children: ['k1', 'k2'], slots: {'trailing': 't'}),
      }, more: {
        'k1': {'type': 'text', 'props': {'text': r'${who}'}, 'layout': {'width': {'hug': 20}, 'height': {'hug': 20}}},
        'k2': {'type': 'text', 'props': {'text': 'two'}, 'layout': {'width': {'hug': 20}, 'height': {'hug': 20}}},
        't': {'type': 'text', 'props': {'text': 'tail'}, 'layout': {'width': {'hug': 20}, 'height': {'hug': 20}}},
      }),
      [chip()],
      variables: [const Variable(name: 'who', type: VariableType.text, value: 'caller')],
    );
    expect(s.text('k1'), 'caller');
    expect(s.text('k2'), 'two');
    expect(s.text('t'), 'tail');
    expect(s.tree.boxAtPath('a/empty'), isNull, reason: 'passed children replace the default');
    // Placed in the definition's row, in order: label, count, k1, k2, tail, hit.
    final row = s.tree.boxOf('a')!;
    final xs = [for (final p in ['a/label', 'a/count', 'k1', 'k2', 't', 'a/hit']) s.tree.boxAtPath(p)!.localToGlobal(Offset.zero, ancestor: row).dx];
    expect(xs, orderedEquals([...xs]..sort()));
  });

  testWidgets('each instance has its own state, variable parameters and events', (tester) async {
    final s = await show(
      tester,
      page({
        'a': call('Chip', props: {'label': 'A', 'on': 'flag'}, actions: [
          {
            'trigger': {'type': 'event', 'event': 'onPick'},
            'actions': [
              {'type': 'setVariable', 'variable': 'picked', 'value': r'${result}'},
            ],
          },
        ]),
        'b': call('Chip', props: {'label': 'B'}),
        'flagText': {'type': 'text', 'props': {'text': r'${flag}'}, 'layout': {'width': 50, 'height': 20}},
      }),
      [chip(text: r'${props.label} ${props.on}')],
      variables: [
        const Variable(name: 'flag', type: VariableType.boolean, value: false),
        const Variable(name: 'picked', type: VariableType.text, value: ''),
      ],
    );
    expect(s.text('a/label'), 'A false');
    await tester.tapAt(s.center('a/hit'));
    await tester.pumpAndSettle();
    expect(s.scope.read('flag'), true, reason: 'the variable parameter writes the caller\'s variable');
    expect(s.text('a/label'), 'A true', reason: 'and reads it live');
    expect(s.text('flagText'), 'true');
    expect(s.scope.read('picked'), 'A', reason: 'the event ran the call\'s reaction with the payload');
    expect(s.text('a/count'), startsWith('1 '));
    expect(s.text('b/count'), startsWith('0 '), reason: 'one set of variables per instance');
  });

  testWidgets('a component can be a list\'s item template and hold a list', (tester) async {
    final list = {
      'schema': 2,
      'roots': ['col'],
      'nodes': {
        'col': {'type': 'column', 'children': ['list'], 'layout': {'width': 400, 'height': {'hug': 600}}},
        'list': {
          'type': 'listView',
          'children': ['item'],
          'bind': {'data': r'${names}'},
          'layout': {'width': 400, 'height': {'hug': 600}},
        },
        'item': call('Chip', bind: {'props.label': r'${item}'}),
      },
    };
    final s = await show(tester, list, [chip()], interactive: listInteractive, variables: [
      const Variable(name: 'names', type: VariableType.list, value: ['x', 'y', 'z']),
    ]);
    expect(s.tree.boxes.where((b) => b.id == 'label'), hasLength(3));
    expect(s.text('item/label'), 'x');
    expect(s.text('item#1/label'), 'y');
    expect(s.text('item#2/label'), 'z');
    s.scope.set('names', ['x', 'q', 'z']);
    await tester.pump();
    expect(s.text('item#1/label'), 'q');
  });

  testWidgets('a component can call another component and hold a list', (tester) async {
    final outer = {
      'schema': 2,
      'roots': ['box'],
      'widget': {
        'type': 'Pair',
        'props': [
          {'key': 'items', 'type': {'kind': 'list', 'item': {'kind': 'string'}}, 'default': []},
        ],
      },
      'nodes': {
        'box': {'type': 'column', 'children': ['first', 'rows'], 'layout': {'width': 300, 'height': {'hug': 300}}},
        'first': call('Chip', bind: {'props.label': r"${= props.items[0] + '*'}"}),
        'rows': {'type': 'listView', 'children': ['row'], 'bind': {'data': r'${props.items}'}, 'layout': {'width': 300, 'height': {'hug': 200}}},
        'row': call('Chip', bind: {'props.label': r'${item}'}),
      },
    };
    final s = await show(tester, page({'p': call('Pair', props: {'items': ['m', 'n']}, layout: {'width': 300, 'height': {'hug': 300}})}), [chip(), outer]);
    expect(s.text('p/first/label'), 'm*');
    expect(s.text('p/row/label'), 'm');
    expect(s.text('p/row#1/label'), 'n');
  });

  testWidgets('editing a definition updates every instance, re-applying only changed nodes', (tester) async {
    final s = await show(tester, page({'a': call('Chip', props: {'label': 'A'}), 'b': call('Chip', props: {'label': 'B'})}), [chip()]);
    NodeBox.debugApplyCounts.clear();
    NodeBox.debugCountApplies = true;
    addTearDown(() => NodeBox.debugCountApplies = false);
    s.registry.define(LayoutDocument.fromJson(chip(text: r'<${props.label}>')));
    await tester.pump();
    expect(s.text('a/label'), '<A>');
    expect(s.text('b/label'), '<B>');
    // The changed node in each instance; the hugging row above it measures
    // again, as after any edit of a child.
    expect(NodeBox.debugApplyCounts.keys.toSet().difference({'label', 'chip'}), isEmpty);
    expect(NodeBox.debugApplyCounts['label'], 2);
  });

  testWidgets('a missing definition renders the call\'s empty box and is reported; it renders when it arrives', (tester) async {
    final registry = ComponentRegistry();
    final doc = LayoutDocument.fromJson(page({'a': call('Chip', layout: {'width': 320, 'height': 30})}));
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: VariableScope(const [])), components: registry);
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col'))));
    expect(tree.boxOf('a')!.size, const Size(320, 30));
    expect(registry.missing['Chip'], {'a'});
    registry.define(LayoutDocument.fromJson(chip()));
    await tester.pump();
    expect(tree.boxOf('a')!.id, 'chip');
  });

  testWidgets('a component that calls itself stops at the depth limit', (tester) async {
    final loop = {
      'schema': 2,
      'roots': ['r'],
      'widget': {'type': 'Loop'},
      'nodes': {
        'r': {'type': 'column', 'children': ['again'], 'layout': {'width': 10, 'height': {'hug': 10}}},
        'again': {'type': 'Loop', 'layout': {'width': 10, 'height': {'hug': 10}}},
      },
    };
    final s = await show(tester, page({'l': call('Loop', layout: {'width': 10, 'height': {'hug': 10}})}), [loop]);
    expect(s.registry.missing['Loop']!.single, contains('component_depth'));
    expect(s.tree.boxes.where((b) => b.id == 'r'), hasLength(kMaxComponentDepth));
  });
}
