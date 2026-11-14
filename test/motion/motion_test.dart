
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Json, LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart';
import 'package:codelessly_sdk/src/render/animations.dart' show RenderAnimations;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

LayoutDocument page(Map<String, Map<String, Object?>> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

Future<(NodeTree, RenderObject)> show(WidgetTester tester, LayoutDocument doc, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

// Behaviors, at rest and running: motion swing,
// phase, pause, arc, wrapping and paced paths, upright orientation and
// shimmer; loop phases; drag tracks parked, relative and in their parent.

Map<String, Object?> doc(Map<String, Map<String, Object?>> nodes) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    };

Future<(NodeTree, RenderObject, DocumentSource)> showMotion(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {bool interactive = false}) async {
  final source = DocumentSource(api.LayoutDocument.fromJson(doc(nodes)));
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)), source);
}

Map<String, Object?> box(Map<String, Object?> extra, {double x = 0, double y = 0, double size = 20}) => {
      'type': 'box',
      'layout': {'width': size, 'height': size, 'x': {'start': x}, 'y': {'start': y}},
      ...extra,
    };

T? _find<T extends RenderObject>(RenderObject root) {
  T? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is T) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(root);
  return found;
}

Map<String, Map<String, Object?>> card({bool flipped = false, Map<String, Object?> motion = const {}}) => {
      'card': {
        'type': 'stack',
        'children': ['front', 'back'],
        'layout': {'width': 100, 'height': 60, 'x': {'start': 0}, 'y': {'start': 0}},
        'flip': {if (flipped) 'flipped': true},
        if (motion.isNotEmpty) 'motion': motion,
      },
      'front': {'type': 'box', 'layout': {'width': 100, 'height': 60}, 'decoration': {'fills': [{'color': '#FFFF0000'}]}},
      'back': {'type': 'box', 'layout': {'width': 100, 'height': 60}, 'decoration': {'fills': [{'color': '#FF0000FF'}]}},
    };

// An entrance held until its page settles (`motion.enterHeld`, bound), and
// replayed when `motion.replayKey` changes.

// motion.replayKey: a change of the key replays the entrance (after its
// delay, through its keyframes), as Rota's auto-fill drops shifts into
// their cells one after another and a refused drop shakes its chip.

Future<(VariableScope, NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Json> nodes) async {
  final scope = VariableScope(const [
    Variable(name: 'stamp', type: VariableType.integer, value: 0),
    Variable(name: 'shake', type: VariableType.text, value: ''),
  ]);
  final tree = NodeTree(
    DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    })),
    binder: NodeBinder(scope: scope),
  );
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
  ));
  return (scope, tree, tester.renderObject(find.byType(NodeView)));
}

// A motion path in a viewBox, stretched over the node's parent (Strata v2:
// a trackmaker walks up a dune on a figure whose size follows the screen).

Map<String, Json> figure(double width, double height, {List<double>? viewBox, double progress = 1}) => {
      'stage': {
        'type': 'stack',
        'layout': {'width': width, 'height': height},
        'children': ['walker'],
      },
      'walker': {
        'type': 'box',
        'layout': {'width': 10, 'height': 10},
        'motion': {
          'path': 'M0 0 L320 0 L320 180',
          'pathProgress': progress,
          'pathViewBox': ?viewBox,
        },
      },
    };

Offset _at(NodeTree tree, String id) => tree.boxOf(id)!.contentBox!.localToGlobal(Offset.zero) - tree.boxOf('stage')!.localToGlobal(Offset.zero);

// The Lineworks train: a looping motion along a path with keyframes for
// pacing and fades, its path, length and keyframes bound to the plan.

// With the platform asking for no animation (prefers-reduced-motion), a
// loop rests at its first frame, as the design canvas draws it.

void main() {
  testWidgets('on the design canvas animated nodes rest in their final state', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          'm': {
            'type': 'box',
            'layout': {'width': 40, 'height': 20, 'x': {'start': 10}, 'y': {'start': 10}},
            'motion': {'translateX': 30, 'scale': 2, 'duration': 500, 'enter': true},
          },
          'l': {
            'type': 'box',
            'layout': {'width': 40, 'height': 40, 'x': {'start': 100}, 'y': {'start': 100}},
            'loops': [
              {'type': 'scale', 'scaleFrom': 0.5, 'duration': 300}
            ],
          },
          'k': {
            'type': 'box',
            'layout': {'width': 20, 'height': 20, 'x': {'start': 200}, 'y': {'start': 200}},
            'drag': {
              'track': {'variable': 'v', 'x2': 100, 'y2': 0, 'max': 10, 'value': 5}
            },
          },
        }));
    // At its values (an entrance doesn't wait at its start), scaled about
    // its center.
    expect(tree.boxOf('m')!.rectIn(view), const Rect.fromLTWH(20, 0, 80, 40));
    // A loop's first frame.
    expect(tree.boxOf('l')!.rectIn(view), const Rect.fromLTWH(110, 110, 20, 20));
    // A track's control at its variable's value.
    expect(tree.boxOf('k')!.rectIn(view), const Rect.fromLTWH(250, 200, 20, 20));
    // Nothing ticks.
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a running app plays entrances and loops', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          'm': {
            'type': 'box',
            'layout': {'width': 40, 'height': 20},
            'motion': {'translateX': 100, 'duration': 1000, 'curve': 'linear', 'enter': true},
          },
          'l': {
            'type': 'box',
            'layout': {'width': 40, 'height': 40, 'x': {'start': 100}, 'y': {'start': 100}},
            'loops': [
              {'type': 'scale', 'scaleFrom': 0.5, 'duration': 1000, 'reverse': true}
            ],
          },
        }),
        interactive: true);
    await tester.pump();
    expect(tree.boxOf('m')!.rectIn(view)!.left, 0);
    expect(tree.boxOf('l')!.rectIn(view)!.width, 20);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tree.boxOf('m')!.rectIn(view)!.left, closeTo(50, 1));
    expect(tree.boxOf('l')!.rectIn(view)!.width, closeTo(30, 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tree.boxOf('m')!.rectIn(view)!.left, 100);
    // Back down, the second run.
    expect(tree.boxOf('l')!.rectIn(view)!.width, closeTo(39, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('blurs and drawn paths paint around the node\'s content', (tester) async {
    final (tree, view) = await show(
        tester,
        page({
          't': {
            'type': 'text',
            'props': {'text': 'Blur'},
            'decoration': {
              'effects': [
                {'type': 'layerBlur', 'blurRadius': 2}
              ]
            },
            'layout': {'width': {'hug': 10}, 'height': {'hug': 10}},
          },
          'p': {
            'type': 'box',
            'layout': {'width': 100, 'height': 50, 'x': {'start': 50}},
            'decoration': {
              'radius': 8,
              'effects': [
                {'type': 'backgroundBlur', 'blurRadius': 10}
              ]
            },
            'strokePath': {
              'points': [
                [0, 0],
                [100, 40]
              ],
              'xUnit': 'pixels',
            },
          },
        }));
    expect(tree.boxOf('t')!.rectIn(view), isNotNull);
    // The drawn path is a custom paint path op (recorded as a picture).
    expect(find.byType(NodeView), paints..something((m, _) => m == #drawPicture));
    expect(tree.boxOf('p')!.rectIn(view), const Rect.fromLTWH(50, 0, 100, 50));
  });

  testWidgets('a drawn path with a draw-on time draws itself on in a running app', (tester) async {
    // The migration writes the draw-on as an animation of the custom paint
    // path op's trimEnd (frame by frame: test/custom_paint/stroke_draw_on_test.dart).
    final (tree, _) = await show(
        tester,
        page({
          'p': {
            'type': 'box',
            'layout': {'width': 100, 'height': 50},
            'strokePath': {
              'points': [
                [0, 0],
                [100, 40]
              ],
              'xUnit': 'pixels',
              'progress': 0.5,
              'drawMs': 400,
              'drawCurve': 'linear',
              'drawKey': 'a',
            },
          },
        }),
        interactive: true);
    final node = (tree.source as DocumentSource).document.nodes['p']!;
    expect(node.extra, isEmpty);
    final op = node.behaviors.customPaint!.painter.single as api.PathOp;
    expect(op.trimEnd.value, 0.5);
    expect(node.behaviors.animations.single.tracks.single.path, 'customPaint.painter.strokePath.trimEnd');
    double shown() => (tree.resolve('p')!.behaviors.customPaint!.painter.single as api.PathOp).trimEnd.value!;
    await tester.pump();
    expect(shown(), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(), closeTo(0.25, 1e-9));
    await tester.pump(const Duration(milliseconds: 300));
    expect(shown(), 0.5);
    expect(find.byType(NodeView), paints..something((m, _) => m == #drawPicture));
  });

  group('loops and effects', () {
    testWidgets('a swing rocks evenly to both sides of rest', (tester) async {
      final (tree, view, _) = await showMotion(
          tester,
          {
            'w': box({
              'motion': {'translateX': 40, 'loop': 'swing', 'duration': 1000},
            }, x: 100),
          },
          interactive: true);
      await tester.pump();
      // At rest, not at an end.
      expect(tree.boxOf('w')!.rectIn(view)!.left, closeTo(100, 0.5));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tree.boxOf('w')!.rectIn(view)!.left, closeTo(140, 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tree.boxOf('w')!.rectIn(view)!.left, closeTo(60, 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a loop starts at its phase, holds while paused and carries on when resumed', (tester) async {
      Map<String, Map<String, Object?>> nodes(bool paused) => {
            'p': box({
              'motion': {'translateX': 100, 'loop': 'restart', 'duration': 1000, 'curve': 'linear', 'phase': 0.25,
                         'paused': paused},
            }),
          };
      final (tree, view, source) = await showMotion(tester, nodes(false), interactive: true);
      await tester.pump();
      expect(tree.boxOf('p')!.rectIn(view)!.left, closeTo(25, 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tree.boxOf('p')!.rectIn(view)!.left, closeTo(50, 1));
      source.document = api.LayoutDocument.fromJson(doc(nodes(true)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tree.boxOf('p')!.rectIn(view)!.left, closeTo(50, 2));
      source.document = api.LayoutDocument.fromJson(doc(nodes(false)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tree.boxOf('p')!.rectIn(view)!.left, closeTo(70, 2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a shimmer sweeps in a running app and sits halfway on the design canvas', (tester) async {
      final (tree, _, _) = await showMotion(tester, {
        's': box({
          'decoration': {
            'fills': [
              {'color': '#FF888888'}
            ]
          },
          'motion': {
            'shimmer': {'duration': 1000}
          },
        }),
      });
      expect(tree.boxOf('s'), isNotNull);
      expect(find.byType(NodeView), findsOneWidget);
      final shimmer = _find<RenderShimmer>(tester.renderObject(find.byType(NodeView)));
      expect(shimmer, isNotNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

  });

  group('entrances', () {
    testWidgets('a held entrance waits at its start, plays when released and does not hold again', (tester) async {
      final screen = await lists.show(
        tester,
        {
          'col': {'type': 'stack', 'children': ['m'], 'layout': {'width': 400, 'height': 300}},
          'm': {
            'type': 'box',
            'layout': {'width': 40, 'height': 20, 'x': {'start': 0}, 'y': {'start': 100}},
            'motion': {
              'enter': true,
              'enterFrom': {'translateX': -100, 'opacity': 0},
              'duration': 1000,
              'curve': 'linear',
            },
            'bind': {'motion.enterHeld': r'${= !settled}', 'motion.replayKey': r'${visit}'},
          },
        },
        variables: [lists.v('settled', false, api.VariableType.boolean), lists.v('visit', 'a')],
      );
      final view = tester.renderObject(find.byType(NodeView));
      double left() => screen.tree.boxOf('m')!.rectIn(view)!.left;
      await tester.pump(const Duration(milliseconds: 1500));
      expect(left(), -100, reason: 'held at the start');
      screen.scope.set('settled', true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(left(), closeTo(-50, 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(left(), 0);
      // Holding again doesn't send it back.
      screen.scope.set('settled', false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(left(), 0);
      // A new replay key plays the entrance again.
      screen.scope.set('settled', true);
      await tester.pump();
      screen.scope.set('visit', 'b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(left(), closeTo(-75, 2));
      await tester.pumpAndSettle();
      expect(left(), 0);
    });

    testWidgets('changing a node\'s replay key plays its entrance again, after its delay', (tester) async {
      final (scope, tree, view) = await _show(tester, {
        'chip': {
          'type': 'box',
          'layout': {'width': 40, 'height': 20, 'x': {'start': 0}, 'y': {'start': 100}},
          'motion': {'enter': true, 'enterFrom': {'translateY': -100}, 'duration': 400, 'delay': 200, 'curve': 'linear'},
          'bind': {'motion.replayKey': r"${= 'fill' + stamp}"},
        },
      });
      double top() => tree.boxOf('chip')!.rectIn(view)!.top;
      // The first entrance plays when it appears.
      await tester.pump();
      expect(top(), 0);
      await tester.pumpAndSettle();
      expect(top(), 100);
      // A new key: back to the start, held through the delay, then in.
      scope.set('stamp', 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(top(), 0);
      await tester.pump(const Duration(milliseconds: 300)); // 200 into the 400 ms run
      expect(top(), closeTo(50, 2));
      await tester.pumpAndSettle();
      expect(top(), 100);
      // The same key again does nothing.
      scope.set('stamp', 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(top(), 100);
    });

    testWidgets('a list item that appears with a replay key plays its entrance', (tester) async {
      final scope = VariableScope(const [
        Variable(name: 'items', type: VariableType.list, value: []),
        Variable(name: 'stamp', type: VariableType.integer, value: 0),
      ]);
      final tree = NodeTree(
        DocumentSource(LayoutDocument.fromJson({
          'roots': ['list'],
          'nodes': {
            'list': {
              'type': 'listView',
              'children': ['item'],
              'layout': {'width': 200, 'height': 300},
              'bind': {'data': r'${items}'},
            },
            'item': {
              'type': 'text',
              'props': {'text': r'${item}'},
              'layout': {'width': 200, 'height': 40},
              'motion': {'enter': true, 'enterFrom': {'translateY': -100}, 'duration': 400, 'curve': 'linear'},
              'bind': {'motion.replayKey': r"${= 'fill' + stamp}"},
            },
          },
        })),
        binder: NodeBinder(scope: scope),
      );
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'list', interactive: true)),
      ));
      await tester.pumpAndSettle();
      scope.set('items', ['a', 'b']);
      scope.set('stamp', 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // The new item is still coming in from above.
      double? top;
      void visit(RenderObject o) {
        if (o is RenderParagraph && o.text.toPlainText() == 'a') top = o.localToGlobal(Offset.zero).dy;
        o.visitChildren(visit);
      }
      visit(tester.renderObject(find.byType(NodeView)));
      expect(top, lessThan(-50));
      await tester.pumpAndSettle();
    });

    testWidgets('keyframes play again on a new replay key', (tester) async {
      final (scope, tree, view) = await _show(tester, {
        'chip': {
          'type': 'box',
          'layout': {'width': 40, 'height': 20, 'x': {'start': 100}, 'y': {'start': 0}},
          'motion': {
            'duration': 400,
            'curve': 'linear',
            'keyframes': [
              {'t': 0.25, 'translateX': -8},
              {'t': 0.75, 'translateX': 8},
            ],
          },
          'bind': {'motion.replayKey': r'${shake}'},
        },
      });
      double left() => tree.boxOf('chip')!.rectIn(view)!.left;
      await tester.pumpAndSettle();
      expect(left(), 100); // no key, no shake
      scope.set('shake', 'a');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(left(), lessThan(95));
      await tester.pump(const Duration(milliseconds: 200));
      expect(left(), greaterThan(105));
      await tester.pumpAndSettle();
      expect(left(), 100);
    });
  });

  group('moving along a path', () {
    testWidgets('a path without a view box is in pixels', (tester) async {
      final s = await harness.show(tester, figure(640, 360), root: 'stage');
      await tester.pump();
      final p = _at(s.tree, 'walker');
      expect(p.dx, closeTo(320, 6));
      expect(p.dy, closeTo(180, 6));
    });

    testWidgets('a path with a view box is stretched over the parent', (tester) async {
      final s = await harness.show(tester, figure(640, 360, viewBox: [320, 180]), root: 'stage');
      await tester.pump();
      await tester.pump();
      final p = _at(s.tree, 'walker');
      expect(p.dx, closeTo(640, 6));
      expect(p.dy, closeTo(360, 6));
    });

    testWidgets('a bound, looping motion along a path moves the node', (tester) async {
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

    testWidgets('a node moving along a path at an even pace covers equal track in equal time', (tester) async {
      // 100 px straight then 100 px on the diagonal, with the train's motion:
      // length pacing, oriented and upright, a linear looping run.
      final doc = LayoutDocument.fromJson({
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['t'], 'layout': {'width': 400, 'height': 300}},
          't': {
            'type': 'box',
            'layout': {'width': 20, 'height': 10, 'x': {'start': -10}, 'y': {'start': -5}},
            'decoration': {'fills': [{'color': '#FF000000'}]},
            'motion': {'path': 'M0 100 L100 100 L160 180', 'pathPacing': 'length', 'orientToPath': true, 'orientUpright': true,
                       'uprightMirror': true, 'loop': 'restart', 'duration': 2000, 'curve': 'linear',
                       'keyframes': [{'t': 0, 'pathProgress': 0}, {'t': 1, 'pathProgress': 1}]},
          },
        },
      });
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
      ));
      final view = tester.renderObject(find.byType(NodeView));
      Offset at() => tree.boxOf('t')!.rectIn(view)!.center;
      final samples = <Offset>[];
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        samples.add(at());
      }
      // 400 ms of a 2 s run is 40 px of the 200 px track, straight or diagonal
      // (the chord across the corner is a little shorter).
      for (var i = 0; i < 3; i++) {
        expect((samples[i + 1] - samples[i]).distance, inInclusiveRange(34, 41), reason: '$samples');
      }
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
  });

  group('reduced motion', () {
    Future<RenderAnimations> show(WidgetTester tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['g'],
        'nodes': {
          'g': {
            'type': 'box',
            'layout': {'width': 64, 'height': 64},
            'decoration': {'fills': [{'color': '#FFFF0000'}]},
            'loops': [{'type': 'flicker', 'duration': 600, 'opacityFrom': 0.5, 'opacityTo': 0.9}],
          },
        },
      })));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'g', interactive: true))));
      RenderAnimations? loops;
      void visit(RenderObject o) {
        if (o is RenderAnimations) loops ??= o;
        o.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(NodeView)));
      return loops!;
    }

    final first = 0.5 + (0.9 - 0.5) * api.flickerAt(0);

    testWidgets('with reduced motion on, a flicker rests on its first frame', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final loops = await show(tester);
      for (final ms in [37, 120, 260]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(loops.opacity, closeTo(first, 1e-9));
      }
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing ticks');
    });

    testWidgets('with reduced motion off, it flickers', (tester) async {
      final loops = await show(tester);
      final seen = <double>{};
      for (final ms in [37, 120, 260]) {
        await tester.pump(Duration(milliseconds: ms));
        seen.add(loops.opacity);
      }
      expect(seen.length, greaterThan(1));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
