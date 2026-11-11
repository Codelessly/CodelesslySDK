import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Screen {
  _Screen(this.scope, this.tree);
  final VariableScope scope;
  final NodeTree tree;
}

Future<_Screen> _show(
  WidgetTester tester,
  String type, {
  bool controlled = true,
  bool expression = false,
  bool enabled = true,
  bool interactive = true,
  bool reactions = true,
}) async {
  final source = DocumentSource(
    LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {
          'type': 'column',
          'children': ['chip'],
          'layout': {'width': 390, 'height': 200},
          'props': {'crossAxisAlignment': 'start'},
        },
        'chip': {
          'type': type,
          'layout': {
            'width': {'hug': 0},
            'height': {'hug': 0},
          },
          'props': {'label': 'North', 'isEnabled': enabled},
          if (controlled)
            'bind': {
              'props.selected': expression
                  ? r'${= region == "North"}'
                  : r'${selected}',
            },
          if (reactions)
            'actions': [
              {
                'trigger': {'type': 'changed'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'changes',
                    'op': 'add',
                    'value': '1',
                  },
                  {
                    'type': 'setVariable',
                    'variable': 'last',
                    'value': r'${result}',
                  },
                  if (expression)
                    {
                      'type': 'setVariable',
                      'variable': 'region',
                      'value': 'North',
                    },
                ],
              },
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'clicks',
                    'op': 'add',
                    'value': '1',
                  },
                  {
                    'type': 'setVariable',
                    'variable': 'clickSawSelection',
                    'value': r'${selected}',
                  },
                ],
              },
            ],
        },
      },
    }),
  );
  final scope = VariableScope([
    const Variable(name: 'selected', type: VariableType.boolean, value: false),
    const Variable(name: 'region', value: 'All regions'),
    const Variable(name: 'changes', type: VariableType.integer, value: 0),
    const Variable(name: 'clicks', type: VariableType.integer, value: 0),
    const Variable(name: 'last', type: VariableType.boolean, value: false),
    const Variable(
      name: 'clickSawSelection',
      type: VariableType.boolean,
      value: false,
    ),
  ]);
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  final actions = TreeReactions(
    runner: const CodelesslyActions(),
    context: RuntimeActionContext(scope: scope, tree: tree),
  );
  tree.interactions = actions;
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 'root', interactive: interactive),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    actions.dispose();
    tree.dispose();
    scope.dispose();
  });
  return _Screen(scope, tree);
}

bool _selected(WidgetTester tester, String type) => type == 'choiceChip'
    ? tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected
    : tester.widget<FilterChip>(find.byType(FilterChip)).selected;

void main() {
  for (final type in ['choiceChip', 'filterChip']) {
    testWidgets(
      '$type pointer selection writes its boolean binding and reports changed/click once',
      (tester) async {
        final s = await _show(tester, type);
        expect(_selected(tester, type), isFalse);
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        expect(_selected(tester, type), isTrue);
        expect(s.scope.read('selected'), true);
        expect(s.scope.read('last'), true);
        expect(s.scope.read('changes'), 1);
        expect(s.scope.read('clicks'), 1);
        expect(
          s.scope.read('clickSawSelection'),
          true,
          reason: 'writeback and changed precede click',
        );
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        expect(_selected(tester, type), isFalse);
        expect(s.scope.read('selected'), false);
        expect(s.scope.read('last'), false);
        expect(s.scope.read('changes'), 2);
        expect(s.scope.read('clicks'), 2);
      },
    );
    testWidgets(
      '$type binding is controlled by external updates and not an optimistic local latch',
      (tester) async {
        final s = await _show(tester, type);
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        s.scope.set('selected', false);
        await tester.pumpAndSettle();
        expect(_selected(tester, type), false);
        s.scope.set('selected', true);
        await tester.pumpAndSettle();
        expect(_selected(tester, type), true);
      },
    );
    testWidgets(
      '$type computed selection follows changed actions, including a rejected deselection',
      (tester) async {
        final s = await _show(tester, type, expression: true);
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        expect(s.scope.read('region'), 'North');
        expect(_selected(tester, type), true);
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        expect(s.scope.read('last'), false);
        expect(
          _selected(tester, type),
          true,
          reason: 'the bound region still selects North',
        );
        expect(s.scope.read('changes'), 2);
        expect(s.scope.read('clicks'), 2);
      },
    );
    testWidgets('$type unbound native selection toggles locally', (
      tester,
    ) async {
      await _show(tester, type, controlled: false, reactions: false);
      await tester.tap(find.text('North'));
      await tester.pumpAndSettle();
      expect(_selected(tester, type), true);
      await tester.tap(find.text('North'));
      await tester.pumpAndSettle();
      expect(_selected(tester, type), false);
    });
    testWidgets(
      '$type boolean binding writes back even without explicit reactions',
      (tester) async {
        final s = await _show(tester, type, reactions: false);
        await tester.tap(find.text('North'));
        await tester.pumpAndSettle();
        expect(s.scope.read('selected'), true);
        expect(_selected(tester, type), true);
      },
    );
    for (final disabled in ['disabled', 'design']) {
      testWidgets('$type $disabled receives no selection actions', (
        tester,
      ) async {
        final s = await _show(
          tester,
          type,
          enabled: disabled != 'disabled',
          interactive: disabled != 'design',
        );
        await tester.tap(find.text('North'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(_selected(tester, type), false);
        expect(s.scope.read('selected'), false);
        expect(s.scope.read('changes'), 0);
        expect(s.scope.read('clicks'), 0);
      });
    }
  }
}
