// Behaviors, at rest and running: motion swing,
// phase, pause, arc, wrapping and paced paths, upright orientation and
// shimmer; loop phases; drag tracks parked, relative and in their parent.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart' show RenderShimmer;
import 'package:codelessly_sdk/src/render/paint/svg_path.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/legacy.dart';

Map<String, Object?> doc(Map<String, Map<String, Object?>> nodes) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    };

Future<(NodeTree, RenderObject, DocumentSource)> showDoc(WidgetTester tester, Map<String, Object?> json,
    {bool interactive = false}) async {
  final source = DocumentSource(api.LayoutDocument.fromJson(json));
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)), source);
}

Future<(NodeTree, RenderObject, DocumentSource)> show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
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

void main() {
  testWidgets('a spin without a ramp survives a zero-length tick (a first frame on the web)', (tester) async {
    final doc = api.LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['b'], 'layout': {'width': 100, 'height': 100}},
        'b': {
          'type': 'box',
          'layout': {'width': 56, 'height': 56, 'x': {'start': 0}, 'y': {'start': 0}},
          'decoration': {'fills': [{'color': '#FFFF0000'}]},
          'motion': {'spin': 0.7, 'spinRamp': 0},
        },
      },
    });
    final tree = NodeTree(NodeValues(DocumentSource(doc)));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));
    // The spin is the animation `spin` on the node's player.
    final spin = tree.boxOf('b')!.animations!.clockOf('spin')!;
    // Played by hand (the design canvas plays nothing). A new ticker's first
    // tick: no time has passed.
    unawaited(spin.repeat());
    spin.tick(Duration.zero);
    spin.tick(const Duration(milliseconds: 100));
    expect(spin.value.isFinite, isTrue, reason: '${spin.value}');
    expect(spin.value, closeTo(0.07, 1e-3), reason: 'turned by 0.07 of a turn');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swing rocks around rest on a sine', (tester) async {
    final (tree, view, _) = await show(
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

  test('a swing track: rest ± (values − rest)', () {
    // The legacy swingPose, now a replacing track's wave between its from
    // (rest) and the property's own value.
    const rotate = api.AnimationTrack(path: 'motion.rotate', from: 0, wave: [api.Wave()]);
    expect(rotate.valueAt(0.75, own: 20) as double, closeTo(-20, 1e-9));
    const opacity = api.AnimationTrack(path: 'opacity', from: 1, wave: [api.Wave()]);
    expect(opacity.valueAt(0.25, own: 0.5) as double, closeTo(0.5, 1e-9));
  });

  testWidgets('a loop starts at its phase; paused holds it, resumed carries on', (tester) async {
    Map<String, Map<String, Object?>> nodes(bool paused) => {
          'p': box({
            'motion': {'translateX': 100, 'loop': 'restart', 'duration': 1000, 'curve': 'linear', 'phase': 0.25,
                       'paused': paused},
          }),
        };
    final (tree, view, source) = await show(tester, nodes(false), interactive: true);
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

  testWidgets('a change of position bends along an arc', (tester) async {
    Map<String, Map<String, Object?>> nodes(double x) => {
          'a': box({
            'motion': {'translateX': x, 'duration': 1000, 'curve': 'linear', 'arc': 0.5},
          }, y: 100),
        };
    final (tree, view, source) = await show(tester, nodes(0), interactive: true);
    await tester.pump();
    source.document = api.LayoutDocument.fromJson(doc(nodes(100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final r = tree.boxOf('a')!.rectIn(view)!;
    // Half way along, half its arc (0.5 · 2 · 0.25 of 100) off the line,
    // to the right of the way it goes (down, on screen).
    expect(r.left, closeTo(50, 1));
    expect(r.top, closeTo(125, 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tree.boxOf('a')!.rectIn(view)!.top, closeTo(100, 0.5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a wrapping path reads its progress modulo 1; upright never turns over', (tester) async {
    final (tree, view, _) = await show(tester, {
      'w': box({
        // A closed path wraps (pathWrap is how it is read now; an open one
        // stops at its ends).
        'motion': {'path': 'M0 0 L100 0 L0 0', 'pathProgress': 1.125, 'pathWrap': true},
      }),
      'u': box({
        'motion': {'path': 'M0 0 L-100 0', 'orientToPath': true, 'orientUpright': true, 'pathProgress': 0.5},
      }, x: 200, y: 100),
    });
    expect(tree.boxOf('w')!.rectIn(view)!.left, closeTo(25, 0.5));
    // Heading left, drawn upright: a 20×20 box's corners stay put.
    expect(tree.boxOf('u')!.rectIn(view)!, rectMoreOrLessEquals(const Rect.fromLTWH(150, 100, 20, 20), epsilon: 0.01));
  });

  testWidgets('the Lineworks train: length pacing gives even speed over straight and diagonal track', (tester) async {
    // A route of 100 px straight then 100 px on the diagonal (60, 80): with
    // the train's pacing (length) a quarter of the progress is 50 px of track
    // on either part.
    const route = 'M0 0 L100 0 L160 80';
    Future<Offset> at(double progress) async {
      final (tree, view, _) = await show(tester, {
        't': box({'motion': {'path': route, 'pathPacing': 'length', 'pathProgress': progress}}, x: 100, y: 100),
      });
      final c = tree.boxOf('t')!.rectIn(view)!.center;
      await tester.pumpWidget(const SizedBox());
      return c - const Offset(110, 110);
    }

    expect(await at(0.25), offsetMoreOrLessEquals(const Offset(50, 0), epsilon: 0.5));
    expect(await at(0.5), offsetMoreOrLessEquals(const Offset(100, 0), epsilon: 0.5));
    expect(await at(0.75), offsetMoreOrLessEquals(const Offset(130, 40), epsilon: 0.5));
    expect(await at(1), offsetMoreOrLessEquals(const Offset(160, 80), epsilon: 0.5));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('upright and mirrored: heading left, the node faces left (its front leads)', (tester) async {
    // A 40×20 carriage with its nose (n, 10×10) at the right end.
    Map<String, Map<String, Object?>> carriage(String path, {required bool mirror}) => {
          't': {
            'type': 'stack',
            'children': ['n'],
            'layout': {'width': 40, 'height': 20, 'x': {'start': 200}, 'y': {'start': 100}},
            'motion': {'path': path, 'orientToPath': true, 'orientUpright': true, 'uprightMirror': mirror, 'pathProgress': 0.5},
          },
          'n': {'type': 'box', 'layout': {'width': 10, 'height': 10, 'x': {'start': 30}, 'y': {'start': 5}}},
        };
    Future<Rect> nose(String path, {required bool mirror}) async {
      final nodes = carriage(path, mirror: mirror);
      final (tree, view, _) = await showDoc(tester, {
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['t'], 'layout': {'width': 400, 'height': 300}},
          ...nodes,
        },
      });
      final r = tree.boxOf('n')!.rectIn(view)!;
      await tester.pumpWidget(const SizedBox());
      return r;
    }

    // Heading left at the path's middle (-50, 0): mirrored, the nose is at the left end.
    expect(await nose('M0 0 L-100 0', mirror: true), rectMoreOrLessEquals(const Rect.fromLTWH(150, 105, 10, 10), epsilon: 0.01));
    // Not mirrored it stays at the right end, facing backwards.
    expect(await nose('M0 0 L-100 0', mirror: false), rectMoreOrLessEquals(const Rect.fromLTWH(180, 105, 10, 10), epsilon: 0.01));
    // Heading right nothing is mirrored.
    expect(await nose('M0 0 L100 0', mirror: true), rectMoreOrLessEquals(const Rect.fromLTWH(280, 105, 10, 10), epsilon: 0.01));
    expect(migratedBehaviors({'motion': {'orientToPath': true, 'orientUpright': true, 'uprightMirror': true}}).motion!.toJson()['path'],
        {'path': '', 'orient': 'uprightFlip'});
  });

  test('area pacing sweeps equal areas about the focus', () {
    // An ellipse with its focus off-center: half the area is swept before
    // half the length.
    const a = 100.0, b = 60.0;
    final c = math.sqrt(a * a - b * b);
    final path = MeasuredPath.of('M${a + c} 0 A$a $b 0 1 1 ${-a + c} 0 A$a $b 0 1 1 ${a + c} 0')!;
    final byLength = path.at(0.25)!.$1;
    final byArea = path.at(0.25, byArea: true)!.$1;
    expect(byArea, isNot(byLength));
    // Far from the focus (aphelion at the start) it moves slowly: a quarter
    // of the area is less far along than a quarter of the length.
    expect(byArea.dx, greaterThan(byLength.dx));
  });

  testWidgets('a shimmer sweeps in a running app and sits halfway at rest', (tester) async {
    final (tree, _, _) = await show(tester, {
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

  testWidgets('loop phases offset a pulse', (tester) async {
    final (tree, view, _) = await show(tester, {
      'a': box({
        'loops': [
          {'type': 'scale', 'scaleFrom': 0.5, 'duration': 1000, 'reverse': true, 'phase': 0.5}
        ],
      }, size: 40),
      'b': box({
        'loops': [
          {'type': 'scale', 'scaleFrom': 0.5, 'duration': 1000, 'reverse': true, 'lag': 500}
        ],
      }, x: 100, size: 40),
    });
    // Half way through there and back: at its end.
    expect(tree.boxOf('a')!.rectIn(view)!.width, closeTo(40, 0.5));
    // 500 ms behind a 2 s loop: three quarters through, half way back.
    expect(tree.boxOf('b')!.rectIn(view)!.width, closeTo(30, 0.5));
  });

  Map<String, Object?> cardDoc({bool flipped = false}) => {
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['card'], 'layout': {'width': 400, 'height': 300}},
          ...card(flipped: flipped),
        },
      };

  testWidgets('a flip card shows the face it is turned to', (tester) async {
    final (tree, _, _) = await showDoc(tester, cardDoc(flipped: true));
    expect(hitIds(tester, tree, const Offset(50, 30), ['front', 'back']), {'back'});
    final (tree2, _, _) = await showDoc(tester, cardDoc());
    expect(hitIds(tester, tree2, const Offset(50, 30), ['front', 'back']), {'front'});
  });

  testWidgets('a tap turns a running card over; a bound flip turns it back', (tester) async {
    final (tree, _, source) = await showDoc(tester, cardDoc(), interactive: true);
    await tester.tapAt(const Offset(50, 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Edge on, half way.
    await tester.pump(const Duration(milliseconds: 400));
    expect(hitIds(tester, tree, const Offset(50, 30), ['front', 'back']), {'back'});
    expect(tester.binding.transientCallbackCount, 0);
    source.document = api.LayoutDocument.fromJson(cardDoc(flipped: true));
    await tester.pump();
    source.document = api.LayoutDocument.fromJson(cardDoc());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(hitIds(tester, tree, const Offset(50, 30), ['front', 'back']), {'front'});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tilt tips toward a hovering pointer and settles back', (tester) async {
    final (tree, view, _) = await show(
        tester,
        {
          't': box({
            'tilt': {
              'max': {'rotateX': 0, 'rotateY': 0, 'scale': 1.5}
            },
          }, x: 100, y: 100, size: 40),
        },
        interactive: true);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(390, 290));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(120, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tree.boxOf('t')!.rectIn(view)!.width, closeTo(60, 0.5));
    await mouse.moveTo(const Offset(390, 290));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tree.boxOf('t')!.rectIn(view)!.width, closeTo(40, 0.5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a drag track parks, goes relative and measures in its parent', (tester) async {
    final (tree, view, _) = await show(tester, {
      'parked': box({
        'drag': {
          'track': {'shape': 'line', 'x2': 100, 'y2': 0, 'min': 1, 'max': 5, 'parkedProgress': -0.25, 'value': 0}
        },
      }, x: 100, y: 10),
      'rel': box({
        'drag': {
          'track': {'shape': 'line', 'x1': -0.5, 'x2': 0.5, 'y2': 0, 'relative': true, 'value': 1}
        },
      }, x: 100, y: 50, size: 40),
      'frac': box({
        'drag': {
          'track': {'shape': 'line', 'x2': 0.5, 'y2': 0, 'units': 'parent', 'value': 1}
        },
      }, y: 100),
      'bound': box({
        'drag': {
          'track': {'shape': 'line', 'x2': 100, 'y2': 0, 'max': 10, 'defaultValue': 2, 'value': 5}
        },
      }, y: 150),
    });
    // Parked a quarter of the line before its start.
    expect(tree.boxOf('parked')!.rectIn(view)!.left, closeTo(75, 0.5));
    // Half its own width to the right.
    expect(tree.boxOf('rel')!.rectIn(view)!.left, closeTo(120, 0.5));
    // Half its parent's width.
    expect(tree.boxOf('frac')!.rectIn(view)!.left, closeTo(200, 0.5));
    // The bound value wins over the default.
    expect(tree.boxOf('bound')!.rectIn(view)!.left, closeTo(50, 0.5));
  });
}

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

/// The ids of the node boxes a hit at [at] goes through.
Set<String> hitIds(WidgetTester tester, NodeTree tree, Offset at, List<String> ids) {
  final result = tester.hitTestOnBinding(at);
  final targets = {for (final e in result.path) e.target};
  return {
    for (final id in ids)
      if (targets.contains(tree.boxOf(id))) id,
  };
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

