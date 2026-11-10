// One-shot effects (shake, wiggle, jelly... with their cycles), played by a
// playAnimation action, a bound cue or on appear; and the fly-in by flight
// key.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
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
}
