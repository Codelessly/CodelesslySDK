// A graph's state and geometry: the rows, the x viewport, each pane's y
// domain (fitted to the rows in view, or set by hand) and the cursor. It
// draws nothing and reads no gesture: the widget turns gestures into its
// commands, and the panes draw what it works out.
//
// What the user does is published as JSON ([state]): `view` and `cursor`,
// for a page's variables to hold, as any control's value is.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
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
  Json? _pendingView;

  // --- layout ----------------------------------------------------------------

  double get yAxisWidth => spec.panes.fold(0.0, (w, p) => math.max(w, p.y.width));
  double get plotWidth => math.max(0, size.width - yAxisWidth);
  double get _panesHeight => math.max(0, size.height - spec.x.axisHeight);

  /// A pane's plot.
  Rect plotRect(int pane) {
    final total = spec.panes.fold(0.0, (s, p) => s + p.grow);
    var top = 0.0;
    for (var i = 0; i < pane; i++) {
      top += _panesHeight * spec.panes[i].grow / total;
    }
    return Rect.fromLTWH(0, top, plotWidth, total == 0 ? 0 : _panesHeight * spec.panes[pane].grow / total);
  }

  Rect yAxisRect(int pane) {
    final plot = plotRect(pane);
    return Rect.fromLTWH(plot.right, plot.top, yAxisWidth, plot.height);
  }

  Rect get xAxisRect => Rect.fromLTWH(0, _panesHeight, size.width, spec.x.axisHeight);

  GraphZone zoneAt(Offset p) {
    if (p.dy >= _panesHeight) return const GraphZone(GraphZoneKind.xAxis);
    for (var i = 0; i < spec.panes.length; i++) {
      final plot = plotRect(i);
      if (p.dy >= plot.top && p.dy < plot.bottom) {
        return GraphZone(p.dx < plot.right ? GraphZoneKind.plot : GraphZoneKind.yAxis, i);
      }
    }
    return const GraphZone(GraphZoneKind.none);
  }

  // --- x ---------------------------------------------------------------------

  double get from => viewport.from(count, plotWidth);
  double get to => viewport.to(count);
  (int, int) get visible => viewport.visible(count, plotWidth);

  /// A position's pixel.
  double xOf(num index) => (index - from) * viewport.barSpacing;

  /// The position under a pixel.
  double indexAt(double px) => from + px / viewport.barSpacing;

  /// A candle's or bar's width.
  double get barWidth => math.max(1, (viewport.barSpacing * 0.72).floorToDouble());

  /// The positions with a time label: every step-th row, the step the
  /// smallest round one whose labels stand 80 px apart.
  List<num> get xTicks {
    if (count == 0) return const [];
    var step = 1;
    for (final s in const [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000]) {
      step = s;
      if (s * viewport.barSpacing >= 80) break;
    }
    final first = math.max(0, from.ceil()), last = math.min(count - 1, to.floor());
    return [for (var i = (first / step).ceil() * step; i <= last; i += step) i];
  }

  final _formats = <String, DateFormat>{};

  String xLabel(int index, [String? format]) {
    if (index < 0 || index >= count) return '';
    final v = rows[index][spec.x.label];
    final time = switch (v) {
      final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
      final String s => DateTime.tryParse(s),
      _ => null,
    };
    if (time == null) return v?.toString() ?? '';
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
    var lo = double.infinity, hi = double.negativeInfinity;
    void take(double? v) {
      if (v == null || !v.isFinite) return;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }

    var fromZero = false;
    for (final m in p.marks) {
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
      final pad = lo == 0 ? 1.0 : lo.abs() * 0.01;
      return (lo - pad, hi + pad);
    }
    final span = hi - lo;
    // Bars stand on zero: no room under it.
    return (fromZero && lo == 0 ? 0 : lo - span * y.marginBottom, hi + span * y.marginTop);
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

  /// A percent scale's ticks (round percents); null for the scale's own.
  List<num>? yTicks(int pane) {
    final base = spec.panes[pane].y.mode == 'percent' ? percentBase(pane) : null;
    if (base == null) return null;
    final (lo, hi) = yDomain(pane);
    final a = (lo / base - 1) * 100, b = (hi / base - 1) * 100;
    final raw = (b - a) / 5, mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [1, 2, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw);
    return [for (var p = (a / step).ceil() * step; p <= b; p += step) base * (1 + p / 100)];
  }

  String yLabel(int pane, num value) {
    final y = spec.panes[pane].y;
    if (y.mode == 'percent') {
      final base = percentBase(pane);
      if (base != null) {
        final pct = (value / base - 1) * 100;
        return '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(pct.abs() < 10 ? 1 : 0)}%';
      }
    }
    final a = value.abs();
    if (a >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (a >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (a >= 1e5) return '${(value / 1e3).toStringAsFixed(0)}K';
    return value.toStringAsFixed(y.decimals);
  }

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
  void setData(List<Json> data) {
    final key = spec.key;
    final lastKey = count == 0 ? null : rows.last[key];
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
    _askedHistory = false;
    _settle();
  }

  void panBy(double dx) => _setViewport(viewport.pan(dx));

  /// [px] is from the plot's left.
  void zoomAt(double px, double factor) => _setViewport(
      viewport.zoomAt(px, factor, plotWidth, min: spec.x.minBarSpacing, max: spec.x.maxBarSpacing));

  void resetX() => _setViewport(GraphViewport(barSpacing: spec.x.barSpacing, rightOffset: spec.x.rightOffset));

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
    if (count == 0 || !spec.crosshair.enabled || p.dx < 0 || p.dx > plotWidth) return null;
    final index = indexAt(p.dx).round().clamp(0, count - 1);
    final row = rows[index];
    final zone = zoneAt(p);
    var pane = zone.pane < 0 ? spec.panes.length - 1 : zone.pane;
    var y = p.dy.clamp(0.0, _panesHeight);
    final magnet = spec.crosshair.magnet;
    if (magnet.isNotEmpty) {
      final home = spec.panes.indexWhere((s) => s.marks.any((m) => m.fields.contains(magnet)));
      if (row[magnet] case final num v when home >= 0) {
        pane = home;
        y = yOf(home, v.toDouble());
      }
    }
    return GraphCursor(index: index, pane: pane, x: xOf(index), y: y, value: valueAt(pane, y), row: row);
  }

  /// Sets the view from state: `{barSpacing, rightOffset}`, or `{last: n}`
  /// for the last n rows across the plot.
  void applyView(Json view, {bool notify = true}) {
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
    if (spec.x.clamp) viewport = viewport.clamp(count, plotWidth);
    _changed();
    if (!_askedHistory && count > 0 && plotWidth > 0 && from < spec.x.historyThreshold) {
      _askedHistory = true;
      onNeedHistory?.call(viewState);
    }
  }

  void _changed() {
    _domains.clear();
    // The pointer has not moved, the rows under it have.
    if (cursor != null && _pointer != null) cursor = _cursorAt(_pointer!);
    notifyListeners();
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
          'key': cursor!.row[spec.key],
          'value': cursor!.value,
          'pane': cursor!.pane,
          'row': cursor!.row,
        };

  /// What a page binds: `view` and `cursor`.
  Json get state => {'view': viewState, 'cursor': cursorState};
}
