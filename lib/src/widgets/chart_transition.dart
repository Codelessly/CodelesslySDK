// Match data by its plotted identity, not by the previous row's position.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart'
    show
        Node,
        Json,
        ChartProps,
        ChartType,
        LineChartProps,
        PlotChartProps,
        PlotChartMarker;

bool isDataChart(Node n) =>
    const {'chart', 'lineChart', 'plotChart'}.contains(n.type);

double? _number(Object? value) {
  final n = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.trim())
      : null;
  return n != null && n.isFinite ? n : null;
}

Object _xIdentity(Object? value, int index) {
  if (_number(value) case final n?) return n;
  if (value is String) {
    final date = DateTime.tryParse(value.trim());
    if (date != null) return date.toUtc().millisecondsSinceEpoch.toDouble();
  }
  return ('unplottable', index);
}

typedef _RowKey = (Object?, int);

List<(_RowKey, Json)> _keyed(
  List<Json> rows,
  Object? Function(Json row, int index) key,
) {
  final occurrences = <Object?, int>{};
  return [
    for (var i = 0; i < rows.length; i++)
      (() {
        final identity = key(rows[i], i);
        final occurrence = occurrences.update(
          identity,
          (v) => v + 1,
          ifAbsent: () => 0,
        );
        return ((identity, occurrence), rows[i]);
      })(),
  ];
}

Object? _category(Json row, String field, int index) =>
    row.containsKey(field) ? '${row[field]}' : ('unlabelled', index);

Set<String> _seriesFields(Node n) {
  if (n.prop(ChartProps.chartType) == ChartType.timeline) {
    return {n.prop(ChartProps.startField), n.prop(ChartProps.endField)};
  }
  final series = n.prop(ChartProps.series);
  if (n.prop(ChartProps.chartType) == ChartType.donut) {
    return {series.isEmpty ? 'value' : series.first.field};
  }
  return {
    for (final s in series) s.field,
    for (final s in series)
      if (s.fillTo != null) s.fillTo!,
  };
}

List<Json> _rowsFrame(
  List<Json> from,
  List<Json> to,
  Set<String> fields,
  Object? Function(Json row, int index) oldKey,
  Object? Function(Json row, int index) newKey,
  double t,
) {
  final previous = {for (final e in _keyed(from, oldKey)) e.$1: e.$2};
  return [
    for (final (key, row) in _keyed(to, newKey))
      {
        ...row,
        for (final field in fields)
          if (_number(row[field]) case final target?)
            field:
                (_number(previous[key]?[field]) ?? 0) +
                (target - (_number(previous[key]?[field]) ?? 0)) * t,
      },
  ];
}

bool _rowsChange(
  List<Json> from,
  List<Json> to,
  Set<String> fields,
  Object? Function(Json row, int index) oldKey,
  Object? Function(Json row, int index) newKey,
) {
  final previous = {for (final e in _keyed(from, oldKey)) e.$1: e.$2};
  for (final (key, row) in _keyed(to, newKey)) {
    for (final field in fields) {
      final target = _number(row[field]);
      if (target != null && target != (_number(previous[key]?[field]) ?? 0)) {
        return true;
      }
    }
  }
  return false;
}

List<Json> _plotMarkers(Node n) => [
  for (final marker in n.prop(PlotChartProps.markers)) marker.toJson(),
];

Object _markerKey(Json row, int index) => _xIdentity(row['x'], index);

bool _sameModel(Node from, Node to) =>
    from.type == to.type &&
    switch (to.type) {
      'chart' =>
        from.prop(ChartProps.labelField) == to.prop(ChartProps.labelField) &&
            from.prop(ChartProps.chartType) == to.prop(ChartProps.chartType),
      'lineChart' =>
        from.prop(LineChartProps.xField) == to.prop(LineChartProps.xField) &&
            from.prop(LineChartProps.yField) == to.prop(LineChartProps.yField),
      'plotChart' => true,
      _ => false,
    };

/// Only changes to plotted numeric values start a timeline. Labels, colours,
/// bounds, cursor positions and overlays' cosmetics apply immediately.
bool chartDataChanges(Node from, Node to) {
  if (!_sameModel(from, to)) return false;
  switch (to.type) {
    case 'chart':
      final label = to.prop(ChartProps.labelField);
      return _rowsChange(
        from.prop(ChartProps.data),
        to.prop(ChartProps.data),
        _seriesFields(to),
        (row, i) => _category(row, label, i),
        (row, i) => _category(row, label, i),
      );
    case 'lineChart':
      final x = to.prop(LineChartProps.xField),
          y = to.prop(LineChartProps.yField);
      return _rowsChange(
            from.prop(LineChartProps.data),
            to.prop(LineChartProps.data),
            {y},
            (row, i) => _xIdentity(row[x], i),
            (row, i) => _xIdentity(row[x], i),
          ) ||
          _rowsChange(
            from.prop(LineChartProps.markers),
            to.prop(LineChartProps.markers),
            {'y'},
            _markerKey,
            _markerKey,
          );
    case 'plotChart':
      final old = from.prop(PlotChartProps.points),
          target = to.prop(PlotChartProps.points);
      // Zooming without changing the samples is a domain edit, not new data.
      final valuesChanged =
          old.length != target.length ||
          Iterable.generate(target.length).any((i) => old[i] != target[i]);
      return (valuesChanged &&
              Iterable.generate(
                target.length,
              ).any((i) => _plotValue(from, _plotX(to, i)) != target[i])) ||
          _rowsChange(
            _plotMarkers(from),
            _plotMarkers(to),
            {'y'},
            _markerKey,
            _markerKey,
          );
    default:
      return false;
  }
}

double _plotX(Node n, int i) {
  final count = n.prop(PlotChartProps.points).length;
  return n.prop(PlotChartProps.xMin) +
      (count <= 1
          ? 0
          : i *
                (n.prop(PlotChartProps.xMax) - n.prop(PlotChartProps.xMin)) /
                (count - 1));
}

double _plotValue(Node n, double x) {
  final values = n.prop(PlotChartProps.points);
  if (values.isEmpty) return 0;
  final x0 = n.prop(PlotChartProps.xMin), x1 = n.prop(PlotChartProps.xMax);
  if (x < math.min(x0, x1) || x > math.max(x0, x1)) return 0;
  if (values.length == 1 || x0 == x1) return values.first;
  final at = ((x - x0) / (x1 - x0)).clamp(0.0, 1.0) * (values.length - 1);
  final i = at.floor().clamp(0, values.length - 2);
  return values[i] + (values[i + 1] - values[i]) * (at - i);
}

/// Keeps the target's topology and metadata. Entering values grow from zero,
/// removed rows leave immediately, and null/missing values stay gaps. Plot
/// samples use the old curve at each target x, so resampling never pairs
/// unrelated indices. Target domain/style values are never interpolated.
Node chartDataFrame(Node from, Node to, double t) {
  if (t >= 1 || !_sameModel(from, to)) return to;
  switch (to.type) {
    case 'chart':
      final label = to.prop(ChartProps.labelField);
      return to.withProp(
        ChartProps.data,
        _rowsFrame(
          from.prop(ChartProps.data),
          to.prop(ChartProps.data),
          _seriesFields(to),
          (row, i) => _category(row, label, i),
          (row, i) => _category(row, label, i),
          t,
        ),
      );
    case 'lineChart':
      final x = to.prop(LineChartProps.xField),
          y = to.prop(LineChartProps.yField);
      return to
          .withProp(
            LineChartProps.data,
            _rowsFrame(
              from.prop(LineChartProps.data),
              to.prop(LineChartProps.data),
              {y},
              (row, i) => _xIdentity(row[x], i),
              (row, i) => _xIdentity(row[x], i),
              t,
            ),
          )
          .withProp(
            LineChartProps.markers,
            _rowsFrame(
              from.prop(LineChartProps.markers),
              to.prop(LineChartProps.markers),
              {'y'},
              _markerKey,
              _markerKey,
              t,
            ),
          );
    case 'plotChart':
      final values = to.prop(PlotChartProps.points);
      final markers = _rowsFrame(
        _plotMarkers(from),
        _plotMarkers(to),
        {'y'},
        _markerKey,
        _markerKey,
        t,
      );
      return to
          .withProp(PlotChartProps.points, [
            for (var i = 0; i < values.length; i++)
              _plotValue(from, _plotX(to, i)) +
                  (values[i] - _plotValue(from, _plotX(to, i))) * t,
          ])
          .withProp(PlotChartProps.markers, [
            for (final m in markers) PlotChartMarker.fromJson(m)!,
          ]);
    default:
      return to;
  }
}

/// A domain edit during an active plot transition moves the plot immediately
/// without changing the already-aligned starting samples or restarting time.
Node chartTransitionRestyle(Node from, Node to) => to.type == 'plotChart'
    ? from
          .withProp(PlotChartProps.xMin, to.prop(PlotChartProps.xMin))
          .withProp(PlotChartProps.xMax, to.prop(PlotChartProps.xMax))
    : from;
