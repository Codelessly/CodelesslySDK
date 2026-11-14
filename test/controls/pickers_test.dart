// Date and time pickers as render objects (render/controls/pickers.dart,
// calendar.dart, time_dial.dart, kit_pickers.dart): SSUI's field with
// nothing styled, the picker as an entry of the root's overlay layer (a
// popover under the field on a wide view, a bottom sheet on a narrow one),
// dismissed by a tap outside or Escape, the calendar's month grid (months,
// years, the range, today, the keyboard), the locale's first weekday and
// names without Material localizations, the time columns, the value
// written back as `changed`, the design's own picker, screen readers, and
// no purple anywhere.
import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/calendar.dart';
import 'package:codelessly_sdk/src/render/controls/kit_pickers.dart';
import 'package:codelessly_sdk/src/render/controls/pickers.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:codelessly_sdk/src/render/controls/time_dial.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula_clock.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import 'support.dart';

RenderPickerField _field(RenderTree tree, String id) {
  RenderPickerField? found;
  void visit(RenderObject o) {
    if (o is RenderPickerField) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

RenderControlRoot _root(WidgetTester tester) => tester.renderObject<RenderControlRoot>(find.byType(NodeView));

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {double width = 800, double height = 600, Map<String, Object?>? theme, bool dark = false, Object? fill}) async {
  final (tree, recorded) = runningTree(columnDoc(nodes, width: width, height: height, fill: fill),
      theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

Rect _globalRect(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;

/// The global centre of day [day] of the month the open calendar shows.
Offset _dayAt(RenderCalendar c, int day) {
  for (var i = 0; i < 42; i++) {
    if (c.dayAt(i)?.day == day) return c.localToGlobal(c.cellRect(i).center);
  }
  throw StateError('day $day is not shown');
}

const _ssuiPrimary = Color(0xFF2563EB);

/// No pixel of Material 3's baseline purple family.
const _purples = [0xFF6750A4, 0xFFEADDFF, 0xFF21005D, 0xFF4F378B, 0xFFD0BCFF, 0xFF381E72, 0xFF9333EA];

void main() {
  setUp(() => FormulaClock.pinned = DateTime(2026, 11, 14, 10, 30));
  tearDown(() => FormulaClock.pinned = null);

  group('the field, with nothing styled', () {
    testWidgets('is SSUI\'s select trigger: 28 high, the surface, a hairline, the control radius, a placeholder',
        (tester) async {
      final (tree, _) = await _show(tester, {
        'date': hugging('datePicker'),
        'time': hugging('timePicker'),
        'dt': hugging('dateTimeInput'),
      });
      for (final id in ['date', 'time', 'dt']) {
        expect(rectOf(tree, id).height, 28, reason: id);
        final f = _field(tree, id);
        expect(f.fillColor, const Color(0xFFFFFFFF), reason: id);
        expect(f.border!.side, const BorderSide(color: Color(0xFFE5E7EB)), reason: '$id: SSUI\'s primaryBorder');
        expect(f.border!.radius.topLeft.x, 7, reason: id);
        expect(f.labelColor, const Color(0xFF9CA3AF), reason: '$id: SSUI\'s tertiary text while empty');
      }
      expect(_field(tree, 'date').shown, 'Select date');
      expect(_field(tree, 'time').shown, 'Select time');
      expect(_field(tree, 'dt').shown, 'Select date');
    });

    testWidgets('shows its value: ISO for a date or time picker, words for a date/time input, or its pattern',
        (tester) async {
      final (tree, _) = await _show(tester, {
        'date': hugging('datePicker', {'value': '2026-11-13'}),
        'time': hugging('timePicker', {'value': '09:30'}),
        'dt': hugging('dateTimeInput', {'mode': 'dateTime', 'value': '2026-11-12T09:05:00'}),
        'pattern': hugging('datePicker', {'value': '2026-11-30', 'format': 'EEE d MMM yyyy'}),
        'time12': hugging('dateTimeInput', {'mode': 'time', 'value': '13:05'}),
      });
      expect(_field(tree, 'date').shown, '2026-11-13');
      expect(_field(tree, 'time').shown, '09:30');
      expect(_field(tree, 'dt').shown, 'Thu, Nov 12 · 9:05 AM');
      expect(_field(tree, 'pattern').shown, 'Mon 30 Nov 2026');
      expect(_field(tree, 'time12').shown, '1:05 PM');
      expect(_field(tree, 'date').labelColor, const Color(0xFF111827));
      expect(rectOf(tree, 'pattern').width, greaterThan(rectOf(tree, 'date').width), reason: 'a hugging field is its content\'s width');
    });

    testWidgets('dark mode takes SSUI\'s dark tokens; disabled is half opacity and does not open', (tester) async {
      final (tree, _) = await _show(tester, {
        'date': hugging('datePicker', {'value': '2026-11-13'}),
        'off': hugging('datePicker', {'value': '2026-11-13', 'enabled': false}),
      }, dark: true, fill: '#FF1C1C1C');
      final f = _field(tree, 'date');
      expect(f.fillColor, const Color(0xFF141414));
      expect(f.border!.side.color, const Color(0xFF383838));
      final off = _field(tree, 'off');
      expect(off.paintedAlpha, 128);
      await tester.tapAt(centreOf(tree, 'off'));
      await tester.pump();
      expect(_root(tester).overlayEntries, isEmpty);
    });

    testWidgets('a decoration draws the field: its fill, border, hint and icons', (tester) async {
      final (tree, _) = await _show(tester, {
        'time': {
          'type': 'timePicker',
          'layout': {'width': 160, 'height': 42},
          'props': {
            'value': '',
            'decoration': {
              'hintText': '—',
              'filled': true,
              'fillColor': '#FFF5F1E8',
              'border': {'type': 'outline', 'borderRadius': 10, 'borderSide': {'color': '#FFD3CDC0'}},
            },
          },
        },
      });
      final f = _field(tree, 'time');
      expect(rectOf(tree, 'time').size, const Size(160, 42));
      expect(f.shown, '—');
      expect(f.fillColor, const Color(0xFFF5F1E8));
      expect(f.border!.side.color, const Color(0xFFD3CDC0));
      expect(f.border!.radius.topLeft.x, 10);
    });
  });

  group('the popup', () {
    testWidgets('on a wide view it is a popover in the root\'s overlay layer, under the field and aligned with it',
        (tester) async {
      final (tree, _) = await _show(tester, {'date': hugging('datePicker', {'value': '2026-11-13'})});
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final popup = _root(tester).overlayEntries.single as RenderPickerPopup;
      expect(popup.sheet, isFalse);
      final panel = _globalRect(popup.child!);
      final field = rectOf(tree, 'date');
      expect(panel.top, field.bottom + 4);
      expect(panel.left, field.left);
      expect(panel.width, 236, reason: 'SSUI\'s 236 wide popover');
      expect(_field(tree, 'date').open, isTrue);
      expect(_field(tree, 'date').border!.side.width, 1.5, reason: 'the focus border while open');
    });

    testWidgets('above the field when there is no room below', (tester) async {
      final (tree, _) = await _show(tester, {
        'spacer': {'type': 'box', 'layout': {'width': 10, 'height': 480}},
        'date': hugging('datePicker'),
      });
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final popup = _root(tester).overlayEntries.single as RenderPickerPopup;
      expect(_globalRect(popup.child!).bottom, rectOf(tree, 'date').top - 4);
    });

    testWidgets('on a narrow view it is a bottom sheet over a scrim', (tester) async {
      final (tree, _) = await _show(tester, {'date': hugging('datePicker')}, width: 390, height: 700);
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final popup = _root(tester).overlayEntries.single as RenderPickerPopup;
      expect(popup.sheet, isTrue);
      final panel = _globalRect(popup.child!);
      expect(panel.bottom, 700);
      expect(panel.width, 390);
      expect(popup.scrim, const Color(0x66000000), reason: 'SSUI\'s scrim');
    });

    testWidgets('a tap outside closes it and presses nothing under it; Escape closes it and keeps the focus',
        (tester) async {
      final (tree, recorded) = await _show(tester, {
        'date': hugging('datePicker'),
        'go': hugging('filledButton', {'label': 'Go'}),
      });
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      expect(_root(tester).overlayEntries, hasLength(1));
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(_root(tester).overlayEntries, isEmpty);
      expect(recorded.fired, isEmpty);
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_root(tester).overlayEntries, isEmpty);
      expect(_field(tree, 'date').focusNode.hasFocus, isTrue);
      expect(recorded.fired, isEmpty, reason: 'nothing picked: no changed');
    });

    testWidgets('a date/time input with the design\'s own picker opens nothing: a tap is its click', (tester) async {
      final s = await lists.show(tester, {
        'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
        'd': {
          'type': 'dateTimeInput',
          'layout': {'width': 300, 'height': 34},
          'props': {'mode': 'date', 'value': '2026-12-01', 'format': 'MMM d, y', 'bare': true, 'picker': 'none'},
          'actions': [
            lists.reaction('click', [{'type': 'setVariable', 'variable': 'opened', 'value': true}]),
          ],
        },
      }, variables: [lists.v('opened', false, VariableType.boolean)]);
      expect(_field(s.tree, 'd').shown, 'Dec 1, 2026');
      await tester.tapAt(centreOf(s.tree, 'd'));
      await tester.pumpAndSettle();
      expect(s['opened'], isTrue);
      expect(_root(tester).overlayEntries, isEmpty);
    });
  });

  group('the calendar', () {
    testWidgets('a month grid: the value selected, today ringed, the locale\'s weekdays from its first day',
        (tester) async {
      final (tree, _) = await _show(tester, {'date': hugging('datePicker', {'value': '2026-11-03'})});
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final c = _field(tree, 'date').panel!.calendar!;
      expect(c.title, 'November 2026');
      expect(c.weekdayInitials, ['S', 'M', 'T', 'W', 'T', 'F', 'S'], reason: 'en_US weeks start on Sunday');
      expect(c.dayAt(0), DateTime(2026, 11, 1), reason: 'Nov 1 2026 is a Sunday');
      final selected = c.lookOf(DateTime(2026, 11, 3));
      expect(selected.fill, _ssuiPrimary);
      expect(selected.ink, const Color(0xFFFFFFFF));
      final today = c.lookOf(DateTime(2026, 11, 14));
      expect(today.ring, _ssuiPrimary, reason: 'today (the pinned clock: --now) is ringed');
      expect(c.lookOf(DateTime(2026, 11, 15)).ring, isNull);
    });

    testWidgets('in a locale whose weeks start on Monday, with its names', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final (tree, _) = await _show(tester, {'date': hugging('datePicker', {'value': '2026-03-04'})});
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final c = _field(tree, 'date').panel!.calendar!;
      expect(c.title, 'März 2026');
      expect(c.weekdayInitials, ['M', 'D', 'M', 'D', 'F', 'S', 'S']);
      expect(c.dayAt(6), DateTime(2026, 3, 1), reason: 'Sunday, March 1 is the last of the first row');
    });

    testWidgets('the arrows change the month, the title shows the years', (tester) async {
      final (tree, _) = await _show(tester, {'date': hugging('datePicker', {'value': '2026-11-13'})});
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final c = _field(tree, 'date').panel!.calendar!;
      await tester.tapAt(c.localToGlobal(c.nextRect.center));
      await tester.pump();
      expect(c.title, 'December 2026');
      await tester.tapAt(c.localToGlobal(c.prevRect.center));
      await tester.tapAt(c.localToGlobal(c.prevRect.center));
      await tester.pump();
      expect(c.title, 'October 2026');
      await tester.tapAt(c.localToGlobal(c.titleRect.center));
      await tester.pump();
      expect(c.showingYears, isTrue);
      expect(c.title, '2016 – 2027');
      await tester.tapAt(c.localToGlobal(c.yearRect(4).center));
      await tester.pump();
      expect(c.showingYears, isFalse);
      expect(c.title, 'October 2020');
    });

    testWidgets('days outside the first and last dates are dimmed and cannot be picked', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'date': hugging('datePicker', {'value': '2024-05-17', 'firstDate': '2024-05-10', 'lastDate': '2024-05-20'}),
      });
      await tester.tapAt(centreOf(tree, 'date'));
      await tester.pump();
      final c = _field(tree, 'date').panel!.calendar!;
      expect(c.lookOf(DateTime(2024, 5, 9)).enabled, isFalse);
      expect(c.lookOf(DateTime(2024, 5, 21)).enabled, isFalse);
      await tester.tapAt(_dayAt(c, 21));
      await tester.pump();
      expect(_root(tester).overlayEntries, hasLength(1));
      expect(recorded.fired, isEmpty);
      await tester.tapAt(_dayAt(c, 20));
      await tester.pump();
      expect(_root(tester).overlayEntries, isEmpty);
      expect(recorded.fired, ['date changed']);
      expect(_field(tree, 'date').shown, '2024-05-20');
    });

    testWidgets('the keyboard: Down opens it, arrows, Page Up/Down, Home/End move, Enter picks', (tester) async {
      final (tree, recorded) = await _show(tester, {'date': hugging('datePicker', {'value': '2026-11-13'})});
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_field(tree, 'date').focusHighlight, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final c = _field(tree, 'date').panel!.calendar!;
      expect(c.keyboardCursor, isTrue);
      expect(c.cursorDay, DateTime(2026, 11, 13));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(c.cursorDay, DateTime(2026, 11, 14));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(c.cursorDay, DateTime(2026, 11, 21));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(c.cursorDay, DateTime(2026, 11, 13));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      expect(c.cursorDay, DateTime(2026, 12, 13));
      expect(c.title, 'December 2026');
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      expect(c.cursorDay, DateTime(2026, 10, 13));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      expect(c.cursorDay, DateTime(2026, 10, 11), reason: 'the Sunday its week starts on');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(c.cursorDay, DateTime(2026, 10, 17));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(c.cursorDay, DateTime(2027, 10, 17), reason: 'Shift and Page Down: a year');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_root(tester).overlayEntries, isEmpty);
      expect(recorded.fired, ['date changed']);
      expect(_field(tree, 'date').shown, '2027-10-17');
      expect(_field(tree, 'date').focusNode.hasFocus, isTrue);
    });
  });

  group('the time', () {
    testWidgets('hour and minute columns, AM/PM in 12-hour time; the keyboard steps and types them', (tester) async {
      final (tree, recorded) = await _show(tester, {'time': hugging('timePicker', {'value': '09:30'})});
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      final t = _field(tree, 'time').panel!.time!;
      expect(t.columns, 3);
      expect(t.display, '9:30 AM');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(t.display, '10:30 AM');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(t.display, '10:29 AM');
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      expect(t.display, '10:34 AM');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      expect(t.display, '10:34 PM');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      expect(t.display, '2:34 PM', reason: 'a 2 can\'t grow past 12: the hour, then the minute');
      expect(t.column, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      expect(t.display, '2:05 PM');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(recorded.fired, ['time changed']);
      expect(_field(tree, 'time').shown, '14:05');
    });

    testWidgets('in 24-hour time two columns; a tap on a row picks it, Done sets it, Cancel does not', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'time': hugging('timePicker', {'value': '13:00', 'alwaysUse24HourFormat': true}),
      });
      await tester.tapAt(centreOf(tree, 'time'));
      await tester.pump();
      var t = _field(tree, 'time').panel!.time!;
      expect(t.columns, 2);
      expect(t.display, '13:00');
      await tester.tapAt(t.localToGlobal(t.rowRect(0, 1).center));
      await tester.tapAt(t.localToGlobal(t.rowRect(1, 2).center));
      await tester.pump();
      expect(t.display, '14:02');
      await tester.tapAt(t.localToGlobal(t.footerRects.cancel.center));
      await tester.pump();
      expect(_root(tester).overlayEntries, isEmpty);
      expect(recorded.fired, isEmpty);
      await tester.tapAt(centreOf(tree, 'time'));
      await tester.pump();
      t = _field(tree, 'time').panel!.time!;
      await tester.tapAt(t.localToGlobal(t.rowRect(1, -1).center));
      await tester.tapAt(t.localToGlobal(t.footerRects.done.center));
      await tester.pump();
      expect(recorded.fired, ['time changed']);
      expect(_field(tree, 'time').shown, '13:59', reason: 'the minute wraps: 13:00 less a minute keeps the hour');
    });

    testWidgets('a date and time: the day, then the time, written back as a UTC date-time', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await lists.show(tester, {
        'col': {'type': 'column', 'children': ['dt'], 'layout': {'width': 800, 'height': 600}},
        'dt': {
          'type': 'dateTimeInput',
          'layout': {'width': 260, 'height': 34},
          'bind': {'props.value': r'${arrival}'},
          'props': {'mode': 'dateTime', 'format': 'EEE, MMM d · h:mm a'},
        },
      }, variables: [lists.v('arrival', '2026-11-12T09:05:00')]);
      final f = _field(s.tree, 'dt');
      expect(f.shown, 'Thu, Nov 12 · 9:05 AM');
      await tester.tapAt(centreOf(s.tree, 'dt'));
      await tester.pump();
      final panel = f.panel!;
      await tester.tapAt(_dayAt(panel.calendar!, 20));
      await tester.pump();
      expect(panel.showingTime, isTrue);
      expect(panel.time!.title, 'Fri, Nov 20');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(s['arrival'], '2026-11-20T10:05:00.000Z');
      expect(_field(s.tree, 'dt').shown, 'Fri, Nov 20 · 10:05 AM');
    });
  });

  testWidgets('a pick writes the bound variable back, and a new bound value wins over the last pick', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await lists.show(tester, {
      'col': {'type': 'column', 'children': ['date'], 'layout': {'width': 800, 'height': 600}},
      'date': {
        'type': 'datePicker',
        'layout': {'width': 200, 'height': 32},
        'bind': {'props.value': r'${day}'},
      },
    }, variables: [lists.v('day', '2026-11-09')]);
    await tester.tapAt(centreOf(s.tree, 'date'));
    await tester.pump();
    await tester.tapAt(_dayAt(_field(s.tree, 'date').panel!.calendar!, 24));
    await tester.pumpAndSettle();
    expect(s['day'], '2026-11-24');
    expect(_field(s.tree, 'date').shown, '2026-11-24');
    s.scope.set('day', '2027-01-02');
    await tester.pumpAndSettle();
    expect(_field(s.tree, 'date').shown, '2027-01-02');
  });

  testWidgets('a node\'s pickerTheme colours the panel and its help text titles it', (tester) async {
    final (tree, _) = await _show(tester, {
      'date': hugging('datePicker', {
        'value': '2026-11-30',
        'helpText': 'FIRST DAY OFF',
        'pickerTheme': {'backgroundColor': '#FFFDFBF7', 'accentColor': '#FF2F4F46', 'textColor': '#FF23262B', 'radius': 14, 'dayRadius': 8},
      }),
    });
    await tester.tapAt(centreOf(tree, 'date'));
    await tester.pump();
    final panel = _field(tree, 'date').panel!;
    final c = panel.calendar!;
    expect(c.lookOf(DateTime(2026, 11, 30)).fill, const Color(0xFF2F4F46));
    expect(c.lookOf(DateTime(2026, 11, 2)).ink, const Color(0xFF23262B));
    expect(panel.outline.tlRadiusX, 14);
    final popup = _root(tester).overlayEntries.single as RenderPickerPopup;
    expect(popup.semanticsLabel, 'FIRST DAY OFF');
  });

  testWidgets('screen readers: the field is a button with its value; the popup a route of days that a tap picks',
      (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'date': hugging('datePicker', {'value': '2026-11-13'})});
    final f = _field(tree, 'date');
    var data = f.debugSemantics!.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.value, '2026-11-13');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isExpanded, Tristate.isFalse);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(f.debugSemantics!.id, SemanticsAction.tap);
    await tester.pump();
    data = f.debugSemantics!.getSemanticsData();
    expect(data.flagsCollection.isExpanded, Tristate.isTrue);
    final popup = _root(tester).overlayEntries.single as RenderPickerPopup;
    expect(popup.debugSemantics!.getSemanticsData().flagsCollection.scopesRoute, isTrue);
    final c = f.panel!.calendar!;
    SemanticsNode? day;
    c.debugSemantics!.visitChildren((n) {
      if (n.label == 'Tuesday, November 24, 2026') day = n;
      return true;
    });
    expect(day, isNotNull);
    final today = <String>[];
    c.debugSemantics!.visitChildren((n) {
      if (n.label.endsWith('today')) today.add(n.label);
      return true;
    });
    expect(today, ['Saturday, November 14, 2026, today']);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(day!.id, SemanticsAction.tap);
    await tester.pump();
    expect(recorded.fired, ['date changed']);
    expect(f.shown, '2026-11-24');
    handle.dispose();
  });

  testWidgets('hover darkens the hairline; the field, calendar and time draw no purple', (tester) async {
    final (tree, _) = await _show(tester, {
      'date': hugging('datePicker', {'value': '2026-11-13'}),
    });
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(centreOf(tree, 'date'));
    await tester.pump();
    expect(_field(tree, 'date').border!.side.color, const Color(0xFFD1D5DB));
    await tester.tapAt(centreOf(tree, 'date'));
    await tester.pump();
    final c = _field(tree, 'date').panel!.calendar!;
    final colors = <Color?>[
      for (var d = 1; d <= 30; d++) ...[c.lookOf(DateTime(2026, 11, d)).fill, c.lookOf(DateTime(2026, 11, d)).ink, c.lookOf(DateTime(2026, 11, d)).ring],
    ];
    for (final col in colors.whereType<Color>()) {
      expect(_purples, isNot(contains(col.toARGB32())), reason: '$col');
    }
  });

  test('the time columns step and wrap', () {
    final t = RenderTimeColumns(colors: _colors(), symbols: PickerLocale.english, minutes: 23 * 60 + 59, use24h: true);
    t.step(1, 1);
    expect(t.minutes, 23 * 60);
    t.step(0, 1);
    expect(t.minutes, 0);
    t.dispose();
  });
}

PickerColors _colors() => PickerColors.of(ControlTokens.resolve(ThemeTokens.none, dark: false), null);
