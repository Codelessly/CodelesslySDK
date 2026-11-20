// codelessly_api docs/design/26-shown-over-and-in-sequence.md, in a running
// screen:
//
// * `transition property=layout` (or `layout.height`, `layout.width`): a box
//   whose size changes with what it holds eases to the new size, its own
//   fill and border following, what doesn't fit yet clipped;
// * an animation's play key that is an expression (`playKey={step}` on an
//   animation line) plays it when the values it reads change;
// * `after=<node>`: an entrance waits until that node has settled;
// * a drag's end says whether it was cancelled (`${result.cancelled}`).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/animations.dart' show RenderAnimations;
import 'package:codelessly_sdk/src/render/controls/field_frame.dart' show RenderFieldFrame;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Variable;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart';

Json _text(String text, {Json extra = const {}}) => {
      'type': 'text',
      'layout': {'width': {'hug': 100}, 'height': 20},
      'props': {'text': text, 'style': {'fontSize': 14}},
      ...extra,
    };

/// A column that hugs a header and a line shown while `open`, under [col].
Map<String, Json> _disclosure(Json transition) => {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 600},
        'children': ['box', 'under'],
      },
      'box': {
        'type': 'column',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        'transitions': [transition],
        'children': ['head', 'more'],
      },
      'head': _text('What is ERP?'),
      'more': {
        'type': 'box',
        'layout': {'width': {'fill': 0}, 'height': 100},
        'bind': {'visible': r'${open}'},
      },
      'under': _text('Under the box'),
    };

double _x(Screen s) => s.tree.boxOf('step')!.contentBox!.localToGlobal(Offset.zero).dx;

double _height(Screen s, String id) => s.tree.boxOf(id)!.size.height;
double _top(Screen s, String id) => s.tree.boxOf(id)!.localToGlobal(Offset.zero).dy;

RenderAnimations _player(Screen s, String id) {
  RenderAnimations? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderAnimations) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(s.tree.boxOf(id)!);
  return found!;
}

void main() {
  testWidgets('a box eases to the height of what it holds: start, middle and end', (tester) async {
    final s = await show(tester, _disclosure({'property': 'layout', 'duration': 300, 'curve': 'linear'}),
        variables: [v('open', false, VariableType.boolean)]);
    expect(_height(s, 'box'), 20);
    expect(_top(s, 'under'), 20);
    s.scope.set('open', true);
    await tester.pump();
    // Its start: the height it had.
    expect(_height(s, 'box'), 20);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 150));
    // Its middle, and what is under it moves with it.
    expect(_height(s, 'box'), closeTo(70, 4));
    expect(_top(s, 'under'), closeTo(70, 4));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_height(s, 'box'), 120);
    expect(_top(s, 'under'), 120);
    // And back.
    s.scope.set('open', false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_height(s, 'box'), closeTo(70, 4));
    // Its own content is laid out at the size drawn, so its fill follows.
    expect(s.tree.boxOf('box')!.contentBox!.size.height, closeTo(70, 4));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_height(s, 'box'), 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout.width eases its width only; a * transition eases no size', (tester) async {
    final s = await show(tester, _disclosure({'property': 'layout.width', 'duration': 300}),
        variables: [v('open', false, VariableType.boolean)]);
    s.scope.set('open', true);
    await tester.pump();
    expect(_height(s, 'box'), 120);
    final star = await show(tester, _disclosure({'property': '*', 'duration': 300}),
        variables: [v('open', false, VariableType.boolean)]);
    star.scope.set('open', true);
    await tester.pump();
    expect(_height(star, 'box'), 120);
  });

  testWidgets('a play key that is an expression plays its animation when what it reads changes', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 300},
        'children': ['step'],
      },
      'step': {
        'type': 'box',
        'layout': {'width': 100, 'height': 100},
        'animations': [
          {
            'id': 'slide',
            'duration': 300,
            'playKey': r'${= "s" + step}',
            'tracks': [
              {'path': 'motion.translateX', 'from': r'${= dir * 100}', 'to': 0},
            ],
          },
        ],
      },
    }, variables: [v('step', 0, VariableType.integer), v('dir', 1, VariableType.integer)]);
    await tester.pump(const Duration(milliseconds: 400));
    final clock = _player(s, 'step').clockOf('slide')!;
    // Where it rests (its column centers it).
    final rest = _x(s);
    expect(clock.isAnimating, isFalse);
    // Forward: from the end.
    s.scope.set('step', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_x(s) - rest, greaterThan(20));
    await tester.pump(const Duration(milliseconds: 300));
    // Back: from the start.
    s.scope.set('dir', -1);
    s.scope.set('step', 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_x(s) - rest, lessThan(-20));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('after= starts an entrance once the node it names has settled', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 300},
        'children': ['first', 'second'],
      },
      'first': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'animations': [
          {'id': 'a', 'preset': 'enter', 'params': {'from': {'opacity': 0}}, 'duration': 400},
        ],
      },
      'second': {
        'type': 'box',
        'layout': {'width': 100, 'height': 50},
        'animations': [
          {'id': 'a', 'preset': 'enter', 'params': {'from': {'opacity': 0}}, 'duration': 200, 'after': 'first'},
        ],
      },
    });
    final second = _player(s, 'second');
    final first = _player(s, 'first');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    // The first plays; the second waits at its start.
    expect(first.clockOf('a')!.isAnimating, isTrue);
    expect(second.clockOf('a')!.isAnimating, isFalse);
    expect(second.waitsForAnother, isTrue);
    expect(second.opacity, 0);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // The first has ended: the second plays.
    expect(first.clockOf('a')!.isAnimating, isFalse);
    expect(second.waitsForAnother, isFalse);
    expect(second.clockOf('a')!.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(second.opacity, 1);
  });

  testWidgets('a drag\'s end says whether it was cancelled', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 300},
        'children': ['pad'],
      },
      'pad': {
        'type': 'box',
        'layout': {'width': 200, 'height': 200},
        'decoration': {'fills': [{'color': '#FFEEEEEE'}]},
        'actions': [
          reaction('drag', []),
          reaction('dragEnd', [
            {'type': 'setVariable', 'variable': 'ended', 'value': r'${result.cancelled}'},
          ]),
        ],
      },
    }, variables: [v('ended', '')]);
    final at = s.center('pad');
    final up = await tester.startGesture(at);
    await up.moveBy(const Offset(0, 40));
    await up.moveBy(const Offset(0, 40));
    await up.up();
    await tester.pump();
    expect('${s['ended']}', 'false');
    final cancelled = await tester.startGesture(at);
    await cancelled.moveBy(const Offset(0, 40));
    await cancelled.moveBy(const Offset(0, 40));
    await cancelled.cancel();
    await tester.pump();
    expect('${s['ended']}', 'true');
  });

  testWidgets('a field\'s frame eases between its looks over transition property=decoration', (tester) async {
    Map<String, Json> field(Json? transition) => {
          'col': {
            'type': 'column',
            'layout': {'width': 300, 'height': 300},
            'children': ['email'],
          },
          'email': {
            'type': 'textField',
            'layout': {'width': 240, 'height': 48},
            'props': {
              'decoration': {
                'enabledBorder': {'type': 'outline', 'borderSide': {'color': '#FF94A3B8', 'width': 1}},
                'focusedBorder': {'type': 'outline', 'borderSide': {'color': '#FF00A3AD', 'width': 2}},
              },
            },
            if (transition != null) 'transitions': [transition],
          },
        };
    RenderFieldFrame frameOf(Screen s) {
      RenderFieldFrame? found;
      void visit(RenderObject o) {
        if (found != null) return;
        if (o is RenderFieldFrame) {
          found = o;
          return;
        }
        o.visitChildren(visit);
      }

      visit(s.tree.boxOf('email')!);
      return found!;
    }

    final s = await show(tester, field({'property': 'decoration', 'duration': 400, 'curve': 'easeOut'}));
    final frame = frameOf(s);
    expect(frame.frameTransition?.duration, 400);
    await tester.tapAt(s.center('email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-way from the enabled look to the focused one.
    expect(frame.frameEasing, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(frame.frameEasing, isFalse);
    // Without it the look changes at once, as before.
    final plain = await show(tester, field(null));
    final still = frameOf(plain);
    expect(still.frameTransition, isNull);
    await tester.tapAt(plain.center('email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(still.frameEasing, isFalse);
  });
}
