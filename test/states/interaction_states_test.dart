import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

LayoutDocument page(Map<String, Map<String, Object?>> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

Future<(NodeTree, RenderObject)> show(WidgetTester tester, LayoutDocument doc, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

// A node that styles its pressed state (a button that shrinks while held)
// still runs its click reactions.
//
// A node's interaction states change how it's drawn while it's pressed or
// hovered; they must never take its taps away.

void _ours() {
  for (final (name, states) in [
    ('scale', {'pressed': {'btn': {'scale': 0.97}}}),
    ('scale + hover fill', {
      'hovered': {'btn': {'decoration': {'fills': [{'color': '#FFDDDBD6'}]}}},
      'pressed': {'btn': {'scale': 0.97}},
    }),
    ('child restyle', {'pressed': {'label': {'props': {'style': {'color': '#FF0E0E10'}}}}}),
  ]) {
    testWidgets('a tap on a node with a pressed style ($name) still runs its click', (tester) async {
      final s = await lists.show(
        tester,
        {
          'col': {
            'type': 'column',
            'children': ['btn'],
            'layout': {'width': 300, 'height': 200},
          },
          'btn': {
            'type': 'row',
            'children': ['label'],
            'layout': {'width': 160, 'height': 56},
            'decoration': {'fills': [{'color': '#FFF7F5F0'}]},
            'states': states,
            'actions': [
              lists.reaction('click', [
                {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
              ]),
            ],
          },
          'label': {'type': 'text', 'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}, 'props': {'text': 'GO'}},
        },
        variables: [lists.v('taps', 0, VariableType.integer)],
      );
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('btn'));
      await tester.pumpAndSettle();
      expect(s['taps'], 1);
    });
  }
}

void _master() {
}

// A state style may replace a node's binding (`bind` in the patch): a card
// whose border is bound to its selection keeps that rule while hovered,
// with the hover color as the fallback, as Flutter code writes
// `selected ? accent : (hover ? strong : line)`.

Map<String, Json> nodes({bool dragged = false}) => {
      'col': {
        'type': 'listView',
        'children': ['card'],
        'layout': {'width': 200, 'height': 300},
        'bind': {'data': r'${items}'},
      },
      'card': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
        'decoration': {
          'fills': [{'color': '#FFFFFFFF'}],
          'strokes': [{'color': '#FFDCE0E6'}],
        },
        'bind': {'decoration.strokes[0]': r"${= selected == item ? '#4B4DED' : '#DCE0E6'}"},
        if (dragged) 'draggable': {'group': 'card', 'data': r'${item}', 'start': 'longPress'},
        if (dragged)
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setVariable', 'variable': 'selected', 'value': r'${item}'},
              ],
            },
          ],
        'states': {
          'hovered': {
            'card': {
              'bind': {'decoration.strokes[0]': r"${= selected == item ? '#4B4DED' : '#C5CBD5'}"},
            },
          },
        },
      },
    };

Color stroke(NodeTree tree, Object? instance) => Color(tree.resolve('card', instance: instance)!.decoration.strokes.first.color!.value);

// `selected` and `disabled` bound to data drive interaction states: the
// node's state styles patch it and the nodes inside it, as hover does
// (Ninefold v2: the selected square of a 9×9 board).

api.Color? fillOf(NodeTree tree, String id, {Object? instance}) =>
    tree.boxOf(id, instance: instance)?.node?.decoration.fills.firstOrNull?.color;

void main() {
  group('hover', () {
    testWidgets('hovering a node applies its hover style', (tester) async {
      final (tree, view) = await show(
          tester,
          page({
            'b': {
              'type': 'box',
              'layout': {'width': 100, 'height': 50},
              'decoration': {
                'fills': [
                  {'color': '#FFFFFFFF'}
                ]
              },
              'inkWell': {'hoverColor': '#33000000'},
              'states': {
                'hovered': {
                  'b': {
                    'layout': {'width': 120}
                  },
                },
              },
            },
          }),
          interactive: true);
      expect(tree.boxOf('b')!.rectIn(view)!.width, 100);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(500, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      expect(tree.statesOf('b'), {api.WidgetState.hovered});
      expect(tree.boxOf('b')!.rectIn(view)!.width, 120);
      await mouse.moveTo(const Offset(300, 200));
      await tester.pump();
      expect(tree.statesOf('b'), isEmpty);
      expect(tree.boxOf('b')!.rectIn(view)!.width, 100);
    });

    for (final dragged in [false, true]) {
    testWidgets('a hover style can override a bound value while the binding\'s other cases keep working${dragged ? ', also after a drag' : ''}', (tester) async {
      final s = await harness.show(tester, nodes(dragged: dragged), variables: [
        harness.v('items', const ['a', 'b'], VariableType.list),
        harness.v('selected', ''),
      ]);
      await tester.pumpAndSettle();
      final boxes = s.tree.boxesOf('card').toList()
        ..sort((x, y) => x.localToGlobal(Offset.zero).dy.compareTo(y.localToGlobal(Offset.zero).dy));
      final first = boxes.first;
      expect(stroke(s.tree, first.instance), const Color(0xFFDCE0E6));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(500, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(first.localToGlobal(const Offset(100, 50)));
      await tester.pump();
      expect(s.tree.statesOf('card', instance: first.instance), {api.WidgetState.hovered});
      // Hovered: the state's binding.
      expect(stroke(s.tree, first.instance), const Color(0xFFC5CBD5));
      // Selected wins while hovered, as the rebinding says.
      s.scope.set('selected', 'a');
      await tester.pump();
      expect(stroke(s.tree, first.instance), const Color(0xFF4B4DED));
      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      s.scope.set('selected', '');
      await tester.pump();
      expect(stroke(s.tree, first.instance), const Color(0xFFDCE0E6));
    });
    }
  
  });

  group('pressed', () {
    _ours();
    _master();
  });

  group('selected', () {
    testWidgets('a bound selected state styles the node and its children', (tester) async {
      final screen = await harness.show(
        tester,
        {
          'col': {
            'type': 'column',
            'layout': {'width': 200, 'height': 200},
            'children': ['cell'],
          },
          'cell': {
            'type': 'stack',
            'layout': {'width': 40, 'height': 40},
            'decoration': {
              'fills': [
                {'color': '#FFFAF6EC'},
              ],
            },
            'bind': {'selected': r'${= sel == 4}'},
            'states': {
              'selected': {
                'cell': {
                  'decoration': {
                    'fills': [
                      {'color': '#FFF7DDD3'},
                    ],
                  },
                },
                'ring': {'visible': true},
              },
            },
            'children': ['ring'],
          },
          'ring': {
            'type': 'box',
            'visible': false,
            'layout': {'width': 36, 'height': 36},
          },
        },
        variables: [harness.v('sel', 0, VariableType.integer)],
      );
      expect(screen.tree.statesOf('cell'), isEmpty);
      expect(fillOf(screen.tree, 'cell'), const api.Color(0xFFFAF6EC));
      expect(screen.tree.boxOf('ring')!.node!.visible, isFalse);

      screen.scope.set('sel', 4);
      await tester.pump();
      expect(screen.tree.statesOf('cell'), {api.WidgetState.selected});
      expect(fillOf(screen.tree, 'cell'), const api.Color(0xFFF7DDD3));
      expect(screen.tree.boxOf('ring')!.node!.visible, isTrue);

      screen.scope.set('sel', 5);
      await tester.pump();
      expect(screen.tree.statesOf('cell'), isEmpty);
      expect(fillOf(screen.tree, 'cell'), const api.Color(0xFFFAF6EC));
      expect(screen.tree.boxOf('ring')!.node!.visible, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each item of a grid has its own selected state', (tester) async {
      final screen = await harness.show(
        tester,
        {
          'col': {
            'type': 'column',
            'layout': {'width': 300, 'height': 300},
            'children': ['grid'],
          },
          'grid': {
            'type': 'gridView',
            'layout': {'width': 270, 'height': 90},
            'props': {'crossAxisCount': 3},
            'bind': {'data': r'${cells}'},
            'children': ['cell'],
          },
          'cell': {
            'type': 'box',
            'layout': {'width': 30, 'height': 30},
            'decoration': {
              'fills': [
                {'color': '#FFFFFFFF'},
              ],
            },
            'bind': {'selected': r'${= item.i == sel}', 'disabled': r'${item.given}'},
            'states': {
              'selected': {
                'cell': {
                  'decoration': {
                    'fills': [
                      {'color': '#FFFF0000'},
                    ],
                  },
                },
              },
              'disabled': {
                'cell': {'opacity': 0.5},
              },
            },
          },
        },
        variables: [
          harness.v('sel', 1, VariableType.integer),
          harness.v('cells', [
            for (var i = 0; i < 6; i++) {'i': i, 'given': i == 2},
          ], VariableType.list),
        ],
      );
      await tester.pump();
      final instances = [
        for (final b in screen.tree.boxesOf('cell')) b.instance,
      ];
      expect(instances, hasLength(6));
      final selected = [
        for (final i in instances)
          if (screen.tree.statesOf('cell', instance: i).contains(api.WidgetState.selected)) i,
      ];
      expect(selected, hasLength(1));
      final disabled = [
        for (final i in instances)
          if (screen.tree.statesOf('cell', instance: i).contains(api.WidgetState.disabled)) i,
      ];
      expect(disabled, hasLength(1));
      screen.scope.set('sel', 4);
      await tester.pump();
      final after = [
        for (final i in instances)
          if (screen.tree.statesOf('cell', instance: i).contains(api.WidgetState.selected)) i,
      ];
      expect(after, hasLength(1));
      expect(after, isNot(selected));
      expect(tester.takeException(), isNull);
    });
  });
}
