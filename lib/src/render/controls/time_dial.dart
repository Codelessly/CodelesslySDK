// A time of day as one render object: SSUI has no dial (its time picker is
// a select of times), so the time is picked in columns, hour and minute (and
// AM / PM in 12-hour time), each showing the chosen value in the middle row
// on the accent and its neighbors around it, the time it makes in the
// header, Cancel and Done below. A tap on a row, the mouse wheel, or the
// keyboard picks; Done (or Enter) sets it.
//
// Keyboard (the picker forwards keys to [RenderTimeColumns.handleKey]):
// Left / Right choose the column, Up / Down step it, Page Up / Down step
// by five minutes (three hours), Home / End its first and last value,
// digits type it, A and P the half of the day, Enter sets the time.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'kit_pickers.dart';

/// Hour, minute and (in 12-hour time) AM / PM columns.
class RenderTimeColumns extends RenderBox implements MouseTrackerAnnotation {
  RenderTimeColumns({
    required PickerColors colors,
    required PickerLocale symbols,
    required int minutes,
    required this.use24h,
    this.title,
    this.onDone,
    this.onCancel,
  })  : _colors = colors, // ignore: prefer_initializing_formals
        _symbols = symbols, // ignore: prefer_initializing_formals
        _minutes = minutes.clamp(0, 24 * 60 - 1) {
    _tap = pickerTap(this, _tapAt);
  }

  static const double width = 220, headerHeight = 28, rowHeight = 28, gap = 2, footerHeight = 28;

  /// Rows each column shows: the chosen value in the middle.
  static const visibleRows = 5;

  /// Sets the time (Done, Enter): minutes since midnight.
  ValueChanged<int>? onDone;

  /// Cancel.
  VoidCallback? onCancel;

  /// 24-hour time (the node's `alwaysUse24HourFormat`); else 1–12 and AM/PM.
  final bool use24h;

  /// A line above the time (the day being picked, in a date and time).
  String? title;

  PickerColors _colors;
  set colors(PickerColors v) {
    if (v == _colors) return;
    _colors = v;
    markNeedsPaint();
  }

  final PickerLocale _symbols;

  int _minutes;

  /// The time chosen so far, minutes since midnight.
  int get minutes => _minutes;
  set minutes(int v) {
    v = v % (24 * 60);
    if (v == _minutes) return;
    _minutes = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  int _column = 0;

  /// The column the keyboard steps: 0 hour, 1 minute, 2 AM / PM.
  int get column => _column;

  bool _keyboard = false;

  /// Whether the keyboard's ring shows.
  bool get keyboardCursor => _keyboard;
  set keyboardCursor(bool v) {
    if (v == _keyboard) return;
    _keyboard = v;
    markNeedsPaint();
  }

  String _typed = '';
  Object? _hovered;
  late final TapGestureRecognizer _tap;

  int get columns => use24h ? 2 : 3;
  int get hour => _minutes ~/ 60;
  int get minute => _minutes % 60;
  bool get pm => hour >= 12;

  /// The time as the header reads it.
  String get display => readableClock(_minutes, _symbols, use24h: use24h);

  // --- values -------------------------------------------------------------------

  /// What column [c] shows at offset [k] rows from its middle.
  String _label(int c, int k) => switch (c) {
        0 => use24h ? ((hour + k) % 24).toString().padLeft(2, '0') : '${((hour % 12) + k) % 12 == 0 ? 12 : ((hour % 12) + k) % 12}',
        1 => ((minute + k) % 60).toString().padLeft(2, '0'),
        _ => _symbols.ampm[k == 0 ? (pm ? 1 : 0) : (pm ? 0 : 1)],
      };

  /// Steps column [c] by [k].
  void step(int c, int k) {
    switch (c) {
      case 0:
        minutes = use24h ? ((hour + k) % 24) * 60 + minute : (pm ? 12 : 0) * 60 + (((hour % 12) + k) % 12) * 60 + minute;
      case 1:
        minutes = hour * 60 + (minute + k) % 60;
      default:
        if (k % 2 != 0) minutes = _minutes + (pm ? -12 * 60 : 12 * 60);
    }
  }

  void _setColumn(int c) {
    _column = c.clamp(0, columns - 1);
    _typed = '';
    markNeedsPaint();
  }

  /// A key while the picker is open; true when it was used.
  bool handleKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final c = _column;
    void kb() => _keyboard = true;
    if (key == LogicalKeyboardKey.arrowLeft) {
      kb();
      _setColumn(c - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      kb();
      _setColumn(c + 1);
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      kb();
      _typed = '';
      step(c, key == LogicalKeyboardKey.arrowUp ? -1 : 1);
    } else if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown) {
      kb();
      _typed = '';
      step(c, (key == LogicalKeyboardKey.pageUp ? -1 : 1) * (c == 1 ? 5 : c == 0 ? 3 : 1));
    } else if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      kb();
      final end = key == LogicalKeyboardKey.end;
      switch (c) {
        case 0:
          minutes = use24h ? (end ? 23 : 0) * 60 + minute : (pm ? 12 : 0) * 60 + (end ? 11 : 0) * 60 + minute;
        case 1:
          minutes = hour * 60 + (end ? 59 : 0);
        default:
          if (pm != end) step(2, 1);
      }
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      onDone?.call(_minutes);
    } else if (!use24h && (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.keyP)) {
      kb();
      if (pm != (key == LogicalKeyboardKey.keyP)) step(2, 1);
    } else if (_digit(key) case final int d when c < 2) {
      kb();
      _type(c, d);
    } else {
      return false;
    }
    return true;
  }

  static int? _digit(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit0, LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, //
      LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad0, LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3, //
      LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5, LogicalKeyboardKey.numpad6, LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8, LogicalKeyboardKey.numpad9,
    ];
    final i = digits.indexOf(key);
    if (i >= 0) return i;
    final j = numpad.indexOf(key);
    return j >= 0 ? j : null;
  }

  /// Typing [d] into column [c]: two digits (or one that can't grow) set it
  /// and go on to the next column.
  void _type(int c, int d) {
    final max = c == 1 ? 59 : (use24h ? 23 : 12);
    var text = '$_typed$d';
    var v = int.parse(text);
    if (v > max) {
      text = '$d';
      v = d;
    }
    if (c == 0) {
      if (use24h) {
        minutes = v * 60 + minute;
      } else if (v >= 1) {
        minutes = (pm ? 12 : 0) * 60 + (v % 12) * 60 + minute;
      }
    } else {
      minutes = hour * 60 + v;
    }
    _typed = text;
    if (text.length == 2 || v * 10 > max) {
      _typed = '';
      if (c == 0) _setColumn(1);
    }
    markNeedsPaint();
  }

  // --- geometry -----------------------------------------------------------------

  double get _columnsTop => headerHeight + 4;
  double get _columnsHeight => visibleRows * rowHeight + (visibleRows - 1) * gap;
  double get _footerTop => _columnsTop + _columnsHeight + 8;

  /// Column [c]'s rect.
  Rect columnRect(int c) {
    const periodWidth = 56.0;
    final rest = size.width - (columns - 1) * 8 - (use24h ? 0 : periodWidth);
    final w = rest / 2;
    final left = c == 0 ? 0.0 : c == 1 ? w + 8 : 2 * w + 16;
    return Rect.fromLTWH(left, _columnsTop, c == 2 ? periodWidth : w, _columnsHeight);
  }

  /// The row of column [c] at [k] from its middle.
  Rect rowRect(int c, int k) {
    final col = columnRect(c);
    // AM / PM: two rows around the middle.
    final shift = c == 2 ? (pm ? .5 : -.5) : 0.0;
    final mid = col.top + (visibleRows ~/ 2 + shift + k) * (rowHeight + gap);
    return Rect.fromLTWH(col.left, mid, col.width, rowHeight);
  }

  /// The rows column [c] shows, as offsets from its middle.
  Iterable<int> _rows(int c) => c == 2 ? (pm ? const [-1, 0] : const [0, 1]) : const [-2, -1, 0, 1, 2];

  ({Rect cancel, Rect done}) get footerRects {
    final done = _buttonWidth('Done');
    final cancel = _buttonWidth('Cancel');
    final d = Rect.fromLTWH(size.width - done, _footerTop, done, footerHeight);
    return (cancel: Rect.fromLTWH(d.left - 6 - cancel, _footerTop, cancel, footerHeight), done: d);
  }

  double _buttonWidth(String label) {
    final p = pickerText(label, _colors.style(12, weight: FontWeight.w500));
    final w = p.width + 20;
    p.dispose();
    return w.ceilToDouble();
  }

  @override
  double computeMinIntrinsicWidth(double height) => width;
  @override
  double computeMaxIntrinsicWidth(double height) => width;
  @override
  double computeMinIntrinsicHeight(double width) => _footerTop + footerHeight;
  @override
  double computeMaxIntrinsicHeight(double width) => _footerTop + footerHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints
      .constrain(Size(constraints.hasBoundedWidth ? math.max(width, constraints.minWidth) : width, _footerTop + footerHeight));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  // --- pointer ------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => true;

  Object? _targetAt(Offset p) {
    final f = footerRects;
    if (f.done.contains(p)) return 'done';
    if (f.cancel.contains(p)) return 'cancel';
    for (var c = 0; c < columns; c++) {
      for (final k in _rows(c)) {
        if (rowRect(c, k).inflate(gap / 2).contains(p)) return (c, k);
      }
    }
    return null;
  }

  void _tapAt(Offset p) {
    final t = _targetAt(p);
    _keyboard = false;
    switch (t) {
      case 'done':
        onDone?.call(_minutes);
      case 'cancel':
        onCancel?.call();
      case (final int c, final int k):
        _column = c;
        _typed = '';
        step(c, k);
        markNeedsPaint();
    }
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) _tap.addPointer(event);
    if (event is PointerHoverEvent) {
      final t = _targetAt(entry.localPosition);
      if (t != _hovered) {
        _hovered = t;
        markNeedsPaint();
      }
    }
    if (event is PointerScrollEvent) {
      final local = entry.localPosition;
      for (var c = 0; c < columns; c++) {
        if (columnRect(c).contains(local) && event.scrollDelta.dy != 0) {
          GestureBinding.instance.pointerSignalResolver.register(event, (e) {
            _keyboard = false;
            step(c, (e as PointerScrollEvent).scrollDelta.dy > 0 ? 1 : -1);
          });
        }
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
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  // --- paint --------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final c = _colors;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final header = Rect.fromLTWH(0, 0, size.width, headerHeight);
    final line = title == null || title!.isEmpty ? display : '$title · $display';
    final h = pickerText(line, c.style(13, weight: FontWeight.w600).merge(c.headline?.copyWith(fontSize: 13)), maxWidth: size.width);
    paintCentered(canvas, h, header);
    h.dispose();
    for (var col = 0; col < columns; col++) {
      for (final k in _rows(col)) {
        final r = rowRect(col, k);
        final rr = RRect.fromRectAndRadius(r, Radius.circular(c.dayRadius));
        final chosen = k == 0;
        if (chosen) {
          canvas.drawRRect(rr, Paint()..color = c.accent);
        } else if (_hovered == (col, k)) {
          canvas.drawRRect(rr, Paint()..color = c.hover);
        }
        if (chosen && _keyboard && col == _column) {
          canvas.drawRRect(
              rr.inflate(.75),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = c.focus);
        }
        // Rows fade away from the middle.
        final ink = chosen ? c.onAccent : (k.abs() == 2 ? c.muted : c.text);
        final p = pickerText(_label(col, k), c.style(12.5, weight: chosen ? FontWeight.w600 : FontWeight.w400, color: ink));
        paintCentered(canvas, p, r);
        p.dispose();
      }
    }
    final f = footerRects;
    final cancel = RRect.fromRectAndRadius(f.cancel, Radius.circular(c.radius));
    if (_hovered == 'cancel') canvas.drawRRect(cancel, Paint()..color = c.hover);
    final cp = pickerText('Cancel', c.style(12, weight: FontWeight.w500));
    paintCentered(canvas, cp, f.cancel);
    cp.dispose();
    final done = RRect.fromRectAndRadius(f.done, Radius.circular(c.radius));
    canvas.drawRRect(done, Paint()..color = c.accent);
    if (_hovered == 'done') canvas.drawRRect(done, Paint()..color = const Color(0x14000000));
    final dp = pickerText('Done', c.style(12, weight: FontWeight.w500, color: c.onAccent));
    paintCentered(canvas, dp, f.done);
    dp.dispose();
    canvas.restore();
  }

  // --- semantics ----------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..label = display
      ..textDirection = TextDirection.ltr;
  }

  final Map<Object, SemanticsNode> _semantics = {};

  /// Each column an adjustable value (a screen reader's increase and
  /// decrease step it), then Cancel and Done.
  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    final out = <SemanticsNode>[];
    const names = ['Hour', 'Minute', 'AM or PM'];
    for (var c = 0; c < columns; c++) {
      final cfg = SemanticsConfiguration()
        ..label = names[c]
        ..value = _label(c, 0)
        ..increasedValue = _label(c, 1)
        ..decreasedValue = _label(c, -1)
        ..textDirection = TextDirection.ltr
        ..onIncrease = (() => step(c, 1))
        ..onDecrease = (() => step(c, -1));
      out.add(_semantics.putIfAbsent('c$c', SemanticsNode.new)
        ..rect = columnRect(c)
        ..updateWith(config: cfg));
    }
    final f = footerRects;
    for (final (key, rect, action) in [('Cancel', f.cancel, onCancel), ('Done', f.done, () => onDone?.call(_minutes))]) {
      final cfg = SemanticsConfiguration()
        ..isButton = true
        ..label = key
        ..isEnabled = true
        ..textDirection = TextDirection.ltr;
      if (action != null) cfg.onTap = action;
      out.add(_semantics.putIfAbsent(key, SemanticsNode.new)
        ..rect = rect
        ..updateWith(config: cfg));
    }
    node.updateWith(config: config, childrenInInversePaintOrder: out);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _semantics.clear();
  }
}
