// The Lineworks train: a looping motion along a path with keyframes for
// pacing and fades, its path, length and keyframes bound to the plan.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a bound looping path motion with keyframes moves the node', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['t'], 'layout': {'width': 400, 'height': 300}},
        't': {
          'type': 'box',
          'layout': {'width': 20, 'height': 10, 'x': {'start': -10}, 'y': {'start': -5}},
          'decoration': {'fills': [{'color': '#FF000000'}]},
          'motion': {'path': 'M0 0 L1 0', 'orientToPath': true, 'orientUpright': true, 'loop': 'restart', 'duration': 5000,
                     'curve': 'linear', 'keyframes': []},
          'bind': {'motion.path': r'${trip.path}', 'motion.duration': r'${trip.ms}', 'motion.keyframes': r'${trip.keys}'},
        },
      },
    });
    final scope = VariableScope([
      Variable(id: 'trip', name: 'trip', type: VariableType.map, value: {
        'path': 'M0 100 L200 100', 'ms': 4000,
        'keys': [
          {'t': 0, 'pathProgress': 0, 'opacity': 0}, {'t': 0.05, 'opacity': 1}, {'t': 0.75, 'pathProgress': 1},
          {'t': 1, 'pathProgress': 1, 'opacity': 0},
        ],
      }),
    ]);
    final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
    ));
    final view = tester.renderObject(find.byType(NodeView));
    Rect at() => tree.boxOf('t')!.rectIn(view)!;
    await tester.pump(const Duration(milliseconds: 1500));
    // Under way along its 3 s run (0.75 of 4 s), then at the end.
    expect(at().center.dx, inInclusiveRange(60, 160));
    // A path is followed from the node's place: offsets from its start (0, 100).
    expect(at().center.dy, closeTo(0, 1));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(at().center.dx, closeTo(200, 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a looping motion hidden by a binding starts again when shown', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['t'], 'layout': {'width': 400, 'height': 300}},
        't': {
          'type': 'box',
          'layout': {'width': 20, 'height': 10, 'x': {'start': -10}, 'y': {'start': -5}},
          'decoration': {'fills': [{'color': '#FF000000'}]},
          'motion': {'path': 'M0 100 L200 100', 'loop': 'restart', 'duration': 2000, 'curve': 'linear', 'pathProgress': 1,
                     'enterFrom': {'pathProgress': 0}},
          'bind': {'visible': r'${shown}'},
        },
      },
    });
    final scope = VariableScope([Variable(id: 'shown', name: 'shown', type: VariableType.boolean, value: false)]);
    final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
    ));
    final view = tester.renderObject(find.byType(NodeView));
    await tester.pump(const Duration(milliseconds: 500));
    scope.set('shown', true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    final x = tree.boxOf('t')!.rectIn(view)!.center.dx;
    expect(x, inInclusiveRange(60, 140));
    expect(tree.boxOf('t')!.rectIn(view)!.center.dy, closeTo(0, 1));
    await tester.pumpWidget(const SizedBox());
  });
}
