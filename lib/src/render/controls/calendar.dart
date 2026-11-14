// A month grid as one render object (SSUI's `SoftSaaSCalendar`, no widget):
// a header with the previous and next month buttons and the month's title
// (a tap on it shows the years), the locale's weekday initials from its
// first weekday, and the days. The selected day is filled with the accent,
// today ringed with it, days outside [first]..[last] at half opacity and
// not pickable.
//
// Keyboard (the picker forwards keys to [RenderCalendar.handleKey]):
// arrows move a day or a week, Page Up / Down a month (with Shift a year),
// Home / End the start and end of the week, Enter or Space picks.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'kit_pickers.dart';

/// A month grid: pick a day in [first]..[last].
class RenderCalendar extends RenderBox implements MouseTrackerAnnotation {
  RenderCalendar({
    required PickerColors colors,
    required PickerLocale symbols,
    required DateTime today,
    DateTime? value,
    DateTime? first,
    DateTime? last,
    this.onPicked,
  })  : _colors = colors, // ignore: prefer_initializing_formals
        _symbols = symbols, // ignore: prefer_initializing_formals
        _today = dayOf(today),
        _value = value == null ? null : dayOf(value),
        _first = first == null ? null : dayOf(first),
        _last = last == null ? null : dayOf(last) {
    final start = clampDay(_value ?? _today);
    _cursor = start;
    _month = DateTime(start.year, start.month);
    _tap = pickerTap(this, _tapAt);
  }

  /// Width of the grid (SSUI's popover is 236 with 8 of padding).
  static const double gridWidth = 220;
  static const double headerHeight = 28, weekdayHeight = 24, cellHeight = 28, gap = 2, headerGap = 4;

  /// Rows of days: always six, so the panel never changes height.
  static const rows = 6;

  /// What a pick does (a tap on a day, Enter).
  ValueChanged<DateTime>? onPicked;

  PickerColors _colors;
  set colors(PickerColors v) {
    if (v == _colors) return;
    _colors = v;
    markNeedsPaint();
  }

  PickerLocale _symbols;
  PickerLocale get symbols => _symbols;
  set symbols(PickerLocale v) {
    if (identical(v, _symbols)) return;
    _symbols = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  final DateTime _today;
  DateTime get today => _today;
  DateTime? _value;
  DateTime? get value => _value;
  final DateTime? _first, _last;
  DateTime? get first => _first;
  DateTime? get last => _last;

  late DateTime _cursor;
  late DateTime _month;

  /// The day the keyboard is on.
  DateTime get cursorDay => _cursor;

  /// The month shown (its first day).
  DateTime get month => _month;

  bool _years = false;

  /// Whether the years show instead of the days (a tap on the title).
  bool get showingYears => _years;
  int _yearPage = 0;

  /// The first year of the twelve shown.
  int get yearPageStart => _yearPage;

  bool _keyboard = false;

  /// Whether the keyboard's cursor shows (after a key; a pointer hides it).
  bool get keyboardCursor => _keyboard;
  set keyboardCursor(bool v) {
    if (v == _keyboard) return;
    _keyboard = v;
    markNeedsPaint();
  }

  int? _hovered;

  late final TapGestureRecognizer _tap;

  bool inRange(DateTime d) => (_first == null || !d.isBefore(_first)) && (_last == null || !d.isAfter(_last));

  DateTime clampDay(DateTime d) {
    if (_first != null && d.isBefore(_first)) return _first;
    if (_last != null && d.isAfter(_last)) return _last;
    return d;
  }

  /// The weekday the grid starts on (`DateTime.weekday`).
  int get firstWeekday => _symbols.firstWeekday;

  /// Days before the 1st in the first row.
  int _lead(DateTime month) => (DateTime(month.year, month.month).weekday - firstWeekday + 7) % 7;

  int _daysIn(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  /// The weekday initials in the grid's order.
  List<String> get weekdayInitials => [
        for (var i = 0; i < 7; i++) _symbols.narrowWeekdays[sundayIndex((firstWeekday - 1 + i) % 7 + 1)],
      ];

  /// The title: `November 2026`, or the years shown.
  String get title => _years ? '$_yearPage – ${_yearPage + 11}' : '${_symbols.months[_month.month - 1]} ${_month.year}';

  // --- moving -----------------------------------------------------------------

  void _show(DateTime month) {
    _month = DateTime(month.year, month.month);
    _hovered = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// Shows the month [delta] months away (the cursor follows, kept in the
  /// month and the range).
  void shiftMonth(int delta) {
    final m = DateTime(_month.year, _month.month + delta);
    final day = math.min(_cursor.day, _daysIn(m));
    _cursor = clampDay(DateTime(m.year, m.month, day));
    _show(m);
  }

  void _moveCursor(DateTime to) {
    _keyboard = true;
    _cursor = clampDay(to);
    if (_cursor.year != _month.year || _cursor.month != _month.month) {
      _show(_cursor);
    } else {
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  /// Shows the years (twelve around the month's) or the days again.
  void toggleYears() {
    _years = !_years;
    _yearPage = _month.year - (_month.year % 12);
    _hovered = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _pickYear(int year) {
    _years = false;
    final day = math.min(_cursor.day, _daysIn(DateTime(year, _month.month)));
    _cursor = clampDay(DateTime(year, _month.month, day));
    _show(_cursor);
  }

  void _pageYears(int delta) {
    _yearPage += 12 * delta;
    _hovered = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _pick(DateTime d) {
    if (!inRange(d)) return;
    _value = d;
    _cursor = d;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    onPicked?.call(d);
  }

  /// A key while the picker is open; true when the calendar used it.
  bool handleKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (_years) {
      final y = _cursor.year;
      int? to;
      if (key == LogicalKeyboardKey.arrowLeft) to = y - 1;
      if (key == LogicalKeyboardKey.arrowRight) to = y + 1;
      if (key == LogicalKeyboardKey.arrowUp) to = y - 3;
      if (key == LogicalKeyboardKey.arrowDown) to = y + 3;
      if (key == LogicalKeyboardKey.pageUp) to = y - 12;
      if (key == LogicalKeyboardKey.pageDown) to = y + 12;
      if (to != null) {
        _keyboard = true;
        _cursor = clampDay(DateTime(to, _cursor.month, math.min(_cursor.day, _daysIn(DateTime(to, _cursor.month)))));
        if (_cursor.year < _yearPage || _cursor.year > _yearPage + 11) _yearPage = _cursor.year - (_cursor.year % 12);
        markNeedsPaint();
        markNeedsSemanticsUpdate();
        return true;
      }
      if (_isPick(key)) {
        _pickYear(_cursor.year);
        return true;
      }
      return false;
    }
    final c = _cursor;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveCursor(DateTime(c.year, c.month, c.day - 1));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveCursor(DateTime(c.year, c.month, c.day + 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveCursor(DateTime(c.year, c.month, c.day - 7));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(DateTime(c.year, c.month, c.day + 7));
    } else if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown) {
      final months = (key == LogicalKeyboardKey.pageUp ? -1 : 1) * (shift ? 12 : 1);
      final m = DateTime(c.year, c.month + months);
      _moveCursor(DateTime(m.year, m.month, math.min(c.day, _daysIn(m))));
    } else if (key == LogicalKeyboardKey.home) {
      _moveCursor(DateTime(c.year, c.month, c.day - (c.weekday - firstWeekday + 7) % 7));
    } else if (key == LogicalKeyboardKey.end) {
      _moveCursor(DateTime(c.year, c.month, c.day + 6 - (c.weekday - firstWeekday + 7) % 7));
    } else if (_isPick(key)) {
      _keyboard = true;
      _pick(_cursor);
    } else {
      return false;
    }
    return true;
  }

  static bool _isPick(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space;

  // --- geometry -----------------------------------------------------------------

  double get _bodyTop => headerHeight + headerGap;
  double get _gridTop => _bodyTop + weekdayHeight;
  double get _bodyHeight => weekdayHeight + rows * cellHeight + (rows - 1) * gap;
  double get _cellWidth => (size.width - 6 * gap) / 7;

  Rect get prevRect => const Rect.fromLTWH(0, 2, 24, 24);
  Rect get nextRect => Rect.fromLTWH(size.width - 24, 2, 24, 24);
  Rect get titleRect => Rect.fromLTRB(28, 2, size.width - 28, 26);

  /// The rect of grid cell [i] (0..41).
  Rect cellRect(int i) {
    final row = i ~/ 7, col = i % 7;
    return Rect.fromLTWH(col * (_cellWidth + gap), _gridTop + row * (cellHeight + gap), _cellWidth, cellHeight);
  }

  /// The day in cell [i] of the month shown, or null (a blank).
  DateTime? dayAt(int i) {
    final n = i - _lead(_month) + 1;
    if (n < 1 || n > _daysIn(_month)) return null;
    return DateTime(_month.year, _month.month, n);
  }

  /// The cell [d] is in, when its month shows.
  int? cellOf(DateTime d) =>
      d.year == _month.year && d.month == _month.month ? d.day - 1 + _lead(_month) : null;

  /// The rect of year cell [i] (0..11).
  Rect yearRect(int i) {
    final w = (size.width - 2 * gap) / 3, h = (_bodyHeight - 3 * gap) / 4;
    return Rect.fromLTWH(i % 3 * (w + gap), _bodyTop + i ~/ 3 * (h + gap), w, h);
  }

  bool _yearInRange(int y) => (_first == null || y >= _first.year) && (_last == null || y <= _last.year);

  @override
  double computeMinIntrinsicWidth(double height) => gridWidth;
  @override
  double computeMaxIntrinsicWidth(double height) => gridWidth;
  @override
  double computeMinIntrinsicHeight(double width) => _bodyTop + _bodyHeight;
  @override
  double computeMaxIntrinsicHeight(double width) => _bodyTop + _bodyHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.hasBoundedWidth ? math.max(gridWidth, constraints.minWidth) : gridWidth, _bodyTop + _bodyHeight));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  // --- pointer ------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => true;

  /// What is at [p]: -1 previous, -2 next, -3 the title, 0..41 a day cell,
  /// 100..111 a year cell; null nothing.
  int? _targetAt(Offset p) {
    if (prevRect.inflate(2).contains(p)) return -1;
    if (nextRect.inflate(2).contains(p)) return -2;
    if (titleRect.contains(p)) return -3;
    if (_years) {
      for (var i = 0; i < 12; i++) {
        if (yearRect(i).contains(p)) return 100 + i;
      }
      return null;
    }
    for (var i = 0; i < rows * 7; i++) {
      if (cellRect(i).inflate(gap / 2).contains(p)) return i;
    }
    return null;
  }

  void _tapAt(Offset p) {
    final t = _targetAt(p);
    if (t == null) return;
    _keyboard = false;
    switch (t) {
      case -1:
        _years ? _pageYears(-1) : shiftMonth(-1);
      case -2:
        _years ? _pageYears(1) : shiftMonth(1);
      case -3:
        toggleYears();
      case >= 100:
        final y = _yearPage + t - 100;
        if (_yearInRange(y)) _pickYear(y);
      default:
        if (dayAt(t) case final DateTime d) _pick(d);
    }
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) _tap.addPointer(event);
    if (event is PointerHoverEvent) {
      final t = _targetAt(entry.localPosition);
      if (t != _hovered) {
        _hovered = t;
        if (t != null) _keyboard = false;
        markNeedsPaint();
      }
    }
  }

  @override
  MouseCursor get cursor => SystemMouseCursors.click;
  @override
  PointerEnterEventListener? get onEnter => null;
  @override
  PointerExitEventListener? get onExit => (_) {
        if (_hovered == null) return;
        _hovered = null;
        markNeedsPaint();
      };
  @override
  bool get validForMouseTracker => attached;

  @override
  void detach() {
    _hovered = null;
    super.detach();
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  // --- paint --------------------------------------------------------------------

  /// The day's look now: its fill, ink, ring and opacity (for tests and
  /// paint).
  ({Color? fill, Color ink, Color? ring, bool enabled, bool cursor}) lookOf(DateTime d) {
    final c = _colors;
    final enabled = inRange(d);
    final selected = sameDay(d, _value);
    final cell = cellOf(d);
    final active = enabled && ((cell != null && _hovered == cell) || (_keyboard && sameDay(d, _cursor)));
    return (
      fill: selected ? c.accent : (active ? c.hover : null),
      ink: selected ? c.onAccent : c.text,
      ring: sameDay(d, _today) && !selected ? c.accent : null,
      enabled: enabled,
      cursor: _keyboard && sameDay(d, _cursor),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final c = _colors;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    // Header: the arrows and the title.
    for (final (i, r, glyph) in [(-1, prevRect, PickerGlyph.chevronLeft), (-2, nextRect, PickerGlyph.chevronRight)]) {
      if (_hovered == i) canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(c.dayRadius)), Paint()..color = c.hover);
      paintPickerGlyph(canvas, glyph, Rect.fromCenter(center: r.center, width: 14, height: 14), c.muted);
    }
    if (_hovered == -3) canvas.drawRRect(RRect.fromRectAndRadius(titleRect, Radius.circular(c.dayRadius)), Paint()..color = c.hover);
    final titleStyle = c.style(13, weight: FontWeight.w600).merge(c.headline?.copyWith(fontSize: c.headline?.fontSize == null ? null : math.min(c.headline!.fontSize!, 16)));
    final t = pickerText(title, titleStyle, maxWidth: titleRect.width);
    paintCentred(canvas, t, titleRect);
    t.dispose();
    if (_years) {
      _paintYears(canvas);
    } else {
      _paintDays(canvas);
    }
    canvas.restore();
  }

  void _paintDays(Canvas canvas) {
    final c = _colors;
    final initials = weekdayInitials;
    for (var i = 0; i < 7; i++) {
      final r = Rect.fromLTWH(i * (_cellWidth + gap), _bodyTop, _cellWidth, weekdayHeight);
      final p = pickerText(initials[i], c.style(11, weight: FontWeight.w500, color: c.muted));
      paintCentred(canvas, p, r);
      p.dispose();
    }
    for (var i = 0; i < rows * 7; i++) {
      final d = dayAt(i);
      if (d == null) continue;
      final r = cellRect(i);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(c.dayRadius));
      final look = lookOf(d);
      final alpha = look.enabled ? 1.0 : .5;
      if (look.fill case final Color fill) canvas.drawRRect(rr, Paint()..color = fill.withValues(alpha: fill.a * alpha));
      if (look.ring case final Color ring) {
        canvas.drawRRect(
            rr.deflate(.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = ring.withValues(alpha: ring.a * alpha));
      }
      if (look.cursor) {
        canvas.drawRRect(
            rr.deflate(.75),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = c.focus);
      }
      final selected = sameDay(d, _value);
      final p = pickerText('${d.day}',
          c.style(12, weight: selected ? FontWeight.w600 : FontWeight.w400, color: look.ink.withValues(alpha: look.ink.a * alpha)));
      paintCentred(canvas, p, r);
      p.dispose();
    }
  }

  void _paintYears(Canvas canvas) {
    final c = _colors;
    for (var i = 0; i < 12; i++) {
      final y = _yearPage + i;
      final r = yearRect(i);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(c.dayRadius));
      final selected = y == _month.year;
      final enabled = _yearInRange(y);
      final alpha = enabled ? 1.0 : .5;
      if (selected) {
        canvas.drawRRect(rr, Paint()..color = c.accent.withValues(alpha: c.accent.a * alpha));
      } else if (enabled && (_hovered == 100 + i || (_keyboard && _cursor.year == y))) {
        canvas.drawRRect(rr, Paint()..color = c.hover);
      }
      if (_keyboard && _cursor.year == y) {
        canvas.drawRRect(
            rr.deflate(.75),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = c.focus);
      }
      final ink = selected ? c.onAccent : c.text;
      final p = pickerText('$y', c.style(12, weight: selected ? FontWeight.w600 : FontWeight.w400, color: ink.withValues(alpha: ink.a * alpha)));
      paintCentred(canvas, p, r);
      p.dispose();
    }
  }

  // --- semantics ----------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..label = title
      ..textDirection = TextDirection.ltr;
  }

  final Map<Object, SemanticsNode> _semantics = {};

  SemanticsNode _node(Object key) => _semantics.putIfAbsent(key, SemanticsNode.new);

  /// The screen reader's children: the arrows, the title, then each day
  /// (or year), each a button that a tap acts on.
  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    final out = <SemanticsNode>[];
    void add(Object key, Rect rect, String label, VoidCallback? onTap, {bool selected = false, bool enabled = true}) {
      final cfg = SemanticsConfiguration()
        ..isButton = true
        ..label = label
        ..isEnabled = enabled
        ..textDirection = TextDirection.ltr;
      if (selected) cfg.isSelected = true;
      if (enabled && onTap != null) cfg.onTap = onTap;
      out.add(_node(key)
        ..rect = rect
        ..updateWith(config: cfg));
    }

    final used = <Object>{};
    void track(Object k) => used.add(k);
    add('prev', prevRect, _years ? 'Previous years' : 'Previous month', () => _years ? _pageYears(-1) : shiftMonth(-1));
    track('prev');
    add('title', titleRect, _years ? 'Choose a day' : 'Choose a year, $title', toggleYears);
    track('title');
    add('next', nextRect, _years ? 'Next years' : 'Next month', () => _years ? _pageYears(1) : shiftMonth(1));
    track('next');
    if (_years) {
      for (var i = 0; i < 12; i++) {
        final y = _yearPage + i;
        add('y$i', yearRect(i), '$y', () => _pickYear(y), selected: y == _month.year, enabled: _yearInRange(y));
        track('y$i');
      }
    } else {
      for (var i = 0; i < rows * 7; i++) {
        final d = dayAt(i);
        if (d == null) continue;
        final label = '${fullDay(d, _symbols)}${sameDay(d, _today) ? ', today' : ''}';
        add('d$i', cellRect(i), label, () => _pick(d), selected: sameDay(d, _value), enabled: inRange(d));
        track('d$i');
      }
    }
    _semantics.removeWhere((k, _) => !used.contains(k));
    node.updateWith(config: config, childrenInInversePaintOrder: out);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _semantics.clear();
  }
}
