// A graph's state and geometry: the rows, the x viewport, each pane's y
// domain (fitted to the rows in view, or set by hand) and the cursor. It
// draws nothing and reads no gesture: the widget turns gestures into its
// commands, and the panes draw what it works out.
//
// What the user does is published as JSON ([state]): `view` and `cursor`,
// for a page's variables to hold, as any control's value is.
import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size, TextDirection;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show FontWeight, TextPainter, TextSpan, TextStyle;
import 'package:intl/intl.dart' show DateFormat;

import 'graph_spec.dart';
import 'graph_transforms.dart';
import 'graph_viewport.dart';

enum GraphZoneKind { plot, yAxis, xAxis, none }

/// Where a point of the graph is: a pane's plot, its price axis, or the
/// time axis.
class GraphZone {
  const GraphZone(this.kind, [this.pane = -1]);
  final GraphZoneKind kind;
  final int pane;

  @override
  bool operator ==(Object other) => other is GraphZone && other.kind == kind && other.pane == pane;
  @override
  int get hashCode => Object.hash(kind, pane);
  @override
  String toString() => 'GraphZone(${kind.name}, $pane)';
}

/// The row and price under the pointer.
class GraphCursor {
  const GraphCursor({required this.index, required this.pane, required this.x, required this.y, required this.value, required this.row});

  final int index, pane;

  /// Where its lines cross, in the graph's own pixels.
  final double x, y;

  /// The price at [y] on [pane]'s scale (the magnet field's, when snapped).
  final double value;
  final Json row;
}

/// What is under a point: a row, and with a selection by mark the one bar
/// or slice of it.
class GraphHit {
  const GraphHit({required this.pane, required this.index, this.mark});

  final int pane, index;

  /// The mark's place in its pane; null for the whole row.
  final int? mark;

  @override
  bool operator ==(Object other) =>
      other is GraphHit && other.pane == pane && other.index == index && other.mark == mark;
  @override
  int get hashCode => Object.hash(pane, index, mark);
  @override
  String toString() => 'GraphHit(pane $pane, row $index, mark $mark)';
}

/// A slice of an arc mark: where it starts and how far it turns (radians,
/// clockwise from the top), without the gap beside it.
class GraphSlice {
  const GraphSlice(this.index, this.start, this.sweep, this.color);
  final int index;
  final double start, sweep;
  final Color color;
}

/// One key of a legend: a color, what it is called and (a slice's) its
/// share, and where it is drawn.
class GraphLegendKey {
  const GraphLegendKey(this.color, this.label, this.value, [this.box = Rect.zero]);
  final Color color;
  final String label, value;

  /// The key's box in the graph's own pixels: its dot at the left, its
  /// label after it, its value against the right edge.
  final Rect box;
}

/// A legend laid out: where it is, its keys, and the room it takes from
/// the panes.
class GraphLegendLayout {
  const GraphLegendLayout(this.position, this.keys, {this.top = 0, this.bottom = 0, this.right = 0});

  /// `top`, `bottom` or `right`.
  final String position;
  final List<GraphLegendKey> keys;

  /// The room taken above, under and right of the panes and their axes.
  final double top, bottom, right;

  /// A key's dot, and the room between it and the label.
  static const dot = 8.0, dotGap = 6.0;
}

class GraphEngine extends ChangeNotifier {
  GraphEngine(GraphSpec spec, {List<Json> data = const [], Json? view}) : _spec = spec {
    viewport = GraphViewport(barSpacing: spec.x.barSpacing, rightOffset: spec.x.rightOffset);
    _manual = List.filled(spec.panes.length, null);
    _source = data;
    rows = applyGraphTransforms(data, spec.transforms);
    if (view != null) applyView(view);
  }

  GraphSpec _spec;
  GraphSpec get spec => _spec;
  set spec(GraphSpec value) {
    _spec = value;
    if (_manual.length != value.panes.length) _manual = List.filled(value.panes.length, null);
    rows = applyGraphTransforms(_source, value.transforms);
    _changed();
  }

  List<Json> _source = const [];

  // A morph under way (GraphXSpec.morph): the line the graph showed, as
  // shares of the plot's width and height, and the rows it is going to.
  List<(double, double)>? _morphFrom;
  List<Json>? _target;
  bool get morphing => _target != null;

  /// The rows, with the transforms' fields and `_i`, each one's position.
  List<Json> rows = const [];
  int get count => rows.length;

  Size size = Size.zero;
  late GraphViewport viewport;

  /// A pane's y domain once set by hand; null while it is fitted.
  late List<(double, double)?> _manual;
  GraphCursor? cursor;

  /// Asked once each time the view comes within the spec's threshold of the
  /// first row: the page's action loads older rows and sets them as data.
  void Function(Json view)? onNeedHistory;
  bool _askedHistory = false;

  /// Older rows have been asked for and have not come yet.
  bool get loadingHistory => _askedHistory && spec.x.moreHistory;
  Json? _pendingView;

  // --- layout ----------------------------------------------------------------

  double get yAxisWidth => spec.panes.fold(0.0, (w, p) => math.max(w, p.y.width));
  double get plotWidth => math.max(0, bodyRight - yAxisWidth);
  double get _top => spec.style.topInset + (legend?.top ?? 0);
  double get _panesHeight => math.max(0, size.height - spec.x.axisHeight - _top - (legend?.bottom ?? 0));

  /// The right edge of the panes and their axes: the graph's, less a
  /// legend beside them.
  double get bodyRight => math.max(0, size.width - (legend?.right ?? 0));

  // --- the legend ------------------------------------------------------------

  /// What a legend would list: each slice of a polar pane (its color, its
  /// label and its share), else each named mark (an area and the line
  /// along its top once).
  List<GraphLegendKey> get legendKeys {
    final out = <GraphLegendKey>[];
    for (final p in spec.panes) {
      if (!p.polar) continue;
      final m = p.marks.where((m) => m.type == 'arc').firstOrNull;
      if (m == null) return out;
      final rows = _tweenTo ?? _target ?? this.rows;
      var total = 0.0;
      for (final r in rows) {
        if (r[m.y] case final num v when v.isFinite && v > 0) total += v;
      }
      for (var i = 0; i < rows.length; i++) {
        final label = rows[i][spec.x.label]?.toString() ?? '';
        if (label.isEmpty) continue;
        final v = rows[i][m.y];
        final share = v is num && v.isFinite && v > 0 && total > 0 ? '${(v / total * 100).round()}%' : '';
        out.add(GraphLegendKey(markColor(m, i), label, spec.legend.values ? share : ''));
      }
      return out;
    }
    final seen = <String>{};
    for (final p in spec.panes) {
      for (final m in p.marks) {
        if (m.name.isEmpty || m.overlay != null || m.type == 'candle' || m.byDirection) continue;
        if (seen.add(m.valueField)) out.add(GraphLegendKey(m.color, m.name, ''));
      }
    }
    return out;
  }

  /// The legend as drawn; null when the spec has none, there is nothing
  /// to tell apart, or it has no room.
  GraphLegendLayout? get legend {
    if (!_legendDone) {
      _legendDone = true;
      _legend = _layoutLegend();
    }
    return _legend;
  }

  GraphLegendLayout? _legend;
  bool _legendDone = false;

  double textWidth(String text, double fontSize, {FontWeight? weight}) => (TextPainter(
        text: TextSpan(
            text: text, style: TextStyle(fontSize: fontSize, fontFamily: spec.style.fontFamily, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;

  GraphLegendLayout? _layoutLegend() {
    final l = spec.legend;
    if (l.show == 'none' || size.isEmpty) return null;
    final keys = legendKeys;
    final polar = spec.panes.any((p) => p.polar);
    final auto = l.show != 'always';
    if (keys.isEmpty || (auto && !polar && keys.length < 2)) return null;
    final font = spec.style.fontSize + 1;
    final rowHeight = (font * 1.5).ceilToDouble();
    const mark = GraphLegendLayout.dot + GraphLegendLayout.dotGap, between = 16.0, rowGap = 4.0, room = 12.0;
    // A whole pixel more than each text measures: the painter lays the
    // texts out again, and none is to end in an ellipsis for a fraction.
    final labels = [for (final k in keys) textWidth(k.label, font).ceilToDouble() + 1];
    final values = [
      for (final k in keys) k.value.isEmpty ? 0.0 : textWidth(k.value, font, weight: FontWeight.w600).ceilToDouble() + 1,
    ];
    final widest = labels.fold(0.0, math.max), widestValue = values.fold(0.0, math.max);
    final listWidth = mark + widest + (widestValue > 0 ? 12 + widestValue : 0);
    final listHeight = keys.length * rowHeight + (keys.length - 1) * rowGap;
    final w = size.width, h = size.height;

    var position = l.position;
    if (position == 'auto') {
      // Beside slices while they keep at least three quarters of the
      // graph's height: slices in a narrower box keep all of it, and have
      // no legend unless the spec says one.
      final beside = polar && w - listWidth - 24 >= h * 0.75 && listHeight <= h;
      if (polar && !beside && auto) return null;
      position = beside ? 'right' : 'bottom';
    }
    if (position == 'right' || position == 'left') {
      // Slices keep a square at the left, the list right beside it; a
      // plot gives the list its width at the right edge.
      final double left, width;
      if (polar) {
        final side = math.min(h, math.max(0.0, w - listWidth - 24));
        left = side + 24;
        width = math.min(w - left, math.max(listWidth, math.min(240.0, listWidth + 40)));
      } else {
        width = math.min(listWidth, w * 0.4);
        left = w - width;
      }
      if (auto && (width < listWidth - 0.5 || listHeight > h)) return null;
      var y = polar ? math.max(0.0, (h - listHeight) / 2) : spec.style.topInset;
      final out = <GraphLegendKey>[];
      for (final k in keys) {
        out.add(GraphLegendKey(k.color, k.label, k.value, Rect.fromLTWH(left, y, width, rowHeight)));
        y += rowHeight + rowGap;
      }
      return GraphLegendLayout('right', out, right: w - left + (polar ? 24 : room));
    }
    // A line of keys in the middle, wrapped.
    final widths = [for (var i = 0; i < keys.length; i++) mark + labels[i] + (values[i] > 0 ? 6 + values[i] : 0)];
    final lines = <List<int>>[[]];
    var used = 0.0;
    for (var i = 0; i < keys.length; i++) {
      final next = used == 0 ? widths[i] : used + between + widths[i];
      if (next > w && lines.last.isNotEmpty) {
        lines.add([i]);
        used = widths[i];
      } else {
        lines.last.add(i);
        used = next;
      }
    }
    final height = lines.length * rowHeight + (lines.length - 1) * rowGap;
    // No room: the legend would take more of the graph than what it names.
    if (auto && height + room > h * (polar ? 0.45 : 0.35)) return null;
    final top = position == 'top';
    var y = top ? 0.0 : h - height;
    final out = <GraphLegendKey>[];
    for (final line in lines) {
      final total = line.fold(0.0, (a, i) => a + widths[i]) + between * (line.length - 1);
      var x = math.max(0.0, (w - total) / 2);
      for (final i in line) {
        out.add(GraphLegendKey(keys[i].color, keys[i].label, keys[i].value, Rect.fromLTWH(x, y, widths[i], rowHeight)));
        x += widths[i] + between;
      }
      y += rowHeight + rowGap;
    }
    return GraphLegendLayout(top ? 'top' : 'bottom', out, top: top ? height + room : 0, bottom: top ? 0 : height + room);
  }
  double get _panesBottom => _top + _panesHeight;

  /// A pane's plot.
  Rect plotRect(int pane) {
    final total = spec.panes.fold(0.0, (s, p) => s + p.grow);
    var top = _top;
    for (var i = 0; i < pane; i++) {
      top += _panesHeight * spec.panes[i].grow / total;
    }
    return Rect.fromLTWH(plotLeft, top, plotWidth, total == 0 ? 0 : _panesHeight * spec.panes[pane].grow / total);
  }

  /// Whether the y axis is left of the plots (any pane says so).
  bool get axisLeft => spec.panes.any((p) => p.y.side == 'left');

  /// The plots' left and right edges.
  double get plotLeft => axisLeft ? yAxisWidth : 0;
  double get plotRight => plotLeft + plotWidth;

  Rect yAxisRect(int pane) {
    final plot = plotRect(pane);
    return Rect.fromLTWH(axisLeft ? 0 : plot.right, plot.top, yAxisWidth, plot.height);
  }

  Rect get xAxisRect => Rect.fromLTWH(0, _panesBottom, bodyRight, spec.x.axisHeight);

  GraphZone zoneAt(Offset p) {
    if (p.dx > bodyRight || p.dy > _panesBottom + spec.x.axisHeight) return const GraphZone(GraphZoneKind.none);
    if (p.dy >= _panesBottom) return const GraphZone(GraphZoneKind.xAxis);
    for (var i = 0; i < spec.panes.length; i++) {
      final plot = plotRect(i);
      if (p.dy >= plot.top && p.dy < plot.bottom) {
        final inPlot = p.dx >= plot.left && p.dx < plot.right;
        return GraphZone(inPlot ? GraphZoneKind.plot : GraphZoneKind.yAxis, i);
      }
    }
    return const GraphZone(GraphZoneKind.none);
  }

  // --- x ---------------------------------------------------------------------

  /// Whether rows are placed by a number of theirs (GraphXSpec.scale), not
  /// one place each.
  bool get linear => spec.x.linear;

  /// A linear scale's stretch: the spec's, else the rows' least and most.
  (double, double) get _xDomain => _linearDomain ??= () {
        var lo = double.infinity, hi = double.negativeInfinity;
        for (final r in rows) {
          if (r[spec.x.field] case final num v when v.isFinite) {
            lo = math.min(lo, v.toDouble());
            hi = math.max(hi, v.toDouble());
          }
        }
        // Bars stand whole: half a row's room past the first and the last.
        var room = 0.0;
        if (spec.panes.any((p) => p.marks.any((m) => m.type == 'bar'))) {
          var least = double.infinity;
          for (var i = 1; i < rows.length; i++) {
            final p = rows[i - 1][spec.x.field], q = rows[i][spec.x.field];
            if (p is num && q is num && q != p) least = math.min(least, (q - p).abs().toDouble());
          }
          room = least.isFinite ? least / 2 : 0.5;
        }
        final a = spec.x.min ?? (lo.isFinite ? lo - room : 0), b = spec.x.max ?? (hi.isFinite ? hi + room : 1);
        return b > a ? (a, b) : (a, a + 1);
      }();
  (double, double)? _linearDomain;

  /// The positions at the plot's left and right edges: on a linear scale
  /// its whole stretch, or the part of it the user has moved to.
  double get from => linear ? (_linearView ?? _xDomain).$1 : viewport.from(count, plotWidth);
  double get to => linear ? (_linearView ?? _xDomain).$2 : viewport.to(count);
  (double, double)? _linearView;

  /// The first and last rows in view (on a linear scale with none in view,
  /// the last is before the first).
  (int, int) get visible {
    if (!linear) return viewport.visible(count, plotWidth);
    if (_linearView == null) return (0, count - 1);
    var first = count, last = -1;
    for (var i = 0; i < count; i++) {
      final p = pos(i);
      if (p >= from && p <= to) {
        if (i < first) first = i;
        last = i;
      }
    }
    return (first, last);
  }

  /// Sets the part of a linear scale in view, kept on the scale (unless
  /// the spec lets the view past it) and no closer than a thousandth of it.
  void _setLinear(double lo, double hi) {
    final (a, b) = _xDomain;
    var span = math.max(hi - lo, (b - a) / 1000);
    if (!spec.x.overscroll) {
      span = math.min(span, b - a);
      lo = lo.clamp(a, b - span).toDouble();
    }
    _linearView = (lo - a).abs() < 1e-12 && (span - (b - a)).abs() < 1e-12 ? null : (lo, lo + span);
    _changed();
  }

  /// Pixels a position apart.
  double get _spacing => linear ? plotWidth / (to - from) : viewport.barSpacing;

  /// A row's position: its place, or on a linear scale its number.
  double pos(int index) {
    if (!linear) return index.toDouble();
    final v = index >= 0 && index < count ? rows[index][spec.x.field] : null;
    return v is num ? v.toDouble() : double.nan;
  }

  /// A position's pixel.
  double xOf(num position) => plotLeft + (position - from) * _spacing;

  /// A row's pixel.
  double xOfRow(int index) => xOf(pos(index));

  /// The position under a pixel.
  double indexAt(double px) => from + (px - plotLeft) / _spacing;

  /// The row nearest a pixel (on rows, the place under it: it may be past
  /// either end).
  int rowAt(double px) {
    final at = indexAt(px);
    if (!linear) return at.round();
    var best = -1;
    var off = double.infinity;
    for (var i = 0; i < count; i++) {
      final d = (pos(i) - at).abs();
      if (d < off) {
        off = d;
        best = i;
      }
    }
    return best;
  }

  /// A place the spec names: a number on a linear scale, a row's key on
  /// rows. Null when it names none.
  double? place(Object? at) {
    if (at == null) return null;
    if (linear) return at is num ? at.toDouble() : null;
    return indexOfKey(at)?.toDouble();
  }

  /// A candle's or bar's width.
  double get barWidth => math.max(1, math.min(spec.x.maxBarWidth ?? double.infinity, (slotWidth * 0.72).floorToDouble()));

  /// The width of a row's bars standing side by side ([groups] of them,
  /// [gap] apart): each at most the widest a bar is drawn, all of them in
  /// their share of the row's place.
  double _groupWidth(int groups, double gap) => groups < 2
      ? barWidth
      : math.max(
          1,
          math.min((spec.x.maxBarWidth ?? double.infinity) * groups + gap * (groups - 1), (slotWidth * 0.72).floorToDouble()),
        );

  /// The room a row has: a place, or on a linear scale the least stretch
  /// between two rows next to one another.
  double get slotWidth {
    if (!linear) return viewport.barSpacing;
    var least = double.infinity;
    for (var i = 1; i < count; i++) {
      final d = (pos(i) - pos(i - 1)).abs();
      if (d > 0 && d < least) least = d;
    }
    return least.isFinite ? least * _spacing : plotWidth / 4;
  }

  /// The positions with a time label: every step-th row, the step the
  /// smallest round one whose labels stand 80 px apart.
  List<num> get xTicks => _ticks ??= _xTicks();
  List<num>? _ticks;

  // The calendar unit the ticks are at: 0 years, 1 months, 2 days, 3 hours.
  int _tickLevel = 1;

  /// A row's time: its label read as one, under a date pattern (an x scale
  /// with no format writes its labels as they are).
  DateTime? _rowTime(int index) => spec.x.format.isEmpty
      ? null
      : switch (rows[index][spec.x.label]) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
        final String s => DateTime.tryParse(s),
        _ => null,
      };

  /// A position's time: its row's, or past the last row (the rest of a
  /// session not over yet) the time it will have at the rows' own step.
  DateTime? _time(int index) {
    if (index < count) return _rowTime(index);
    if (count < 2) return null;
    final last = _rowTime(count - 1), before = _rowTime(count - 2);
    if (last == null || before == null) return null;
    return last.add(last.difference(before) * (index - (count - 1)));
  }

  int _bucket(DateTime t, int level) => switch (level) {
        0 => t.year,
        1 => t.year * 12 + t.month,
        2 => t.millisecondsSinceEpoch ~/ 86400000,
        _ => t.millisecondsSinceEpoch ~/ 3600000,
      };

  /// Calendar ticks: the rows that start an hour, a day, a month or a year,
  /// at the finest of those whose labels stand apart.
  List<num> _calendarTicks() {
    final (first, last) = visible;
    final most = plotWidth / 70;
    var ticks = const <num>[];
    for (var level = 3; level >= 0; level--) {
      _tickLevel = level;
      ticks = [
        for (var i = math.max(first, 1); i <= last; i++)
          if (_time(i) case final t? when _time(i - 1) != null && _bucket(t, level) != _bucket(_time(i - 1)!, level)) i,
      ];
      if (ticks.length <= most) {
        // A coarser unit that starts at the same rows names them better
        // (daily rows each start an hour, but they are days).
        for (var coarser = level - 1; coarser >= 0; coarser--) {
          final same = [
            for (var i = math.max(first, 1); i <= last; i++)
              if (_time(i) case final t?
                  when _time(i - 1) != null && _bucket(t, coarser) != _bucket(_time(i - 1)!, coarser))
                i,
          ];
          if (same.length != ticks.length) break;
          _tickLevel = coarser;
        }
        break;
      }
    }
    return ticks;
  }

  /// A tick's label: its own unit, or the larger one it also starts (a
  /// year at January, a month at its first day).
  String xTickLabel(int index) {
    if (spec.x.ticks != 'calendar') return xLabel(index);
    if (index < 0 || index >= count) return '';
    final t = _time(index);
    if (t == null) return xLabel(index);
    final before = index > 0 ? _time(index - 1) : null;
    bool starts(int level) => before != null && _bucket(t, level) != _bucket(before, level);
    final pattern = switch (_tickLevel) {
      0 => 'yyyy',
      1 => starts(0) ? 'yyyy' : 'MMM',
      2 => starts(1) ? 'MMM' : 'd',
      _ => starts(2) ? 'd' : 'HH:mm',
    };
    return xLabel(index, pattern);
  }

  List<num> _xTicks() {
    if (spec.x.tickValues.isNotEmpty) {
      return [
        for (final t in spec.x.tickValues)
          if (t.value >= from - 1e-9 && t.value <= to + 1e-9) t.value,
      ];
    }
    if (count == 0) return const [];
    if (linear) {
      final step = _niceStep((to - from) / math.max(1, plotWidth / 90));
      return [for (var k = (from / step - 1e-9).ceil(); k * step <= to + step * 1e-9; k++) k * step];
    }
    if (spec.x.ticks == 'calendar') return _calendarTicks();
    // A fitted view that names no step: the rows whose labels stand apart,
    // the first and the last among them.
    if (spec.x.fit != 'none' && spec.x.tickEvery == null) {
      final end = math.max(count, spec.x.slots ?? count) - 1;
      return [for (final l in _thin([for (var i = 0; i <= end; i++) i])) l.$1];
    }
    var step = spec.x.tickEvery ?? 1;
    if (spec.x.tickEvery == null) {
      for (final s in const [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000]) {
        step = s;
        if (s * viewport.barSpacing >= (spec.x.fit == 'none' ? 80 : 40)) break;
      }
    }
    // A fitted view labels the positions its rows have not reached yet.
    final end = spec.x.fit == 'none' ? count - 1 : math.max(count, spec.x.slots ?? count) - 1;
    final first = math.max(0, from.ceil()), last = math.min(end, to.floor());
    // A label hard against the left edge would be cut: it is left out. A
    // fitted view keeps it where it is whole (an axis left of the plot gives
    // it room) or the view keeps room at its ends (GraphXSpec.inset: the
    // painter then keeps the label inside the graph).
    bool whole(int i) {
      if (xOf(i) - plotLeft >= 16) return true;
      if (spec.x.fit == 'none') return false;
      return spec.x.inset > 0 || xOf(i) - textWidth(xTickLabel(i), spec.style.fontSize) / 2 >= 0;
    }

    return [
      for (var i = (first / step).ceil() * step; i <= last; i += step)
        if (whole(i)) i,
    ];
  }

  /// The x ticks whose labels are written, each with its text and where it
  /// starts: all of them where they stand apart, else every second, third…
  /// from the first, whichever is the most that do, and the last, which
  /// takes the place of one before it that it would run into. The first and
  /// the last are always written, and no two touch.
  List<(num, String, double)> get xLabels => _labels ??= _thin(xTicks);
  List<(num, String, double)>? _labels;

  /// Those of [ticks] whose labels are written (see [xLabels]).
  List<(num, String, double)> _thin(List<num> ticks) {
    const apart = 8.0;
    final size = spec.style.fontSize;
    // No more are measured than could ever stand apart (a label and its
    // room take 12 px at the least): of thousands of rows every n-th, and
    // the last.
    final most = math.max(2, (bodyRight / 12).floor());
    if (ticks.length > most) {
      final stride = (ticks.length / most).ceil();
      ticks = [for (var i = 0; i < ticks.length - 1; i += stride) ticks[i], ticks.last];
    }
    final all = <(num, String, double, double)>[];
    for (final t in ticks) {
      final x = xOf(t);
      if (x < plotLeft - 0.5 || x > plotRight + 0.5) continue;
      final label = xTickText(t);
      if (label.isEmpty) continue;
      final w = textWidth(label, size);
      final left = (x - w / 2).clamp(0.0, math.max(0.0, bodyRight - w)).toDouble();
      all.add((t, label, left, left + w));
    }
    final n = all.length;
    List<(num, String, double)> pick(Iterable<int> at) => [for (final i in at) (all[i].$1, all[i].$2, all[i].$3)];
    bool fits(List<int> at) {
      for (var i = 1; i < at.length; i++) {
        if (all[at[i]].$3 < all[at[i - 1]].$4 + apart) return false;
      }
      return true;
    }

    if (n < 2) return pick([for (var i = 0; i < n; i++) i]);
    for (var step = 1; step < n; step++) {
      final at = [for (var i = 0; i < n; i += step) i];
      if (!fits(at)) continue;
      if (at.last == n - 1) return pick(at);
      // The last, in place of those before it that it would run into.
      while (at.length > 1 && all[n - 1].$3 < all[at.last].$4 + apart) {
        at.removeLast();
      }
      at.add(n - 1);
      if (fits(at)) return pick(at);
    }
    return pick(fits([0, n - 1]) ? [0, n - 1] : [0]);
  }

  /// The round step (1, 2 or 5 times a power of ten) that cuts [span] into
  /// the number of parts nearest [parts]; of two as near, the larger.
  double _evenStep(double span, int parts) {
    if (!(span > 0) || !span.isFinite || parts <= 0) return 1;
    final mag = math.pow(10, (math.log(span / parts) / math.ln10).floor()).toDouble();
    var best = mag, off = double.infinity;
    for (final m in const [1, 2, 5, 10]) {
      final step = m * mag;
      final d = ((span / step - 1e-9).ceil() - parts).abs().toDouble();
      if (d <= off) {
        off = d;
        best = step;
      }
    }
    return best;
  }

  /// A round step no smaller than [raw]: 1, 2 or 5 times a power of ten.
  double _niceStep(double raw) {
    if (!(raw > 0) || !raw.isFinite) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    return [1, 2, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw * 0.999);
  }

  String _number(num v) {
    final r = v.roundToDouble();
    if ((v - r).abs() < 1e-9) return r.toInt().toString();
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// What is written at an x tick: the spec's label for it, the row's
  /// label, or on a linear scale the number.
  String xTickText(num position) {
    for (final t in spec.x.tickValues) {
      if ((t.value - position).abs() < 1e-9 && t.label != null) return t.label!;
    }
    return linear ? _number(position) : xTickLabel(position.round());
  }

  final _formats = <String, DateFormat>{};

  String xLabel(int index, [String? format]) {
    if (index < 0) return '';
    final time = _time(index);
    if (time == null) return index < count ? rows[index][spec.x.label]?.toString() ?? '' : '';
    final pattern = format ?? spec.x.format;
    return (_formats[pattern] ??= DateFormat(pattern)).format(time);
  }

  // --- y ---------------------------------------------------------------------

  final _domains = <int, (double, double)>{};

  /// Whether a pane's y is fitted (not set by hand).
  bool yAuto(int pane) => _manual[pane] == null;

  /// A pane's y domain.
  (double, double) yDomain(int pane) => _manual[pane] ?? (_domains[pane] ??= _fit(pane));

  (double, double) _fit(int pane) {
    final p = spec.panes[pane], y = p.y;
    if (y.domain == 'fixed' && y.min != null && y.max != null) return (y.min!, y.max!);
    final (first, last) = y.domain == 'data' ? (0, count - 1) : visible;
    // A morph is drawn on the scale of where it is going.
    final rows = _target ?? _tweenTo ?? this.rows;
    var lo = double.infinity, hi = double.negativeInfinity;
    void take(double? v) {
      if (v == null || !v.isFinite) return;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }

    var fromZero = false;
    // A stack reaches the sum of its bars.
    for (final group in barGroups(pane)) {
      if (group.length < 2) continue;
      for (var i = first; i <= last; i++) {
        var sum = 0.0;
        for (final g in group) {
          if (rows[i][p.marks[g].y] case final num v when v.isFinite) sum += v;
        }
        take(sum);
      }
    }
    for (final m in p.marks) {
      if (m.overlay != null || m.type == 'arc') continue;
      if (m.type == 'bar') {
        fromZero = true;
        take(0);
      }
      for (final f in m.extentFields) {
        for (var i = first; i <= last; i++) {
          final v = rows[i][f];
          if (v is num) take(v.toDouble());
        }
      }
    }
    y.include.forEach(take);
    if (!lo.isFinite || !hi.isFinite) return (0, 1);
    if (hi == lo) {
      // Bars with nothing to show yet stand on zero all the same.
      if (y.nice && fromZero && lo == 0) return (0, 1);
      final pad = lo == 0 ? 1.0 : lo.abs() * 0.01;
      return (lo - pad, hi + pad);
    }
    if (y.nice && y.tickValues.isEmpty && y.ticks > 0) {
      // Out to the ticks: the step is chosen again for the wider stretch
      // until it holds.
      var a = lo, b = hi;
      for (var k = 0; k < 4; k++) {
        final step = _evenStep(b - a, y.ticks);
        final na = (lo / step + 1e-9).floor() * step, nb = (hi / step - 1e-9).ceil() * step;
        if (na == a && nb == b) break;
        a = na;
        b = nb;
      }
      return (a, b > a ? b : a + 1);
    }
    final span = hi - lo;
    // Bars stand on zero: no room under it.
    return (fromZero && lo == 0 ? 0 : lo - span * y.marginBottom, hi + span * y.marginTop);
  }

  /// The domain of a mark on a scale of its own (GraphMarkSpec.overlay): from
  /// zero, its largest value in view at the top of its share of the pane.
  (double, double) overlayDomain(int pane, GraphMarkSpec mark) {
    final (first, last) = visible;
    var hi = 0.0;
    for (var i = first; i <= last; i++) {
      if (rows[i][mark.valueField] case final num v when v.isFinite) hi = math.max(hi, v.toDouble());
    }
    return (0, (hi == 0 ? 1 : hi) / mark.overlay!.clamp(0.01, 1));
  }

  /// The band a position is in; null for none.
  GraphBandSpec? bandAt(num index) {
    final bands = spec.x.bands;
    for (final b in bands) {
      // A band ends where the next starts; the last holds its own end.
      if (index >= b.from && (index < b.to || (identical(b, bands.last) && index <= b.to))) return b;
    }
    return null;
  }

  /// The band in use: the cursor's, else the last row's.
  String? get activeBand => count == 0 ? null : bandAt(cursor?.index ?? count - 1)?.id;

  /// The group of the band in use.
  String? get activeGroup => count == 0 ? null : bandAt(cursor?.index ?? count - 1)?.group;

  /// The mark the crosshair snaps to (the first with the magnet field).
  GraphMarkSpec? get magnetMark {
    final magnet = spec.crosshair.magnet;
    if (magnet.isEmpty) return null;
    for (final p in spec.panes) {
      for (final m in p.marks) {
        if (m.fields.contains(magnet)) return m;
      }
    }
    return null;
  }

  double yOf(int pane, double value) {
    final plot = plotRect(pane);
    final (lo, hi) = yDomain(pane);
    return plot.bottom - (value - lo) / (hi - lo) * plot.height;
  }

  double valueAt(int pane, double py) {
    final plot = plotRect(pane);
    final (lo, hi) = yDomain(pane);
    return lo + (plot.bottom - py) / plot.height * (hi - lo);
  }

  /// The value a percent scale measures from: the first row in view's close
  /// (or y) of the pane's first mark.
  double? percentBase(int pane) {
    final marks = spec.panes[pane].marks;
    if (marks.isEmpty) return null;
    final field = marks.first.type == 'candle' ? marks.first.close : marks.first.y;
    final (first, last) = visible;
    for (var i = first; i <= last; i++) {
      if (rows[i][field] case final num v when v != 0) return v.toDouble();
    }
    return null;
  }

  /// A pane's y ticks: round values about five apart (a percent scale's:
  /// round percents).
  List<num> yTicks(int pane) {
    final y = spec.panes[pane].y;
    final base = y.mode == 'percent' ? percentBase(pane) : null;
    final (lo, hi) = yDomain(pane);
    if (y.tickValues.isNotEmpty) {
      return [
        for (final t in y.tickValues)
          if (t.value >= lo - 1e-9 && t.value <= hi + 1e-9) t.value,
      ];
    }
    if (base == null) {
      final span = hi - lo;
      if (!(span > 0) || !span.isFinite || y.ticks <= 0) return const [];
      final step = y.nice ? _evenStep(span, y.ticks) : _niceStep(span / y.ticks);
      // Whole steps, so a tick is 0.3 and never 0.30000000000000004.
      return [for (var k = (lo / step - 1e-9).ceil(); k * step <= hi + step * 1e-9; k++) k * step];
    }
    final a = (lo / base - 1) * 100, b = (hi / base - 1) * 100;
    final raw = (b - a) / 5, mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [1, 2, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw);
    return [for (var p = (a / step).ceil() * step; p <= b; p += step) base * (1 + p / 100)];
  }

  String yLabel(int pane, num value) {
    final y = spec.panes[pane].y;
    for (final t in y.tickValues) {
      if ((t.value - value).abs() < 1e-9 && t.label != null) return t.label!;
    }
    return '${y.prefix}${_yNumber(pane, value)}${y.suffix}';
  }

  String _yNumber(int pane, num value) {
    final y = spec.panes[pane].y;
    if (y.mode == 'percent') {
      final base = percentBase(pane);
      if (base != null) {
        final pct = (value / base - 1) * 100;
        return '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(pct.abs() < 10 ? 1 : 0)}%';
      }
    }
    final a = value.abs();
    // On a scale rounded out to its ticks, a large value in few
    // characters: 20K, 1.5M.
    if (y.nice && a >= 1e4) {
      String short(num n, String unit) {
        final s = n.toStringAsFixed(n.abs() >= 100 ? 0 : (n.abs() >= 10 ? 1 : 2));
        return '${s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s}$unit';
      }

      return a >= 1e9 ? short(value / 1e9, 'B') : (a >= 1e6 ? short(value / 1e6, 'M') : short(value / 1e3, 'K'));
    }
    if (a >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (a >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (a >= 1e5) return '${(value / 1e3).toStringAsFixed(0)}K';
    // On a scale rounded out to its ticks, as many decimals as its step
    // has: ticks of 0.5 are never written 0, 1, 1, 2.
    var decimals = y.decimals;
    if (y.nice && y.tickValues.isEmpty) {
      final (lo, hi) = yDomain(pane);
      final step = _evenStep(hi - lo, y.ticks);
      while (decimals < 6 && (step * math.pow(10, decimals)).roundToDouble() != _trim(step * math.pow(10, decimals))) {
        decimals++;
      }
    }
    return value.toStringAsFixed(decimals);
  }

  double _trim(double v) => (v * 1e6).roundToDouble() / 1e6;

  Map<Object?, int>? _keys;

  /// The position of the row with this key; null for none.
  int? indexOfKey(Object? key) =>
      (_keys ??= {for (var i = 0; i < count; i++) rows[i][spec.key]: i})[key];

  /// A price line's value: its own, or its field in the last row.
  double? priceLineValue(GraphPriceLineSpec line) {
    if (line.value != null) return line.value;
    if (count == 0) return null;
    final v = rows.last[line.field];
    return v is num ? v.toDouble() : null;
  }

  // --- commands --------------------------------------------------------------

  void resize(Size value) {
    if (value == size) return;
    size = value;
    if (_pendingView != null) {
      final v = _pendingView!;
      _pendingView = null;
      applyView(v, notify: false);
    }
    _settle();
  }

  /// New rows. Told apart by the spec's key: rows after the last one known
  /// are followed (a view at the end) or left off screen (a view back in
  /// history); older rows put before move nothing; a row with a known key is
  /// an update in place.
  ///
  /// With [tween] (and a spec that animates), the marks move from the
  /// values on screen to the new ones as [tweenTo] is turned from 0 to 1,
  /// rows told apart by the spec's key (a row not there before grows from
  /// zero).
  void setData(List<Json> data, {bool tween = false}) {
    final key = spec.key;
    final lastKey = count == 0 ? null : rows.last[key];
    final firstKey = count == 0 ? null : rows.first[key];
    final before = tween && spec.animate > 0 && plotWidth > 0 ? {for (final r in rows) r[key]: r} : null;
    _tweenFrom = _tweenTo = null;
    _source = data;
    rows = applyGraphTransforms(data, spec.transforms);
    if (lastKey != null) {
      final at = rows.lastIndexWhere((r) => r[key] == lastKey);
      if (at < 0) {
        viewport = GraphViewport(barSpacing: spec.x.barSpacing, rightOffset: spec.x.rightOffset);
      } else {
        viewport = viewport.afterAppend(count - 1 - at, follow: spec.x.follow == 'end');
      }
    }
    // Older rows have come (or the rows are other rows altogether): the
    // graph may ask again. A new row at the end answers nothing, so a
    // request under way is not sent twice.
    if (count == 0 || rows.first[key] != firstKey) _askedHistory = false;
    if (_morphFrom != null && count > 0 && plotWidth > 0) {
      _target = rows;
      _settle();
      morphTo(0);
      return;
    }
    _morphFrom = null;
    if (before != null && count > 0) {
      _tweenFrom = before;
      _tweenTo = rows;
      _settle();
      tweenTo(0);
      return;
    }
    _settle();
  }

  // A tween under way (GraphSpec.animate): the rows the graph showed, by
  // key, and the rows it is going to.
  Map<Object?, Json>? _tweenFrom;
  List<Json>? _tweenTo;
  bool get tweening => _tweenTo != null;

  /// Starts the marks from zero (GraphSpec.animateIn): [tweenTo] turned from
  /// 0 to 1 grows them to their values.
  void enter() {
    if (count == 0 || morphing) return;
    _tweenFrom = const {};
    _tweenTo = _tweenTo ?? rows;
    tweenTo(0);
  }

  /// The row fields the marks draw.
  Set<String> get _markFields => {
        for (final p in spec.panes)
          for (final m in p.marks) ...m.fields.where((f) => f.isNotEmpty),
      };

  /// A tween's progress, 0 to 1: each mark's value between what it was and
  /// what it is, on the scale of where it is going.
  void tweenTo(double t) {
    final to = _tweenTo, from = _tweenFrom;
    if (to == null || from == null) return;
    if (t >= 1) {
      rows = to;
      _tweenFrom = _tweenTo = null;
      _changed();
      return;
    }
    final fields = _markFields;
    final key = spec.key;
    rows = [
      for (final r in to)
        {
          ...r,
          for (final f in fields)
            if (r[f] case final num now when now.isFinite)
              f: () {
                final was = from[r[key]]?[f];
                final a = was is num && was.isFinite ? was.toDouble() : 0.0;
                return a + (now - a) * t;
              }(),
        },
    ];
    _changed();
  }

  /// The mark a morph moves: the crosshair's, else the first.
  (int, GraphMarkSpec)? get _morphMark {
    final magnet = magnetMark;
    for (var p = 0; p < spec.panes.length; p++) {
      for (final m in spec.panes[p].marks) {
        if (magnet == null || identical(m, magnet)) return (p, m);
      }
    }
    return null;
  }

  /// Remembers the line on screen, before new rows (and a new spec) are
  /// set: the next [setData] starts from it instead of jumping.
  void captureMorph() {
    _morphFrom = null;
    final mark = _morphMark;
    if (spec.x.morph <= 0 || mark == null || count == 0 || plotWidth <= 0 || morphing) return;
    final (pane, m) = mark;
    final (lo, hi) = yDomain(pane);
    _morphFrom = [
      for (var i = 0; i < count; i++)
        if (rows[i][m.valueField] case final num v) ((xOfRow(i) - plotLeft) / plotWidth, (v - lo) / (hi - lo)),
    ];
    if (_morphFrom!.isEmpty) _morphFrom = null;
  }

  double _morphHeightAt(double share) {
    final from = _morphFrom!;
    if (share <= from.first.$1) return from.first.$2;
    for (var i = 1; i < from.length; i++) {
      final (b, bh) = from[i];
      if (share <= b) {
        final (a, ah) = from[i - 1];
        return b == a ? bh : ah + (bh - ah) * (share - a) / (b - a);
      }
    }
    return from.last.$2;
  }

  /// A morph's progress, 0 to 1: each point of the new line is drawn
  /// between where the old line was above it and where it belongs.
  void morphTo(double t) {
    final target = _target, mark = _morphMark;
    if (target == null) return;
    if (t >= 1 || mark == null || _morphFrom == null) {
      rows = target;
      _target = null;
      _morphFrom = null;
      _changed();
      return;
    }
    final (pane, m) = mark;
    _domains.clear();
    final (lo, hi) = yDomain(pane);
    rows = [
      for (var i = 0; i < target.length; i++)
        if (target[i][m.valueField] case final num v)
          {
            ...target[i],
            m.valueField: () {
              final was = _morphHeightAt((xOfRow(i) - plotLeft) / plotWidth), now = (v - lo) / (hi - lo);
              return lo + (was + (now - was) * t) * (hi - lo);
            }(),
          }
        else
          target[i],
    ];
    _changed();
  }

  void panBy(double dx) =>
      linear ? _setLinear(from - dx / _spacing, to - dx / _spacing) : _setViewport(viewport.pan(dx));

  /// [px] is from the plot's left.
  void zoomAt(double px, double factor) {
    if (linear) {
      // The position under the pointer stays under it.
      final at = indexAt(px), lo = at - (at - from) / factor;
      return _setLinear(lo, lo + (to - from) / factor);
    }
    _setViewport(
        viewport.zoomAt(px - plotLeft, factor, plotWidth, min: spec.x.minBarSpacing, max: spec.x.maxBarSpacing));
  }

  void resetX() {
    if (linear) {
      _linearView = null;
      return _changed();
    }
    _setViewport(GraphViewport(barSpacing: spec.x.barSpacing, rightOffset: spec.x.rightOffset));
  }

  /// Scales a pane's y about its middle: autoscale goes off.
  void scaleY(int pane, double factor) {
    final (lo, hi) = yDomain(pane);
    final mid = (lo + hi) / 2, half = (hi - lo) / 2 * factor;
    _manual[pane] = (mid - half, mid + half);
    _changed();
  }

  /// Moves a pane's y by [dy] pixels, once it is set by hand.
  void panY(int pane, double dy) {
    if (yAuto(pane)) return;
    final (lo, hi) = yDomain(pane);
    final d = dy / plotRect(pane).height * (hi - lo);
    _manual[pane] = (lo + d, hi + d);
    _changed();
  }

  /// Fits a pane's y again.
  void resetY(int pane) {
    _manual[pane] = null;
    _changed();
  }

  /// The pointer at [p] (null: away). The cursor is the row under it, at the
  /// magnet field's price when the spec names one.
  void setCursor(Offset? p) {
    final before = cursor;
    cursor = p == null ? null : _cursorAt(p);
    if (before?.index != cursor?.index || before?.y != cursor?.y || before?.pane != cursor?.pane) notifyListeners();
  }

  Offset? _pointer;

  GraphCursor? _cursorAt(Offset p) {
    _pointer = p;
    if (count == 0 || !spec.crosshair.enabled || p.dx < plotLeft || p.dx > plotRight) return null;
    final index = rowAt(p.dx).clamp(0, count - 1);
    final row = rows[index];
    final zone = zoneAt(p);
    var pane = zone.pane < 0 ? spec.panes.length - 1 : zone.pane;
    var y = p.dy.clamp(_top, _panesBottom);
    final magnet = spec.crosshair.magnet;
    if (magnet.isNotEmpty) {
      final home = spec.panes.indexWhere((s) => s.marks.any((m) => m.fields.contains(magnet)));
      if (row[magnet] case final num v when home >= 0) {
        pane = home;
        y = yOf(home, v.toDouble());
      }
    }
    return GraphCursor(index: index, pane: pane, x: xOfRow(index), y: y, value: valueAt(pane, y), row: row);
  }

  /// Sets the view from state: `{barSpacing, rightOffset}`, or `{last: n}`
  /// for the last n rows across the plot.
  void applyView(Json view, {bool notify = true}) {
    if (linear) {
      // `{from, to}`: a stretch of the scale.
      final lo = view['from'], hi = view['to'];
      if (lo is num && hi is num && hi > lo) _setLinear(lo.toDouble(), hi.toDouble());
      return;
    }
    if (view['last'] case final num n) {
      if (plotWidth <= 0) {
        _pendingView = view;
        return;
      }
      viewport = GraphViewport.showLast(n.toInt(), plotWidth, rightOffset: spec.x.rightOffset);
    } else {
      viewport = GraphViewport(
        barSpacing: (view['barSpacing'] as num?)?.toDouble() ?? viewport.barSpacing,
        rightOffset: (view['rightOffset'] as num?)?.toDouble() ?? viewport.rightOffset,
      );
    }
    if (notify) _settle();
  }

  void _setViewport(GraphViewport next) {
    viewport = next;
    _settle();
  }

  void _settle() {
    final fit = spec.x.fit;
    if (linear) {
      // The rows may have moved the scale's ends: the view stays on it.
      if (_linearView case (final lo, final hi)) {
        _linearDomain = null;
        final (a, b) = _xDomain;
        final span = math.min(hi - lo, b - a);
        final at = spec.x.overscroll ? lo : lo.clamp(a, b - span).toDouble();
        _linearView = (at, at + span);
      }
    } else if (fit != 'none' && plotWidth > 0 && count > 0) {
      // Every position across the plot: the view is not the user's.
      final slots = math.max(2, math.max(spec.x.slots ?? count, count));
      // The room kept clear at each end, never more than a quarter of the
      // plot.
      final inset = spec.x.inset.clamp(0.0, plotWidth / 4).toDouble();
      final across = plotWidth - inset * 2;
      if (fit == 'points') {
        final spacing = across / (slots - 1);
        viewport = GraphViewport(barSpacing: spacing, rightOffset: slots - count - 0.5 + inset / spacing);
      } else {
        final spacing = across / slots;
        viewport = GraphViewport(barSpacing: spacing, rightOffset: slots - count + inset / spacing);
      }
    } else if (!spec.x.overscroll && plotWidth > 0 && count > 0) {
      // The view never shows a stretch with no rows: zooming out stops when
      // the rows there are fill the plot, and panning stops at the first
      // row and at the last (with the spec's room right of it).
      final room = math.max(0.0, spec.x.rightOffset);
      final spacing = math.max(viewport.barSpacing, plotWidth / (count + room));
      final least = math.min(plotWidth / spacing - count, room);
      viewport = GraphViewport(barSpacing: spacing, rightOffset: viewport.rightOffset.clamp(least, room));
    } else if (spec.x.clamp) {
      viewport = viewport.clamp(count, plotWidth);
    }
    _changed();
    if (!_askedHistory && !linear && spec.x.moreHistory && count > 0 && plotWidth > 0 && from < spec.x.historyThreshold) {
      _askedHistory = true;
      onNeedHistory?.call(viewState);
    }
  }

  void _changed() {
    _domains.clear();
    _legendDone = false;
    _labels = null;
    _ticks = null;
    _keys = null;
    _linearDomain = null;
    // The pointer has not moved, the rows under it have.
    if (cursor != null && _pointer != null) cursor = _cursorAt(_pointer!);
    if (_hoverAt != null) _hover = hitAt(_hoverAt!);
    if (_pinned != null && _pinned!.index >= count) _pinned = null;
    notifyListeners();
  }

  // --- bars, slices and the selection -------------------------------------

  /// A pane's bars by their place in the row: marks with the same stack are
  /// one group (one on another), every other bar a group of its own. The
  /// numbers are the marks' places in the pane. Overlay bars (volume under
  /// a price) are not grouped: each is drawn across the row.
  List<List<int>> barGroups(int pane) {
    final marks = spec.panes[pane].marks;
    final groups = <List<int>>[];
    final byStack = <String, List<int>>{};
    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      if (m.type != 'bar' || m.overlay != null) continue;
      final stack = m.stack;
      if (stack == null) {
        groups.add([i]);
      } else if (byStack[stack] case final list?) {
        list.add(i);
      } else {
        groups.add(byStack[stack] = [i]);
      }
    }
    return groups;
  }

  /// A row's bars on a pane: each drawn mark's place and its box, in the
  /// graph's own pixels.
  List<(int, Rect)> barRects(int pane, int index) {
    final marks = spec.panes[pane].marks;
    final row = rows[index];
    final out = <(int, Rect)>[];
    final center = xOfRow(index);
    final plot = plotRect(pane);
    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      if (m.type != 'bar' || m.overlay == null) continue;
      if (row[m.y] case final num v when v.isFinite) {
        final (_, hi) = overlayDomain(pane, m);
        final h = v / hi * plot.height;
        out.add((i, Rect.fromLTRB(center - barWidth / 2, plot.bottom - h, center + barWidth / 2, plot.bottom)));
      }
    }
    final groups = barGroups(pane);
    if (groups.isEmpty) return out;
    final gap = groups.length > 1 ? math.min(2.0, barWidth / (groups.length * 4)) : 0.0;
    final all = _groupWidth(groups.length, gap);
    final w = (all - gap * (groups.length - 1)) / groups.length;
    final zero = yOf(pane, 0);
    for (var g = 0; g < groups.length; g++) {
      final left = center - all / 2 + g * (w + gap);
      var up = 0.0, down = 0.0;
      for (final i in groups[g]) {
        if (row[marks[i].y] case final num v when v.isFinite && v != 0) {
          final a = v > 0 ? up : down;
          final b = a + v;
          if (v > 0) {
            up = b;
          } else {
            down = b;
          }
          final ya = yOf(pane, a), yb = yOf(pane, b);
          final r = Rect.fromLTRB(left, math.min(ya, yb), left + w, math.max(ya, yb));
          // A bar too thin to see still shows where it is.
          out.add((i, r.height < 1 ? Rect.fromLTRB(r.left, zero - 1, r.right, zero) : r));
        }
      }
    }
    return out;
  }

  /// A row's color for a mark: its own field's, the mark's list's, or the
  /// mark's.
  Color markColor(GraphMarkSpec m, int index) {
    if (m.colorField.isNotEmpty && index < count) {
      if (rows[index][m.colorField] case final String s) return graphColor(s, m.color);
    }
    if (m.colors.isNotEmpty) return m.colors[index % m.colors.length];
    return m.color;
  }

  /// An arc mark's circle on its pane: center, outer radius and the hole's.
  (Offset, double, double) arcGeometry(int pane, GraphMarkSpec m) {
    final plot = plotRect(pane);
    final box = Rect.fromLTWH(plot.left, plot.top, plot.width + yAxisWidth, plot.height);
    final room = spec.selection.on == 'none' ? 0.0 : spec.selection.grow;
    final outer = math.max(0.0, math.min(box.width, box.height) / 2 - room);
    return (box.center, outer, outer * m.inner.clamp(0.0, 0.98));
  }

  /// An arc mark's slices: each row's share of the turn (a negative or
  /// missing value has none).
  List<GraphSlice> slices(GraphMarkSpec m) {
    final values = [
      for (final r in rows)
        if (r[m.y] case final num v when v.isFinite && v > 0) v.toDouble() else 0.0,
    ];
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const [];
    final gap = values.where((v) => v > 0).length > 1 ? m.gap * math.pi / 180 : 0.0;
    var at = m.startAngle * math.pi / 180;
    final out = <GraphSlice>[];
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      if (sweep > gap) out.add(GraphSlice(i, at + gap / 2, sweep - gap, markColor(m, i)));
      at += sweep;
    }
    return out;
  }

  /// What is under [p]; null for nothing.
  GraphHit? hitAt(Offset p) {
    if (count == 0) return null;
    final byMark = spec.selection.by == 'mark';
    for (var pane = 0; pane < spec.panes.length; pane++) {
      final s = spec.panes[pane];
      final plot = plotRect(pane);
      if (p.dy < plot.top || p.dy >= plot.bottom) continue;
      if (s.polar) {
        for (var k = 0; k < s.marks.length; k++) {
          final m = s.marks[k];
          if (m.type != 'arc') continue;
          final (center, outer, inner) = arcGeometry(pane, m);
          final d = p - center;
          if (d.distance > outer + spec.selection.grow || d.distance < inner) continue;
          // Clockwise from the top.
          final angle = math.atan2(d.dx, -d.dy);
          for (final slice in slices(m)) {
            final turned = (angle - slice.start) % (2 * math.pi);
            if (turned <= slice.sweep) return GraphHit(pane: pane, index: slice.index, mark: k);
          }
        }
        return null;
      }
      if (p.dx < plot.left || p.dx > plot.right) return null;
      final index = rowAt(p.dx);
      if (index < 0 || index >= count) return null;
      if (!byMark) return GraphHit(pane: pane, index: index);
      (int, double)? best;
      for (final (k, r) in barRects(pane, index)) {
        if (p.dx < r.left || p.dx > r.right) continue;
        final off = p.dy < r.top ? r.top - p.dy : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
        if (best == null || off < best.$2) best = (k, off);
      }
      return best == null ? null : GraphHit(pane: pane, index: index, mark: best.$1);
    }
    return null;
  }

  GraphHit? _hover, _pinned;
  Offset? _hoverAt;

  /// Where the pointer is while it selects; null once it left.
  Offset? get pointer => _hover == null ? null : _hoverAt;

  /// What is selected: under the pointer, else pinned by a tap.
  GraphHit? get selection => _hover ?? _pinned;
  bool get pinned => _pinned != null;

  /// The pointer is at [p] (null: it left).
  void hover(Offset? p) {
    _hoverAt = spec.selection.hover ? p : null;
    final next = _hoverAt == null ? null : hitAt(_hoverAt!);
    if (next == _hover) return;
    _hover = next;
    notifyListeners();
  }

  /// A tap at [p]: it pins what is there; on what is pinned, or on nothing,
  /// it lets go.
  void tap(Offset p) {
    if (!spec.selection.tap) return;
    final hit = hitAt(p);
    final next = hit == _pinned ? null : hit;
    if (next == _pinned) return;
    _pinned = next;
    notifyListeners();
  }

  /// Sets the pinned selection from state: `{index}` or `{index, mark}`
  /// (the mark's place in its pane); null lets go.
  void select(Json? value) {
    GraphHit? next;
    if (value?['index'] case final num i when i >= 0 && i < count) {
      final pane = ((value?['pane'] as num?)?.toInt() ?? 0).clamp(0, spec.panes.length - 1);
      next = GraphHit(pane: pane, index: i.toInt(), mark: (value?['mark'] as num?)?.toInt());
    }
    if (next == _pinned) return;
    _pinned = next;
    notifyListeners();
  }

  /// How much of itself a row's mark shows: all of it, or the selection's
  /// dim while another is selected.
  double emphasis(int pane, int mark, int index) {
    final sel = selection;
    if (sel == null) return 1;
    final on = sel.index == index && (sel.mark == null || (sel.pane == pane && sel.mark == mark));
    return on ? 1 : spec.selection.dim.clamp(0.0, 1.0);
  }

  /// The marks a tooltip lists for the selection: color, name and value.
  List<(Color, String, double)> selectionRows() {
    final sel = selection;
    if (sel == null || sel.index >= count) return const [];
    final row = rows[sel.index];
    final out = <(Color, String, double)>[];
    var named = false;
    final seen = <(int, String)>{};
    for (var p = 0; p < spec.panes.length; p++) {
      final marks = spec.panes[p].marks;
      for (var k = 0; k < marks.length; k++) {
        if (sel.mark != null && (sel.pane != p || sel.mark != k)) continue;
        final m = marks[k];
        // An area and the line along its top are one thing to read: the line.
        if (sel.mark == null && m.type == 'area' && marks.any((o) => o.type == 'line' && o.valueField == m.valueField)) continue;
        if (sel.mark == null && !seen.add((p, m.valueField))) continue;
        if (row[m.valueField] case final num v when v.isFinite) {
          out.add((markColor(m, sel.index), m.label, v.toDouble()));
          named = named || m.name.isNotEmpty;
        }
      }
    }
    // One mark with no name: its value needs no name beside it (its field
    // is no word to read).
    if (out.length == 1 && !named) return [(out.single.$1, '', out.single.$3)];
    return out;
  }

  /// Where a tooltip points: the top of the selected row's place, or the
  /// middle of the selected slice's outer edge.
  Offset? get selectionAnchor {
    final sel = selection;
    if (sel == null || sel.index >= count) return null;
    final pane = spec.panes[sel.pane];
    if (pane.polar) {
      final k = sel.mark ?? pane.marks.indexWhere((m) => m.type == 'arc');
      if (k < 0) return null;
      final m = pane.marks[k];
      final (center, outer, _) = arcGeometry(sel.pane, m);
      for (final s in slices(m)) {
        if (s.index != sel.index) continue;
        final mid = s.start + s.sweep / 2;
        return center + Offset(math.sin(mid), -math.cos(mid)) * outer;
      }
      return center;
    }
    return Offset(xOfRow(sel.index), plotRect(sel.pane).top);
  }

  Json? get selectionState {
    final sel = selection;
    if (sel == null || sel.index >= count) return null;
    final row = rows[sel.index];
    final mark = sel.mark == null ? null : spec.panes[sel.pane].marks[sel.mark!];
    final value = mark == null ? null : row[mark.valueField];
    return {
      'index': sel.index,
      'key': row[spec.key],
      'label': xLabel(sel.index),
      'pane': sel.pane,
      'mark': sel.mark,
      'name': mark?.label,
      'field': mark?.valueField,
      'value': value is num ? value : null,
      'pinned': _hover == null && _pinned != null,
      'row': row,
    };
  }

  // --- state -----------------------------------------------------------------

  Json get viewState {
    final (first, last) = visible;
    return {
      'barSpacing': viewport.barSpacing,
      'rightOffset': viewport.rightOffset,
      'from': from,
      'to': to,
      'first': first,
      'last': last,
      'firstKey': last < first ? null : rows[first][spec.key],
      'lastKey': last < first ? null : rows[last][spec.key],
      'atEnd': viewport.atEnd,
      'loadingHistory': loadingHistory,
      'auto': [for (var i = 0; i < spec.panes.length; i++) yAuto(i)],
      'domains': [
        for (var i = 0; i < spec.panes.length; i++) [yDomain(i).$1, yDomain(i).$2],
      ],
    };
  }

  Json? get cursorState => cursor == null
      ? null
      : {
          'index': cursor!.index,
          'x': cursor!.x,
          'y': cursor!.y,
          'key': cursor!.row[spec.key],
          'value': cursor!.value,
          'pane': cursor!.pane,
          'row': cursor!.row,
        };

  /// What a page binds: `view` and `cursor`.
  Json get state => {'view': viewState, 'cursor': cursorState, 'selection': selectionState};
}
