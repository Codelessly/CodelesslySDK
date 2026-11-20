// The parts a picker or an input of one's own is made of
// (codelessly_api docs/design/26-snapping-lists-and-custom-controls.md),
// driven: a wheel (a page view that scrolls down, a row a page) settles a
// drag on a row and sets its value; its arrow keys are its own while it has
// the focus (two wheels side by side); a passcode's keypad takes digit keys
// and Backspace; a code field's slots are the field's own box at its height;
// a switch's thumb can be a pill.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit.dart' show firstTextUnder;
import 'package:codelessly_sdk/src/render/controls/text_field.dart' show RenderTextField;
import 'package:codelessly_sdk/src/render/controls/toggles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';

const _wheel = '''
define Wheel @value=0 items=[] rows=5 rowHeight=36
  Stack w=96 h={rows * rowHeight} onTap={value=clamp(value + round((result.y - rows * rowHeight / 2) / rowHeight), 0, length(items) - 1)} onKeyDown(key=ArrowDown, focused=true)={value=min(value + 1, length(items) - 1)} onKeyDown(key=ArrowUp, focused=true)={value=max(value - 1, 0)} ...
    Box w=fill h={rowHeight} y={(rows - 1) / 2 * rowHeight} fill=#FFF1F5F9
    Pages @value w=fill h=fill scrollDirection=vertical peek={1 / rows} padEnds=true edgeFade=0 animationDuration=200 pageMotion={"rotateX":-28,"perspective":0.003,"opacity":0.55,"scale":0.94}
      each item in items
        Text "{item}" w=fill h=fill center size=20
''';

Future<UiSession> _show(WidgetTester tester, String page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(page.trimLeft()));
  await _settle(tester);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

NodeBox _box(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id) found ??= o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  expect(found, isNotNull, reason: id);
  return found!;
}

T _under<T extends RenderObject>(WidgetTester tester, String id) {
  T? found;
  void visit(RenderObject o) {
    if (o is T) found ??= o;
    o.visitChildren(visit);
  }

  visit(_box(tester, id));
  expect(found, isNotNull, reason: '$T in $id');
  return found!;
}

String _out(WidgetTester tester) => firstTextUnder(_box(tester, 'out'))!;

void main() {
  group('a wheel', () {
    const page = '''
$_wheel
state hour=8
state minute=30
Column gap=8
  Text#out "{hour}:{minute}"
  Row
    Wheel#hours @hour items={range(24)}
    Wheel#minutes @minute items={range(60)}
''';

    testWidgets('a drag settles on a row: the row in the middle is the value', (tester) async {
      await _show(tester, page);
      expect(_out(tester), '8:30');
      final hours = _box(tester, 'hours');
      // Two rows up (36 each, past the touch slop of 18), slowly: it comes to rest two rows on.
      await tester.timedDragFrom(hours.localToGlobal(hours.size.center(Offset.zero)), const Offset(0, -90),
          const Duration(milliseconds: 800));
      await _settle(tester);
      expect(_out(tester), '10:30');
      // Part of a row comes back to the nearest one.
      await tester.timedDragFrom(hours.localToGlobal(hours.size.center(Offset.zero)), const Offset(0, 30),
          const Duration(milliseconds: 800));
      await _settle(tester);
      expect(_out(tester), '10:30');
      // A tap on the row under the middle turns to it.
      await tester.tapAt(hours.localToGlobal(hours.size.center(Offset.zero) + const Offset(0, 36)));
      await _settle(tester);
      expect(_out(tester), '11:30');
    });

    testWidgets('its arrow keys are its own while it has the focus, not the wheel beside it', (tester) async {
      await _show(tester, page);
      final keys = Keyboard(tester);
      await keys.down();
      expect(_out(tester), '8:30', reason: 'nothing has the focus: no wheel takes the key');
      for (var i = 0; i < 4 && keys.focusedId != 'hours'; i++) {
        await keys.tab();
      }
      expect(keys.focusedId, 'hours');
      await keys.down();
      await keys.down();
      await _settle(tester);
      expect(_out(tester), '10:30');
      await keys.tab();
      expect(keys.focusedId, 'minutes');
      await keys.up();
      await _settle(tester);
      expect(_out(tester), '10:29');
    });
  });

  testWidgets('a passcode keypad takes the digit keys and Backspace, and its keys by a tap', (tester) async {
    await _show(tester, r'''
state pin=""
Column gap=8
  Text#out "[{pin}]"
  Column onKeyDown={matches(coalesce(result.character, ''), '^[0-9]$') && length(pin) < 4 ? {pin=pin + result.character}}
    Grid cols=3 gap=8 w=240
      each k in ["1","2","3"]
        Column#padKey h=48 center middle onTap={length(pin) < 4 ? {pin=pin + k}}
          Text "{k}"
key Backspace onPress={pin=substring(pin, 0, max(0, length(pin) - 1))}
''');
    final keys = Keyboard(tester);
    await keys.press(LogicalKeyboardKey.digit7, character: '7');
    await keys.press(LogicalKeyboardKey.digit4, character: '4');
    await keys.press(LogicalKeyboardKey.keyA, character: 'a');
    expect(_out(tester), '[74]', reason: 'a letter is no digit');
    await keys.press(LogicalKeyboardKey.backspace);
    expect(_out(tester), '[7]');
    final second = _box(tester, 'padKey');
    await tester.tapAt(second.localToGlobal(second.size.center(Offset.zero)));
    await _settle(tester);
    expect(_out(tester), '[71]');
    for (final k in [LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit5]) {
      await keys.press(k, character: k.keyLabel);
    }
    expect(_out(tester), '[7123]', reason: 'four digits at most');
  });

  testWidgets('a code field\'s slots are the field\'s own box, as tall as the field', (tester) async {
    await _show(tester, '''
state code="12"
Column gap=16
  CodeInput#tall @code length=5 digits w=300 h=60 radius=12 fill=#FFF5F6FD border=#FFD9DCE7
  CodeInput#plain @code length=6 digits w=300
''');
    final tall = _under<RenderTextField>(tester, 'tall');
    expect(tall.otpSlots, hasLength(5));
    expect(tall.otpSlots.first.size.height, 60);
    expect(tall.otpSlots.first.size.width, closeTo(53.6, 0.01));
    expect(tall.otpSlots[1].left - tall.otpSlots[0].right, 8);
    expect(tall, paints..rrect(rrect: RRect.fromRectAndRadius(tall.otpSlots.first, const Radius.circular(12)), color: const Color(0xFFF5F6FD)));
    final plain = _under<RenderTextField>(tester, 'plain');
    expect(plain.otpSlots.first.size, const Size(32, 32), reason: 'a field that hugs keeps its 32 px slots');
  });

  testWidgets('a switch\'s thumb can be a pill: thumbWidth along the track', (tester) async {
    await _show(tester, '''
state on=false
Toggle#sw w=48 h=24 @on fillTrack=true thumbInset=2 thumbWidth=28
''');
    final sw = _under<RenderToggle>(tester, 'sw');
    expect(sw.thumbLength, 28);
    expect(sw.thumb.radius, 10);
    expect(sw.thumb.center.dx, 2 + 14, reason: 'off: at the start, 2 in');
    await tester.tapAt(_box(tester, 'sw').localToGlobal(const Offset(24, 12)));
    await _settle(tester);
    expect(sw.thumb.center.dx, 48 - 2 - 14, reason: 'on: at the end');
  });
}
