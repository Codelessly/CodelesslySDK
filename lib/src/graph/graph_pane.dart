// One pane drawn by the graphic fork: the pane's marks and axes as a graphic
// spec, its dataflow run on the rows in view under the engine's domains.
//
// The spec names fields; the accessors and encoders graphic wants as
// closures are made here from those names, so no closure is ever part of a
// graph's description.
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart' show TickerProvider;

import 'graph_engine.dart';
import 'graph_spec.dart';
import 'graphic/src/algebra/varset.dart';
import 'graphic/src/chart/chart.dart';
import 'graphic/src/chart/view.dart';
import 'graphic/src/common/dim.dart';
import 'graphic/src/coord/rect.dart';
import 'graphic/src/encode/color.dart';
import 'graphic/src/encode/gradient.dart';
import 'graphic/src/encode/shape.dart';
import 'graphic/src/encode/size.dart';
import 'graphic/src/graffiti/element/label.dart';
import 'graphic/src/guide/axis/axis.dart';
import 'graphic/src/mark/area.dart';
import 'graphic/src/mark/custom.dart';
import 'graphic/src/mark/line.dart';
import 'graphic/src/mark/mark.dart';
import 'graphic/src/scale/continuous.dart';
import 'graphic/src/scale/linear.dart';
import 'graphic/src/shape/area.dart';
import 'graphic/src/shape/custom.dart';
import 'graphic/src/shape/line.dart';
import 'graphic/src/variable/variable.dart';

class GraphPane {
  GraphPane(this.engine, this.index, TickerProvider tickers, void Function() repaint) {
    final plot = engine.plotRect(index);
    _size = _sizeOf(plot);
    final (rows, windows) = _window();
    _view = ChartView<Json>(_chart(rows), _size, tickers, repaint, windows);
  }

  final GraphEngine engine;
  final int index;
  late Size _size;
  late final ChartView<Json> _view;

  GraphPaneSpec get _spec => engine.spec.panes[index];
  bool get _last => index == engine.spec.panes.length - 1;

  /// The pane's box: its plot, the price axis right of it and, under the
  /// last pane, the time axis.
  Size _sizeOf(Rect plot) =>
      Size(plot.width + engine.yAxisWidth, plot.height + (_last ? engine.spec.x.axisHeight : 0));

  /// The fields on the pane's own y scale.
  List<String> get _fields => {
        for (final m in _spec.marks)
          if (m.overlay == null && m.type != 'arc') ...m.fields.where((f) => f.isNotEmpty),
      }.toList();

  /// The marks on a scale of their own.
  Iterable<GraphMarkSpec> get _overlays => _spec.marks.where((m) => m.overlay != null);

  /// The marks drawn band by band.
  Iterable<GraphMarkSpec> get _segmented =>
      _spec.marks.where((m) => m.segmentBy.isNotEmpty && m.overlay == null && engine.spec.x.bands.isNotEmpty);

  /// A segmented mark's value in one band: the variable of that part of
  /// its line.
  String _part(GraphMarkSpec m, GraphBandSpec band) => '${m.y}@${band.id}';

  /// A row's value for a band's part: its own while it is in the band, and
  /// the first row after it too, so the parts meet with no gap.
  num _partValue(GraphMarkSpec m, GraphBandSpec band, Json r) {
    final i = r['_i']! as int;
    final inBand = r[m.segmentBy] == band.id || (i > 0 && engine.rows[i - 1][m.segmentBy] == band.id);
    return inBand && r[m.y] is num ? r[m.y]! as num : double.nan;
  }

  /// One band's part of a line, dimmed while another band is in use.
  Mark _partMark(GraphMarkSpec m, GraphBandSpec band) => LineMark(
        position: Varset('_i') * Varset(_part(m, band)),
        color: ColorEncode(
          encoder: (_) =>
              band.id == engine.activeBand ? m.color : m.color.withValues(alpha: m.color.a * m.dimInactive),
        ),
        size: SizeEncode(value: m.width),
        shape: ShapeEncode(value: BasicLineShape(smooth: m.curved)),
      );

  Chart<Json> _chart(List<Json> rows) {
    final fields = _fields;
    Variable<Json, num> number(String f, {bool labeled = false}) => Variable(
          accessor: (Json r) => r[f] is num ? r[f]! as num : double.nan,
          scale: LinearScale(formatter: (v) => engine.yLabel(index, v)),
        );
    // Bars and slices are drawn by the graph's painter, under these.
    final marks = <Mark>[
      for (final m in _spec.marks)
        if (m.type == 'bar' || m.type == 'arc')
          ...const <Mark>[]
        else if (_segmented.contains(m))
          for (final band in engine.spec.x.bands) _partMark(m, band)
        else
          _mark(m),
    ];
    // A pane of bars alone still has its axes: a line nobody sees holds them.
    if (marks.isEmpty && fields.isNotEmpty) {
      marks.add(LineMark(
        position: Varset('_i') * Varset(fields.first),
        color: ColorEncode(value: const Color(0x00000000)),
        size: SizeEncode(value: 0),
      ));
    }
    return Chart<Json>(
      data: rows,
      padding: (_) => EdgeInsets.only(
        left: engine.axisLeft ? engine.yAxisWidth : 0,
        right: engine.axisLeft ? 0 : engine.yAxisWidth,
        bottom: _last ? engine.spec.x.axisHeight : 0,
      ),
      coord: RectCoord(),
      variables: {
        '_i': Variable(
          // A row's position: its place, or on a linear scale its number.
          accessor: (Json r) => engine.linear
              ? (r[engine.spec.x.field] is num ? r[engine.spec.x.field]! as num : double.nan)
              : r['_i']! as num,
          scale: LinearScale(formatter: (v) => engine.xTickText(v)),
        ),
        for (final f in fields) f: number(f),
        for (final m in _overlays)
          if (!fields.contains(m.valueField)) m.valueField: number(m.valueField),
        for (final m in _segmented)
          for (final band in engine.spec.x.bands)
            _part(m, band): Variable(
              accessor: (Json r) => _partValue(m, band, r),
              scale: LinearScale(formatter: (v) => engine.yLabel(index, v)),
            ),
      },
      marks: marks,
      // The grid and the axes' labels are the graph painter's.
      axes: const [],
    );
  }

  Mark _mark(GraphMarkSpec m) {
    // By the row itself: a tuple holds only the fields on this pane's scale.
    Color direction(Map<String, dynamic> t) {
      final row = engine.rows[(t['_i'] as num).toInt()];
      final open = row[m.open], close = row[m.close];
      return open is num && close is num && close < open ? m.downColor : m.upColor;
    }

    final x = Varset('_i');
    switch (m.type) {
      case 'candle':
        return CustomMark(
          shape: ShapeEncode(value: CandlestickShape(hollow: false)),
          position: x * (Varset(m.open) + Varset(m.high) + Varset(m.low) + Varset(m.close)),
          color: ColorEncode(encoder: direction),
          size: SizeEncode(encoder: (_) => engine.barWidth),
        );
      case 'area':
        return AreaMark(
          position: x * Varset(m.y),
          color: m.fade || m.fillTo != null ? null : ColorEncode(value: m.color.withValues(alpha: m.color.a * m.fillOpacity)),
          gradient: m.fade || m.fillTo != null
              ? GradientEncode(
                  value: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [m.color.withValues(alpha: m.color.a * m.fillOpacity), m.fillTo ?? m.color.withValues(alpha: 0)],
                  ),
                )
              : null,
          shape: ShapeEncode(value: BasicAreaShape(smooth: m.curved)),
        );
      default:
        return LineMark(
          position: x * Varset(m.y),
          color: ColorEncode(value: m.color),
          size: SizeEncode(value: m.width),
          shape: ShapeEncode(value: BasicLineShape(smooth: m.curved)),
        );
    }
  }

  /// Shows what the engine holds now: the rows in view (and one past each
  /// edge, so a line runs to the edge) under the x and y domains.
  void sync() {
    final size = _sizeOf(engine.plotRect(index));
    if (size != _size) {
      _size = size;
      _view.resizeNow(size);
    }
    final (rows, windows) = _window();
    _view.window(rows, windows);
  }

  (List<Json>, Map<String, ScaleWindow>) _window() {
    final (first, last) = engine.visible;
    final a = (first - 1).clamp(0, engine.count), b = (last + 2).clamp(0, engine.count);
    final (lo, hi) = engine.yDomain(index);
    final y = ScaleWindow(lo, hi, engine.yTicks(index));
    final windows = {
      '_i': ScaleWindow(engine.from, engine.to, engine.xTicks),
      for (final f in _fields) f: y,
      for (final m in _segmented)
        for (final band in engine.spec.x.bands) _part(m, band): y,
    };
    for (final m in _overlays) {
      final (oLo, oHi) = engine.overlayDomain(index, m);
      windows.putIfAbsent(m.valueField, () => ScaleWindow(oLo, oHi));
    }
    return (a < b ? engine.rows.sublist(a, b) : const [], windows);
  }

  void paint(Canvas canvas) => _view.graffiti.paint(canvas);

  void dispose() => _view.dispose();
}
