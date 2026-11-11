// The node tree with bindings: SDK 8.x's runtime results for bound
// visibility (collapse), size, flex, paints, text interpolation, conditions
// and data-bound lists, and a design canvas's placeholders.
import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument page(Map<String, Map<String, Object?>> nodes, {String root = 'col', Map<String, Object?> extra = const {}}) =>
    LayoutDocument.fromJson({
      'roots': [root],
      'nodes': nodes,
      ...extra,
    });

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(id: name, name: name, type: type, value: type.coerce(value));

Future<(NodeTree, RenderObject)> show(WidgetTester tester, LayoutDocument doc, NodeBinder? binder, {String root = 'col'}) async {
  final tree = NodeTree(DocumentSource(doc), binder: binder);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

/// A hugging column of three 100×20 boxes, 10 apart.
Map<String, Map<String, Object?>> column({Map<String, String> bindB = const {}, bool bVisible = true}) => {
      'col': {
        'type': 'column',
        'children': ['a', 'b', 'c'],
        'layout': {'width': 100, 'height': {'hug': 80}},
        'props': {'spacing': 10, 'crossAxisAlignment': 'start'},
      },
      for (final id in ['a', 'b', 'c'])
        id: {
          'type': 'box',
          'layout': {'width': 100, 'height': 20},
          'decoration': {'fills': [{'id': 'p', 'color': '#FF000000'}]},
          if (id == 'b' && bindB.isNotEmpty) 'bind': bindB,
          if (id == 'b' && !bVisible) 'visible': false,
        },
    };

String paragraphText(NodeTree tree, String id) {
  final box = tree.boxOf(id)!;
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(box);
  return found!.text.toPlainText();
}

void main() {
  testWidgets('a node a binding hides collapses: no space, no gap', (tester) async {
    final vars = VariableScope([v('shown', false, VariableType.boolean)]);
    final (tree, view) = await show(tester, page(column(bindB: {'visible': r'${shown}'})), NodeBinder(scope: vars));
    expect(tree.boxOf('b')!.collapsed, isTrue);
    expect(tree.boxOf('c')!.rectIn(view), const Rect.fromLTWH(0, 30, 100, 20));
    expect(tree.boxOf('col')!.rectIn(view)!.height, 50);

    vars.set('shown', true);
    await tester.pump();
    expect(tree.boxOf('b')!.collapsed, isFalse);
    expect(tree.boxOf('b')!.rectIn(view), const Rect.fromLTWH(0, 30, 100, 20));
    expect(tree.boxOf('c')!.rectIn(view), const Rect.fromLTWH(0, 60, 100, 20));
    expect(tree.boxOf('col')!.rectIn(view)!.height, 80);
  });

  testWidgets('collapsed text stays layout-safe across font and repeated binding updates', (tester) async {
    final vars = VariableScope([v('shown', true, VariableType.boolean), v('message', 'First')]);
    final nodes = column(bindB: {'visible': r'${shown}'});
    nodes['b'] = {...nodes['b']!, 'type': 'text', 'props': {'text': r'${message}'}};
    final (tree, _) = await show(tester, page(nodes), NodeBinder(scope: vars));
    RenderParagraph? paragraph;
    void visit(RenderObject object) {
      if (object is RenderParagraph) paragraph = object;
      object.visitChildren(visit);
    }
    visit(tree.boxOf('b')!);
    vars.set('shown', false);
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      paragraph!.systemFontsDidChange();
      vars.set('message', 'Update $i');
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    vars.set('shown', true);
    await tester.pump();
    expect(paragraphText(tree, 'b'), 'Update 2');
  });

  testWidgets('a node hidden in its own data keeps its space', (tester) async {
    final (tree, view) = await show(tester, page(column(bVisible: false)), NodeBinder(scope: VariableScope(const [])));
    expect(tree.boxOf('b')!.collapsed, isFalse);
    expect(tree.boxOf('c')!.rectIn(view), const Rect.fromLTWH(0, 60, 100, 20));
  });

  testWidgets('without a binder, bindings are inert (the static render)', (tester) async {
    final (tree, view) = await show(tester, page(column(bindB: {'visible': r'${= false}', 'layout.height': '50'})), null);
    expect(tree.boxOf('b')!.collapsed, isFalse);
    expect(tree.boxOf('c')!.rectIn(view), const Rect.fromLTWH(0, 60, 100, 20));
  });

  testWidgets('bound size and paint re-apply only the boxes that read them', (tester) async {
    final vars = VariableScope([v('h', 40, VariableType.integer), v('tint', '#FF00FF00', VariableType.color), v('other', 1, VariableType.integer)]);
    final (tree, view) = await show(
      tester,
      page(column(bindB: {'layout.height': r'${h}', 'decoration.fills.p': r'${tint}'})),
      NodeBinder(scope: vars),
    );
    expect(tree.boxOf('b')!.rectIn(view)!.height, 40);
    expect(tree.boxOf('b')!.node!.decoration.fills.single.color, const api.Color(0xFF00FF00));
    expect(tree.boxOf('c')!.rectIn(view)!.top, 80);

    NodeBox.debugCountApplies = true;
    addTearDown(() => NodeBox.debugCountApplies = false);
    NodeBox.debugApplyCounts.clear();
    vars.set('h', 25);
    await tester.pump();
    expect(NodeBox.debugApplyCounts.keys, ['b']);
    expect(tree.boxOf('b')!.rectIn(view)!.height, 25);
    expect(tree.boxOf('c')!.rectIn(view)!.top, 65);

    NodeBox.debugApplyCounts.clear();
    vars.set('other', 2);
    await tester.pump();
    expect(NodeBox.debugApplyCounts, isEmpty);
  });

  testWidgets('a bound flex shares a row', (tester) async {
    final vars = VariableScope([v('n', 3, VariableType.integer)]);
    final (tree, view) = await show(
      tester,
      page({
        'row': {
          'type': 'row',
          'children': ['a', 'b'],
          'layout': {'width': 400, 'height': 20},
        },
        'a': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': 20}},
        'b': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': 20}, 'bind': {'layout.flex': r'${n}'}},
      }, root: 'row'),
      NodeBinder(scope: vars),
      root: 'row',
    );
    expect(tree.boxOf('a')!.rectIn(view)!.width, 100);
    expect(tree.boxOf('b')!.rectIn(view)!.width, 300);
    vars.set('n', 1);
    await tester.pump();
    expect(tree.boxOf('b')!.rectIn(view)!.width, 200);
  });

  testWidgets('a collapsed fill child gives its share to the others', (tester) async {
    final vars = VariableScope([v('show', false, VariableType.boolean)]);
    final (tree, view) = await show(
      tester,
      page({
        'row': {
          'type': 'row',
          'children': ['a', 'b'],
          'layout': {'width': 400, 'height': 20},
          'props': {'spacing': 20},
        },
        'a': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': 20}},
        'b': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': 20}, 'bind': {'visible': r'${show}'}},
      }, root: 'row'),
      NodeBinder(scope: vars),
      root: 'row',
    );
    expect(tree.boxOf('a')!.rectIn(view)!.width, 400);
    vars.set('show', true);
    await tester.pump();
    expect(tree.boxOf('a')!.rectIn(view)!.width, 190);
  });

  testWidgets('text interpolates, each run in its style', (tester) async {
    final vars = VariableScope([v('name', 'Ava'), v('count', 3, VariableType.integer)]);
    final (tree, _) = await show(
      tester,
      page({
        'col': {'type': 'column', 'children': ['t'], 'layout': {'width': 300, 'height': {'hug': 20}}},
        't': {
          'type': 'text',
          'layout': {'width': {'hug': 100}, 'height': {'hug': 20}},
          'props': {
            'text': r'Hi ${name}, ${= count * 2} items ${missing}!',
            'runs': [
              {'start': 0, 'end': 10, 'style': {'fontWeight': 700}},
              {'start': 10, 'end': 44, 'style': {'fontWeight': 400}},
            ],
          },
        },
      }),
      NodeBinder(scope: vars),
    );
    expect(paragraphText(tree, 't'), 'Hi Ava, 6 items !');
    final runs = tree.boxOf('t')!.node!.prop(TextProps.runs);
    expect([for (final r in runs) (r.start, r.end)], [(0, 6), (6, 17)]);
    vars.set('name', 'Ben');
    await tester.pump();
    expect(paragraphText(tree, 't'), 'Hi Ben, 6 items !');
  });

  testWidgets('a design canvas shows placeholders, or the defaults it is given', (tester) async {
    final doc = page({
      'col': {'type': 'column', 'children': ['t'], 'layout': {'width': 300, 'height': {'hug': 20}}},
      't': {
        'type': 'text',
        'layout': {'width': {'hug': 100}, 'height': {'hug': 20}},
        'props': {'text': r'Hi ${user.displayName} (${= count + 1})'},
        'bind': {'visible': r'${= count > 5}'},
      },
    });
    var (tree, _) = await show(tester, doc, NodeBinder(preview: true));
    expect(paragraphText(tree, 't'), 'Hi Display name (Count)');
    expect(tree.boxOf('t')!.collapsed, isFalse);
    (tree, _) = await show(
      tester,
      doc,
      NodeBinder(preview: true, scope: VariableScope([v('count', 2, VariableType.integer)])),
    );
    expect(paragraphText(tree, 't'), 'Hi Display name (3)');
    expect(tree.boxOf('t')!.collapsed, isTrue, reason: 'v1 previewed bound visibility with the defaults');
  });

  testWidgets('conditions win over bindings', (tester) async {
    final vars = VariableScope([v('stock', 2, VariableType.integer), v('o', 1, VariableType.decimal)]);
    final doc = page(column(bindB: {'opacity': r'${o}'}), extra: {
      'conditions': {
        'col': [
          {
            'id': 'k',
            'branches': [
              {
                'when': {'left': r'${stock}', 'op': 'lessThan', 'right': '5'},
                'set': [
                  {'node': 'b', 'path': 'opacity', 'value': 0.25},
                  {'node': 'c', 'path': 'visible', 'value': 'false'},
                ],
              },
              {
                'set': [
                  {'node': 'c', 'path': 'visible', 'value': true},
                ],
              },
            ],
          },
        ],
      },
    });
    final (tree, view) = await show(tester, doc, NodeBinder(scope: vars, logic: doc.logic));
    expect(tree.boxOf('b')!.node!.opacity, 0.25);
    expect(tree.boxOf('c')!.collapsed, isTrue);
    vars.set('stock', 9);
    await tester.pump();
    // The else branch sets nothing for b: its binding gives it its value.
    expect(tree.boxOf('b')!.node!.opacity, 1);
    expect(tree.boxOf('c')!.collapsed, isFalse);
    expect(tree.boxOf('c')!.rectIn(view)!.top, 60);
  });

  testWidgets('a list bound to data builds one item per element, each reading its own', (tester) async {
    final vars = VariableScope([
      v('rows', ['Ada', 'Ben', 'Cy'], VariableType.list),
      v('prefix', '#'),
    ]);
    final (tree, view) = await show(
      tester,
      page({
        'list': {
          'type': 'listView',
          'children': ['item'],
          'layout': {'width': 200, 'height': {'hug': 60}},
          'props': {'itemCount': 1},
          'bind': {'data': r'${rows}'},
        },
        'item': {
          'type': 'text',
          'layout': {'width': 200, 'height': 20},
          'props': {'text': r'${prefix}${index} ${item}'},
        },
      }, root: 'list'),
      NodeBinder(scope: vars),
      root: 'list',
    );
    expect(tree.boxOf('list')!.node!.prop(CollectionScrollProps.itemCount), 3);
    final texts = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) texts.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    visit(tree.boxOf('list')!);
    expect(texts, ['#0 Ada', '#1 Ben', '#2 Cy']);
    expect(view, isNotNull);

    vars.set('rows', ['Zed', 'Yan']);
    await tester.pump();
    texts.clear();
    visit(tree.boxOf('list')!);
    expect(texts, ['#0 Zed', '#1 Yan']);
  });
}
