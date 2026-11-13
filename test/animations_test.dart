// The animation player (render/animations.dart): its controller against
// Flutter's own AnimationController + Tween, tracks on the node's motion,
// opacity, any binding path and variables, the design canvas at rest, the
// animate action, play keys, exposed state, the frame trigger and the
// timer's expression interval.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_test/flutter_test.dart';

import 'support/screen.dart' show reaction, show, v;
import 'support/legacy.dart';

Json box(String id, Json extra, {double x = 0, double y = 0, double size = 40}) => {
      id: {
        'type': 'box',
        'layout': {'width': size, 'height': size, 'x': {'start': x}, 'y': {'start': y}},
        'decoration': {
          'fills': [
            {'color': '#FF000000'},
          ],
        },
        ...extra,
      },
    };

Map<String, Json> stack(List<Json> boxes) => {
      's': {
        'type': 'stack',
        'children': [for (final b in boxes) b.keys.single],
        'layout': {'width': 400, 'height': 400},
      },
      for (final b in boxes) b.keys.single: b.values.single as Json,
    };

Rect rectOf(WidgetTester tester, NodeTree tree, String id) {
  final b = tree.boxOf(id)!;
  final content = b.contentBox ?? b;
  final view = tester.renderObject(find.byType(NodeView));
  return MatrixUtils.transformRect(content.getTransformTo(view), Offset.zero & content.size);
}

RenderAnimations playerOf(NodeTree tree, String id) => tree.boxOf(id)!.animations!;

/// A plain tree (no bindings), drawn running or as a design canvas.
Future<NodeTree> plain(WidgetTester tester, Map<String, Json> nodes, {bool interactive = true}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': ['s'], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return tree;
}

void main() {
  group('an animation plays as Flutter\'s AnimationController does', () {
    // The clock and a real controller, ticked by the same frames.
    testWidgets('forward, reverse, animate-to, repeat and a spring give Flutter\'s values at sampled times', (tester) async {
      Future<void> compare(
        api.NodeAnimation spec,
        void Function(AnimationController c) startFlutter,
        Future<void> Function(AnimationClock c) startClock, {
        bool unbounded = false,
        double begin = 0,
      }) async {
        final controller = unbounded
            ? AnimationController.unbounded(vsync: const TestVSync())
            : AnimationController(vsync: const TestVSync(), duration: Duration(milliseconds: spec.durationMs), value: begin);
        addTearDown(controller.dispose);
        final clock = AnimationClock(spec)..value = begin;
        final curve = Curves.easeInOut;
        final tween = Tween<double>(begin: -20, end: 80);
        final track = const api.AnimationTrack(path: 'motion.translateX', from: -20, to: 80);
        final ticker = Ticker((elapsed) => clock.tick(elapsed));
        addTearDown(ticker.dispose);
        startFlutter(controller);
        unawaited(startClock(clock));
        ticker.start();
        for (var frame = 0; frame < 80; frame++) {
          await tester.pump(Duration(milliseconds: frame == 0 ? 0 : 16));
          expect(clock.value, closeTo(controller.value, 1e-9), reason: 'value');
          if (!unbounded) {
            final want = tween.transform(curve.transform(controller.value.clamp(0, 1)));
            final got = api.readDouble(track.valueAt(api.AnimationCurve.easeInOut.transform(clock.value)))!;
            expect(got, closeTo(want, 1e-9), reason: 'tween');
            expect(clock.status, controller.status, reason: 'status at ${controller.value}');
          }
        }
        controller.stop();
      }

      const spec = api.NodeAnimation(id: 'a', duration: 1000);
      await compare(spec, (c) => c.forward(), (c) => c.forward());
      await compare(spec, (c) => c.reverse(), (c) => c.reverse(), begin: 1);
      await compare(spec, (c) => c.animateTo(0.6, duration: const Duration(milliseconds: 700), curve: Curves.easeOut),
          (c) => c.animateTo(0.6, durationMs: 700, curve: api.AnimationCurve.easeOut));
      // From part way: the time left scales with the distance.
      await compare(spec, (c) => c.forward(), (c) => c.forward(), begin: 0.25);
      const rep = api.NodeAnimation(id: 'r', duration: 400, repeat: api.AnimationRepeat(reverse: true));
      await compare(rep, (c) => c.repeat(reverse: true), (c) => c.repeat());
      // A spring: animateWith(SpringSimulation), not held to 0–1.
      const spring = api.Spring(duration: 500, bounce: 0.4);
      final desc = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 500), bounce: 0.4);
      await compare(const api.NodeAnimation(id: 's', spring: spring), (c) => c.animateWith(SpringSimulation(desc, 0, 1, 0)),
          (c) => c.forward(), unbounded: true);
    });
  });

  group('animation tracks', () {
    testWidgets('an entrance with two tracks plays, and the design canvas shows it at its end', (tester) async {
      final nodes = stack([
        box('card', {
          'animations': [
            {
              'id': 'enter',
              'duration': 1000,
              'tracks': [
                {'path': 'motion.translateY', 'from': -100},
                {'path': 'opacity', 'from': 0, 'interval': [0, 0.5]},
              ],
            },
          ],
        }, x: 100, y: 200),
      ]);
      final tree = await plain(tester, nodes);
      await tester.pump();
      expect(rectOf(tester, tree, 'card').top, 100);
      expect(playerOf(tree, 'card').opacity, 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(rectOf(tester, tree, 'card').top, closeTo(125, 0.01));
      expect(playerOf(tree, 'card').opacity, closeTo(0.5, 1e-9));
      await tester.pump(const Duration(milliseconds: 500));
      expect(rectOf(tester, tree, 'card').top, closeTo(175, 0.01));
      expect(playerOf(tree, 'card').opacity, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(rectOf(tester, tree, 'card').top, 200);
      expect(playerOf(tree, 'card').clockOf('enter')!.status, AnimationStatus.completed);
      expect(tester.binding.transientCallbackCount, 0);

      final canvas = await plain(tester, nodes, interactive: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rectOf(tester, canvas, 'card'), const Rect.fromLTWH(100, 200, 40, 40));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('an animation at rest is drawn on the design canvas at its preview point', (tester) async {
      final tree = await plain(
          tester,
          stack([
            box('k', {
              'animations': [
                {'id': 'grow', 'tracks': [{'path': 'motion.scale', 'from': 1, 'to': 2}], 'previewAt': 0.5},
              ],
            }, x: 100, y: 100),
          ]),
          interactive: false);
      expect(rectOf(tester, tree, 'k').width, closeTo(60, 0.01));
    });

    testWidgets('a paint\'s path and a variable can follow an animation', (tester) async {
      final s = await show(
          tester,
          stack([
            box('k', {
              'animations': [
                {
                  'id': 'tint',
                  'duration': 1000,
                  'tracks': [
                    {'path': 'decoration.fills[0].color', 'from': '#FF000000', 'to': '#FFFFFFFF'},
                    {'variable': 'level', 'from': 0, 'to': 10},
                  ],
                },
              ],
            }),
          ]),
          root: 's',
          variables: [v('level', 0, VariableType.decimal)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(s['level'] as num, closeTo(5, 0.2));
      final shown = s.tree.resolve('k')!;
      final c = shown.decoration.fills.first.color!;
      expect(c.red, inInclusiveRange(120, 135));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(s['level'], 10);
      expect(s.tree.resolve('k')!.decoration.fills.first.color, const api.Color(0xFFFFFFFF));
    });
  });

  group('cues and commands', () {
    testWidgets('the animate action plays a node\'s animation while the chain waits, and a play key cues it', (tester) async {
      final s = await show(
          tester,
          stack([
            box('k', {
              'animations': [
                {
                  'id': 'slide',
                  'duration': 400,
                  'autoplay': false,
                  'tracks': [{'path': 'motion.translateX', 'blend': 'add', 'from': 0, 'to': 100}],
                },
              ],
              'bind': {'animations.slide.playKey': r'${cue}'},
              'actions': [
                reaction('click', [
                  {'type': 'animate', 'animation': 'slide'},
                  {'type': 'setVariable', 'variable': 'done', 'value': 'yes'},
                ]),
              ],
            }),
          ]),
          root: 's',
          variables: [v('cue', ''), v('done', 'no')]);
      await tester.pump();
      expect(rectOf(tester, s.tree, 'k').left, 0);
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(rectOf(tester, s.tree, 'k').left, closeTo(50, 1));
      expect(s['done'], 'no');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(rectOf(tester, s.tree, 'k').left, 100);
      expect(s['done'], 'yes');
      // Reverse from a command elsewhere.
      await const CodelesslyActions().run(
          migratedNode({
            'type': 'box',
            'actions': [
              reaction('click', [
                {'type': 'animate', 'node': 'k', 'animation': 'slide', 'command': 'reverse', 'nonBlocking': true},
              ]),
            ],
          }, id: 'tap')!,
          'click',
          s.context);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(rectOf(tester, s.tree, 'k').left, 0);
      // A falsy cue doesn't play; a new value does.
      s.scope.set('cue', '0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rectOf(tester, s.tree, 'k').left, 0);
      s.scope.set('cue', 'go');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rectOf(tester, s.tree, 'k').left, greaterThan(10));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a motion\'s pulse key plays its keyframes there and back', (tester) async {
      final s = await show(
          tester,
          stack([
            box('k', {
              'motion': {
                'duration': 400,
                'curve': 'linear',
                'keyframes': [
                  {'t': 0.5, 'translateX': 40},
                ],
              },
              'bind': {'motion.pulseKey': r'${bump}'},
            }),
          ]),
          root: 's',
          variables: [v('bump', 0, VariableType.integer)]);
      await tester.pump();
      expect(rectOf(tester, s.tree, 'k').left, 0);
      s.scope.set('bump', 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(rectOf(tester, s.tree, 'k').left, closeTo(40, 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(rectOf(tester, s.tree, 'k').left, 0);
    });

    testWidgets('an animation\'s value, status and whether it is running can be read in formulas', (tester) async {
      final s = await show(
          tester,
          {
            's': {
              'type': 'stack',
              'children': ['label'],
              'layout': {'width': 400, 'height': 400},
              'animations': [
                {'id': 'year', 'duration': 1000},
              ],
              'actions': [
                reaction('valueChanged', [
                  {'type': 'setVariable', 'variable': 'seen', 'value': r'${animation.year.status}'},
                ], extra: {'variable': 'animation.year.status'}),
              ],
            },
            'label': {
              'type': 'text',
              'layout': {'width': 200, 'height': 20},
              'props': {'text': r'${animation.year.status}'},
            },
          },
          root: 's',
          variables: [v('seen', '')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      String shown() => s.tree.resolve('label')!.prop(api.TextProps.text);
      expect(shown(), 'forward');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(shown(), 'completed');
      expect(s['seen'], 'completed');
    });
  });

  group('frame and timer triggers', () {
    testWidgets('a frame trigger runs every frame while its condition holds, with the time since the last frame and since it started', (tester) async {
      final s = await show(
          tester,
          stack([
            box('k', {
              'actions': [
                reaction('frame', [
                  {'type': 'setVariable', 'variable': 'frames', 'op': 'add', 'value': '1'},
                  {'type': 'setVariable', 'variable': 'time', 'op': 'add', 'value': r'${result.dt}'},
                ], extra: {'when': r'${running}'}),
              ],
            }),
          ]),
          root: 's',
          variables: [v('frames', 0, VariableType.integer), v('time', 0, VariableType.decimal), v('running', true, VariableType.boolean)]);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s['frames'] as int, greaterThanOrEqualTo(8));
      expect(s['time'] as num, closeTo(16.0 * ((s['frames'] as int) - 1), 17));
      s.scope.set('running', false);
      await tester.pump(const Duration(milliseconds: 16));
      final stopped = s['frames'];
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s['frames'], stopped);
    });

    testWidgets('a timer\'s interval can be a formula', (tester) async {
      final s = await show(
          tester,
          stack([
            box('k', {
              'actions': [
                reaction('timer', [
                  {'type': 'setVariable', 'variable': 'ticks', 'op': 'add', 'value': '1'},
                ], extra: {'intervalMs': r'${= 1000 / rate}'}),
              ],
            }),
          ]),
          root: 's',
          variables: [v('ticks', 0, VariableType.integer), v('rate', 10, VariableType.integer)]);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(s['ticks'], 10);
      s.scope.set('rate', 2);
      await tester.pump();
      final at = s['ticks'] as int;
      await tester.pump(const Duration(milliseconds: 1050));
      expect((s['ticks'] as int) - at, 2);
    });
  });

  testWidgets('an older loop and the same loop written as an animation draw the same', (tester) async {
    final legacy = await plain(
        tester,
        stack([
          box('l', {
            'loops': [
              {'type': 'pulse', 'scaleFrom': 0.5, 'opacityFrom': 0.2, 'duration': 600, 'reverse': true, 'lag': 150, 'curve': 'easeInOut'},
            ],
          }, x: 100, y: 100),
        ]));
    final legacyRects = <Rect>[], legacyOpacity = <double>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 97));
      legacyRects.add(rectOf(tester, legacy, 'l'));
      legacyOpacity.add(playerOf(legacy, 'l').opacity);
    }
    final explicit = await plain(
        tester,
        stack([
          box('l', {
            'animations': [
              {
                'id': 'loop0',
                'duration': 600,
                'curve': 'easeInOut',
                'repeat': {'reverse': true},
                'phase': 0.875,
                'tracks': [
                  {'path': 'motion.scale', 'blend': 'multiply', 'from': 0.5, 'to': 1},
                  {'path': 'opacity', 'blend': 'multiply', 'from': 0.2, 'to': 1},
                ],
              },
            ],
          }, x: 100, y: 100),
        ]));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 97));
      final r = rectOf(tester, explicit, 'l');
      expect(r.left, closeTo(legacyRects[i].left, 1e-6));
      expect(r.width, closeTo(legacyRects[i].width, 1e-6));
      expect(playerOf(explicit, 'l').opacity, closeTo(legacyOpacity[i], 1e-9));
    }
  });
}
