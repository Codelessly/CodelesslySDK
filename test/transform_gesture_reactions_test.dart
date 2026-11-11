// A transform gesture's pinch on a node that also has tap, double-tap and
// drag reactions (a graph surface: tap to pick, double tap to zoom, drag to
// trace), with a content target and no bounds.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transform_gesture_test.dart' show twoFingers, v;

Json react(String trigger) => {
  'trigger': {'type': trigger},
  'actions': [
    {'type': 'setVariable', 'variable': 'hits', 'op': 'add', 'value': trigger},
  ],
};

Future<VariableScope> surface(WidgetTester tester, List<String> reactions, {String pan = 'always'}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['board'],
    'nodes': {
      'board': {'type': 'stack', 'children': ['p'], 'layout': {'width': 400, 'height': 400}},
      'p': {
        'type': 'box',
        'layout': {'width': 200, 'height': 200, 'x': {'start': 100}, 'y': {'start': 100}},
        'transformGesture': {
          'target': 'content', 'bounds': 'none', 'minScale': 0.00001, 'maxScale': 40000, 'doubleTapScale': 0,
          'pan': pan, 'xVariable': 'tx', 'yVariable': 'ty', 'scaleVariable': 'ts', 'physics': {'fling': false},
        },
        'actions': [for (final r in reactions) react(r)],
      },
    },
  });
  final scope = VariableScope([v('tx', 0), v('ty', 0), v('ts', 1), v('hits', const <Object?>[], VariableType.list)]);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final r = TreeReactions(runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values));
  tree.interactions = r;
  addTearDown(() {
    r.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'board', interactive: true))));
  await tester.pump();
  return scope;
}

Future<void> oneFinger(WidgetTester tester) async {
  final g = await tester.startGesture(const Offset(200, 200), pointer: 9);
  for (var i = 0; i < 12; i++) {
    await g.moveBy(const Offset(6, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('trace mode (pan: never): one finger drags, two fingers still pinch, then one finger drags again', (tester) async {
    final scope = await surface(tester, ['drag'], pan: 'never');
    await oneFinger(tester);
    final drags = (scope.read('hits')! as List).length;
    expect(drags, greaterThan(0));
    expect(scope.read('tx'), 0);
    await twoFingers(tester, const Offset(190, 200), const Offset(210, 200), const Offset(150, 200), const Offset(250, 200));
    await tester.pumpAndSettle();
    expect(scope.read('ts'), greaterThan(3));
    await oneFinger(tester);
    expect((scope.read('hits')! as List).length, greaterThan(drags));
  });

  for (final reactions in [<String>[], ['click'], ['doubleTap'], ['drag'], ['click', 'doubleTap', 'drag']]) {
    testWidgets('a pinch zooms with ${reactions.isEmpty ? 'no' : reactions.join(', ')} reactions', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['board'],
        'nodes': {
          'board': {'type': 'stack', 'children': ['p'], 'layout': {'width': 400, 'height': 400}},
          'p': {
            'type': 'box',
            'layout': {'width': 200, 'height': 200, 'x': {'start': 100}, 'y': {'start': 100}},
            'transformGesture': {
              'target': 'content', 'bounds': 'none', 'minScale': 0.00001, 'maxScale': 40000, 'doubleTapScale': 0,
              'wheel': 'zoom', 'physics': {'fling': true, 'friction': 0.9975, 'overscroll': 0},
              'xVariable': 'tx', 'yVariable': 'ty', 'scaleVariable': 'ts',
            },
            'actions': [for (final r in reactions) react(r)],
          },
        },
      });
      final scope = VariableScope([v('tx', 0), v('ty', 0), v('ts', 1), v('hits', const <Object?>[], VariableType.list)]);
      final values = NodeValues(DocumentSource(doc));
      final tree = NodeTree(values, binder: NodeBinder(scope: scope));
      final r = TreeReactions(runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values));
      tree.interactions = r;
      addTearDown(() {
        r.dispose();
        tree.dispose();
      });
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'board', interactive: true))));
      await tester.pump();
      await twoFingers(tester, const Offset(190, 200), const Offset(210, 200), const Offset(150, 200), const Offset(250, 200));
      await tester.pumpAndSettle();
      expect(scope.read('ts'), greaterThan(3), reason: 'hits: ${scope.read('hits')}');
    });
  }
}
