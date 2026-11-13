// Drag tracks in a running app: a node is a value control that the pointer, the wheel and the
// keys move along its track, writing its variable and firing its
// reactions; inside it `${track.*}` can be read.
import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/drag_track.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.decimal]) =>
    Variable(name: name, type: type, value: type.coerce(value));

class Screen {
  Screen(this.tree, this.scope);
  final NodeTree tree;
  final VariableScope scope;

  Object? operator [](String name) => scope.read(name);
  void set(String name, Object? value) => scope.set(name, value);

  RenderBox content(String id) {
    final box = tree.boxOf(id)!;
    return box.contentBox ?? box;
  }

  Offset center(String id) {
    final c = content(id);
    return c.localToGlobal(c.size.center(Offset.zero));
  }

  RenderDragTrack track(String id) {
    RenderDragTrack? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderDragTrack) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    visit(tree.boxOf(id)!);
    return found!;
  }
}

/// A 400×400 faceplate with node `k` (a [size] box at [at], top left)
/// carrying [track]; [extra] more nodes inside `k`.
Future<Screen> plate(
  WidgetTester tester,
  Json track, {
  Size size = const Size(40, 22),
  Offset at = const Offset(180, 300),
  List<Variable> variables = const [],
  List<Json> actions = const [],
  Map<String, Json> inside = const {},
  Json drag = const {},
  Json bind = const {},
  bool interactive = true,
}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['plate'],
    'nodes': {
      'plate': {
        'type': 'stack',
        'children': ['k'],
        'layout': {'width': 400, 'height': 400},
      },
      'k': {
        'type': inside.isEmpty ? 'box' : 'stack',
        if (inside.isNotEmpty) 'children': inside.keys.toList(),
        'layout': {
          'width': size.width,
          'height': size.height,
          'x': {'start': at.dx},
          'y': {'start': at.dy},
        },
        'decoration': {
          'fills': [
            {'color': '#FF2196F3'},
          ],
        },
        'drag': {...drag, 'track': track},
        'actions': actions,
        'bind': bind,
      },
      ...inside,
    },
  });
  final scope = VariableScope(variables);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, tree: tree, nodeValues: values);
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 'plate', interactive: interactive),
      ),
    ),
  );
  return Screen(tree, scope);
}

Json reaction(String trigger, List<Json> actions) => {
  'trigger': {'type': trigger},
  'actions': actions,
};

Json setTo(String name, String value) => {'type': 'setVariable', 'variable': name, 'value': value};
Json add(String name) => {'type': 'setVariable', 'variable': name, 'op': 'add', 'value': '1'};

String textOf(NodeTree tree, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!.text.toPlainText();
}

// A fader: the cap rests at the bottom of a 250px throw, -48 to +6 dB.
const Json fader = {
  'variable': 'accent',
  'min': -48,
  'max': 6,
  'step': 0.5,
  'defaultValue': 0,
  'y2': -250,
  'jumpOnTap': true,
};

void main() {
  testWidgets('a line track draws the node at its variable\'s value', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -21)]);
    // Laid out centered at (200, 311); halfway up the 250px throw.
    expect(s.center('k'), const Offset(200, 186));
    s.set('accent', 6);
    await tester.pump();
    expect(s.center('k').dy, closeTo(61, 1e-6));
  });

  testWidgets('dragging along a line writes snapped values and fires its reactions', (tester) async {
    final s = await plate(
      tester,
      fader,
      variables: [v('accent', -48), v('changes', 0, VariableType.integer), v('ended', 0), v('settled', 0)],
      actions: [
        reaction('changed', [add('changes')]),
        reaction('dragEnd', [setTo('ended', r'${result.value}')]),
        reaction('changeEnd', [setTo('settled', r'${result.value}')]),
      ],
      inside: {
        'label': {
          'type': 'text',
          'layout': {'width': 40, 'height': 22},
          'props': {'text': r'${track.value} ${track.dragging}'},
        },
      },
    );
    expect(textOf(s.tree, 'label'), '-48.0 false');
    final gesture = await tester.startGesture(const Offset(200, 311));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -105));
    await tester.pump();
    // Followed the pointer 125px up: halfway (the node keeps the point it
    // was grabbed by).
    expect(s['accent'], -21);
    expect(textOf(s.tree, 'label'), '-21.0 true');
    expect(s['changes'], greaterThan(0));
    await gesture.up();
    await tester.pump();
    expect(s['ended'], -21);
    expect(s['settled'], -21);
    expect(textOf(s.tree, 'label'), '-21.0 false');
    expect(s.center('k').dy, closeTo(186, 0.01));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('sideways movement off a line still follows its nearest point', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -48)]);
    final gesture = await tester.startGesture(const Offset(200, 311));
    await gesture.moveBy(const Offset(60, -30));
    await gesture.moveBy(const Offset(40, -220));
    await tester.pump();
    expect(s['accent'], 6); // past the top: clamped to max
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping the track off the node jumps the node there', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -48)]);
    // 50px below the top of the throw, outside the node's own box.
    await tester.tapAt(const Offset(200, 111));
    await tester.pump();
    expect(s['accent'] as double, closeTo(6 - 54 * 50 / 250, 0.5));
    expect(s.center('k').dy, closeTo(111, 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('without jumpOnTap the track off the node is not hit', (tester) async {
    final s = await plate(tester, {...fader, 'jumpOnTap': false}, variables: [v('accent', -48)]);
    await tester.tapAt(const Offset(200, 111));
    await tester.pump();
    expect(s['accent'], -48);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the wheel steps (a double tap reset is gone in schema 3)', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', 0)]);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(s.center('k')));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(s['accent'], 0.5);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('vertical input turns a knob by dragging up; an integer variable stays whole', (tester) async {
    final s = await plate(
      tester,
      {
        'shape': 'arc',
        'variable': 'gain',
        'min': 0,
        'max': 100,
        'input': 'vertical',
        'pixelsPerRange': 160,
      },
      size: const Size(40, 40),
      at: const Offset(180, 180),
      variables: [v('gain', 50, VariableType.integer)],
    );
    final gesture = await tester.startGesture(s.center('k'));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -5));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(s['gain'], isA<int>());
    expect(s['gain'] as int, greaterThan(60));
  });

  testWidgets('an arc follows the pointer\'s angle and rotates the node', (tester) async {
    final s = await plate(
      tester,
      {'shape': 'arc', 'variable': 'bpm', 'min': 30, 'max': 250, 'step': 1, 'defaultValue': 120},
      size: const Size(120, 120),
      at: const Offset(140, 140),
      variables: [v('bpm', 140)],
    );
    // Halfway: pointing straight up.
    expect(s.content('k').getTransformTo(null).getTranslation().x, closeTo(140, 0.01));
    // Grab the top of the knob and turn it a quarter turn clockwise.
    final gesture = await tester.startGesture(const Offset(200, 145));
    await gesture.moveTo(const Offset(240, 160));
    await tester.pump();
    await gesture.moveTo(const Offset(255, 200));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    // 90° of a 270° sweep over 220 BPM: about 73 more.
    expect(s['bpm'] as double, closeTo(140 + 220 / 3, 6));
  });

  testWidgets('the keys step a focused track', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -21)]);
    await tester.tapAt(s.center('k'));
    await tester.pump(const Duration(seconds: 1));
    expect(s.track('k'), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(s['accent'], -20.5);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(s['accent'], -25.5);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(s['accent'], 6);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(s['accent'], -48);
  });

  testWidgets('track.focused reads the focus', (tester) async {
    final s = await plate(
      tester,
      fader,
      variables: [v('accent', -21)],
      inside: {
        'label': {
          'type': 'text',
          'layout': {'width': 40, 'height': 22},
          'props': {'text': r'${track.focused}'},
        },
      },
    );
    expect(textOf(s.tree, 'label'), 'false');
    await tester.tapAt(s.center('k'));
    await tester.pump(const Duration(seconds: 1));
    expect(textOf(s.tree, 'label'), 'true');
  });

  testWidgets('write: false leaves the variable to its reactions', (tester) async {
    final s = await plate(
      tester,
      {...fader, 'write': false},
      variables: [v('accent', -48), v('seen', 0)],
      actions: [
        reaction('changed', [setTo('seen', r'${result.value}')]),
      ],
    );
    final gesture = await tester.startGesture(const Offset(200, 311));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -105));
    await tester.pump();
    expect(s['accent'], -48);
    expect(s['seen'], -21);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    // Back at its variable's value.
    expect(s.center('k').dy, closeTo(311, 0.01));
  });

  testWidgets('a bound value draws it; dragging reports it', (tester) async {
    final s = await plate(
      tester,
      {...fader, 'variable': ''},
      variables: [v('level', -21), v('seen', 0)],
      bind: {'drag.track.value': r'${level}'},
      actions: [
        reaction('changed', [setTo('level', r'${result.value}')]),
      ],
    );
    expect(s.center('k').dy, closeTo(186, 1e-6));
    final gesture = await tester.startGesture(s.center('k'));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 105));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(s['level'], -48);
    expect(s.center('k').dy, closeTo(311, 0.01));
  });

  testWidgets('a disabled track does not move', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -48)], drag: {'enabled': false});
    final gesture = await tester.startGesture(const Offset(200, 311));
    await gesture.moveBy(const Offset(0, -125));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(s['accent'], -48);
  });

  testWidgets('the design canvas draws the variable\'s value and takes no input', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -21)], interactive: false);
    expect(s.center('k'), const Offset(200, 186));
    await tester.tapAt(const Offset(200, 111));
    final gesture = await tester.startGesture(s.center('k'));
    await gesture.moveBy(const Offset(0, -60));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(s['accent'], -21);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a knob turns by dx - dy from anywhere in its parent (hitArea parent)', (tester) async {
    final s = await plate(
      tester,
      {
        'shape': 'arc',
        'variable': 'g',
        'min': 0,
        'max': 100,
        'input': 'both',
        'pixelsPerRange': 100,
        'hitArea': 'parent',
      },
      size: const Size(40, 40),
      at: const Offset(20, 20),
      variables: [v('g', 0)],
    );
    final gesture = await tester.startGesture(const Offset(300, 300));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(5, -5));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(s['g'] as double, greaterThan(40));
  });

  // Removed in schema 3: the fine mode (fineStep, finePixelsPerRange, fineHold, fineVariable).

  testWidgets('momentum: a flick coasts on, then settles once (changeEnd)', (tester) async {
    final s = await plate(
      tester,
      {
        'variable': 'n',
        'min': 0,
        'max': 1000,
        'step': 1,
        'input': 'horizontal',
        'pixelsPerRange': 2000,
        'momentum': true,
        'x2': 0,
        'y2': 0,
      },
      variables: [v('n', 0), v('settled', 0, VariableType.integer)],
      actions: [
        reaction('changeEnd', [add('settled')]),
      ],
    );
    await tester.flingFrom(s.center('k'), const Offset(200, 0), 3000);
    await tester.pump();
    final released = s['n'] as double;
    expect(s['settled'], 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(s['n'] as double, greaterThan(released));
    await tester.pumpAndSettle();
    expect(s['settled'], 1);
  });

  testWidgets('a control drag action steps a track, as a drag would', (tester) async {
    final doc = {
      'roots': ['plate'],
      'nodes': {
        'plate': {
          'type': 'stack',
          'children': ['k', 'nudge'],
          'layout': {'width': 400, 'height': 400},
        },
        'k': {
          'type': 'box',
          'layout': {'width': 40, 'height': 22, 'x': {'start': 180}, 'y': {'start': 300}},
          'drag': {'track': fader},
        },
        'nudge': {
          'type': 'box',
          'layout': {'width': 40, 'height': 40},
          'actions': [
            reaction('click', [
              {'type': 'controlDrag', 'node': 'k', 'command': 'step', 'steps': r'${by}'},
            ]),
          ],
        },
      },
    };
    final scope = VariableScope([v('accent', -21), v('by', 2, VariableType.integer)]);
    final values = NodeValues(DocumentSource(LayoutDocument.fromJson(doc)));
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
          child: NodeView(tree: tree, rootId: 'plate', interactive: true),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(scope.read('accent'), -20);
  });

  testWidgets('overscroll stretches past an end and springs back', (tester) async {
    final s = await plate(
      tester,
      {...fader, 'overscroll': 0.5, 'settleCurve': 'spring'},
      variables: [v('accent', 6)],
    );
    expect(s.center('k').dy, closeTo(61, 1e-6));
    final gesture = await tester.startGesture(s.center('k'));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    // 60px past the top, at half the pointer's travel.
    expect(s.center('k').dy, closeTo(31, 1));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(s.center('k').dy, lessThan(61));
    await tester.pumpAndSettle();
    expect(s.center('k').dy, closeTo(61, 0.5));
    expect(s['accent'], 6);
  });

  testWidgets('a value set from elsewhere glides there with settle', (tester) async {
    final s = await plate(tester, {...fader, 'settle': 200}, variables: [v('accent', -48)]);
    s.set('accent', 6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = s.center('k').dy;
    expect(mid, inExclusiveRange(61, 311));
    await tester.pump(const Duration(milliseconds: 200));
    expect(s.center('k').dy, closeTo(61, 0.01));
  });

  // Removed in schema 3: parkedProgress.

  testWidgets('a relative scrub area maps a tap to that fraction across', (tester) async {
    final s = await plate(
      tester,
      {'variable': 'p', 'min': 0, 'max': 1, 'relative': true, 'x1': -0.5, 'y1': 0, 'x2': 0.5, 'y2': 0, 'jumpOnTap': true},
      size: const Size(400, 40),
      at: const Offset(0, 0),
      variables: [v('p', 0.5)],
    );
    await tester.tapAt(const Offset(300, 20));
    await tester.pump(const Duration(seconds: 1));
    expect(s['p'] as double, closeTo(0.75, 0.01));
  });

  testWidgets('a parent-unit playhead scrubs across its parent', (tester) async {
    final s = await plate(
      tester,
      {'variable': 't', 'min': 0, 'max': 10, 'units': 'parent', 'x1': 0, 'y1': 0, 'x2': 1, 'y2': 0, 'jumpOnTap': true, 'hitArea': 'parent'},
      size: const Size(2, 400),
      at: const Offset(-1, 0),
      variables: [v('t', 2.5)],
    );
    expect(s.center('k').dx, closeTo(100, 1e-6));
    await tester.tapAt(const Offset(300, 200));
    await tester.pump(const Duration(seconds: 1));
    expect(s['t'] as double, closeTo(7.5, 0.05));
    expect(s.center('k').dx, closeTo(300, 0.5));
  });

  testWidgets('Tab reaches it; it is a slider with its value', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await plate(tester, fader, variables: [v('accent', -21)]);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(s['accent'], -20.5);
    SemanticsData? data;
    bool visit(SemanticsNode n) {
      if (n.getSemanticsData().value.isNotEmpty) data = n.getSemanticsData();
      n.visitChildren(visit);
      return true;
    }

    visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    data = data!;
    expect(data!.value, '-20.5');
    expect(data!.increasedValue, '-20');
    expect(data!.decreasedValue, '-21');
    handle.dispose();
  });

  testWidgets('scrubbing a variable an animation plays pauses it', (tester) async {
    final s = await plate(tester, fader, variables: [v('accent', -48)]);
    final done = VariableAnimator.play(s.scope, 'accent', from: -48, to: 6, duration: const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 100));
    final gesture = await tester.startGesture(s.center('k'));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(VariableAnimator.isPlaying(s.scope, 'accent'), isFalse);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    VariableAnimator.stop(s.scope, 'accent');
    await done;
  });

  group('a combination dial', () {
    // 40 numbers a turn, endless, coasting, drawn between numbers while it
    // moves: a 400×400 face round (200, 200).
    const Json dial = {
      'shape': 'arc',
      'variable': 'dial',
      'min': 0,
      'max': 40,
      'step': 1,
      'startAngle': 0,
      'endAngle': 360,
      'endless': true,
      'momentum': true,
      'smooth': true,
    };

    Future<Screen> face(WidgetTester t, Json track, {double start = 0}) => plate(
      t,
      track,
      size: const Size(400, 400),
      at: Offset.zero,
      variables: [
        v('dial', start),
        v('crossed', const <Object?>[], VariableType.list),
        v('settled', const <Object?>[], VariableType.list),
      ],
      actions: [
        reaction('changed', [
          {'type': 'setVariable', 'variable': 'crossed', 'op': 'add', 'value': r'${result.crossed}'},
        ]),
        reaction('changeEnd', [
          {'type': 'setVariable', 'variable': 'settled', 'op': 'add', 'value': r'${result.value}'},
        ]),
      ],
    );

    Future<void> arc(WidgetTester t, double fromDeg, double deg, {int steps = 20, int ms = 16}) async {
      Offset pt(double a) => const Offset(200, 200) + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * 150;
      final g = await t.startGesture(pt(fromDeg));
      for (var i = 1; i <= steps; i++) {
        await g.moveTo(pt(fromDeg + deg * i / steps), timeStamp: Duration(milliseconds: ms * i));
        await t.pump(Duration(milliseconds: ms));
      }
      await g.up(timeStamp: Duration(milliseconds: ms * steps + 1));
    }

    double angle(Screen s) {
      final m = s.content('k').getTransformTo(null).storage;
      return math.atan2(m[1], m[0]) * 180 / math.pi;
    }

    testWidgets('endless: turns go past a full turn and keep counting', (t) async {
      final s = await face(t, {...dial, 'momentum': false});
      for (var k = 0; k < 5; k++) {
        await arc(t, k * 180.0, 180, steps: 30, ms: 40);
        await t.pumpAndSettle();
      }
      expect(s['dial'], 100);
    });

    // Removed in schema 3: smooth (drawn between numbers).

    testWidgets('momentum: a flick coasts on, crossing every number, then settles', (t) async {
      final s = await face(t, dial);
      await arc(t, 0, 90, steps: 6);
      final atRelease = s['dial'] as double;
      await t.pumpAndSettle();
      final value = s['dial'] as double;
      expect(value, greaterThan(atRelease + 3));
      expect(s['crossed'], [for (var i = 1; i <= value; i++) i]);
      expect(s['settled'], [value]);
    });

    testWidgets('a slow turn that stops before letting go does not coast', (t) async {
      final s = await face(t, dial);
      await arc(t, 0, 144, steps: 40, ms: 40);
      await t.pumpAndSettle();
      expect(s['dial'], 16);
      expect(s['settled'], [16]);
    });

    // Removed in schema 3: gain round an arc.

    testWidgets('step: an action turns it a number, as a drag would', (t) async {
      final s = await face(t, dial);
      expect(await DragTracks.step(s.tree, 'k', -1), isTrue);
      await t.pumpAndSettle();
      expect(s['dial'], -1);
      expect(s['settled'], [-1]);
      await DragTracks.step(s.tree, 'k', 3);
      await t.pumpAndSettle();
      expect(s['dial'], 2);
      expect(s['crossed'], [-1, 0, 1, 2]);
      expect(await DragTracks.step(s.tree, 'none', 1), isFalse);
      expect(await DragTracks.step(s.tree, 'tablet-copy, k', 1), isTrue);
      await t.pumpAndSettle();
      expect(s['dial'], 3);
    });

    // Removed in schema 3: a smooth track's glide to a value set from elsewhere.
  });
}
