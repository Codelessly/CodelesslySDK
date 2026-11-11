// One-shot effects (shake, wiggle, jelly... with their cycles), played by a
// playAnimation action, a bound cue or on appear; and the fly-in by flight
// key.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> at(double x, double y, double w, double h) =>
    {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}};

class Screen {
  Screen(Map<String, Object?> nodes, {List<Variable> variables = const []}) : scope = VariableScope(variables) {
    final doc = LayoutDocument.fromJson({
      'roots': ['r'],
      'nodes': {
        'r': {
          'type': 'stack',
          'children': [...nodes.keys],
          'layout': {'width': 400, 'height': 400},
        },
        ...nodes,
      },
    });
    tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: scope, logic: const LayoutLogic()));
    context = RuntimeActionContext(scope: scope, tree: tree);
  }

  final VariableScope scope;
  late final NodeTree tree;
  late final RuntimeActionContext context;

  Future<void> pump(WidgetTester tester, {bool interactive = true}) async {
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r', interactive: interactive)),
    ));
    await tester.pump();
  }

  Future<void> run(List<Json> actions) => const CodelesslyActions().run(
        Node.fromJson({
          'type': 'box',
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': actions},
          ],
        }, id: 'tap')!,
        'click',
        context,
      );

  /// Where node [id]'s content is drawn now (its effects and flights
  /// applied).
  Rect rectOf(WidgetTester tester, String id) {
    final box = tree.boxOf(id)!;
    final content = box.contentBox ?? box;
    final view = tester.renderObject(find.byType(NodeView));
    return MatrixUtils.transformRect(content.getTransformTo(view), Offset.zero & content.size);
  }
}

Map<String, Object?> box(Map<String, Object?> extra) => {
      'type': 'box',
      'layout': at(100, 100, 50, 50),
      'decoration': {
        'fills': [
          {'color': '#FF000000'},
        ],
      },
      ...extra,
    };

void main() {
  test('a shake swings its own count unless cycles says', () {
    expect(effectTransformAt(EffectAnimationType.shake, 1 / 16, 1).dx, closeTo(12 * (1 - 1 / 16), 1e-9));
    const t = 1 / 12;
    expect(
      effectTransformAt(EffectAnimationType.shake, t, 8 / 12, cycles: 3).dx,
      closeTo(math.sin(t * math.pi * 6) * 8 * (1 - t), 1e-9),
    );
    // A wiggle's three swings, a jelly's two, unless cycles says.
    expect(effectTransformAt(EffectAnimationType.wiggle, 1 / 12, 1).rotation, closeTo(0.14 * (1 - 1 / 12), 1e-9));
    expect(effectTransformAt(EffectAnimationType.jelly, 1 / 20, 1, cycles: 5).sx, closeTo(1 + 0.16 * 0.95, 1e-9));
    expect(effectTransformAt(EffectAnimationType.flash, 0.25, 1).opacity, closeTo(0, 1e-9));
  });

  testWidgets('playAnimation particles waits for emission and particle lifetime', (tester) async {
    final s = Screen({'n': box({'particles': {'count': 5, 'emit': 100, 'lifetime': 200}})});
    await s.pump(tester);
    var done = false;
    unawaited(s.run([{'type': 'playAnimation', 'node': 'n', 'animation': 'particles'}]).then((_) => done = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, isTrue);
  });

  testWidgets('playAnimation plays the named effect; the chain waits for it', (tester) async {
    final s = Screen({
      'n': box({
        'effectAnimations': [
          {'name': 'nudge', 'type': 'shake', 'duration': 400, 'cycles': 2},
        ],
      }),
    });
    await s.pump(tester);
    expect(s.rectOf(tester, 'n').left, 100);
    var done = false;
    unawaited(s.run([
      {'type': 'playAnimation', 'node': 'n', 'animation': 'nudge'},
    ]).then((_) => done = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Two swings over 400 ms: a quarter swing in at 50 ms, pushed right.
    expect(s.rectOf(tester, 'n').left, greaterThan(105));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(s.rectOf(tester, 'n').left, 100);
    expect(done, isTrue);
  });

  testWidgets('a bound cue plays it when it changes (not when it first shows); a delay waits', (tester) async {
    final s = Screen({
      'n': box({
        'effectAnimations': [
          {'name': 'pop', 'type': 'pop', 'duration': 400, 'delay': 100},
        ],
        'bind': {'effectAnimations[0].playKey': r'${hits}'},
      }),
    }, variables: [const Variable(name: 'hits', type: VariableType.integer, value: 0)]);
    await s.pump(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(s.rectOf(tester, 'n').width, 50);
    s.scope.set('hits', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Still waiting for its delay.
    expect(s.rectOf(tester, 'n').width, 50);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    expect(s.rectOf(tester, 'n').width, greaterThan(55));
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.rectOf(tester, 'n').width, 50);
  });

  testWidgets('a cue that clears does not play: nodes can share one cue', (tester) async {
    final s = Screen({
      'n': box({
        'effectAnimations': [
          {'name': 'shake', 'type': 'shake', 'duration': 300},
        ],
        // Shakes only when the shared cue names this node.
        'bind': {'effectAnimations[0].playKey': r"${= shake.cell == 4 ? shake.tick : ''}"},
      }),
    }, variables: [
      const Variable(name: 'shake', type: VariableType.map, value: {'cell': -1, 'tick': 0}),
    ]);
    await s.pump(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(s.rectOf(tester, 'n').left, 100);
    s.scope.set('shake', {'cell': 4, 'tick': 1});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(s.rectOf(tester, 'n').left, isNot(100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(s.rectOf(tester, 'n').left, 100);
    // Another node's turn: this cue clears, and nothing plays here.
    s.scope.set('shake', {'cell': 7, 'tick': 2});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(s.rectOf(tester, 'n').left, 100);
    // Its turn again with a new tick: it plays.
    s.scope.set('shake', {'cell': 4, 'tick': 3});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(s.rectOf(tester, 'n').left, isNot(100));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('playOnAppear plays as it shows; a design canvas never plays', (tester) async {
    final s = Screen({
      'n': box({
        'effectAnimations': [
          {'name': 'in', 'type': 'wiggle', 'duration': 600, 'playOnAppear': true},
        ],
      }),
    });
    await s.pump(tester);
    await tester.pump(const Duration(milliseconds: 60));
    final r = s.rectOf(tester, 'n');
    // Turned: its bounds grow.
    expect(r.width, greaterThan(50.5));
    await tester.pump(const Duration(milliseconds: 700));

    final canvas = Screen({
      'n': box({
        'effectAnimations': [
          {'name': 'in', 'type': 'wiggle', 'duration': 600, 'playOnAppear': true},
        ],
      }),
    });
    await canvas.pump(tester, interactive: false);
    await tester.pump(const Duration(milliseconds: 60));
    expect(canvas.rectOf(tester, 'n'), const Rect.fromLTWH(100, 100, 50, 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a node flies in from where the node with its flight key was', (tester) async {
    FlightRegistry.reset();
    final s = Screen({
      'a': box({'layout': at(0, 0, 40, 40), 'flightKey': r'tile', 'bind': {'visible': r'${!moved}'}}),
      'b': box({'layout': at(200, 200, 80, 80), 'flightKey': r'tile', 'bind': {'visible': r'${moved}'}}),
    }, variables: [const Variable(name: 'moved', type: VariableType.boolean, value: false)]);
    await s.pump(tester);
    s.scope.set('moved', true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final early = s.rectOf(tester, 'b');
    // Starts near the old place and size, then springs home.
    expect(early.center.dx, lessThan(200));
    expect(early.width, lessThan(80));
    await tester.pumpAndSettle();
    expect(s.rectOf(tester, 'b'), const Rect.fromLTWH(200, 200, 80, 80));
  });

  testWidgets('a timed flight arcs above both ends, swells mid-way and lands upright', (tester) async {
    FlightRegistry.reset();
    final flight = {'duration': 720, 'curve': 'linear', 'lift': 110, 'swell': 1.75, 'turns': 0.6, 'trail': 4};
    final s = Screen({
      'a': box({'layout': at(200, 300, 40, 40), 'flightKey': r'react', 'bind': {'visible': r'${!moved}'}}),
      'b': box({'layout': at(40, 320, 40, 40), 'flightKey': r'react', 'flight': flight, 'bind': {'visible': r'${moved}'}}),
    }, variables: [const Variable(name: 'moved', type: VariableType.boolean, value: false)]);
    await s.pump(tester);
    s.scope.set('moved', true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    final mid = s.rectOf(tester, 'b');
    // Half-way along x, well above both ends (lift 110 over the higher, y 300).
    expect(mid.center.dx, closeTo(140, 2));
    expect(mid.center.dy, lessThan(300));
    // Swollen: 1.75 times its size at the middle.
    expect(mid.width, greaterThan(60));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(s.rectOf(tester, 'b'), const Rect.fromLTWH(40, 320, 40, 40));
  });

  testWidgets('a node flies from a holder on a popover that is closing', (tester) async {
    FlightRegistry.reset();
    final flight = {'duration': 720, 'curve': 'linear', 'lift': 110};
    final s = Screen({
      'b': box({'layout': at(40, 320, 40, 40), 'flightKey': r'react', 'flight': flight, 'bind': {'visible': r'${moved}'}}),
    }, variables: [const Variable(name: 'moved', type: VariableType.boolean, value: false)]);
    final picker = Screen({
      'a': box({'layout': at(200, 100, 40, 40), 'flightKey': r'react'}),
    });
    await s.pump(tester);
    final nav = Navigator.of(tester.element(find.byType(NodeView)));
    unawaited(nav.push(PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) {
        HeroRoutes.bind(picker.tree, ModalRoute.of(context));
        return Align(alignment: Alignment.topLeft, child: NodeView(tree: picker.tree, rootId: 'r', interactive: true));
      },
      transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    )));
    await tester.pumpAndSettle();
    // Picked: the popover starts closing and the chip's emoji shows at once,
    // while the picker still fades out.
    nav.pop();
    // ignore: avoid_print
    s.scope.set('moved', true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final b = s.tree.boxOf('b')!;
    final content = b.contentBox ?? b;
    final early = MatrixUtils.transformRect(content.getTransformTo(null), Offset.zero & content.size);
    // On its way from the picker (x 200) to its place (x 40).
    expect(early.left, greaterThan(50));
    await tester.pumpAndSettle();
    final landed = MatrixUtils.transformRect(content.getTransformTo(null), Offset.zero & content.size);
    expect(landed, const Rect.fromLTWH(40, 320, 40, 40));
  });

  testWidgets('a flight keeps going when hovering its card re-parents it', (tester) async {
    FlightRegistry.reset();
    final flight = {'duration': 720, 'curve': 'linear', 'lift': 110};
    final s = Screen({
      'a': box({'layout': at(300, 300, 40, 40), 'flightKey': r'react', 'bind': {'visible': r'${!moved}'}}),
      'card': {
        'type': 'stack',
        'children': ['b'],
        'layout': at(0, 200, 200, 200),
        // Hovered, the card lifts: a motion its box didn't have.
        'states': {
          'hovered': {'card': {'motion': {'translateX': -2, 'translateY': -2, 'duration': 180}}},
        },
      },
      'b': box({'layout': at(40, 120, 40, 40), 'flightKey': r'react', 'flight': flight, 'bind': {'visible': r'${moved}'}}),
    }, variables: [const Variable(name: 'moved', type: VariableType.boolean, value: false)]);
    await s.pump(tester);
    s.scope.set('moved', true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(100, 250));
    addTearDown(gesture.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    final mid = s.rectOf(tester, 'b');
    // Half-way: well off its place (40, 320), not frozen where it started.
    expect(mid.center.dx, inExclusiveRange(80, 280));
    await tester.pumpAndSettle();
    expect(s.rectOf(tester, 'b').topLeft, const Offset(38, 318));
  });
}
