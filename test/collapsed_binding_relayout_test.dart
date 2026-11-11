import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets(
    'reapplying an already-collapsed bound container invalidates its clean parent before dirty wrappers',
    (tester) async {
      final (scope, tree) = await _show(
        tester,
        nodes: _nodes(constant: true),
        variables: _vars,
      );
      scope.set('shown', false);
      await tester.pump();
      expect(tree.boxOf('panel')!.collapsed, true);
      for (var value = 2; value <= 4; value++) {
        scope.set('count', value);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      scope.set('shown', true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tree.boxOf('panel')!.collapsed, false);
    },
  );
  testWidgets(
    'hidden numeric text can grow through repeated updates and lay out correctly when shown',
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
  testWidgets(
    'count glides continue while a bound metric is collapsed then shown',
    (tester) async {
      final nodes = _nodes();
      nodes['root'] = {
        ...nodes['root']!,
        'children': ['next', 'panel'],
      };
      nodes['next'] = {
        'type': 'filledButton',
        'layout': {'width': 120, 'height': 40},
        'props': {'label': 'Next wave'},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {
                'type': 'setVariable',
                'variable': 'count',
                'value': '710917',
                'animateMs': '650',
              },
            ],
          },
        ],
      };
      final (scope, tree) = await _show(tester, nodes: nodes, variables: _vars);
      scope.set('shown', false);
      await tester.pump();
      await tester.tap(find.text('Next wave'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
      scope.set('shown', true);
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
      expect(scope.read('count'), 710917);
      expect(tree.boxOf('panel')!.collapsed, false);
    },
  );
  testWidgets(
    'nested collapsed metrics dirty the outermost skipped layout path first',
    (tester) async {
      final nodes = _nodes();
      nodes['panel'] = {
        ...nodes['panel']!,
        'children': ['inner'],
      };
      nodes['inner'] = {
        'type': 'column',
        'children': ['number'],
        'layout': {
          'width': {'hug': 100},
          'height': {'hug': 40},
        },
        'bind': {'visible': r'${innerShown}'},
      };
      final (scope, tree) = await _show(
        tester,
        nodes: nodes,
        variables: [
          ..._vars,
          const Variable(
            name: 'innerShown',
            type: VariableType.boolean,
            value: true,
          ),
        ],
      );
      scope.set('innerShown', false);
      scope.set('shown', false);
      await tester.pump();
      for (final value in [10, 100, 1000]) {
        scope.set('count', value);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      scope.set('shown', true);
      await tester.pump();
      expect(tree.boxOf('inner')!.collapsed, true);
      scope.set('count', 10000);
      await tester.pump();
      expect(tester.takeException(), isNull);
      scope.set('innerShown', true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tree.boxOf('inner')!.collapsed, false);
      expect(scope.read('count'), 10000);
    },
  );
}
