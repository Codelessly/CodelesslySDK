import 'dart:async' show Stream;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/calendar.dart';
import 'package:codelessly_sdk/src/render/controls/kit_pickers.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula_clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';
import 'support.dart';

RenderCalendar _calendar(RenderTree tree) {
  RenderCalendar? found;
  void visit(RenderObject object) {
    if (object is RenderCalendar && object.inline) found = object;
    object.visitChildren(visit);
  }

  visit(tree.boxOf('stay')!);
  return found!;
}

Future<(NodeTree, RecordedInteractions, RenderCalendar)> _show(
  WidgetTester tester, {
  double width = 800,
  bool dark = false,
  bool rtl = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final doc = columnDoc(
    {
      'stay': hugging('calendar', {
        'start': '2026-11-20',
        'end': '',
        'label': 'Choose your nights',
        'disabledDates': ['2026-11-21'],
        'dayPrices': {'2026-11-20': '£225', '2026-11-22': '£245'},
        'marks': {'2026-11-24': 'Sold'},
      }, rtl ? {'textDirection': 'rtl'} : const {}),
    },
    width: width,
    height: 900,
    fill: dark ? '#FF1C1C1C' : '#FFFFFFFF',
  );
  final (tree, recorded) = runningTree(doc, dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(
    NodeView(tree: tree, rootId: 'col', interactive: true),
  );
  await tester.pump();
  return (tree, recorded, _calendar(tree));
}

Offset _day(RenderCalendar calendar, int day) {
  for (var i = 0; i < 42; i++) {
    if (calendar.dayAt(i)?.day == day)
      return calendar.localToGlobal(calendar.cellRect(i).center);
  }
  throw StateError('Missing day $day');
}

void main() {
  setUp(() => FormulaClock.pinned = DateTime(2026, 11, 14));
  tearDown(() => FormulaClock.pinned = null);

  testWidgets(
    'pointer picks a range, skips unavailable nights, and exposes prices and state to semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, recorded, calendar) = await _show(tester, width: 390);
      expect(calendar.inline, isTrue);
      expect(calendar.inRange(DateTime(2026, 11, 21)), isFalse);
      expect(calendar.size.width, greaterThanOrEqualTo(320));
      expect(
        calendar.targetCellRect(calendar.cellOf(DateTime(2026, 11, 22))!).width,
        greaterThanOrEqualTo(44),
      );
      expect(calendar.headerTarget(calendar.prevRect).width, 44);
      await tester.tapAt(_day(calendar, 21));
      await tester.pump();
      expect(recorded.fired, isEmpty);
      await tester.tapAt(_day(calendar, 22));
      await tester.pump();
      expect(
        calendar.keyboardCursor,
        isFalse,
        reason: 'a pointer does not leave a keyboard ring',
      );
      expect(isoDay(calendar.value!), '2026-11-22');
      expect(calendar.rangeEnd, isNull);
      await tester.tapAt(_day(calendar, 23));
      await tester.pump();
      expect(isoDay(calendar.rangeEnd!), '2026-11-23');
      expect(recorded.fired, ['stay changed', 'stay changed']);
      final semantics = tester
          .getSemantics(find.byType(NodeView))
          .toStringDeep();
      expect(semantics, contains('£225'));
      expect(semantics, contains('unavailable'));
      expect(semantics, contains('check-out'));
      expect(tree.boxOf('stay'), isNotNull);
      handle.dispose();
    },
  );

  testWidgets(
    'one Tab reaches the calendar; arrows, Home, End and Space pick on a phone in dark mode',
    (tester) async {
      final handle = tester.ensureSemantics();
      final (_, _, calendar) = await _show(tester, width: 390, dark: true);
      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedId, 'stay');
      expect(keys.stopIds(calendar).where((id) => id == 'stay'), hasLength(1));
      expect(keys.ringShown, isTrue);
      expect(keys.semantics!.label, contains('Choose your nights'));
      expect(keys.semantics!.isFocused, isTrue);
      await keys.right();
      expect(calendar.cursorDay.day, 21);
    calendar.updateRange(start: DateTime(2026, 11, 20), disabledDates: {'2026-11-21'});
    expect(calendar.cursorDay.day, 21, reason: 'an unchanged bound range does not reset the keyboard cursor');
      await keys.right();
      expect(calendar.cursorDay.day, 22);
      await keys.enter();
      expect(calendar.value!.day, 22);
      expect(calendar.rangeEnd, isNull);
      await keys.right();
      await keys.space();
      expect(calendar.rangeEnd!.day, 23);
      await keys.home();
      expect(calendar.cursorDay.day, 22);
      await keys.end();
      expect(calendar.cursorDay.day, 28);
      expect(calendar.size.width, lessThanOrEqualTo(390));
      handle.dispose();
    },
  );

  testWidgets('RTL reverses horizontal movement and mirrors the month grid', (
    tester,
  ) async {
    final (_, _, calendar) = await _show(tester, width: 390, rtl: true);
    expect(calendar.direction, TextDirection.rtl);
    final first = calendar.cellOf(DateTime(2026, 11, 20))!;
    final next = calendar.cellOf(DateTime(2026, 11, 21))!;
    expect(
      calendar.cellRect(next).center.dx,
      lessThan(calendar.cellRect(first).center.dx),
    );
    final keys = Keyboard(tester);
    await keys.tab();
    await keys.left();
    expect(calendar.cursorDay.day, 21);
    await keys.right();
    expect(calendar.cursorDay.day, 20);
    await keys.press(LogicalKeyboardKey.pageDown);
    expect(calendar.cursorDay.month, 12);
    calendar.toggleYears();
    expect(calendar.yearRect(1).center.dx, lessThan(calendar.yearRect(0).center.dx));
    await keys.left();
    expect(calendar.cursorDay.year, 2027);
  });

  testWidgets('notation writes both selected dates back into the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodelesslyView(session: session)),
      ),
    );
    final result = await session.applyNotation(
      Stream.value('''
state arrival="2026-11-20"
state departure="2026-11-22"
Page
  Section
    Calendar#stay =arrival =departure disabledDates:["2026-11-24"]
    Text#chosen "{arrival} to {departure}"
'''),
    );
    await tester.pump();
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty);
    RenderCalendar? calendar;
    void visit(RenderObject object) {
      if (object is RenderCalendar && object.inline) calendar = object;
      object.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
    expect(calendar, isNotNull);
    await tester.tapAt(_day(calendar!, 22));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(_day(calendar!, 23));
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.values['arrival'], '2026-11-22');
    expect(session.values['departure'], '2026-11-23');
  });
}
