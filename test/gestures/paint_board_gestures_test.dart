// Petri's board: a transform gesture that pans only with two fingers
// (`pan: multiTouch`) around a grid whose drag reaction paints, reading
// `${drag.x}` / `${drag.y}` in the grid's own (zoomed) coordinates.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/transform_gesture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, VariableType type) => Variable(name: name, type: type, value: type.coerce(value));

Future<(NodeTree, VariableScope)> show(WidgetTester tester, {String pan = 'multiTouch'}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {
        'type': 'stack',
        'children': ['board'],
        'layout': {'width': 400, 'height': 400},
      },
      'board': {
        'type': 'stack',
        'children': ['grid'],
        'layout': {'width': 200, 'height': 200, 'x': {'start': 100}, 'y': {'start': 100}},
        'decoration': {'clip': 'hardEdge'},
        'transformGesture': {'target': 'content', 'pan': pan, 'bounds': 'cover', 'maxScale': 4, 'scaleVariable': 'zoom'},
      },
      'grid': {
        'type': 'box',
        'layout': {'width': {'fill': 200}, 'height': {'fill': 200}},
        'decoration': {'fills': [{'color': '#FFEAD49A'}]},
        'actions': [
          {
            'trigger': {'type': 'dragStart'},
            'actions': [
              {'type': 'setVariable', 'variable': 'downs', 'op': 'add', 'value': r'${= floor(drag.x)}'},
            ],
          },
          {
            'trigger': {'type': 'drag'},
            'actions': [
              {'type': 'setVariable', 'variable': 'xs', 'op': 'add', 'value': r'${= floor(drag.x)}'},
              {'type': 'setVariable', 'variable': 'ys', 'op': 'add', 'value': r'${= floor(drag.y)}'},
              {'type': 'setVariable', 'variable': 'starts', 'op': 'add', 'value': r'${= floor(drag.startX)}'},
            ],
          },
        ],
      },
    },
  });
  final scope = VariableScope([
    v('xs', [], VariableType.list),
    v('ys', [], VariableType.list),
    v('starts', [], VariableType.list),
    v('downs', [], VariableType.list),
    v('zoom', 1, VariableType.decimal),
  ]);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, tree: tree, nodeValues: values, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root', interactive: true)),
  ));
  await tester.pump();
  return (tree, scope);
}

RenderTransformGesture gestureOf(NodeTree tree) {
  RenderTransformGesture? found;
  void visit(RenderObject o) {
    if (o is RenderTransformGesture) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf('board')!);
  return found!;
}

void main() {
  testWidgets('one finger paints: the drag reaction reads drag.x/y, the board stays put', (tester) async {
    final (tree, scope) = await show(tester);
    final g = await tester.startGesture(const Offset(120, 130));
    for (var i = 1; i <= 6; i++) {
      await g.moveTo(Offset(120 + i * 10.0, 130 + i * 5.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    final xs = (scope.read('xs') as List).cast<num>();
    final ys = (scope.read('ys') as List).cast<num>();
    expect(xs, isNotEmpty);
    expect(xs.last, 80, reason: 'the pointer at x 180 is 80 into the grid');
    expect(ys.last, 60);
    expect((scope.read('starts') as List).first, 20, reason: 'the drag started 20 into the grid');
    // dragStart: once, where the finger went down (a stroke's first cell).
    expect(scope.read('downs'), [20]);
    expect(gestureOf(tree).pose.scale, 1);
    expect(gestureOf(tree).pose.x, 0);
  });

  testWidgets('two fingers zoom and pan; one finger then still paints in grid coordinates', (tester) async {
    final (tree, scope) = await show(tester);
    final a = await tester.startGesture(const Offset(180, 200), pointer: 1);
    final b = await tester.startGesture(const Offset(220, 200), pointer: 2);
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(Offset(180 - i * 2.0, 200 + i * 1.0));
      await b.moveTo(Offset(220 + i * 2.0, 200 + i * 1.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    final pose = gestureOf(tree).pose;
    expect(pose.scale, closeTo(2, 0.05));
    expect(scope.read('zoom'), closeTo(2, 0.05));
    expect(scope.read('xs'), isEmpty, reason: 'a pinch paints nothing');
    // Petri v2: a pinch dabbed a cell under each finger when strokes began
    // on pointerDown (it fires per finger). dragStart doesn't fire for one.
    expect(scope.read('downs'), isEmpty, reason: 'a pinch starts no stroke');
    // Paint across the middle: drag.x is in the grid's own coordinates, so
    // each 10 screen px is 5 grid px at 2x.
    final g = await tester.startGesture(const Offset(200, 200));
    for (var i = 1; i <= 6; i++) {
      await g.moveTo(Offset(200 + i * 10.0, 200));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    final xs = (scope.read('xs') as List).cast<num>();
    expect(xs.length, greaterThan(2));
    expect(xs.last - xs[xs.length - 2], closeTo(5, 1));
  });

  testWidgets('pan: never only zooms; multiTouch also pans with the pinch', (tester) async {
    final (tree, _) = await show(tester, pan: 'never');
    final a = await tester.startGesture(const Offset(180, 200), pointer: 1);
    final b = await tester.startGesture(const Offset(220, 200), pointer: 2);
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(Offset(180 - i * 2.0, 230));
      await b.moveTo(Offset(220 + i * 2.0, 230));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(gestureOf(tree).pose.scale, greaterThan(1.5));
    final never = gestureOf(tree).pose.y;
    // multiTouch: the same pinch moving down pans down too.
    final (tree2, _) = await show(tester);
    final c = await tester.startGesture(const Offset(180, 200), pointer: 3);
    final d = await tester.startGesture(const Offset(220, 200), pointer: 4);
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await c.moveTo(Offset(180 - i * 2.0, 230));
      await d.moveTo(Offset(220 + i * 2.0, 230));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await c.up();
    await d.up();
    await tester.pumpAndSettle();
    expect(gestureOf(tree2).pose.y, isNot(closeTo(never, 1)));
  });
}
