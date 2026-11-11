import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scroll metrics drive variables; scrollEnd and animated scrollTo fire',
    (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['body'],
        'nodes': {
          'body': {
            'type': 'column',
            'layout': {'width': 200, 'height': 120},
            'props': {'scrollable': true},
            'children': ['a', 'b'],
            'actions': [
              {
                'trigger': {'type': 'scroll'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'offset',
                    'value': r'${result.offset}',
                  },
                  {
                    'type': 'setVariable',
                    'variable': 'progress',
                    'value': r'${result.progress}',
                  },
                ],
              },
              {
                'trigger': {'type': 'scrollEnd'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'ended',
                    'op': 'add',
                    'value': '1',
                  },
                ],
              },
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {
                    'type': 'scrollTo',
                    'node': 'b',
                    'durationMs': 200,
                    'axis': 'vertical',
                  },
                ],
              },
            ],
          },
          'a': {
            'type': 'box',
            'layout': {'width': 200, 'height': 120},
          },
          'b': {
            'actions': [
              {
                'trigger': {'type': 'enterViewport', 'visibleFraction': .9},
                'actions': [
                  {'type': 'setVariable', 'variable': 'entered', 'value': '1'},
                ],
              },
            ],
            'type': 'box',
            'layout': {'width': 200, 'height': 120},
          },
        },
      });
      final values = NodeValues(DocumentSource(doc));
      final scope = VariableScope([
        const Variable(
          id: 'v',
          name: 'entered',
          type: VariableType.integer,
          value: 0,
        ),
        const Variable(
          id: 'o',
          name: 'offset',
          type: VariableType.decimal,
          value: 0.0,
        ),
        const Variable(
          id: 'p',
          name: 'progress',
          type: VariableType.decimal,
          value: 0.0,
        ),
        const Variable(
          id: 'e',
          name: 'ended',
          type: VariableType.integer,
          value: 0,
        ),
      ]);
      final tree = NodeTree(values, binder: NodeBinder(scope: scope));
      final context = RuntimeActionContext(
        scope: scope,
        tree: tree,
        nodeValues: values,
      );
      tree.interactions = TreeReactions(
        runner: const CodelesslyActions(),
        context: context,
      );
      addTearDown(tree.dispose);
      addTearDown(scope.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: NodeView(tree: tree, rootId: 'body', interactive: true),
          ),
        ),
      );
      expect(visibleShare(tree.boxOf('b')!), 0);
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(80, 80),
          scrollDelta: Offset(0, 50),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(scope.read('offset'), 50);
      expect(scope.read('progress'), closeTo(50 / 120, 1e-6));
      await tester.pump(const Duration(milliseconds: 120));
      expect(scope.read('ended'), 1);
      final move = const CodelesslyActions().trigger(
        doc['body']!,
        'click',
        context,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        (scope.read('offset') as num).toDouble(),
        inExclusiveRange(50, 120),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await move;
      await tester.pump();
      expect(scope.read('offset'), 120);
      expect(scope.read('progress'), 1);
      expect(visibleShare(tree.boxOf('b')!), 1);
      expect(scope.read('entered'), 1);
      expect(tree.boxOf('b')!.localToGlobal(Offset.zero).dy, closeTo(0, 1e-6));
      await tester.pump(const Duration(milliseconds: 120));
    },
  );
}
