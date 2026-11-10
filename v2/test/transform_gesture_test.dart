// Transform gestures in a running app (SDK 8.x's NodeTransformGesture,
// ported from its tests): a 200×200 node laid out at (100, 100) in a
// 400×400 parent, so global and parent coordinates are the same.
import 'dart:math' as math;

import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/render/transform_gesture.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.decimal]) =>
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
    v('changes', const <Object?>[], VariableType.list),
    v('ends', const <Object?>[], VariableType.list),
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

void main() {
  testWidgets('a pinch zooms around the point between the fingers', (tester) async {
    final b = await board(tester, {'bounds': 'none'}, variables: [v('zoom', 1)]);
    await twoFingers(tester, const Offset(125, 150), const Offset(175, 150), const Offset(100, 150), const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(b.pose.scale, closeTo(2, 0.02));
    expect(b.pose.x, closeTo(50, 2.5));
    expect(b.pose.y, closeTo(50, 2.5));
    expect(b.changes, contains('pinch'));
    expect(b.ends, isNotEmpty);
  });

  testWidgets('the pose writes its variables and the node is drawn at it', (tester) async {
    final b = await board(
      tester,
      {'bounds': 'none', 'scaleVariable': 'zoom', 'xVariable': 'px'},
      variables: [v('zoom', 1), v('px', 0)],
    );
    await twoFingers(tester, const Offset(125, 150), const Offset(175, 150), const Offset(100, 150), const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(b['zoom'] as double, closeTo(2, 0.02));
    expect(b['px'] as double, closeTo(50, 2.5));
    final box = b.tree.boxOf('p')!.contentBox!;
    final r = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    expect(r.width, closeTo(400, 4));
  });

  testWidgets('past maxScale the zoom rubber-bands and springs back', (tester) async {
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

  testWidgets('a double tap zooms to the tapped point, another zooms out (zoomable)', (tester) async {
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

  testWidgets('cover bounds: a zoomed photo pans to its edge and no further', (tester) async {
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

  testWidgets('contain keeps a sticker inside its parent', (tester) async {
    final b = await board(tester, {
      'bounds': 'contain',
      'physics': {'fling': false},
    });
    await tester.dragFrom(const Offset(200, 200), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(b.pose.x, closeTo(-100, 0.1));
  });

  testWidgets('a given pose outside cover bounds is moved inside on layout', (tester) async {
    final b = await board(
      tester,
      {'target': 'content', 'scaleVariable': 'zoom', 'xVariable': 'px'},
      variables: [v('zoom', 2), v('px', 300)],
    );
    await tester.pump();
    expect(b.pose.x, closeTo(100, 0.01));
    expect(b['px'], 100);
  });

  testWidgets('a release flings on by friction and slows to a stop', (tester) async {
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

  testWidgets('ctrl + wheel zooms around the pointer; a plain wheel does not', (tester) async {
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

  testWidgets('wheel: pan pans', (tester) async {
    final b = await board(tester, {'bounds': 'none', 'wheel': 'pan'});
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 200)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await tester.pump();
    expect(b.pose.y, -40);
    expect(b.pose.scale, 1);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('two fingers rotate and the rotation snaps on release', (tester) async {
    final b = await board(tester, {'rotate': true, 'zoom': false, 'bounds': 'none', 'rotationSnap': 15});
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
    expect(b.pose.rotation, closeTo(45, 0.05));
  });

  testWidgets('a given pose springs the node there; a scale alone zooms the middle', (tester) async {
    final b = await board(
      tester,
      {'bounds': 'none', 'scaleVariable': 'zoom', 'xVariable': 'px', 'yVariable': 'py'},
      variables: [v('zoom', 1), v('px', 0), v('py', 0)],
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

  testWidgets('a bound pose (transformGesture.scale) and the node reads it as transform', (tester) async {
    final b = await board(
      tester,
      {'bounds': 'none'},
      variables: [v('z', 1.5)],
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

  testWidgets('a control drag reset springs it back', (tester) async {
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
    final scope = VariableScope([v('px', 80)]);
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

  testWidgets('the design canvas has no gesture', (tester) async {
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

  group('handles', () {
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

    testWidgets('a corner scales, keeping the aspect, and takes the pointer outside the box', (tester) async {
      final b = await board(tester, sticker);
      await dragHandle(tester, const Offset(300, 300), const Offset(380, 380));
      expect(b.pose.scale, closeTo(1.8, 0.02));
      expect(b.pose.scaleX, 1);
      // The handle followed, outside the node's laid out box.
      await dragHandle(tester, const Offset(380, 380), const Offset(350, 350));
      expect(b.pose.scale, closeTo(1.5, 0.02));
      expect(b.ends.last, 'handle');
    });

    testWidgets('the minimum size holds', (tester) async {
      final b = await board(tester, sticker);
      await dragHandle(tester, const Offset(300, 300), const Offset(210, 210));
      expect(b.pose.scale, closeTo(0.5, 0.01));
    });

    testWidgets('the knob rotates in 15° steps', (tester) async {
      final b = await board(tester, sticker);
      // 28px above the top edge's middle.
      await dragHandle(tester, const Offset(200, 72), const Offset(320, 200));
      expect(b.pose.rotation, closeTo(90, 0.01));
      final knob = const Offset(200, 200) + const Offset(128, 0);
      await dragHandle(tester, knob, const Offset(320, 177));
      expect(b.pose.rotation, closeTo(75, 0.01));
    });

    testWidgets('edges stretch one axis when the aspect is free', (tester) async {
      final b = await board(tester, {
        'bounds': 'none',
        'handles': {'edges': true, 'aspectLock': false},
      });
      await dragHandle(tester, const Offset(300, 200), const Offset(350, 200));
      expect(b.pose.scaleX, closeTo(1.5, 0.02));
      expect(b.pose.scaleY, 1);
      expect(b.pose.scale, 1);
    });

    testWidgets('handles show only while selected; a tap selects', (tester) async {
      final b = await board(
        tester,
        {
          ...sticker,
          'handles': {'selectionVariable': 'sel'},
        },
        variables: [v('sel', '', VariableType.text)],
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

    testWidgets('a moved sticker is grabbed where it is drawn', (tester) async {
      final b = await board(
        tester,
        {
          'bounds': 'none',
          'physics': {'fling': false},
          'xVariable': 'px',
        },
        variables: [v('px', 150)],
      );
      await tester.dragFrom(const Offset(380, 200), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(b.pose.y, closeTo(60, 0.5));
    });
  });
}

/// The corner handle at rest.
const double b0 = 300;
