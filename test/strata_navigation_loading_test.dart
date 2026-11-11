import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  testWidgets(
    'specimen load chain completes while a container hero route enters',
    (tester) async {
      final scope = VariableScope([
        support.v('loading', false, VariableType.boolean),
      ]);
      NodeTree make(bool detail) {
        final values = NodeValues(
          DocumentSource(
            LayoutDocument.fromJson({
              'roots': ['root'],
              'nodes': {
                'root': {
                  'type': 'column',
                  'layout': {'width': 400, 'height': 800},
                  'props': {'scrollable': true},
                  'children': ['hero', 'label'],
                  if (detail)
                    'actions': [
                      support.reaction('load', [
                        {
                          'type': 'setVariable',
                          'variable': 'loading',
                          'value': 'true',
                        },
                        {'type': 'delay', 'ms': 450},
                        {
                          'type': 'setVariable',
                          'variable': 'loading',
                          'value': 'false',
                        },
                      ]),
                    ],
                },
                'hero': {
                  'type': 'box',
                  'hero': {
                    'tag': 'specimen',
                    'flight': detail ? 'morphCorners' : 'containerTransform',
                    'placeholder': 'source',
                  },
                  'layout': {'width': 300, 'height': detail ? 330 : 120},
                },
                'label': {
                  'type': 'text',
                  'layout': {'width': 300, 'height': 30},
                  'props': {'text': r'${loading}'},
                },
              },
            }),
          ),
        );
        final tree = NodeTree(values, binder: NodeBinder(scope: scope));
        final context = RuntimeActionContext(
          scope: scope,
          tree: tree,
          nodeValues: values,
          ui: const NoActionUi(),
          services: Services(),
        );
        final reactions = TreeReactions(
          runner: const CodelesslyActions(),
          context: context,
        );
        tree.interactions = reactions;
        addTearDown(() {
          reactions.dispose();
          tree.dispose();
        });
        return tree;
      }

      final first = make(false), second = make(true);
      Widget view(NodeTree tree) => Builder(
        builder: (context) {
          HeroRoutes.bind(tree, ModalRoute.of(context));
          return NodeView(tree: tree, rootId: 'root', interactive: true);
        },
      );
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: view(first)),
      );
      nav.currentState!.push(
        CodelesslyPageRoute<void>(builder: (_) => view(second)),
      );
      await tester.pump();
      await tester.pump();
      expect(scope.read('loading'), true);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(scope.read('loading'), false);
      expect(tester.takeException(), isNull);
    },
  );
}
