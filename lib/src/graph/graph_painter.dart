// Draws a graph from its engine: each pane's grid, bars and slices (drawn
// here), its lines, areas, candles and axis labels (drawn by the graphic
// fork), and over them the price lines, markers, the legend, the selection
// with its tooltip, and the crosshair with its tags.
//
// It reads the engine and holds nothing of its own, so the graph's hosts
// (a render object, a widget) draw the same picture.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'graph_engine.dart';
import 'graph_pane.dart';
import 'graph_spec.dart';

class GraphPainter {
  const GraphPainter(this.engine, this.panes, {this.pulse = 0});

  final GraphEngine engine;

  /// The graphic pane of each rect pane, by the pane's place; a polar pane
  /// has none.
  final Map<int, GraphPane> panes;

  /// 0 to 1, turning: a pulsing end dot's ring.
  final double pulse;

  GraphSpec get _spec => engine.spec;
  GraphStyleSpec get _style => _spec.style;

  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _style.background);
    for (var i = 0; i < _spec.panes.length; i++) {
      final pane = _spec.panes[i];
      final plot = engine.plotRect(i);
      if (pane.polar) {
        _arcs(canvas, i);
        continue;
      }
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(plot.left, plot.top - 1, plot.right, plot.bottom + 1));
      _grid(canvas, i, plot);
      _band(canvas, i, plot);
      _bars(canvas, i);
      canvas.restore();
      if (panes[i] case final drawn?) {
        canvas.save();
        canvas.translate(0, plot.top);
        drawn.paint(canvas);
        canvas.restore();
      }
      if (i > 0) {
        canvas.drawLine(plot.topLeft, Offset(engine.bodyRight, plot.top), Paint()..color = _style.separator);
      }
      _dots(canvas, i, plot);
      for (final line in pane.priceLines) {
        _priceLine(canvas, i, plot, line);
      }
      for (final mark in pane.marks) {
        if (mark.endDot > 0) _endDot(canvas, i, plot, mark);
      }
      _barLabels(canvas, i);
      _guides(canvas, i, plot);
      // Zoomed out, badges that would sit on one another are left out.
      double? badge;
      for (final marker in pane.markers) {
        final index = engine.indexOfKey(marker.at);
        if (index == null) continue;
        final x = engine.xOf(index);
        if (badge != null && (x - badge).abs() < 20) continue;
        if (_marker(canvas, plot, marker)) badge = x;
      }
      _selectionDots(canvas, i, plot);
    }
    _axisLabels(canvas, size);
    _legend(canvas);
    final cursor = engine.cursor;
    if (cursor != null) _crosshair(canvas, cursor);
    _tooltip(canvas, size);
  }

  // --- what is drawn here: grid, bars, slices -------------------------------

  void _grid(Canvas canvas, int pane, Rect plot) {
    final paint = Paint()
      ..color = _style.grid
      ..strokeWidth = 1;
    for (final v in engine.yTicks(pane)) {
      final y = engine.yOf(pane, v.toDouble());
      if (y < plot.top - 0.5 || y > plot.bottom + 0.5) continue;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
    if (!_spec.x.grid) return;
    for (final i in engine.xTicks) {
      final x = engine.xOf(i);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
    }
  }

  /// The axes' labels: each y tick's in its pane's gutter, each x tick's
  /// under the last pane, kept inside the graph (a label at an edge is not
  /// cut).
  void _axisLabels(Canvas canvas, Size size) {
    for (var i = 0; i < _spec.panes.length; i++) {
      final pane = _spec.panes[i];
      if (pane.polar || !pane.y.labels || engine.yAxisWidth <= 0) continue;
      final plot = engine.plotRect(i), axis = engine.yAxisRect(i);
      for (final v in engine.yTicks(i)) {
        final y = engine.yOf(i, v.toDouble());
        if (y < plot.top - 0.5 || y > plot.bottom + 0.5) continue;
        final label = engine.yLabel(i, v);
        if (label.isEmpty) continue;
        final tp = _text(label, _style.text, _style.fontSize);
        final top = (y - tp.height / 2).clamp(0.0, math.max(0.0, size.height - tp.height)).toDouble();
        tp.paint(canvas, Offset(engine.axisLeft ? axis.right - 6 - tp.width : axis.left + 6, top));
      }
    }
    final axis = engine.xAxisRect;
    if (!_spec.x.labels || axis.height <= 0 || _spec.panes.every((p) => p.polar)) return;
    // The labels that stand apart (GraphEngine.xLabels), a long one cut to
    // its room.
    for (final (_, label, left, width) in engine.xLabels) {
      final tp = _text(label, _style.text, _style.fontSize, maxWidth: width.isFinite ? width : null);
      tp.paint(canvas, Offset(left, axis.top + math.max(2.0, math.min(6.0, axis.height - tp.height))));
    }
  }

  /// The legend's keys: a dot in the key's color, its name, and a slice's
  /// share against the key's right edge.
  void _legend(Canvas canvas) {
    final legend = engine.legend;
    if (legend == null) return;
    final font = _style.fontSize + 1;
    const mark = GraphLegendLayout.dot + GraphLegendLayout.dotGap;
    for (final k in legend.keys) {
      final box = k.box;
      canvas.drawCircle(Offset(box.left + GraphLegendLayout.dot / 2, box.center.dy), GraphLegendLayout.dot / 2, Paint()..color = k.color);
      final value = k.value.isEmpty ? null : _text(k.value, _style.ink, font, weight: FontWeight.w600);
      final room = math.max(0.0, box.width - mark - (value == null ? 0 : value.width + 6));
      final label = _text(k.label, _style.text, font, maxWidth: room);
      label.paint(canvas, Offset(box.left + mark, box.center.dy - label.height / 2));
      value?.paint(canvas, Offset(box.right - value.width, box.center.dy - value.height / 2));
    }
  }

  /// A dot on every row of a line that asks for them (GraphMarkSpec.dots).
  void _dots(Canvas canvas, int pane, Rect plot) {
    final marks = _spec.panes[pane].marks;
    if (!marks.any((m) => m.dots > 0) || engine.count == 0) return;
    final (first, last) = engine.visible;
    for (var k = 0; k < marks.length; k++) {
      final m = marks[k];
      if (m.dots <= 0 || m.type != 'line' || m.overlay != null) continue;
      final paint = Paint()..color = m.color;
      for (var i = math.max(0, first); i <= math.min(engine.count - 1, last); i++) {
        if (engine.rows[i][m.y] case final num v when v.isFinite) {
          final x = engine.xOfRow(i);
          if (x < plot.left - 1 || x > plot.right + 1) continue;
          canvas.drawCircle(Offset(x, engine.yOf(pane, v.toDouble())), m.dots, paint);
        }
      }
    }
  }

  /// The fill behind the selected row.
  void _band(Canvas canvas, int pane, Rect plot) {
    final sel = engine.selection, color = _spec.selection.band;
    if (sel == null || color == null || _spec.panes[sel.pane].polar) return;
    final x = engine.xOfRow(sel.index), half = engine.slotWidth / 2;
    canvas.drawRect(Rect.fromLTRB(x - half, plot.top, x + half, plot.bottom), Paint()..color = color);
  }

  void _bars(Canvas canvas, int pane) {
    final marks = _spec.panes[pane].marks;
    if (!marks.any((m) => m.type == 'bar') || engine.count == 0) return;
    final (first, last) = engine.visible;
    final paint = Paint();
    for (var i = math.max(0, first - 1); i <= math.min(engine.count - 1, last + 1); i++) {
      final rects = engine.barRects(pane, i);
      for (final (k, r) in rects) {
        final m = marks[k];
        final row = engine.rows[i];
        final open = row[m.open], close = row[m.close];
        final base = m.byDirection
            ? (open is num && close is num && close < open ? m.downColor : m.upColor)
            : engine.markColor(m, i);
        paint.color = base.withValues(alpha: base.a * engine.emphasis(pane, k, i));
        // Round where nothing of its group stands on it.
        final top = !rects.any((o) => o.$2.left == r.left && o.$2.top < r.top);
        final radius = top ? Radius.circular(math.min(m.radius, r.width / 2)) : Radius.zero;
        if (radius == Radius.zero) {
          canvas.drawRect(r, paint);
        } else {
          canvas.drawRRect(RRect.fromRectAndCorners(r, topLeft: radius, topRight: radius), paint);
        }
      }
    }
  }

  void _arcs(Canvas canvas, int pane) {
    final marks = _spec.panes[pane].marks;
    final sel = engine.selection;
    for (var k = 0; k < marks.length; k++) {
      final m = marks[k];
      if (m.type != 'arc') continue;
      final (center, outer, inner) = engine.arcGeometry(pane, m);
      if (outer <= 0) continue;
      final slices = engine.slices(m);
      if (slices.isEmpty) {
        // Nothing to share out: the ring itself, in the grid's color.
        _slice(canvas, center, outer, inner, 0, 2 * math.pi, _style.grid);
        continue;
      }
      for (final s in slices) {
        final on = sel != null && sel.pane == pane && sel.index == s.index && (sel.mark == null || sel.mark == k);
        final color = s.color.withValues(alpha: s.color.a * engine.emphasis(pane, k, s.index));
        _slice(canvas, center, outer + (on ? _spec.selection.grow : 0), inner, s.start, s.sweep, color);
      }
      if (m.center == 'total' && inner >= 20) _center(canvas, pane, k, m, center, inner);
    }
  }

  /// What is written in an arc's hole: the sum of its values with the
  /// mark's label under it, or the selected slice's value and its label.
  void _center(Canvas canvas, int pane, int k, GraphMarkSpec m, Offset center, double inner) {
    final sel = engine.selection;
    final on = sel != null && sel.pane == pane && sel.index < engine.count && (sel.mark == null || sel.mark == k);
    var value = 0.0;
    if (on) {
      if (engine.rows[sel.index][m.y] case final num v when v.isFinite) value = v.toDouble();
    } else {
      for (final r in engine.rows) {
        if (r[m.y] case final num v when v.isFinite && v > 0) value += v;
      }
    }
    final y = _spec.panes[pane].y;
    final label = on ? engine.xLabel(sel.index) : m.centerLabel;
    final room = inner * 1.6;
    var size = (inner * 0.44).clamp(12.0, 34.0).toDouble();
    var figure = _text('${y.prefix}${_compact(value)}${y.suffix}', _style.ink, size, weight: FontWeight.w600);
    if (figure.width > room) {
      size = math.max(9.0, size * room / figure.width);
      figure = _text('${y.prefix}${_compact(value)}${y.suffix}', _style.ink, size, weight: FontWeight.w600);
    }
    final under = label.isEmpty || inner < 34 ? null : _text(label, _style.text, _style.fontSize + 1, maxWidth: room);
    final height = figure.height + (under == null ? 0 : under.height);
    figure.paint(canvas, Offset(center.dx - figure.width / 2, center.dy - height / 2));
    under?.paint(canvas, Offset(center.dx - under.width / 2, center.dy - height / 2 + figure.height));
  }

  /// A figure in few characters: 1,234 with its separator, 12,400 as 12.4K.
  String _compact(double v) {
    final a = v.abs();
    String short(double n, String unit) {
      final s = n.abs() >= 100 ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
      return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}$unit';
    }

    if (a >= 1e9) return short(v / 1e9, 'B');
    if (a >= 1e6) return short(v / 1e6, 'M');
    if (a >= 1e4) return short(v / 1e3, 'K');
    final r = v.roundToDouble();
    if ((v - r).abs() < 1e-9) return graphGrouped(r.toInt().toString());
    return graphGrouped(v.toStringAsFixed(a < 10 ? 2 : 1));
  }

  /// A slice from [start] turning [sweep] (radians, clockwise from the top).
  void _slice(Canvas canvas, Offset center, double outer, double inner, double start, double sweep, Color color) {
    final from = start - math.pi / 2;
    final path = Path();
    final big = Rect.fromCircle(center: center, radius: outer);
    if (sweep >= 2 * math.pi - 1e-6) {
      path.addOval(big);
      if (inner > 0) {
        path
          ..addOval(Rect.fromCircle(center: center, radius: inner))
          ..fillType = PathFillType.evenOdd;
      }
    } else if (inner <= 0) {
      path
        ..moveTo(center.dx, center.dy)
        ..arcTo(big, from, sweep, false)
        ..close();
    } else {
      path
        ..arcTo(big, from, sweep, true)
        ..arcTo(Rect.fromCircle(center: center, radius: inner), from + sweep, -sweep, false)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// The pane's guides: stretches under everything else of theirs, then
  /// lines, then dots with their labels.
  void _guides(Canvas canvas, int pane, Rect plot) {
    final guides = _spec.panes[pane].guides;
    if (guides.isEmpty) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left - 8, plot.top - 16, plot.right + 8, plot.bottom + 1));
    for (final g in guides) {
      final a = engine.place(g.from), b = engine.place(g.to);
      if (a == null || b == null) continue;
      final left = engine.xOf(a).clamp(plot.left, plot.right).toDouble();
      final right = engine.xOf(b).clamp(plot.left, plot.right).toDouble();
      canvas.drawRect(Rect.fromLTRB(left, plot.top, right, plot.bottom), Paint()..color = g.color);
      if (g.label.isNotEmpty) {
        final tp = _text(g.label, g.labelColor ?? _style.text, _style.fontSize);
        tp.paint(canvas, Offset((left + right - tp.width) / 2, plot.top + 2));
      }
    }
    for (final g in guides) {
      if (g.from != null || g.to != null) continue;
      final at = engine.place(g.x);
      final x = at == null ? null : engine.xOf(at);
      final y = g.y == null ? null : engine.yOf(pane, g.y!);
      if (x != null && (x < plot.left - 0.5 || x > plot.right + 0.5)) continue;
      if (y != null && (y < plot.top - 0.5 || y > plot.bottom + 0.5)) continue;
      final label = g.label.isEmpty ? null : _text(g.label, g.labelColor ?? g.color, _style.fontSize);
      if (x != null && y != null) {
        final dot = Offset(x, y);
        canvas.drawCircle(dot, g.radius, Paint()..color = g.color);
        if (g.fill != null) canvas.drawCircle(dot, math.max(0, g.radius - math.max(1.5, g.width)), Paint()..color = g.fill!);
        if (label != null) {
          final lx = (x - label.width / 2).clamp(plot.left, math.max(plot.left, plot.right - label.width)).toDouble();
          label.paint(canvas, Offset(lx, g.below ? y + g.radius + 3 : y - g.radius - 3 - label.height));
        }
      } else if (x != null) {
        _line(canvas, Offset(x, plot.top), Offset(x, plot.bottom), g.color, style: g.line, width: g.width);
        if (label != null) {
          final lx = (x + 4 + label.width > plot.right ? x - 4 - label.width : x + 4);
          label.paint(canvas, Offset(lx, plot.top + 2));
        }
      } else if (y != null) {
        _line(canvas, Offset(plot.left, y), Offset(plot.right, y), g.color, style: g.line, width: g.width);
        label?.paint(canvas, Offset(plot.right - label.width - 4, g.below ? y + 2 : y - label.height - 2));
      }
    }
    canvas.restore();
  }

  /// Each bar's value over it (GraphMarkSpec.labels): a stack's, over its
  /// top bar.
  void _barLabels(Canvas canvas, int pane) {
    final marks = _spec.panes[pane].marks;
    if (!marks.any((m) => m.type == 'bar' && m.labels) || engine.count == 0) return;
    final (first, last) = engine.visible;
    for (var i = math.max(0, first); i <= math.min(engine.count - 1, last); i++) {
      for (final (k, r) in engine.barRects(pane, i)) {
        final m = marks[k];
        if (!m.labels) continue;
        if (engine.rows[i][m.y] case final num v) {
          final tp = _text(engine.yLabel(pane, v), _style.text.withValues(alpha: _style.text.a * engine.emphasis(pane, k, i)),
              _style.fontSize);
          tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.top - tp.height - 2));
        }
      }
    }
  }

  /// A dot on each line at the selected row.
  void _selectionDots(Canvas canvas, int pane, Rect plot) {
    final sel = engine.selection, radius = _spec.selection.dot;
    if (sel == null || radius <= 0 || sel.index >= engine.count || _spec.panes[sel.pane].polar) return;
    final x = engine.xOfRow(sel.index);
    if (x < plot.left - 1 || x > plot.right + 1) return;
    for (final m in _spec.panes[pane].marks) {
      if (m.type != 'line' && m.type != 'area' || m.overlay != null) continue;
      if (engine.rows[sel.index][m.y] case final num v when v.isFinite) {
        final at = Offset(x, engine.yOf(pane, v.toDouble()));
        canvas.drawCircle(at, radius + 1.5, Paint()..color = _style.background);
        canvas.drawCircle(at, radius, Paint()..color = m.color);
      }
    }
  }

  /// The selection's box: its title, then a row per mark (a dot in its
  /// color, its name, its value). Beside the pointer, or where the pinned
  /// row is, and always inside the graph.
  void _tooltip(Canvas canvas, Size size) {
    final sel = engine.selection, s = _spec.selection;
    if (sel == null || !s.tooltip || sel.index >= engine.count) return;
    final rows = engine.selectionRows();
    final row = engine.rows[sel.index];
    final title = s.title.isEmpty ? engine.xLabel(sel.index) : '${row[s.title] ?? ''}';
    final font = _style.fontSize + 1;
    final tooltipText = s.tooltipText ?? _style.tooltipText, tooltipFill = s.tooltipFill ?? _style.tooltip;
    final titleText = title.isEmpty ? null : _text(title, tooltipText.withValues(alpha: tooltipText.a * 0.64), font - 1);
    final polar = _spec.panes[sel.pane].polar;
    final total = rows.fold(0.0, (a, r) => a + r.$3);
    final lines = <(Color?, TextPainter, TextPainter)>[
      for (final (color, name, value) in rows)
        (
          color,
          _text(name, tooltipText, font),
          _text(polar ? '${engine.yLabel(sel.pane, value)}  ${_share(sel, value)}' : engine.yLabel(sel.pane, value),
              tooltipText, font, weight: FontWeight.w600),
        ),
      if (s.total && rows.length > 1 && !polar)
        (null, _text('Total', tooltipText, font), _text(engine.yLabel(sel.pane, total), tooltipText, font, weight: FontWeight.w600)),
    ];
    if (titleText == null && lines.isEmpty) return;
    const pad = 10.0, dot = 8.0, gap = 16.0, lineGap = 4.0;
    var w = titleText?.width ?? 0;
    var h = titleText == null ? 0.0 : titleText.height + (lines.isEmpty ? 0 : 6);
    for (final (color, name, value) in lines) {
      w = math.max(w, (color == null ? 0 : dot + 6) + name.width + (name.width > 0 ? gap : 0) + value.width);
      h += math.max(name.height, value.height) + lineGap;
    }
    if (lines.isNotEmpty) h -= lineGap;
    w += pad * 2;
    h += pad * 2;
    // A graph too small to hold it (a sparkline) has no tooltip: it would
    // cover what it is about.
    if (w > size.width || h > size.height) return;
    final pointer = engine.pointer;
    final anchor = pointer ?? engine.selectionAnchor;
    if (anchor == null) return;
    // Beside the pointer, on the side that has the room, and kept over the
    // panes: never over a legend or the labels under the plot, never out
    // of the graph.
    final within = engine.tooltipBounds;
    var left = anchor.dx + 14, top = pointer == null ? anchor.dy + 6 : anchor.dy + 14;
    if (left + w > within.right) left = anchor.dx - 14 - w;
    if (top + h > within.bottom) top = anchor.dy - 14 - h;
    left = left.clamp(within.left, math.max(within.left, within.right - w)).toDouble();
    top = top.clamp(within.top, math.max(within.top, within.bottom - h)).toDouble();
    // A surface with a line round it, lifted by a soft shadow.
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(8));
    canvas.drawRRect(
        box.shift(const Offset(0, 2)),
        Paint()
          ..color = const Color(0x1F000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawRRect(box, Paint()..color = tooltipFill);
    canvas.drawRRect(
        box.deflate(0.5),
        Paint()
          ..color = _style.tooltipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    var y = top + pad;
    if (titleText != null) {
      titleText.paint(canvas, Offset(left + pad, y));
      y += titleText.height + 6;
    }
    for (final (color, name, value) in lines) {
      final lh = math.max(name.height, value.height);
      var x = left + pad;
      if (color != null) {
        canvas.drawCircle(Offset(x + dot / 2, y + lh / 2), dot / 2, Paint()..color = color);
        x += dot + 6;
      }
      name.paint(canvas, Offset(x, y + (lh - name.height) / 2));
      value.paint(canvas, Offset(left + w - pad - value.width, y + (lh - value.height) / 2));
      y += lh + lineGap;
    }
  }

  /// A slice's share of its mark's turn, as a percent.
  String _share(GraphHit sel, double value) {
    final marks = _spec.panes[sel.pane].marks;
    final k = sel.mark ?? marks.indexWhere((m) => m.type == 'arc');
    if (k < 0) return '';
    var total = 0.0;
    for (final r in engine.rows) {
      if (r[marks[k].y] case final num v when v.isFinite && v > 0) total += v;
    }
    if (total <= 0) return '';
    final pct = value / total * 100;
    return '${pct.toStringAsFixed(pct < 10 && pct != pct.roundToDouble() ? 1 : 0)}%';
  }

  // --- over the panes -----------------------------------------------------

  void _priceLine(Canvas canvas, int pane, Rect plot, GraphPriceLineSpec line) {
    final v = engine.priceLineValue(line);
    if (v == null) return;
    final y = engine.yOf(pane, v);
    if (y < plot.top || y > plot.bottom) return;
    if (line.byBand && _spec.x.bands.isNotEmpty) {
      // Band by band over the whole x scale, the one in use in its color.
      final active = engine.activeGroup;
      for (final band in _spec.x.bands) {
        final a = engine.xOf(band.from).clamp(plot.left, plot.right).toDouble();
        final b = engine.xOf(band.to).clamp(plot.left, plot.right).toDouble();
        final color = band.group == active ? line.activeColor ?? line.color : line.color;
        _line(canvas, Offset(a, y), Offset(b, y), color, style: line.line);
      }
    } else {
      _line(canvas, Offset(plot.left, y), Offset(plot.right, y), line.color, style: line.line);
    }
    if (line.tag) {
      _tag(canvas, engine.yLabel(pane, v), Offset(engine.yAxisRect(pane).left, y), line.color, const Color(0xFFFFFFFF), _style.fontSize,
          width: engine.yAxisWidth, note: line.note);
    }
    if (line.label.isNotEmpty) {
      final tp = _text(line.label, line.color, _style.fontSize);
      tp.paint(canvas, Offset(plot.right - tp.width - 6, y - tp.height - 2));
    }
  }

  /// A lettered badge at the foot of the pane, on its row.
  /// Whether it was drawn (it is in the plot).
  bool _marker(Canvas canvas, Rect plot, GraphMarkerSpec marker) {
    final index = engine.indexOfKey(marker.at);
    if (index == null) return false;
    final x = engine.xOf(index);
    if (x < plot.left + 9 || x > plot.right - 9) return false;
    final at = Offset(x, plot.bottom - 12);
    canvas.drawCircle(at, 8.5, Paint()..color = _style.background);
    canvas.drawCircle(
        at,
        8,
        Paint()
          ..color = marker.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    final tp = _text(marker.text, marker.color, 10);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    return true;
  }

  /// The dot on a mark's last row, with its ring swelling and fading.
  void _endDot(Canvas canvas, int pane, Rect plot, GraphMarkSpec mark) {
    if (engine.count == 0) return;
    final v = engine.rows.last[mark.valueField];
    if (v is! num) return;
    final at = Offset(engine.xOfRow(engine.count - 1), engine.yOf(pane, v.toDouble()));
    if (at.dx < plot.left - 1 || at.dx > plot.right + 1) return;
    final color = mark.endDotColor ?? mark.color;
    if (mark.pulse) {
      canvas.drawCircle(at, mark.endDot * (1 + 2 * pulse), Paint()..color = color.withValues(alpha: 0.35 * (1 - pulse)));
    }
    canvas.drawCircle(at, mark.endDot, Paint()..color = color);
  }

  void _crosshair(Canvas canvas, GraphCursor cursor) {
    final cross = _spec.crosshair;
    final axis = engine.xAxisRect;
    final top = engine.plotRect(0).top;
    if (cross.vertical) {
      _line(canvas, Offset(cursor.x, top), Offset(cursor.x, axis.top), _style.crosshair, style: cross.line);
    }
    if (cross.horizontal) {
      _line(canvas, Offset(engine.plotLeft, cursor.y), Offset(engine.plotRight, cursor.y), _style.crosshair, style: cross.line);
    }
    if (cross.dot > 0) {
      final at = Offset(cursor.x, cursor.y);
      if (cross.dotStroke > 0) {
        canvas.drawCircle(at, cross.dot + cross.dotStroke / 2, Paint()..color = _style.background);
      }
      canvas.drawCircle(at, cross.dot - cross.dotStroke / 2, Paint()..color = engine.magnetMark?.color ?? _style.crosshair);
    }
    if (cross.priceTag) {
      _tag(canvas, engine.yLabel(cursor.pane, cursor.value), Offset(engine.yAxisRect(cursor.pane).left, cursor.y), _style.tag,
          _style.tagText, _style.fontSize,
          width: engine.yAxisWidth);
    }
    if (cross.timeLabel == 'none') return;
    final label = engine.xLabel(cursor.index, cross.timeFormat.isEmpty ? null : cross.timeFormat);
    if (cross.timeLabel == 'top') {
      // Plain text over the line, kept inside the plot.
      final time = _text(label, _style.text, _style.fontSize);
      final left = (cursor.x - time.width / 2).clamp(engine.plotLeft, math.max(engine.plotLeft, engine.plotRight - time.width)).toDouble();
      time.paint(canvas, Offset(left, math.max(0, (top - time.height) / 2)));
      return;
    }
    final time = _text(label, _style.tagText, _style.fontSize);
    final w = time.width + 12;
    final left = (cursor.x - w / 2).clamp(engine.plotLeft, math.max(engine.plotLeft, engine.plotRight - w)).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, axis.top + 2, w, axis.height - 4), const Radius.circular(3)),
      Paint()..color = _style.tag,
    );
    time.paint(canvas, Offset(left + 6, axis.top + (axis.height - time.height) / 2));
  }

  /// With a [maxWidth], a text too long for it ends in an ellipsis.
  TextPainter _text(String text, Color color, double size, {FontWeight? weight, double? maxWidth}) => TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: color,
                fontSize: size,
                fontFamily: _style.fontFamily,
                fontFamilyFallback: _style.fontFamilyFallback,
                fontWeight: weight)),
        textDirection: TextDirection.ltr,
        maxLines: maxWidth == null ? null : 1,
        ellipsis: maxWidth == null ? null : '\u2026',
      )..layout(maxWidth: maxWidth ?? double.infinity);

  /// A value's tag on the price axis, its middle at [at].
  /// With a [note], a second line under the value (the tag grows down).
  void _tag(Canvas canvas, String text, Offset at, Color fill, Color color, double size,
      {required double width, String note = ''}) {
    if (width <= 0) return;
    final tp = _text(text, color, size);
    final second = note.isEmpty ? null : _text(note, color, size - 1);
    final h = tp.height + 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx, at.dy - h / 2, width, h + (second?.height ?? 0)), const Radius.circular(3)),
      Paint()..color = fill,
    );
    tp.paint(canvas, Offset(at.dx + 6, at.dy - tp.height / 2));
    second?.paint(canvas, Offset(at.dx + 6, at.dy + tp.height / 2));
  }

  /// A 1 px line: `solid`, `dashed` (3 on, 3 off) or `dotted` (1 on, 1 off).
  void _line(Canvas canvas, Offset a, Offset b, Color color, {String style = 'solid', double width = 1}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final length = (b - a).distance;
    if (length == 0) return;
    if (style == 'solid') {
      canvas.drawLine(a, b, paint);
      return;
    }
    final on = style == 'dotted' ? 1.0 : 3.0, off = style == 'dotted' ? 1.0 : 3.0;
    final step = (b - a) / length;
    for (var d = 0.0; d < length; d += on + off) {
      canvas.drawLine(a + step * d, a + step * math.min(d + on, length).toDouble(), paint);
    }
  }
}
