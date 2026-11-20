// The parts a picker or an input of one's own is made of
// (codelessly_api docs/design/26-snapping-lists-and-custom-controls.md),
// driven: a wheel (a page view that scrolls down, a row a page) settles a
// drag on a row and sets its value; its arrow keys are its own while it has
// the focus (two wheels side by side); a passcode's keypad takes digit keys
// and Backspace; a code field's slots are the field's own box at its height;
// a switch's thumb can be a pill.
import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:codelessly_sdk/src/render/controls/kit.dart' show firstTextUnder;
import 'package:codelessly_sdk/src/render/controls/text_field.dart' show RenderTextField;
import 'package:codelessly_sdk/src/render/controls/toggles.dart';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';

const _wheel = '''
define Wheel @value=0 items=[] rows=5 rowHeight=36 friction=0.865 depth=2
  Stack w=96 h={rows * rowHeight} onTap={value=clamp(value + round((result.y - rows * rowHeight / 2) / rowHeight), 0, length(items) - 1)} onKeyDown(key=ArrowDown, focused=true)={value=min(value + 1, length(items) - 1)} onKeyDown(key=ArrowUp, focused=true)={value=max(value - 1, 0)} ...
    Box w=fill h={rowHeight} y={(rows - 1) / 2 * rowHeight} fill=#FFF1F5F9
    Pages @value w=fill h=fill scrollDirection=vertical peek={1 / rows} padEnds=true edgeFade=0 allowImplicitScrolling=true animationDuration=200 perspective={depth} snapPhysics.friction={friction}
      each item in items
        Text#wheelRow "{item}" w=fill h=fill center size=20 motion.perspective=0 motion.translateY={rows * rowHeight / 2 * sin(pageOffset * 2 / rows) - pageOffset * rowHeight} motion.translateZ={rows * rowHeight / 2 * (cos(pageOffset * 2 / rows) - 1)} motion.rotateX={-pageOffset * 2 / rows * 180 / pi()} opacity={abs(pageOffset * 2 / rows) < pi() / 2 ? 1 - 0.7 * abs(pageOffset * 2 / rows) / (pi() / 2) : 0}
''';

/// The (first) wheel's scroll position.
ScrollPosition _position(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position;

/// A drag of [by] that stops before it lets go: no fling.
Future<void> _dragAndHold(WidgetTester tester, Offset from, Offset by) async {
  final g = await tester.startGesture(from);
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(from + by * (i / 10));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pump(const Duration(milliseconds: 400));
  await g.up();
}

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
      // Two rows up (36 each, past the touch slop of 18), held before it is
      // let go (no fling): it rests on the nearest row, two rows on.
      await _dragAndHold(tester, hours.localToGlobal(hours.size.center(Offset.zero)), const Offset(0, -90));
      await _settle(tester);
      expect(_out(tester), '10:30');
      // Part of a row comes back to the nearest one.
      await _dragAndHold(tester, hours.localToGlobal(hours.size.center(Offset.zero)), const Offset(0, 30));
      await _settle(tester);
      expect(_out(tester), '10:30');
      final p = _position(tester);
      expect(p.pixels / (p.viewportDimension / 5) % 1, closeTo(0, 0.001), reason: 'on a row');
      // A tap on the row under the middle turns to it.
      await tester.tapAt(hours.localToGlobal(hours.size.center(Offset.zero) + const Offset(0, 36)));
      await _settle(tester);
      expect(_out(tester), '11:30');
    });

    const sixty = '''
$_wheel
state n=10
Column gap=8
  Text#out "{n}"
  Wheel#reel @n items={range(60)} rows=7
''';

    testWidgets('a fling spins it over many rows by its speed and rests on the row its coast is nearest', (tester) async {
      await _show(tester, sixty);
      expect(_out(tester), '10');
      final reel = _box(tester, 'reel');
      final physics = _position(tester).physics;
      expect(physics, isA<ScrollPhysics>());
      final start = _position(tester).pixels;
      final extent = start / 10;
      expect(extent, closeTo(36, 0.02), reason: "a row's height");
      // What friction 0.865 projects for a release at 1500 px/s: 1500 / -ln(0.135) = 749 px, 20.8 rows; the row nearest.
      final metrics = _position(tester).copyWith(pixels: start);
      final target = (start + 1500 / -math.log(1 - 0.865)) / extent;
      final simulation = physics.createBallisticSimulation(metrics, 1500)!;
      expect(simulation.x(30), closeTo(target.round() * extent, 0.001));
      await tester.flingFrom(reel.localToGlobal(reel.size.center(Offset.zero)), const Offset(0, -120), 1500);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final rested = _position(tester).pixels;
      expect((rested / extent - (rested / extent).round()).abs(), lessThan(0.001), reason: 'on a row');
      expect(rested / extent - 10, greaterThan(12), reason: 'many rows on: $rested');
      expect(_out(tester), '${(rested / extent).round()}');
    });

    testWidgets('with reduced motion a fling still rests on a row', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _show(tester, sixty);
      final reel = _box(tester, 'reel');
      final start0 = _position(tester).pixels;
      await tester.flingFrom(reel.localToGlobal(reel.size.center(Offset.zero)), const Offset(0, -120), 1500);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final rested = _position(tester).pixels;
      final extent = start0 / 10;
      expect((rested / extent - (rested / extent).round()).abs(), lessThan(0.001));
      expect(_out(tester), '${(rested / extent).round()}');
      expect(rested / extent, greaterThan(10));
    });

    testWidgets('seen through the camera, its rows recede on the drum: R sin(angle) over 1 + p R (1 - cos(angle))', (tester) async {
      await _show(tester, sixty);
      final reel = _box(tester, 'reel');
      final middle = reel.localToGlobal(reel.size.center(Offset.zero)).dy;
      const h = 36.0, radius = 7 * 36 / 2, p = 0.0012 * 2;
      final painted = <String, Rect>{};
      final middles = <String, Offset>{};
      void visit(RenderObject o) {
        if (o is RenderParagraph) {
          painted[o.text.toPlainText()] = MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);
          middles[o.text.toPlainText()] = MatrixUtils.transformPoint(o.getTransformTo(null), o.size.center(Offset.zero));
        }
        o.visitChildren(visit);
      }

      visit(reel);
      final rest = painted['10']!;
      final c = rest.center.dy - middle;
      // The row at rest is not moved at all: exactly the band's row.
      final restBox = _under<RenderParagraph>(tester, 'reel');
      expect(rest.size, isNot(Size.zero));
      expect(restBox.attached, isTrue);
      for (final d in [1, 2, 3]) {
        final angle = d * h / radius;
        for (final side in [1, -1]) {
          final row = painted['${10 + side * d}']!;
          // The text's middle (c from its row's): on the drum at y, z (away).
          final y = side * radius * math.sin(angle) + c * math.cos(angle);
          final away = radius * (1 - math.cos(angle)) - side * c * math.sin(angle);
          expect(middles['${10 + side * d}']!.dy - middle, closeTo(y / (1 + p * away), 0.5), reason: 'row ${side * d}: its place');
          expect(row.height, lessThan(rest.height), reason: 'row ${side * d}: turned and farther');
          expect(row.width, lessThan(rest.width), reason: 'row ${side * d}: narrower as it recedes');
        }
      }
    });

    testWidgets('a node pushed away (translateZ) shrinks toward its middle by 1 / (1 + p z)', (tester) async {
      await _show(tester, '''
Stack w=300 h=300
  Box#near w=100 h=100 x=100 y=100 fill=#FF000000
  Box#far w=100 h=100 x=100 y=100 fill=#FF000000 motion.translateZ=-100 motion.perspective=1
''');
      Rect drawn(String id) {
        final box = _box(tester, id);
        RenderObject? inner;
        void visit(RenderObject o) {
          if (o is RenderBox && o.hasSize && o.size == const Size(100, 100)) inner = o;
          o.visitChildren(visit);
        }

        box.visitChildren(visit);
        final o = (inner ?? box) as RenderBox;
        return MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);
      }

      final near = drawn('near'), far = drawn('far');
      expect(far.width, closeTo(near.width / (1 + 0.0012 * 100), 0.5));
      expect(far.center.dx, closeTo(near.center.dx, 0.5), reason: 'toward its own middle');
      expect(far.center.dy, closeTo(near.center.dy, 0.5));
    });

    testWidgets('its rows sit on a drum: placed at R sin(angle), as tall as h cos(angle) (depth=0: flat)', (tester) async {
      await _show(tester, sixty.replaceFirst('rows=7', 'rows=7 depth=0'));
      final reel = _box(tester, 'reel');
      final middle = reel.localToGlobal(reel.size.center(Offset.zero)).dy;
      const h = 36.0, radius = 7 * 36 / 2;
      // Each copy's text as painted: the corners of its paragraph through every transform above it.
      final painted = <String, Rect>{};
      void visit(RenderObject o) {
        if (o is RenderParagraph) {
          final t = o.getTransformTo(null);
          painted[o.text.toPlainText()] = MatrixUtils.transformRect(t, Offset.zero & o.size);
        }
        o.visitChildren(visit);
      }

      visit(reel);
      final rest = painted['10']!;
      // The text sits c from its row's middle; on the drum that point turns with the row.
      final c = rest.center.dy - middle;
      for (final d in [0, 1, 2, 3]) {
        final angle = d * h / radius;
        final row = painted['${10 + d}']!;
        expect(row.center.dy - rest.center.dy, closeTo(radius * math.sin(angle) + c * (math.cos(angle) - 1), 0.75), reason: 'row $d: its place');
        expect(row.height / rest.height, closeTo(math.cos(angle), 0.01), reason: 'row $d: foreshortened');
        final above = painted['${10 - d}']!;
        expect(above.center.dy - rest.center.dy, closeTo(-radius * math.sin(angle) + c * (math.cos(angle) - 1), 0.75), reason: 'row -$d');
      }
      expect(c.abs(), lessThan(10));
    });

    testWidgets('a page view\'s camera (perspective) sees every page\'s turn from its middle', (tester) async {
      Future<Rect> turned(int perspective) async {
        await _show(tester, '''
state p=0
Pages#flow @p w=300 h=200 scrollDirection=horizontal peek=0.4 perspective=$perspective
  each i in range(5)
    Text "page {i}" w=fill h=fill center size=20 motion.perspective=0 motion.rotateY={-pageOffset * 40}
''');
        final out = <String, Rect>{};
        void visit(RenderObject o) {
          if (o is RenderParagraph) out[o.text.toPlainText()] = MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);
          o.visitChildren(visit);
        }

        visit(_box(tester, 'flow'));
        return out['page 1']!;
      }

      final flat = await turned(0);
      final seen = await turned(2);
      // Turned 40 degrees about y: flat, it is only narrower; seen from the
      // view's middle, its far edge is shorter than its near one, so its box
      // (the near edge's height) is taller than the flat one.
      expect(seen.height, greaterThan(flat.height + 0.5));
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

  group('a code field\'s focused look is the slot typed into next', () {
    const red = Color(0xFFE11D48);

    // The color of the pixel on each slot's left edge, halfway down: inside
    // the 2 px focused border, half under a 1 px resting one.
    Future<List<Color>> edges(WidgetTester tester, RenderTextField f) async {
      final image = await captureImage(find.byType(Scaffold).evaluate().single);
      final bytes = (await tester.runAsync(() => image.toByteData()))!;
      return [
        for (final s in f.otpSlots)
          () {
            final p = f.localToGlobal(Offset(s.left, s.center.dy));
            final i = (p.dy.floor() * image.width + p.dx.floor()) * 4;
            return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
          }(),
      ];
    }

    bool isRed(Color c) => (c.r - red.r).abs() < 0.04 && (c.g - red.g).abs() < 0.04 && (c.b - red.b).abs() < 0.04;

    for (final (name, focusWord) in [('written', ' focused.border=#FFE11D48'), ('not written', '')]) {
      testWidgets('focused.border $name: only the active slot is drawn focused, the others at rest', (tester) async {
        await _show(tester, '''
state code=""
Column
  CodeInput#six @code length=6 digits w=328 h=48 radius=8 fill=#FFFFFFFF border=#FFD1D5DB$focusWord
''');
        final f = _under<RenderTextField>(tester, 'six');
        expect([for (final s in f.otpSlots) s.left], [0, 56, 112, 168, 224, 280], reason: 'whole pixels: 48 wide, 8 apart');
        bool focusedLook(Color c) => focusWord.isEmpty ? (c.b - c.r) > 0.3 : isRed(c);
        await tester.tapAt(f.localToGlobal(f.otpSlots[3].center), kind: PointerDeviceKind.mouse);
        await _settle(tester);
        expect(f.focusNode.hasFocus, isTrue);
        expect(f.focusNode.showsHighlight, isFalse, reason: 'a pointer brought the focus: the active slot shows anyway');
        var colors = await edges(tester, f);
        expect([for (final c in colors) focusedLook(c)], [true, false, false, false, false, false], reason: '$colors');
        tester.testTextInput.enterText('12');
        await _settle(tester);
        colors = await edges(tester, f);
        expect([for (final c in colors) focusedLook(c)], [false, false, true, false, false, false], reason: '$colors');
      });
    }
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

  group('a snapping list and its fling', () {
    /// The painted texts under [id] by their text, with their painted rects.
    Map<String, Rect> painted(WidgetTester tester, String id) {
      final out = <String, Rect>{};
      void visit(RenderObject o) {
        if (o is RenderParagraph) out[o.text.toPlainText()] = MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);
        o.visitChildren(visit);
      }

      visit(_box(tester, id));
      return out;
    }

    testWidgets('an item of a snapping list reads its distance from the snap point, as a page does: whole at rest, a fraction mid-scroll',
        (tester) async {
      await _show(tester, '''
Column
  ListView#lst h=200 itemSnapping=true
    each i in range(30)
      Text "row {i} at {pageOffset}" h=40 motion.scale={1 - 0.1 * min(abs(coalesce(pageOffset, 0)), 3)}
''');
      await _settle(tester);
      var texts = painted(tester, 'lst');
      expect(texts.keys, containsAll(['row 0 at 0', 'row 1 at 1', 'row 2 at 2']), reason: '${texts.keys}');
      expect(texts['row 1 at 1']!.height / texts['row 0 at 0']!.height, closeTo(0.9, 0.01), reason: 'scaled by its distance');
      // Held halfway (a finger on it): no settle while it is held.
      final list = _box(tester, 'lst');
      final g = await tester.startGesture(list.localToGlobal(const Offset(50, 100)));
      await g.moveBy(const Offset(0, -30));
      await tester.pump();
      await g.moveBy(const Offset(0, -20));
      await tester.pump();
      await tester.pump();
      final held = tester.stateList<ScrollableState>(find.byType(Scrollable)).map((s) => s.position).firstWhere((p) => p.viewportDimension == 200).pixels;
      texts = painted(tester, 'lst');
      expect(held % 40, isNot(0), reason: 'between rows: $held');
      final read = {for (final k in texts.keys) if (RegExp(r'^row (\d+) at (.+)$').firstMatch(k) case final m?) int.parse(m[1]!): double.parse(m[2]!)};
      for (final i in [0, 1, 2]) {
        expect(read[i], closeTo(i - held / 40, 0.01), reason: 'row $i: $texts');
      }
      await g.up();
      final r1 = texts.entries.firstWhere((e) => e.key.startsWith('row 1 at ')).value, r2 = texts.entries.firstWhere((e) => e.key.startsWith('row 2 at ')).value;
      expect(r1.height / r2.height, closeTo((1 - 0.1 * (1 - held / 40).abs()) / (1 - 0.1 * (2 - held / 40).abs()), 0.01));
    });

    testWidgets('a wheel\'s value changes as each row passes during a fling, its position reads continuously, and its rest is reported',
        (tester) async {
      final session = await _show(tester, '''
state n=10
state pos:decimal=10
state rested=-1
Column
  Text#out "{n}"
  Pages#reel @n w=96 h=252 scrollDirection=vertical peek={1 / 7} padEnds=true snapPhysics.friction=0.865 onScroll={pos=result.page} onScrollEnd={rested=result.index}
    each i in range(60)
      Text "{i}" h=fill
''');
      final position = _position(tester) as ScrollPositionWithSingleContext;
      position.goBallistic(1500);
      final values = <String>[], positions = <double>[];
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        values.add(_out(tester));
        positions.add((session.values['pos'] as num).toDouble());
        if (i > 5 && !position.isScrollingNotifier.value) break;
      }
      await _settle(tester);
      expect(values.toSet().length, greaterThan(8), reason: 'the bound value passed many rows: ${values.toSet()}');
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThanOrEqualTo(positions[i - 1] - 1e-9), reason: 'the position only moves on');
      }
      expect(positions.any((p) => p != p.roundToDouble()), isTrue, reason: 'a decimal between rows: $positions');
      expect('${session.values['rested']}', _out(tester), reason: 'scrollEnd reports the row at rest');
    });

    const long = '''
state rested=-1
Column
  ListView#long h=400 itemSnapping=true snapPhysics.friction=FRICTION onScrollEnd={rested=result.index}
    each i in range(500)
      Text "{i}" h=EXTENT
''';

    Future<(List<double>, ScrollPosition, UiSession)> flingList(WidgetTester tester, String page, double velocity) async {
      final session = await _show(tester, page);
      final position = _position(tester) as ScrollPositionWithSingleContext;
      position.goBallistic(velocity);
      final speeds = <double>[];
      for (var i = 0; i < 2000; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        speeds.add((position.activity?.velocity ?? 0).abs());
        if (i > 5 && !position.isScrollingNotifier.value) break;
      }
      await _settle(tester);
      return (speeds, position as ScrollPosition, session);
    }

    testWidgets('a hard fling on a 500-row lazy list coasts by its own friction past unbuilt rows and rests on the projected row',
        (tester) async {
      final (speeds, position, session) =
          await flingList(tester, long.replaceFirst('FRICTION', '0.5').replaceFirst('EXTENT', '40'), 6000);
      // 6000 / -ln(0.5) = 8656 px: row 216.4, so row 216.
      expect(position.pixels, 216 * 40.0);
      expect(session.values['rested'], 216);
      for (var i = 1; i < speeds.length; i++) {
        expect(speeds[i], lessThanOrEqualTo(speeds[i - 1] + 0.5), reason: 'the speed only falls (frame $i: ${speeds[i - 1]} -> ${speeds[i]})');
      }
      expect(speeds.first, greaterThan(4000));
    });

    testWidgets('with rows of two heights it rests on a row, within one row of the projection', (tester) async {
      final (_, position, _) =
          await flingList(tester, long.replaceFirst('FRICTION', '0.5').replaceFirst('EXTENT', '{i % 2 == 0 ? 40 : 60}'), 6000);
      // Rows alternate 40 and 60: a pair is 100, so a row starts at 100k or 100k + 40.
      final p = position.pixels;
      final rest = p - (p / 100).floor() * 100;
      expect(rest == 0 || rest == 40, isTrue, reason: '$p is a row start');
      expect((p - 6000 / -math.log(0.5)).abs(), lessThanOrEqualTo(60));
    });

    testWidgets('a fling past the end of the data stops at the last row', (tester) async {
      final (_, position, _) = await flingList(tester, long.replaceFirst('FRICTION', '0.1').replaceFirst('EXTENT', '40'), 6000);
      expect(position.maxScrollExtent, 500 * 40.0 - 400);
      expect(position.pixels, position.maxScrollExtent);
    });
  });
}
