// A node with a click reaction is a press target for the keyboard: a Tab
// stop that shows the theme's focus ring when the keyboard brings the focus
// and runs its click on Enter and Space (runtime/actions/wiring.dart's
// RenderReactions.configurePress). Nothing of it shows for a pointer.
import 'package:codelessly_api/core.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart';
import 'package:codelessly_sdk/src/render/controls/overlay.dart' show RenderTooltipBubble;
import 'package:codelessly_sdk/src/render/controls/root.dart' show RenderControlRoot;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';
import '../support/screen.dart' as harness;

Json _text(String text) => {
      'type': 'text',
      'layout': {'width': {'hug': 80}, 'height': {'hug': 20}},
      'props': {'text': text, 'style': {'color': '#FF111111', 'fontSize': 14}},
    };

Json _click(String variable, {String when = ''}) => harness.reaction(
      'click',
      [harness.add(variable)],
      extra: {if (when.isNotEmpty) 'when': when},
    );

// A page of plain nodes: a link (a text), a nav line (a row with a text), a
// card tile with a button inside, and everything that must be skipped.
Map<String, Json> _page() => {
      'col': {
        'type': 'column',
        'layout': {'width': 400, 'height': 600},
        'props': {'spacing': 12},
        'children': ['link', 'nav', 'hover', 'optOut', 'through', 'off', 'row', 'tile', 'field', 'gone'],
      },
      // A link: a text with a click.
      'link': {..._text('Features'), 'actions': [_click('link')]},
      // A nav line: a row with rounded corners and a `focused` state style.
      'nav': {
        'type': 'row',
        'layout': {'width': 200, 'height': 32},
        'decoration': {'radius': 8, 'fills': [{'color': '#FFFFFFFF'}]},
        'children': ['navText'],
        'actions': [_click('nav')],
        'states': {
          'focused': {'nav': {'decoration': {'fills': [{'color': '#FFEEEEEE'}]}}},
        },
      },
      'navText': _text('Billing'),
      // Hover alone is not a press.
      'hover': {
        'type': 'box',
        'layout': {'width': 100, 'height': 20},
        'actions': [harness.reaction('hover', [harness.add('hover')])],
      },
      // The document's opt-out.
      'optOut': {
        'type': 'box',
        'layout': {'width': 100, 'height': 20},
        'focusable': false,
        'actions': [_click('optOut')],
      },
      // Lets the pointer through: not the keyboard's either.
      'through': {
        'type': 'box',
        'layout': {'width': 100, 'height': 20},
        'ignorePointer': true,
        'actions': [_click('through')],
      },
      // Its click's condition does not hold: skipped while it does not.
      'off': {
        'type': 'box',
        'layout': {'width': 100, 'height': 20},
        'actions': [_click('off', when: r'${= allowed}')],
      },
      // A row that toggles: its checkbox ignores the pointer, so the row
      // is the one stop.
      'row': {
        'type': 'row',
        'layout': {'width': 200, 'height': 40},
        'children': ['check', 'rowText'],
        'actions': [_click('row')],
      },
      'check': {
        'type': 'checkbox',
        'layout': {'width': 24, 'height': 24},
        'ignorePointer': true,
        'props': {'value': false},
      },
      'rowText': _text('Remember me'),
      // A card tile with a button of its own: both are stops, the tile
      // first.
      'tile': {
        'type': 'column',
        'layout': {'width': 200, 'height': 90, 'padding': 8},
        'decoration': {'radius': 12, 'fills': [{'color': '#FFF5F5F5'}]},
        'children': ['tileText', 'tileButton'],
        'actions': [_click('tile')],
      },
      'tileText': _text('Harbor room'),
      'tileButton': {
        'type': 'filledButton',
        'layout': {'width': 90, 'height': 36},
        'props': {'label': 'Book'},
        'actions': [_click('book')],
      },
      // A control with a click reaction is one stop: the control.
      'field': {
        'type': 'textField',
        'layout': {'width': 200, 'height': 48},
        'actions': [_click('field')],
      },
      // Not shown: not in the order.
      'gone': {
        'type': 'box',
        'layout': {'width': 100, 'height': 20},
        'visible': false,
        'actions': [_click('gone')],
      },
    };

const _names = ['link', 'nav', 'hover', 'optOut', 'through', 'off', 'row', 'tile', 'book', 'field', 'gone'];

Future<harness.Screen> _show(WidgetTester tester) => harness.show(
      tester,
      _page(),
      variables: [
        for (final n in _names) harness.v(n, 0, VariableType.integer),
        harness.v('allowed', false, VariableType.boolean),
      ],
    );

RenderReactions _reactions(harness.Screen s, String id) {
  RenderReactions? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderReactions) {
      found = o;
      return;
    }
    if (o is NodeBox && o.id != id) return;
    o.visitChildren(visit);
  }

  visit(s.tree.boxOf(id)!);
  return found!;
}

// Whether [box] draws a focus ring: a stroked rounded rectangle.
bool _drawsRing(RenderBox box, {RRect? at, Color? color}) {
  final canvas = TestRecordingCanvas();
  box.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  for (final call in canvas.invocations) {
    if (call.invocation.memberName != #drawRRect) continue;
    final rrect = call.invocation.positionalArguments[0] as RRect;
    final paint = call.invocation.positionalArguments[1] as Paint;
    if (paint.style != PaintingStyle.stroke || paint.strokeWidth != 1.5) continue;
    if (at != null &&
        ((rrect.outerRect.topLeft - at.outerRect.topLeft).distance > .01 ||
            (rrect.outerRect.bottomRight - at.outerRect.bottomRight).distance > .01 ||
            (rrect.tlRadiusX - at.tlRadiusX).abs() > .01)) {
      continue;
    }
    if (color != null && paint.color.toARGB32() != color.toARGB32()) continue;
    return true;
  }
  return false;
}

void main() {
  testWidgets('Tab and Shift+Tab stop at each press target and control, in reading order, and wrap', (tester) async {
    final s = await _show(tester);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    expect(keys.focused, isNull);
    final seen = <String?>[];
    for (var i = 0; i < 7; i++) {
      await keys.tab();
      seen.add(keys.focusedId);
      expect(keys.ringShown, isTrue, reason: 'the keyboard brought the focus to ${keys.focusedId}');
    }
    // hover, optOut, through, off, the checkbox and gone are skipped; the
    // tile comes before the button in it; the field is one stop.
    expect(seen, ['link', 'nav', 'row', 'tile', 'tileButton', 'field', 'link']);
    expect(keys.stopIds(s.tree.boxOf('col')!), ['link', 'nav', 'row', 'tile', 'tileButton', 'field']);
    await keys.shiftTab();
    expect(keys.focusedId, 'field');
    await keys.shiftTab();
    expect(keys.focusedId, 'tileButton');
    await keys.shiftTab();
    expect(keys.focusedId, 'tile');
  });

  testWidgets('Enter and Space run the click of the focused node, and only its', (tester) async {
    final s = await _show(tester);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    await keys.tab();
    await keys.enter();
    expect(s['link'], 1);
    await keys.space();
    expect(s['link'], 2);
    await keys.tab();
    await keys.enter();
    expect(s['nav'], 1);
    await keys.tab();
    await keys.space();
    expect(s['row'], 1);
    await keys.tab();
    await keys.enter();
    expect(s['tile'], 1);
    expect(s['book'], 0, reason: 'the tile, not the button in it');
    await keys.tab();
    await keys.enter();
    expect(s['book'], 1);
    expect(s['tile'], 1);
    expect([s['hover'], s['optOut'], s['through'], s['off'], s['gone']], [0, 0, 0, 0, 0]);
  });

  testWidgets('a node whose click condition starts to hold joins the order', (tester) async {
    final s = await _show(tester);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    expect(keys.stopIds(s.tree.boxOf('col')!), isNot(contains('off')));
    s.scope.set('allowed', true);
    await tester.pumpAndSettle();
    expect(keys.stopIds(s.tree.boxOf('col')!), ['link', 'nav', 'off', 'row', 'tile', 'tileButton', 'field']);
  });

  testWidgets('the ring is the theme\'s, just outside the node with its corners, and the focused state applies', (tester) async {
    final s = await _show(tester);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    final nav = _reactions(s, 'nav');
    expect(_drawsRing(nav), isFalse);
    await keys.tab();
    await keys.tab();
    expect(keys.focusedId, 'nav');
    final color = ControlTokens.of(s.tree.boxOf('nav')!).focusBorder;
    final box = Offset.zero & nav.size;
    expect(_drawsRing(nav, at: RRect.fromRectAndRadius(box, const Radius.circular(8)).inflate(0.75), color: color), isTrue);
    // Its `states.focused` patch: the keyboard's highlight.
    expect(s.tree.statesOf('nav'), contains(api.WidgetState.focused));
    await keys.tab();
    expect(_drawsRing(nav), isFalse);
    expect(s.tree.statesOf('nav'), isNot(contains(api.WidgetState.focused)));
  });

  testWidgets('a pointer tap runs the click and shows no ring and no focus', (tester) async {
    final s = await _show(tester);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    await tester.tapAt(s.center('nav'));
    await tester.pumpAndSettle();
    expect(s['nav'], 1);
    expect(keys.focused, isNull);
    expect(keys.ringShown, isFalse);
    expect(_drawsRing(_reactions(s, 'nav')), isFalse);
    expect(s.tree.statesOf('nav'), isNot(contains(api.WidgetState.focused)));
    await tester.tapAt(s.center('link'));
    await tester.pumpAndSettle();
    expect(s['link'], 1);
    expect(keys.focused, isNull);
  });

  testWidgets('a screen reader is told a focusable button with the node\'s text, and its focus', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await _show(tester);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    final before = keys.semanticsOf(_reactions(s, 'nav'))!;
    expect(before.isButton, isTrue);
    expect(before.label, 'Billing');
    expect(before.isFocusable, isTrue);
    expect(before.isFocused, isFalse);
    expect(before.isEnabled, isTrue);
    expect(before.canTap, isTrue);
    await keys.tab();
    await keys.tab();
    final focused = keys.semantics!;
    expect(focused.label, 'Billing');
    expect(focused.isButton, isTrue);
    expect(focused.isFocused, isTrue);
    // A click that cannot run now: a disabled button, not focusable.
    final off = keys.semanticsOf(_reactions(s, 'off'))!;
    expect(off.isButton, isTrue);
    expect(off.isEnabled, isFalse);
    expect(off.isFocusable, isFalse);
    // The opt-out stays a button a screen reader can press.
    final optOut = keys.semanticsOf(_reactions(s, 'optOut'))!;
    expect(optOut.isButton, isTrue);
    expect(optOut.canTap, isTrue);
    expect(optOut.isFocusable, isFalse);
    // A tile with a button in it keeps the button apart.
    final tile = keys.semanticsOf(_reactions(s, 'tile'))!;
    expect(tile.isButton, isTrue);
    expect(tile.isFocusable, isTrue);
    await keys.tab();
    await keys.tab();
    await keys.tab();
    expect(keys.focusedId, 'tileButton');
    expect(keys.semantics!.label, 'Book');
    handle.dispose();
  });

  testWidgets('a bound selected shows in semantics, and a tooltip names a node with no text', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await harness.show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 200},
        'children': ['a', 'b'],
      },
      'a': {
        'type': 'box',
        'layout': {'width': 40, 'height': 40},
        'tooltip': 'Close',
        'actions': [_click('n')],
      },
      'b': {
        ..._text('Pricing'),
        'bind': {'selected': r'${= tab == "pricing"}'},
        'actions': [_click('n')],
      },
    }, variables: [harness.v('n', 0, VariableType.integer), harness.v('tab', 'pricing')]);
    await tester.pumpAndSettle();
    final keys = Keyboard(tester);
    expect(keys.semanticsOf(_reactions(s, 'a'))!.label, 'Close');
    final b = keys.semanticsOf(_reactions(s, 'b'))!;
    expect(b.label, 'Pricing');
    expect(b.isSelected, isTrue);
    handle.dispose();
  });

  testWidgets('a plain press target shows its tooltip on keyboard focus without an extra stop', (tester) async {
    final s = await harness.show(tester, {
      'col': {'type': 'column', 'layout': {'width': 300, 'height': 200}, 'children': ['help']},
      'help': {'type': 'box', 'layout': {'width': 44, 'height': 44}, 'tooltip': 'Filter help', 'actions': [_click('n')]},
    }, variables: [harness.v('n', 0, VariableType.integer)]);
    final root = tester.renderObject<RenderControlRoot>(find.byType(NodeView));
    final keys = Keyboard(tester);
    expect(keys.stopIds(s.tree.boxOf('help')!), ['help']);
    await keys.tab();
    expect(keys.focusedId, 'help');
    expect(keys.semantics!.label, 'Filter help');
    expect((root.overlayEntries.single as RenderTooltipBubble).message, 'Filter help');
    await keys.escape();
    expect(root.overlayEntries, isEmpty);
  });
}
