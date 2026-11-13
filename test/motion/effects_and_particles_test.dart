import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/particles.dart';
import 'package:codelessly_sdk/src/render/animations.dart' show RenderAnimations;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/legacy.dart';

// Keyframed one-shot effects (a hop with squash and stretch, a fly-away and
// back) and image particles (petals, seeds, raindrops).

const hop = [
  {'t': 0.12, 'scaleX': 1.07, 'scaleY': 0.86},
  {'t': 0.45, 'translateY': -110, 'scaleY': 1.1, 'scaleX': 0.95},
  {'t': 0.75, 'translateY': 0, 'scaleY': 1, 'scaleX': 1},
  {'t': 0.88, 'scaleY': 0.9, 'scaleX': 1.05},
];

class Particles extends SingleChildRenderObjectWidget {
  const Particles(this.emitter, {super.key})
    : super(child: const SizedBox(width: 100, height: 100));
  final api.ParticleEmitter emitter;
  @override
  RenderParticles createRenderObject(BuildContext context) => RenderParticles()
    ..nodeId = 'test'
    ..emitter = emitter;
  @override
  void updateRenderObject(BuildContext context, RenderParticles object) =>
      object.emitter = emitter;
}

class ConfettiBurst extends SingleChildRenderObjectWidget {
  const ConfettiBurst(this.emitter, {super.key}) : super(child: const SizedBox(width: 200, height: 200));
  final api.ParticleEmitter emitter;
  @override
  RenderParticles createRenderObject(BuildContext context) => RenderParticles()
    ..nodeId = 'paper'
    ..emitter = emitter;
}

// One-shot effects (shake, wiggle, jelly... with their cycles), played by a
// playAnimation action, a bound cue or on appear; and the fly-in by flight
// key.

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
        migratedNode({
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
  group('a played effect', () {
    testWidgets('changing a node\'s bound play key plays its keyframes, then it rests', (tester) async {
      final screen = await lists.show(
        tester,
        {
          'col': {
            'type': 'stack',
            'children': ['frog'],
            'layout': {'width': 400, 'height': 400},
          },
          'frog': {
            'type': 'box',
            'layout': {'width': 100, 'height': 100, 'x': {'start': 150}, 'y': {'start': 250}},
            'decoration': {'fills': [{'color': '#FF00AA00'}]},
            'effectAnimations': [
              {'name': 'hop', 'type': 'keyframes', 'duration': 1000, 'keyframes': hop},
            ],
            'particles': {'shapes': ['image'], 'image': 'https://example.com/petal.png', 'count': 8},
            'bind': {'effectAnimations[0].playKey': r'${taps}', 'particles.playKey': r'${taps}'},
          },
        },
        root: 'col',
        variables: [lists.v('taps', 0, api.VariableType.integer)],
      );
      RenderAnimations effects() {
        RenderAnimations? found;
        void visit(RenderObject o) {
          if (o is RenderAnimations) found = o;
          o.visitChildren(visit);
        }

        visit(tester.binding.renderView);
        return found!;
      }

      final particles = () {
        RenderParticles? found;
        void visit(RenderObject o) {
          if (o is RenderParticles) found = o;
          o.visitChildren(visit);
        }

        visit(tester.binding.renderView);
        return found!;
      }();
      screen.scope.set('taps', 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      final mid = effects().effectiveTransform.getTranslation();
      expect(mid.y, lessThan(-60), reason: 'up in the air at 45%');
      expect(particles.activeBursts, 1);
      await tester.pump(const Duration(milliseconds: 700));
      expect(effects().effectiveTransform.getTranslation().y, closeTo(0, 0.01));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a play action plays the named effect and the next action waits for it', (tester) async {
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

    testWidgets('a bound cue plays the effect when it changes, not when it first shows', (tester) async {
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

    testWidgets('an effect set to play on appear plays as the node shows, and never on the design canvas', (tester) async {
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

    testWidgets('a node flies in from where the node sharing its flight key was', (tester) async {
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
  
  });

  group('particles', () {
    testWidgets(
      'a play action fires particles and finishes when the last one has died',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Particles(api.ParticleEmitter(emit: 100, lifetime: 200)),
            ),
          ),
        );
        final render = tester.renderObject<RenderParticles>(
          find.byType(Particles),
        );
        var done = false;
        ParticlePlayers.play('test', 'particles').then((_) {
          done = true;
        });
        expect(render.activeBursts, 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(done, false);
        await tester.pump(const Duration(milliseconds: 200));
        expect(done, true);
        expect(render.activeBursts, 0);
      },
    );
    testWidgets('a change of the play key fires one burst, and removing the node finishes waiting actions', (
      tester,
    ) async {
      Widget view(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: Particles(api.ParticleEmitter(playKey: key)),
      );
      await tester.pumpWidget(view('a'));
      final render = tester.renderObject<RenderParticles>(find.byType(Particles));
      expect(render.activeBursts, 0);
      await tester.pumpWidget(view('b'));
      expect(render.activeBursts, 1);
      await tester.pumpWidget(view('b'));
      expect(render.activeBursts, 1);
      var done = false;
      ParticlePlayers.play('test', 'particles').then((_) {
        done = true;
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(done, true);
    });
    testWidgets('particles with no colors or a zero count are harmless', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Particles(
            api.ParticleEmitter(
              playOnAppear: true,
              colors: [],
              shapes: [],
              lifetime: 50,
            ),
          ),
        ),
      );
      final render = tester.renderObject<RenderParticles>(find.byType(Particles));
      expect(render.activeBursts, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(render.activeBursts, 0);
    });

    testWidgets('a delayed burst waits, then runs, painting emoji, triangles and squiggles', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConfettiBurst(api.ParticleEmitter(
            count: 12,
            delay: 300,
            lifetime: 200,
            mirror: true,
            drag: 1.9,
            terminalVelocity: 135,
            sway: 10,
            flutter: 11,
            fadeOut: 100,
            glyph: '🔥',
            shapes: [api.ParticleShape.emoji, api.ParticleShape.triangle, api.ParticleShape.squiggle],
          )),
        ),
      ));
      final render = tester.renderObject<RenderParticles>(find.byType(ConfettiBurst));
      var done = false;
      ParticlePlayers.play('paper', 'particles').then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(done, false, reason: 'still waiting out the delay');
      await tester.pump(const Duration(milliseconds: 150));
      expect(render.activeBursts, 1);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, true);
      expect(render.activeBursts, 0);
    });
  });

}
