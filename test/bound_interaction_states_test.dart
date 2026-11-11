// `selected` and `disabled` bound to data drive interaction states: the
// node's state styles patch it and the nodes inside it, as hover does
// (Ninefold v2: the selected square of a 9×9 board).
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

api.Color? fillOf(NodeTree tree, String id, {Object? instance}) =>
    tree.boxOf(id, instance: instance)?.node?.decoration.fills.firstOrNull?.color;

void main() {
  testWidgets('a bound selected state patches the node and its children', (tester) async {
    final screen = await show(
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
      variables: [v('sel', 0, VariableType.integer)],
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

  testWidgets('each repeat of a grid holds its own selected state', (tester) async {
    final screen = await show(
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
        v('sel', 1, VariableType.integer),
        v('cells', [
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
}
