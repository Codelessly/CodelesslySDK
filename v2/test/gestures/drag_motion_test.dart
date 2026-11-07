// A node that follows the pointer (`drag`, DragMotion): SDK 8.x's
// node_drag_test and drag_physics_test, ported to the v2 render tree. The
// node follows, tilts, shares its drag as `${drag}`, writes its variables,
// fires drag, dragEnd and swipes, and springs back, stays, settles on
// physics or flies off.
import 'dart:math' as math;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/runtime/gestures/drag_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, Object?> swipeCard = {
  'release': 'dismiss',
  'directions': ['left', 'right', 'up'],
  'rotateFactor': 15,
  'originY': 1.6,
  'distanceThreshold': 0.35,
  'resistance': 0.7,
};

class Shown {
  Shown(this.tree, this.scope);
  final NodeTree tree;
  final VariableScope scope;

  RenderDragMotion drag([String id = 'card']) {
    RenderDragMotion? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderDragMotion) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    visit(tree.boxOf(id)!);
    return found!;
  }

  DragValues values([String id = 'card']) => drag(id).values;
  String text(String id) => tree.boxOf(id)!.node!.prop(TextProps.text);
}

/// A 400×600 stack with node `card` ([w]×[h] at [x], [y]) holding a text
/// that reads `${drag}`; [actions] are the card's reactions.
Future<Shown> show(
  WidgetTester tester, {
  Map<String, Object?> drag = swipeCard,
  double x = 0,
  double y = 0,
  double w = 200,
  double h = 300,
  List<Json> actions = const [],
  List<Variable> variables = const [],
  Map<String, String> bind = const {},
  Map<String, Object?> extra = const {},
}) async {
  final doc = api.LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {
      's': {
        'type': 'stack',
        'children': ['card'],
        'layout': {'width': 400, 'height': 600},
      },
      'card': {
        'type': 'stack',
        'children': ['label'],
        'layout': {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}},
        'decoration': {'fills': [{'color': '#FF2196F3'}]},
        'drag': drag,
        'actions': actions,
        'bind': bind,
        ...extra,
      },
      'label': {
        'type': 'text',
        'layout': {'width': 100, 'height': 20},
        'props': {'text': r'${drag.dx}|${drag.dragging}|${drag.direction}'},
      },
    },
  });
  final scope = VariableScope(variables);
  final source = NodeValues(DocumentSource(doc));
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, tree: tree, nodeValues: source, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
  ));
  return Shown(tree, scope);
}

Json react(String trigger, List<Json> actions) => {'trigger': {'type': trigger}, 'actions': actions};
Json record(String name, String value) => {'type': 'setVariable', 'variable': name, 'value': value};
Json append(String name) => {'type': 'setVariable', 'variable': name, 'op': 'add', 'value': r'${result}'};

Variable listVar(String name) => Variable(name: name, type: VariableType.list, value: const []);

List<Map> ends(Shown s) => [...(s.scope.read('ends') as List? ?? const []).cast<Map>()];

void main() {
  testWidgets('follows the pointer, tilts and shares its progress', (tester) async {
    final s = await show(tester);
    final gesture = await tester.startGesture(const Offset(100, 150));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    final m = s.drag().debugTransform;
    // Moved right by 60 (DragStartBehavior.down: no slop lost).
    expect(m.getTranslation().x, greaterThan(30));
    // Tilted clockwise: 15° per card width.
    final angle = math.atan2(m.storage[1], m.storage[0]) * 180 / math.pi;
    expect(angle, closeTo(s.values().offset.dx / 200 * 15, 0.01));
    final values = s.values();
    expect(values.dragging, isTrue);
    expect(values.right, greaterThan(0));
    expect(values.right, lessThan(1));
    expect(values.left, 0);
    expect(values.direction, 'right');
    // The nodes inside read it.
    await tester.pump();
    expect(s.text('label'), '${values.offset.dx}|true|right');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('springs back when let go short of the threshold', (tester) async {
    final s = await show(tester, actions: [react('dragEnd', [append('ends')])], variables: [listVar('ends')]);
    await tester.timedDragFrom(const Offset(100, 150), const Offset(40, 0), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(ends(s).single['dismissed'], isFalse);
    expect(s.values().offset, Offset.zero);
    expect(s.values().dragging, isFalse);
  });

  testWidgets('flies off past the threshold, swipes and comes back', (tester) async {
    final s = await show(tester, actions: [
      react('dragEnd', [append('ends')]),
      react('swipeLeft', [record('swiped', r'${result.direction}')]),
    ], variables: [
      listVar('ends'),
      const Variable(name: 'swiped', type: VariableType.text, value: ''),
    ]);
    await tester.timedDragFrom(const Offset(100, 150), const Offset(-120, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(s.scope.read('swiped'), 'left');
    expect(ends(s).single['direction'], 'left');
    // Still there: back at rest for its next content.
    expect(s.values().offset, Offset.zero);
    expect(s.values().dismissed, isFalse);
  });

  testWidgets('a fast fling dismisses even when short', (tester) async {
    final s = await show(tester, actions: [react('swipeUp', [record('swiped', 'up')])], variables: [
      const Variable(name: 'swiped', type: VariableType.text, value: ''),
    ]);
    await tester.flingFrom(const Offset(100, 150), const Offset(0, -50), 1500);
    await tester.pumpAndSettle();
    expect(s.scope.read('swiped'), 'up');
  });

  testWidgets('directions that cannot dismiss resist and spring back', (tester) async {
    final s = await show(tester);
    final gesture = await tester.startGesture(const Offset(100, 150));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 30));
    }
    await tester.pump();
    // 300px pulled down, held back by the rubber band.
    expect(s.values().offset.dy, greaterThan(0));
    expect(s.values().offset.dy, lessThan(120 * 0.3 + 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(s.values().offset, Offset.zero);
  });

  testWidgets('a disabled drag does not move; disabledFollow follows a little and reports blocked', (tester) async {
    final s = await show(tester, drag: {...swipeCard, 'enabled': false, 'shakeWhenDisabled': true});
    await tester.timedDragFrom(const Offset(100, 150), const Offset(-150, 0), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(s.values().offset, Offset.zero);
    await tester.pumpWidget(const SizedBox());

    final f = await show(tester,
        drag: {...swipeCard, 'enabled': false, 'disabledFollow': 0.3},
        actions: [react('dragEnd', [append('ends')])],
        variables: [listVar('ends')]);
    final gesture = await tester.startGesture(const Offset(100, 150));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-30, 0));
    }
    await tester.pump();
    // 150px of pointer travel at 30%.
    expect(f.values().offset.dx, closeTo(-45, 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(ends(f).last['blocked'], isTrue);
    expect(f.values().offset, Offset.zero);
  });

  testWidgets('drag.enabled binds the switch', (tester) async {
    final s = await show(tester,
        bind: {'drag.enabled': r'${on}'},
        variables: [const Variable(name: 'on', type: VariableType.boolean, value: false)]);
    await tester.timedDragFrom(const Offset(100, 150), const Offset(60, 0), const Duration(milliseconds: 300));
    await tester.pump();
    expect(s.values().offset, Offset.zero);
    s.scope.set('on', true);
    await tester.pump();
    final g = await tester.startGesture(const Offset(100, 150));
    await g.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(s.values().offset.dx, 60);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('actions fling, return and reset the enabled instance', (tester) async {
    final s = await show(tester, actions: [react('swipeRight', [record('swiped', 'right')])], variables: [
      const Variable(name: 'swiped', type: VariableType.text, value: ''),
    ]);
    final flung = DragMotionControl.control('card', api.DragCommand.fling, api.DragDirection.right);
    await tester.pumpAndSettle();
    expect(await flung, isTrue);
    expect(s.scope.read('swiped'), 'right');

    final back = DragMotionControl.control('card', api.DragCommand.returnFrom, api.DragDirection.left);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Starts off-screen on the left and glides in.
    expect(s.values().offset.dx, lessThan(-200));
    await tester.pumpAndSettle();
    await back;
    expect(s.values().offset, Offset.zero);

    await DragMotionControl.control('card', api.DragCommand.shake, api.DragDirection.right);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(s.values().offset.dx, isNot(0));
    await tester.pumpAndSettle();
    expect(s.values().offset, Offset.zero);
  });

  testWidgets('a returning card built in the next frame starts off-screen', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final back = DragMotionControl.control('card', api.DragCommand.returnFrom, api.DragDirection.up);
    final s = await show(tester);
    expect(s.values().offset.dy, lessThan(-300));
    await tester.pumpAndSettle();
    await back;
    expect(s.values().offset, Offset.zero);
  });

  testWidgets('spins as it flies off', (tester) async {
    final s = await show(tester, drag: {...swipeCard, 'flyOutRotate': 20, 'rotateFactor': 0});
    final gesture = await tester.startGesture(const Offset(100, 150));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final m = s.drag().debugTransform;
    final angle = math.atan2(m.storage[1], m.storage[0]) * 180 / math.pi;
    // No tilt from the drag: the turn is the fly-off spin, on its way to 20°.
    expect(angle, greaterThan(1));
    expect(angle, lessThanOrEqualTo(20));
    await tester.pumpAndSettle();
  });

  testWidgets('up and down can have their own threshold', (tester) async {
    var s = await show(tester, actions: [react('swipeUp', [record('swiped', 'up')])], variables: [
      const Variable(name: 'swiped', type: VariableType.text, value: ''),
    ]);
    await tester.timedDragFrom(const Offset(100, 150), const Offset(0, -100), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    // Short of 35% of the height (105).
    expect(s.scope.read('swiped'), '');
    await tester.pumpWidget(const SizedBox());

    s = await show(tester, drag: {...swipeCard, 'verticalThreshold': 0.25}, actions: [
      react('swipeUp', [record('swiped', 'up')]),
    ], variables: [
      const Variable(name: 'swiped', type: VariableType.text, value: ''),
    ]);
    await tester.timedDragFrom(const Offset(100, 150), const Offset(0, -100), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    // Past 25% (75).
    expect(s.scope.read('swiped'), 'up');
  });

  testWidgets('rests where data puts it and moves when it changes', (tester) async {
    final s = await show(tester,
        bind: {'drag.restX': r'${peek}'},
        variables: [const Variable(name: 'peek', type: VariableType.decimal, value: 40)]);
    await tester.pump();
    expect(s.values().offset, const Offset(40, 0));
    expect(s.values().right, closeTo(40 / 70, 0.001));
    expect(s.drag().debugTransform.getTranslation().x, 40);
    s.scope.set('peek', 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.values().offset.dx, inExclusiveRange(-20, 40));
    await tester.pumpAndSettle();
    expect(s.values().offset, Offset.zero);
  });

  testWidgets('writes shareAs, xVariable and yVariable; fires drag with deltas', (tester) async {
    final s = await show(tester, drag: {
      ...swipeCard,
      'shareAs': 'live',
      'xVariable': 'x',
      'yVariable': 'y',
    }, actions: [
      react('drag', [record('lastDx', r'${result.dx}')]),
    ], variables: [
      const Variable(name: 'live', type: VariableType.map, value: {}),
      const Variable(name: 'x', type: VariableType.decimal, value: 0),
      const Variable(name: 'y', type: VariableType.decimal, value: 0),
      const Variable(name: 'lastDx', type: VariableType.decimal, value: 0),
    ]);
    final g = await tester.startGesture(const Offset(100, 150));
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.moveBy(const Offset(15.333, 0));
    await tester.pump();
    await tester.pump();
    expect(s.scope.read('x'), 45.33);
    expect(s.scope.read('y'), 0);
    expect((s.scope.read('live') as Map)['dragging'], isTrue);
    expect((s.scope.read('live') as Map)['direction'], 'right');
    expect(s.scope.read('lastDx'), closeTo(45.333, 0.001));
    await g.up();
    await tester.pumpAndSettle();
    expect(s.scope.read('x'), 0);
    expect((s.scope.read('live') as Map)['dragging'], isFalse);
  });

  testWidgets('the dragged state styles the node while held', (tester) async {
    final s = await show(tester, extra: {
      'states': {
        'dragged': {
          'card': {'opacity': 0.5},
        },
      },
    });
    expect(s.tree.boxOf('card')!.node!.opacity, 1);
    final g = await tester.startGesture(const Offset(100, 150));
    await g.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(s.tree.boxOf('card')!.node!.opacity, 0.5);
    await g.up();
    await tester.pumpAndSettle();
    expect(s.tree.boxOf('card')!.node!.opacity, 1);
  });

  testWidgets('the design canvas draws it at rest and takes no drag', (tester) async {
    final doc = api.LayoutDocument.fromJson({
      'roots': ['card'],
      'nodes': {
        'card': {'type': 'box', 'layout': {'width': 100, 'height': 100}, 'drag': swipeCard},
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'card'))));
    expect(find.byType(NodeView), findsOneWidget);
    var found = false;
    void visit(RenderObject o) {
      if (o is RenderDragMotion) found = true;
      o.visitChildren(visit);
    }

    visit(tree.boxOf('card')!);
    expect(found, isFalse);
    expect(SchedulerBindingTicks.active(tester), isFalse);
  });

  group('physics', () {
    // A 100×100 node laid out at (150, 450) in a 400×600 parent.
    Future<Shown> pump(WidgetTester tester, Map<String, Object?> drag) => show(tester,
        drag: drag,
        x: 150,
        y: 450,
        w: 100,
        h: 100,
        actions: [react('dragEnd', [append('ends')])],
        variables: [listVar('ends')]);

    const sheet = {
      'axis': 'vertical',
      'release': 'stay',
      'minY': -400,
      'maxY': 0,
      'physics': {
        'snap': {
          'points': [
            [0, 0],
            [0, -200],
            [0, -400],
          ],
        },
      },
    };

    testWidgets('a slow drag settles on the nearest stop', (tester) async {
      final s = await pump(tester, sheet);
      final g = await tester.startGesture(const Offset(200, 500));
      for (var i = 0; i < 15; i++) {
        await g.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await g.up();
      await tester.pump();
      expect(ends(s).single['snapIndex'], 1);
      expect(ends(s).single['targetY'], -200);
      await tester.pump(const Duration(milliseconds: 16));
      expect(s.values().settling, isTrue);
      await tester.pumpAndSettle();
      expect(s.values().offset.dy, closeTo(-200, 0.01));
      expect(s.values().offset.dx, 0);
      expect(s.values().snapIndex, 1);
    });

    testWidgets('velocity picks the stop: a flick one, a throw two', (tester) async {
      final s = await pump(tester, sheet);
      await tester.flingFrom(const Offset(200, 500), const Offset(0, -80), 400);
      await tester.pumpAndSettle();
      expect((ends(s).last['velocityY'] as num).abs(), greaterThan(300));
      expect(ends(s).last['snapIndex'], 1);
      expect(s.values().offset.dy, closeTo(-200, 0.01));
      // Grabbed where it is drawn now, 200px up.
      await tester.flingFrom(const Offset(200, 300), const Offset(0, 100), 3000);
      await tester.pumpAndSettle();
      expect(ends(s).last['snapIndex'], 0);
      await tester.flingFrom(const Offset(200, 500), const Offset(0, -100), 3000);
      await tester.pumpAndSettle();
      expect(ends(s).last['snapIndex'], 2);
      expect(s.values().offset.dy, closeTo(-400, 0.01));
    });

    testWidgets('past its limits the sheet stretches like a rubber band', (tester) async {
      final s = await pump(tester, sheet);
      final g = await tester.startGesture(const Offset(200, 500));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final held = s.values().offset.dy;
      expect(held, greaterThan(0));
      expect(held, lessThan(150));
      await g.up();
      await tester.pumpAndSettle();
      expect(s.values().offset.dy, closeTo(0, 0.01));
    });

    testWidgets('a vertical drag ignores sideways moves', (tester) async {
      final s = await pump(tester, sheet);
      await tester.dragFrom(const Offset(200, 500), const Offset(80, -150));
      await tester.pumpAndSettle();
      expect(s.values().offset.dx, 0);
    });

    testWidgets('a puck flings by friction and stops at its parent\'s edge', (tester) async {
      final s = await pump(tester, {
        'release': 'stay',
        'bounds': 'contain',
        'physics': {'friction': 0.6, 'overscroll': 0},
      });
      await tester.flingFrom(const Offset(200, 500), const Offset(-60, 0), 2000);
      await tester.pump();
      expect(ends(s).single['velocityX'] as num, lessThan(-1000));
      await tester.pump(const Duration(milliseconds: 30));
      expect(s.values().offset.dx, lessThan(-60));
      await tester.pumpAndSettle();
      // The left edge of the parent is 150px from where it rests.
      expect(s.values().offset.dx, closeTo(-150, 0.01));
    });

    testWidgets('a fling inside its bounds coasts to where friction stops it', (tester) async {
      const physics = api.GesturePhysics(friction: 0.9);
      final s = await pump(tester, {
        'release': 'stay',
        'physics': {'friction': 0.9},
      });
      await tester.flingFrom(const Offset(200, 500), const Offset(20, 0), 500);
      await tester.pump();
      final released = (ends(s).single['dx'] as num).toDouble();
      final velocity = (ends(s).single['velocityX'] as num).toDouble();
      await tester.pumpAndSettle();
      expect(s.values().offset.dx, closeTo(physics.projectFling(released, velocity), 1));
      expect(ends(s).single['targetX'] as num, closeTo(s.values().offset.dx, 1));
    });

    testWidgets('snap back with physics springs home with the release speed', (tester) async {
      final s = await pump(tester, {
        'physics': {'bounce': 0.4, 'duration': 500},
      });
      await tester.flingFrom(const Offset(200, 500), const Offset(60, 0), 1500);
      var furthest = 0.0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final dx = s.values().offset.dx;
        if (dx < furthest) furthest = dx;
      }
      // A bouncy spring overshoots rest on the way back.
      expect(furthest, lessThan(0));
      await tester.pumpAndSettle();
      expect(s.values().offset, Offset.zero);
    });

    testWidgets('without physics a drag still snaps back on its curve', (tester) async {
      final s = await pump(tester, {'snapBack': 300});
      await tester.dragFrom(const Offset(200, 500), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(s.values().offset.dx, greaterThan(0));
      await tester.pumpAndSettle();
      expect(s.values().offset.dx, closeTo(0, 0.01));
      expect(ends(s).single.containsKey('snapIndex'), isFalse);
    });
  });
}

abstract final class SchedulerBindingTicks {
  static bool active(WidgetTester tester) => tester.binding.transientCallbackCount > 0;
}
