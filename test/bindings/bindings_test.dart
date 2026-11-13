import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// The node tree with bindings: runtime results for bound
// visibility (collapse), size, flex, paints, text interpolation, conditions
// and data-bound lists, and a design canvas's placeholders.

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

// A binding of a paint the node doesn't have yet (`decoration.fills[0]` on
// a node with no fills) adds it: Wireless's sidebar highlights the open
// show with a fill bound on a row that has none at design time.

LayoutDocument doc(Map<String, Object?> decoration, Map<String, Object?> bind) => LayoutDocument.fromJson({
      'roots': ['row'],
      'nodes': {
        'row': {
          'type': 'box',
          'layout': {'width': 64, 'height': 64},
          'decoration': decoration,
          'bind': bind,
        },
      },
    });

Node bound(LayoutDocument d, VariableScope vars) =>
    NodeBinder(scope: vars).bind(DocumentSource(d), d.nodes['row']!, null).node;

// A layout width bound to an axis size object ({"hug": 0} / {"fill": 1}):
// the first item of a horizontal list hugs, the others fill.

// A deep prop path binding (props.decoration.enabledBorder.borderSide.color)
// on a list item follows its item when the item changes, as plain prop
// bindings do.

Future<(VariableScope, NodeTree)> _show(
  WidgetTester tester, {
  required Map<String, Json> nodes,
  required List<Variable> variables,
}) async {
  final scope = VariableScope(variables);
  final tree = NodeTree(
    DocumentSource(
      LayoutDocument.fromJson({
        'roots': ['root'],
        'nodes': nodes,
      }),
    ),
    binder: NodeBinder(scope: scope),
  );
  final reactions = TreeReactions(
    runner: const CodelesslyActions(),
    context: RuntimeActionContext(scope: scope, tree: tree),
  );
  tree.interactions = reactions;
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 'root', interactive: true),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    reactions.dispose();
    tree.dispose();
    scope.dispose();
  });
  return (scope, tree);
}

const _vars = [
  Variable(name: 'shown', type: VariableType.boolean, value: true),
  Variable(name: 'count', type: VariableType.integer, value: 1),
];
Map<String, Json> _nodes({bool constant = false}) => {
  'root': {
    'type': 'column',
    'children': ['panel'],
    'layout': {'width': 300, 'height': 300},
    'props': {'crossAxisAlignment': 'start'},
  },
  'panel': {
    'type': 'column',
    'children': ['number'],
    'layout': {
      'width': {'hug': 100},
      'height': {'hug': 40},
      'padding': 8,
    },
    'props': {'crossAxisAlignment': 'stretch'},
    'bind': {'visible': constant ? r'${= shown && count >= 0}' : r'${shown}'},
  },
  'number': {
    'type': 'text',
    'layout': {
      'width': {'hug': 50},
      'height': {'hug': 30},
    },
    'props': {
      'text': constant ? 'Tally' : r'${count}',
      'style': {'fontSize': 24},
    },
  },
};

void main() {
  testWidgets('a node hidden by a binding takes no space and leaves no gap', (tester) async {
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

  testWidgets('a node saved as hidden keeps its space', (tester) async {
    final (tree, view) = await show(tester, page(column(bVisible: false)), NodeBinder(scope: VariableScope(const [])));
    expect(tree.boxOf('b')!.collapsed, isFalse);
    expect(tree.boxOf('c')!.rectIn(view), const Rect.fromLTWH(0, 60, 100, 20));
  });

  testWidgets('a document shown without variables leaves its bindings alone', (tester) async {
    final (tree, view) = await show(tester, page(column(bindB: {'visible': r'${= false}', 'layout.height': '50'})), null);
    expect(tree.boxOf('b')!.collapsed, isFalse);
    expect(tree.boxOf('c')!.rectIn(view), const Rect.fromLTWH(0, 60, 100, 20));
  });

  testWidgets('a bound size and a bound color follow their variables, and only the nodes reading them update', (tester) async {
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

  testWidgets('bound flex values share out a row', (tester) async {
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

  testWidgets('a hidden fill child gives its share to the others', (tester) async {
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

  testWidgets('text fills in its variables, each run keeping its style', (tester) async {
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

  testWidgets('on the design canvas bound text shows placeholders, or the sample values it is given', (tester) async {
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
    expect(tree.boxOf('t')!.collapsed, isTrue, reason: 'bound visibility previews with the defaults');
  });

  testWidgets('a condition wins over a binding on the same value', (tester) async {
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

  group('bound fills', () {
    {
      final vars = VariableScope([const Variable(id: 'on', name: 'on', type: VariableType.boolean, value: true)]);

      test('a bound fill is added to a node that has none', () {
        final n = bound(doc({'radius': 10}, {'decoration.fills[0]': r"${= on ? '#22F4E9D3' : '#00000000'}"}), vars);
        expect(n.decoration.fills, hasLength(1));
        expect(n.decoration.fills.single.color?.toJson(), '#22F4E9D3');
      });

      test('a bound fill replaces the one the node has', () {
        final n = bound(doc({'fills': [{'color': '#FF000000'}]}, {'decoration.fills[0]': '#FFFFFFFF'}), vars);
        expect(n.decoration.fills.single.color?.toJson(), '#FFFFFFFF');
      });
    }

    {
      test('an image fill bound to a variable or a formula follows it', () {
        Set<String> reads(String url) => Expressions.readsOf(url).map(rootOf).toSet();
        expect(reads(r'${fArt}'), {'fArt'});
        expect(reads(r'${= editing ? record.art : fallback}'), {'editing', 'record', 'fallback'});
        expect(reads('https://x/y.jpg'), isEmpty);
      });
    }
  });

  group('bound sizes', () {
    testWidgets('a width bound to hug or fill sizes each item', (tester) async {
      final s = await harness.show(
        tester,
        {
          'col': {'type': 'column', 'children': ['path'], 'layout': {'width': 300, 'height': 100}},
          'path': {
            'type': 'listView',
            'children': ['step'],
            'layout': {'width': 300, 'height': {'hug': 0}},
            'props': {'scrollDirection': 'horizontal', 'scrollable': false},
            'bind': {'data': r'${steps}'},
          },
          'step': {
            'type': 'row',
            'children': ['dot'],
            'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
            'props': {'mainAxisAlignment': 'end'},
            'bind': {'layout.width': r"${= index == 0 ? {'hug': 0} : {'fill': 1}}"},
          },
          'dot': {'type': 'box', 'layout': {'width': 22, 'height': 22}, 'decoration': {'fills': [{'color': '#FF0000FF'}]}},
        },
        variables: [harness.v('steps', [1, 2, 3], VariableType.list)],
      );
      await tester.pumpAndSettle();
      final rects = [
        for (var i = 0; i < 3; i++)
          (s.tree.boxOf('step', instance: ('item', null, 'path', i)) ?? (i == 0 ? s.tree.boxOf('step') : null))?.paintBounds,
      ];
      expect(rects[0]?.width, 22);
      expect(rects[1]?.width, closeTo((300 - 22) / 2, 0.5));
      expect(rects[2]?.width, closeTo((300 - 22) / 2, 0.5));
    });
  });

  group('list items', () {
    for (final (interactive, tickers) in [(false, true), (true, true), (false, false)]) {
      testWidgets('a list item\'s bound border follows its item\'s data (interactive: $interactive, tickers: $tickers)', (tester) async {
        final doc = LayoutDocument.fromJson({
          'roots': ['l'],
          'nodes': {
            'l': {'type': 'listView', 'children': ['f'], 'layout': {'width': 220, 'height': {'hug': 40}}, 'props': {'scrollable': false}, 'bind': {'data': r'${rows}'}},
            'f': {
              'type': 'textField',
              'layout': {'width': {'fill': 100}, 'height': 34},
              'props': {'maxLines': 1, 'decoration': {'enabledBorder': {'borderRadius': 0, 'borderSide': {'color': '#FF00FF00'}}}},
              'bind': {
                'props.initialValue': r'${item.tag} ${item.error}',
                'props.decoration.enabledBorder.borderSide.color': r"${= item.error != '' ? '#FFFF0000' : '#FF0000FF'}",
              },
            },
          },
        });
        final scope = VariableScope([
          Variable(name: 'rows', type: api.VariableType.list, value: [{'tag': 'x', 'error': 'bad'}]),
        ]);
        final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope, preview: !interactive));
        addTearDown(tree.dispose);
        await tester.pumpWidget(MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
            child: RepaintBoundary(key: const Key('shot'), child: TickerMode(enabled: tickers, child: NodeView(tree: tree, rootId: 'l', interactive: interactive)))))));
        await tester.pump();
        // What is painted: on a design canvas (tickers off) the decorator's
        // border animation never runs, so its widget can be right while the
        // border it paints is the old one.
        Future<Color> side() async {
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
          late final Uint8List bytes;
          late final int width;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            width = image.width;
            bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
          });
          // The middle of the field's top border.
          final i = (0 * width + 110) * 4;
          return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
        }
        expect(await side(), const Color(0xFFFF0000));
        scope.set('rows', [{'tag': 'x', 'error': ''}]);
        await tester.pump();
        await tester.pump();
        expect(await side(), const Color(0xFF0000FF));
      });
    }
  });

  group('hidden nodes', () {
    testWidgets(
      'a hidden text can change while hidden and lays out correctly when shown',
      (tester) async {
        final (scope, tree) = await _show(
          tester,
          nodes: _nodes(),
          variables: _vars,
        );
        scope.set('shown', false);
        await tester.pump();
        for (final value in [10, 100, 1000, 1000000]) {
          scope.set('count', value);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        scope.set('shown', true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final view = tester.renderObject(find.byType(NodeView));
        final number = tree.boxOf('number')!.rectIn(view)!;
        expect(number.width, greaterThan(100));
        expect(tree.boxOf('panel')!.rectIn(view)!.height, greaterThan(24));
      },
    );
  });
}
