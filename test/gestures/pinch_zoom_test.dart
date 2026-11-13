import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart' show RenderPose;
import 'package:codelessly_sdk/src/render/transform_gesture.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Petri's board: a transform gesture that pans only with two fingers
// (`pan: multiTouch`) around a grid whose drag reaction paints, reading
// `${drag.x}` / `${drag.y}` in the grid's own (zoomed) coordinates.

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

// Transform gestures in a running app: a 200×200 node laid out at (100, 100) in a
// 400×400 parent, so global and parent coordinates are the same.


Variable decimal(String name, Object? value, [VariableType type = VariableType.decimal]) =>
    Variable(name: name, type: type, value: type.coerce(value));

class Board {
  Board(this.tree, this.scope);
  final NodeTree tree;
  final VariableScope scope;

  Object? operator [](String name) => scope.read(name);

  RenderTransformGesture get gesture {
    RenderTransformGesture? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderTransformGesture) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    visit(tree.boxOf('p')!);
    return found!;
  }

  TransformPose get pose => gesture.pose;

  /// The gestures the `changed` and `changeEnd` reactions saw.
  List<Object?> get changes => scope.read('changes')! as List<Object?>;
  List<Object?> get ends => scope.read('ends')! as List<Object?>;
}

Json record(String trigger, String list) => {
  'trigger': {'type': trigger},
  'actions': [
    {'type': 'setVariable', 'variable': list, 'op': 'add', 'value': r'${result.gesture}'},
  ],
};

Future<Board> board(
  WidgetTester tester,
  Json gesture, {
  List<Variable> variables = const [],
  Json bind = const {},
  Map<String, Json> inside = const {},
  bool interactive = true,
}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['board'],
    'nodes': {
      'board': {
        'type': 'stack',
        'children': ['p'],
        'layout': {'width': 400, 'height': 400},
      },
      'p': {
        'type': inside.isEmpty ? 'box' : 'stack',
        if (inside.isNotEmpty) 'children': inside.keys.toList(),
        'layout': {'width': 200, 'height': 200, 'x': {'start': 100}, 'y': {'start': 100}},
        'decoration': {
          'fills': [
            {'color': '#FF3366FF'},
          ],
        },
        'transformGesture': gesture,
        'bind': bind,
        'actions': [record('changed', 'changes'), record('changeEnd', 'ends')],
      },
      ...inside,
    },
  });
  final scope = VariableScope([
    decimal('changes', const <Object?>[], VariableType.list),
    decimal('ends', const <Object?>[], VariableType.list),
    ...variables,
  ]);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final reactions = TreeReactions(
    runner: const CodelesslyActions(),
    context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values),
  );
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 'board', interactive: interactive),
      ),
    ),
  );
  await tester.pump();
  return Board(tree, scope);
}

Future<(TestGesture, TestGesture)> twoFingers(
  WidgetTester tester,
  Offset a1,
  Offset a2,
  Offset b1,
  Offset b2, {
  int steps = 12,
  bool lift = true,
}) async {
  final g1 = await tester.startGesture(a1, pointer: 1);
  final g2 = await tester.startGesture(a2, pointer: 2);
  await tester.pump();
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    await g1.moveTo(Offset.lerp(a1, b1, t)!);
    await g2.moveTo(Offset.lerp(a2, b2, t)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (lift) {
    await g1.up();
    await g2.up();
  }
  return (g1, g2);
}

/// The corner handle at rest.
const double b0 = 300;

// A design canvas draws a transform gesture's pose given by data (a caption
// placed by its record), where a running app starts it.

// Transform gestures in a running app: a 200×200 node laid out at (100, 100) in a
// 400×400 parent, so global and parent coordinates are the same.


void main() {
  group('content inside a zoomable board', () {
    testWidgets('two fingers zoom and pan the board, and one finger still drags inside it at the right place', (tester) async {
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
  });

  testWidgets('a pinch zooms around the point between the fingers', (tester) async {
    final b = await board(tester, {'bounds': 'none'}, variables: [decimal('zoom', 1)]);
    await twoFingers(tester, const Offset(125, 150), const Offset(175, 150), const Offset(100, 150), const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(b.pose.scale, closeTo(2, 0.02));
    expect(b.pose.x, closeTo(50, 2.5));
    expect(b.pose.y, closeTo(50, 2.5));
    expect(b.changes, contains('pinch'));
    expect(b.ends, isNotEmpty);
  });

  testWidgets('a pinch zooms and a drag pans, and both write their variables', (tester) async {
    // The map's transformGesture as the app has it (editor/build/gen_map.py).
    final b = await board(tester, {
      'minScale': 0.3, 'maxScale': 4, 'bounds': 'none', 'wheel': 'zoom', 'doubleTapScale': 2,
      'xVariable': 'mapX', 'yVariable': 'mapY', 'scaleVariable': 'mapScale',
    }, variables: [decimal('mapX', 0), decimal('mapY', 0), decimal('mapScale', 1)]);
    // Pinch out: fingers 50 px apart to 100 px apart, about (150, 150).
    await twoFingers(tester, const Offset(125, 150), const Offset(175, 150), const Offset(100, 150), const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(b['mapScale'] as double, closeTo(2, 0.02));
    // One finger pans by its travel (in the parent's pixels).
    final x0 = b['mapX'] as double, y0 = b['mapY'] as double;
    final g = await tester.startGesture(const Offset(200, 200));
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(200 - i * 6.0, 200 - i * 3.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect((b['mapX'] as double) - x0, closeTo(-60, 6));
    expect((b['mapY'] as double) - y0, closeTo(-30, 6));
    await tester.pumpAndSettle();
    // Pinch in past the minimum: it settles at minScale.
    await twoFingers(tester, const Offset(50, 200), const Offset(350, 200), const Offset(195, 200), const Offset(205, 200));
    await tester.pumpAndSettle();
    expect(b['mapScale'] as double, closeTo(0.3, 0.01));
  });

  testWidgets('past its maximum the zoom stretches and springs back', (tester) async {
    final b = await board(tester, {'maxScale': 2, 'bounds': 'none'});
    final (g1, g2) = await twoFingers(
      tester,
      const Offset(180, 200),
      const Offset(220, 200),
      const Offset(80, 200),
      const Offset(320, 200),
      lift: false,
    );
    final held = b.pose.scale;
    expect(held, greaterThan(2));
    expect(held, lessThan(6));
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    expect(b.pose.scale, closeTo(2, 0.01));
  });

  testWidgets('a double tap zooms to the tapped point, and another zooms out', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['board'],
      'nodes': {
        'board': {
          'type': 'stack',
          'children': ['p'],
          'layout': {'width': 400, 'height': 400},
        },
        'p': {
          'type': 'box',
          'zoomable': true,
          'layout': {'width': 200, 'height': 200, 'x': {'start': 100}, 'y': {'start': 100}},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: VariableScope(const [])));
    addTearDown(tree.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: NodeView(tree: tree, rootId: 'board', interactive: true),
        ),
      ),
    );
    final b = Board(tree, VariableScope(const []));
    Future<void> doubleTap(Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
    }

    await doubleTap(const Offset(200, 200));
    expect(b.pose.scale, closeTo(2.5, 0.01));
    expect(b.pose.x, closeTo(0, 0.5));
    await doubleTap(const Offset(200, 200));
    expect(b.pose.scale, closeTo(1, 0.01));
  });

  testWidgets('a zoomed photo pans to its edge and no further', (tester) async {
    final b = await board(tester, {'target': 'content', 'pan': 'whenZoomed', 'doubleTapScale': 2});
    await tester.dragFrom(const Offset(200, 200), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(b.pose.x, 0);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    expect(b.pose.scale, closeTo(2, 0.01));
    final g = await tester.startGesture(const Offset(150, 200));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final held = b.pose.x;
    expect(held, greaterThan(100));
    expect(held, lessThan(300));
    await g.up();
    await tester.pumpAndSettle();
    expect(b.pose.x, closeTo(100, 0.1));
    expect(b.pose.y, closeTo(0, 0.1));
  });

  testWidgets('a node kept inside its parent cannot be dragged out', (tester) async {
    final b = await board(tester, {
      'bounds': 'contain',
      'physics': {'fling': false},
    });
    await tester.dragFrom(const Offset(200, 200), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(b.pose.x, closeTo(-100, 0.1));
  });

  testWidgets('a release keeps moving and slows to a stop', (tester) async {
    final b = await board(tester, {'bounds': 'none'});
    await tester.flingFrom(const Offset(200, 200), const Offset(100, 0), 1500);
    await tester.pump();
    final released = b.pose.x;
    await tester.pump(const Duration(milliseconds: 100));
    final a = b.pose.x;
    await tester.pump(const Duration(milliseconds: 100));
    final c = b.pose.x;
    expect(a, greaterThan(released));
    expect(c - a, lessThan(a - released));
    await tester.pumpAndSettle();
    expect(b.pose.x, greaterThan(200));
    expect(b.ends.last, 'fling');
  });

  testWidgets('Ctrl + wheel zooms around the pointer, and a plain wheel does not', (tester) async {
    final b = await board(tester, {'bounds': 'none'});
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 200)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump();
    expect(b.pose.scale, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(b.pose.scale, closeTo(math.exp(100 / 300), 0.001));
    expect(b.pose.x, closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(b.ends.last, 'wheel');
  });

  testWidgets('two fingers rotate the board, and it stays at the angle where it is let go', (tester) async {
    final b = await board(tester, {'rotate': true, 'zoom': false, 'bounds': 'none'});
    const c = Offset(200, 200);
    Offset at(double degrees, double r) {
      final a = degrees * math.pi / 180;
      return c + Offset(math.cos(a), math.sin(a)) * r;
    }

    final (g1, g2) = await twoFingers(tester, at(180, 60), at(0, 60), at(220, 60), at(40, 60), lift: false);
    expect(b.pose.rotation, closeTo(40, 1.5));
    expect(b.pose.scale, 1);
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    expect(b.pose.rotation, closeTo(40, 1.5));
  });

  testWidgets('a bound scale and position move the node, and the node can read them', (tester) async {
    final b = await board(
      tester,
      {'bounds': 'none'},
      variables: [decimal('z', 1.5)],
      bind: {'transformGesture.scale': r'${z}', 'transformGesture.rotation': '10'},
      inside: {
        'label': {
          'type': 'text',
          'layout': {'width': 200, 'height': 20},
          'props': {'text': r'${transform.scale} ${transform.rotation} ${transform.active}'},
        },
      },
    );
    expect(b.pose.scale, 1.5);
    RenderParagraph? found;
    void visit(RenderObject o) {
      if (o is RenderParagraph) found ??= o;
      o.visitChildren(visit);
    }

    visit(b.tree.boxOf('label')!);
    expect(found!.text.toPlainText(), '1.5 10 false');
  });

  testWidgets('a reset action springs it back', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['board'],
      'nodes': {
        'board': {
          'type': 'stack',
          'children': ['p', 'reset'],
          'layout': {'width': 400, 'height': 400},
        },
        'p': {
          'type': 'box',
          'transformGesture': {'bounds': 'none', 'xVariable': 'px'},
          'layout': {'width': 200, 'height': 200, 'x': {'start': 100}, 'y': {'start': 100}},
        },
        'reset': {
          'type': 'box',
          'layout': {'width': 40, 'height': 40},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'controlDrag', 'node': 'p', 'command': 'reset'},
              ],
            },
          ],
        },
      },
    });
    final scope = VariableScope([decimal('px', 80)]);
    final values = NodeValues(DocumentSource(doc));
    final tree = NodeTree(values, binder: NodeBinder(scope: scope));
    final reactions = TreeReactions(
      runner: const CodelesslyActions(),
      context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values),
    );
    tree.interactions = reactions;
    addTearDown(() {
      reactions.dispose();
      tree.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: NodeView(tree: tree, rootId: 'board', interactive: true),
        ),
      ),
    );
    final b = Board(tree, scope);
    expect(b.pose.x, 80);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(b.pose.x, closeTo(0, 0.05));
    expect(scope.read('px'), 0);
  });

  testWidgets('on the design canvas nothing zooms or pans', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['p'],
      'nodes': {
        'p': {
          'type': 'box',
          'zoomable': true,
          'layout': {'width': 200, 'height': 200},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'p'))));
    RenderTransformGesture? found;
    void visit(RenderObject o) {
      if (o is RenderTransformGesture) found = o;
      o.visitChildren(visit);
    }

    visit(tree.boxOf('p')!);
    expect(found, isNull);
  });

  group('resize handles', () {
    const Json sticker = {
      'bounds': 'none',
      'handles': {'snapAngle': 15, 'minWidth': 100},
    };

    Future<void> dragHandle(WidgetTester tester, Offset from, Offset to) async {
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a corner handle scales the node, keeping its proportions', (tester) async {
      final b = await board(tester, sticker);
      await dragHandle(tester, const Offset(300, 300), const Offset(380, 380));
      expect(b.pose.scale, closeTo(1.8, 0.02));
      expect(b.pose.scaleX, 1);
      // The handle followed, outside the node's laid out box.
      await dragHandle(tester, const Offset(380, 380), const Offset(350, 350));
      expect(b.pose.scale, closeTo(1.5, 0.02));
      expect(b.ends.last, 'handle');
    });

    testWidgets('the rotate handle turns the node in 15° steps', (tester) async {
      final b = await board(tester, sticker);
      // 28px above the top edge's middle.
      await dragHandle(tester, const Offset(200, 72), const Offset(320, 200));
      expect(b.pose.rotation, closeTo(90, 0.01));
      final knob = const Offset(200, 200) + const Offset(128, 0);
      await dragHandle(tester, knob, const Offset(320, 177));
      expect(b.pose.rotation, closeTo(75, 0.01));
    });

    testWidgets('handles show only while the node is selected, and a tap selects it', (tester) async {
      final b = await board(
        tester,
        {
          ...sticker,
          'handles': {'selectionVariable': 'sel'},
        },
        variables: [decimal('sel', '', VariableType.text)],
      );
      // Not selected: the corner isn't a handle (nothing moves it).
      await dragHandle(tester, const Offset(300, 300), const Offset(380, 380));
      expect(b.pose.scale, 1);
      await tester.tapAt(const Offset(200, 200));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(b['sel'], 'p');
      await dragHandle(tester, const Offset(b0, b0), const Offset(380, 380));
      expect(b.pose.scale, greaterThan(1));
    });

  });

  group('on the design canvas', () {
    testWidgets('a node\'s saved zoom and position show on the design canvas', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['cap'], 'layout': {'width': 300, 'height': 300}},
          'cap': {
            'type': 'box',
            'layout': {'width': 40, 'height': 20, 'x': {'align': 0}, 'y': {'align': 0}},
            'transformGesture': {'x': 30, 'y': -50, 'scale': 2, 'rotation': 0},
          },
        },
      });
      final tree = NodeTree(DocumentSource(doc));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 's')));
      RenderPose? pose;
      void find(RenderObject o) {
        if (o is RenderPose) pose ??= o;
        o.visitChildren(find);
      }

      find(tree.boxOf('cap')!);
      expect(pose, isNotNull);
      final m = pose!.transform;
      expect(m.getTranslation().x, 30);
      expect(m.getTranslation().y, -50);
      expect(m.getMaxScaleOnAxis(), 2);
    });
  });

  group('moved by an action', () {
    testWidgets('a given position and zoom spring the node there, and a zoom alone zooms about the middle', (tester) async {
      final b = await board(
        tester,
        {'bounds': 'none', 'scaleVariable': 'zoom', 'xVariable': 'px', 'yVariable': 'py'},
        variables: [decimal('zoom', 1), decimal('px', 0), decimal('py', 0)],
      );
      b.scope.set('zoom', 2);
      await tester.pumpAndSettle();
      expect(b.pose.scale, closeTo(2, 0.001));
      expect(b.pose.x, closeTo(0, 0.1));
      expect(b.changes, contains('variable'));
      b.scope.set('px', 30);
      b.scope.set('py', -20);
      await tester.pumpAndSettle();
      expect(b.pose.x, closeTo(30, 0.05));
      expect(b.pose.y, closeTo(-20, 0.05));
    });
  });
}
