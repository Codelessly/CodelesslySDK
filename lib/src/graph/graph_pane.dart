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
import 'graphic/src/encode/shape.dart';
import 'graphic/src/encode/size.dart';
import 'graphic/src/graffiti/element/element.dart';
import 'graphic/src/graffiti/element/label.dart';
import 'graphic/src/guide/axis/axis.dart';
import 'graphic/src/mark/area.dart';
import 'graphic/src/mark/custom.dart';
import 'graphic/src/mark/interval.dart';
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

  /// The fields on the pane's y scale.
  List<String> get _fields => {
        for (final m in _spec.marks) ...m.fields.where((f) => f.isNotEmpty),
      }.toList();

  Chart<Json> _chart(List<Json> rows) {
    final style = engine.spec.style;
    final text = TextStyle(fontSize: style.fontSize, color: style.text, fontFamily: style.fontFamily);
    final grid = PaintStyle(strokeColor: style.grid, strokeWidth: 1);
    final fields = _fields;
    return Chart<Json>(
      data: rows,
      padding: (_) => EdgeInsets.only(right: engine.yAxisWidth, bottom: _last ? engine.spec.x.axisHeight : 0),
      coord: RectCoord(),
      variables: {
        '_i': Variable(
          accessor: (Json r) => r['_i']! as num,
          scale: LinearScale(formatter: (v) => engine.xLabel(v.round())),
        ),
        for (final f in fields)
          f: Variable(
            accessor: (Json r) => r[f] is num ? r[f]! as num : double.nan,
            scale: LinearScale(formatter: (v) => engine.yLabel(index, v)),
          ),
      },
      marks: [for (final m in _spec.marks) _mark(m)],
      axes: [
        AxisGuide(
          dim: Dim.x,
          variable: '_i',
          grid: grid,
          label: _last ? LabelStyle(textStyle: text, offset: const Offset(0, 6)) : null,
        ),
        if (fields.isNotEmpty)
          AxisGuide(
            dim: Dim.y,
            variable: fields.first,
            position: 1,
            flip: true,
            grid: grid,
            label: LabelStyle(textStyle: text, offset: const Offset(6, 0)),
          ),
      ],
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
      case 'bar':
        return IntervalMark(
          position: x * Varset(m.y),
          color: m.byDirection ? ColorEncode(encoder: direction) : ColorEncode(value: m.color),
          size: SizeEncode(encoder: (_) => engine.barWidth),
        );
      case 'area':
        return AreaMark(
          position: x * Varset(m.y),
          color: ColorEncode(value: m.color.withValues(alpha: m.fillOpacity)),
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
    return (
      a < b ? engine.rows.sublist(a, b) : const [],
      {
        '_i': ScaleWindow(engine.from, engine.to, engine.xTicks),
        for (final f in _fields) f: y,
      },
    );
  }

  void paint(Canvas canvas) => _view.graffiti.paint(canvas);

  void dispose() => _view.dispose();
}
