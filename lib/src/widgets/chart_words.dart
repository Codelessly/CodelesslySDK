// The chart types as words over the graph: `barChart`, `lineChart`, `chart`
// and `plotChart` are each written out as a graph (its spec and rows) and
// drawn by it. Nothing here draws: a chart's look is the graph's, and what
// a chart type says that the graph has no word for is not drawn.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show BarChartProps, ChartProps, ChartSeriesKind, ChartType, Json, LineChartProps, Node, PlotChartProps;


/// A chart as a graph: the graph's spec, its rows and its pinned selection.
typedef ChartGraph = ({Json spec, List<Json> data, Json? selected});

String _hex(api.Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
String? _hexOr(api.Color? c) => c == null ? null : _hex(c);

const _still = {'dragPan': false, 'wheelZoom': false, 'pinchZoom': false, 'axisScale': false, 'doubleTapReset': false};
const _noCrosshair = {'enabled': false};

Json _style({api.Color? grid, api.Color? text, double? fontSize, String? fontFamily, double topInset = 0}) => {
      'grid': ?_hexOr(grid),
      'text': ?_hexOr(text),
      'fontSize': ?fontSize,
      'fontFamily': ?fontFamily,
      if (topInset > 0) 'topInset': topInset,
    };

/// The graph a chart node of any of the four types says; null for another
/// type.
ChartGraph? chartGraphOf(Node n) => switch (n.type) {
      'barChart' => barChartGraph(n),
      'chart' => seriesChartGraph(n),
      'lineChart' => lineChartGraph(n),
      'plotChart' => plotChartGraph(n),
      _ => null,
    };

/// `barChart`: a bar per value, a label under each.
ChartGraph barChartGraph(Node n) {
  T p<T>(api.PropDef<T> def) => n.prop(def);
  final values = p(BarChartProps.values), labels = p(BarChartProps.labels);
  final colors = p(BarChartProps.colors);
  final color = p(BarChartProps.color);
  final gridLabels = p(BarChartProps.gridLabels);
  final max = p(BarChartProps.max);
  final highlight = p(BarChartProps.highlight);
  final fontSize = p(BarChartProps.labelFontSize);
  final most = values.whereType<double>().fold(0.0, math.max);
  final top = max > 0 ? max : (most > 0 ? most : 1.0);
  final lines = p(BarChartProps.gridLines);
  return (
    data: [
      for (var i = 0; i < values.length; i++) {'i': i, 'label': i < labels.length ? labels[i] : '', 'value': values[i]},
    ],
    selected: highlight == null ? null : {'index': highlight},
    spec: {
      'key': 'i',
      'animate': p(BarChartProps.animate) ? p(BarChartProps.animationDuration) : 0,
      'x': {
        'label': 'label',
        'format': '',
        'fit': 'bars',
        'grid': false,
        'tickEvery': 1,
        // With no limit written a bar is at most 56 wide, in the middle of
        // its place: a few values in a wide card were slabs.
        'maxBarWidth': p(BarChartProps.maxBarWidth) ?? 56,
        'labels': labels.isNotEmpty,
        'axisHeight': labels.isEmpty ? 0 : p(BarChartProps.labelAreaHeight) ?? fontSize + p(BarChartProps.labelGap) + 8,
      },
      'panes': [
        {
          'y': {
            'domain': 'fixed',
            'min': 0,
            'max': top + p(BarChartProps.barHeadroom) * 0,
            'side': p(BarChartProps.gridLabelsLeft) ? 'left' : 'right',
            'width': gridLabels.isEmpty ? 0 : p(BarChartProps.gridLabelWidth),
            'labels': gridLabels.isNotEmpty,
            'decimals': p(BarChartProps.valueDecimals) ?? 0,
            'suffix': p(BarChartProps.valueSuffix),
            // The lines the chart asks for, evenly from zero to the top,
            // with the labels it gives them.
            'ticks': lines,
            if (lines > 0)
              'tickValues': [
                for (var k = 0; k <= lines; k++)
                  {'value': top * k / lines, if (k < gridLabels.length) 'label': gridLabels[k]},
              ],
          },
          'marks': [
            {
              'type': 'bar',
              'y': 'value',
              'name': 'Value',
              'color': ?_hexOr(color),
              if (colors.isNotEmpty) 'colors': [for (final c in colors) _hex(c)],
              'radius': p(BarChartProps.barRadius),
              'labels': p(BarChartProps.showValues),
            },
          ],
        },
      ],
      'selection': {'on': 'none', 'dim': p(BarChartProps.dimmedOpacity), 'tooltip': false},
      'crosshair': _noCrosshair,
      'interactions': _still,
      'style': _style(
        grid: p(BarChartProps.gridColor),
        text: p(BarChartProps.labelColor),
        fontSize: fontSize,
        fontFamily: p(BarChartProps.labelFontFamily),
      ),
    },
  );
}

/// `chart`: series over data rows as bars, lines and areas, or a donut.
ChartGraph seriesChartGraph(Node n) {
  T p<T>(api.PropDef<T> def) => n.prop(def);
  final type = p(ChartProps.chartType);
  final series = p(ChartProps.series);
  final data = p(ChartProps.data);
  final selectedIndex = p(ChartProps.selectedIndex);
  final hover = p(ChartProps.selectOnHover);
  final style = _style(
    grid: p(ChartProps.gridColor),
    text: p(ChartProps.axisLabelColor),
    fontSize: p(ChartProps.axisFontSize),
    fontFamily: p(ChartProps.axisFontFamily),
  );
  final selection = {
    'on': hover ? 'both' : 'none',
    'dim': p(ChartProps.dimUnselected) || type == ChartType.donut ? 0.35 : 1,
    'tooltip': p(ChartProps.tooltip),
    if (p(ChartProps.tooltipTitleField).isNotEmpty) 'title': p(ChartProps.tooltipTitleField),
    'tooltipFill': ?_hexOr(p(ChartProps.tooltipColor)),
    'tooltipText': ?_hexOr(p(ChartProps.tooltipTextColor)),
    'total': p(ChartProps.showTotals),
  };
  final selected = selectedIndex >= 0 ? <String, Object?>{'index': selectedIndex} : null;
  final labelField = p(ChartProps.labelField);
  final rows = [
    for (var i = 0; i < data.length; i++) {...data[i], '_row': i},
  ];

  if (type == ChartType.donut) {
    final first = series.firstOrNull;
    return (
      data: rows,
      selected: selected,
      spec: {
        'key': '_row',
        'animate': p(ChartProps.animate) ? p(ChartProps.animationDuration) : 0,
        'animateIn': p(ChartProps.animateIn),
        'x': {'label': labelField, 'format': '', 'axisHeight': 0},
        'panes': [
          {
            'coord': 'polar',
            'y': {'width': 0, 'decimals': 0},
            'marks': [
              {
                'type': 'arc',
                'y': first?.field ?? 'value',
                'name': first == null || first.name.isEmpty ? 'Value' : first.name,
                if (first != null) 'color': _hex(first.color),
                if (first?.colorField case final field?) 'colorField': field,
                // The ring is this share of the diameter thick.
                'inner': (1 - 2 * p(ChartProps.donutThickness)).clamp(0.0, 0.96),
                'gap': p(ChartProps.sliceGap),
                'startAngle': p(ChartProps.startAngle),
              },
            ],
          },
        ],
        'selection': {...selection, 'by': 'mark', 'grow': 4},
        'crosshair': _noCrosshair,
        'style': style,
      },
    );
  }

  final line = type == ChartType.line;
  final minY = p(ChartProps.minY), maxY = p(ChartProps.maxY);
  final band = p(ChartProps.selectionColor);
  return (
    data: rows,
    selected: selected,
    spec: {
      'key': '_row',
      'animate': p(ChartProps.animate) ? p(ChartProps.animationDuration) : 0,
      'animateIn': p(ChartProps.animateIn),
      'x': {
        'label': labelField,
        'format': '',
        'fit': line ? 'points' : 'bars',
        if (p(ChartProps.xSlots) > 0) 'slots': p(ChartProps.xSlots) + (line ? 1 : 0),
        'grid': false,
        'tickEvery': math.max(1, p(ChartProps.xLabelEvery)),
        'labels': p(ChartProps.showXAxis),
        'axisHeight': p(ChartProps.showXAxis) ? p(ChartProps.xAxisHeight) : 0,
      },
      'panes': [
        {
          'y': {
            'side': 'left',
            'width': p(ChartProps.showYAxis) ? p(ChartProps.yAxisWidth) + 8 : 0,
            'labels': p(ChartProps.showYAxis),
            'decimals': 0,
            'prefix': p(ChartProps.yLabelPrefix),
            'suffix': p(ChartProps.yLabelSuffix),
            'ticks': p(ChartProps.gridLines),
            if (minY != null && maxY != null) ...{
              'domain': 'fixed',
              'min': minY,
              'max': maxY,
            } else ...{
              'domain': 'data',
              'margins': [0.05, 0],
              // From zero, unless the chart fits its least value.
              'include': [
                ?minY,
                ?maxY,
                if (minY == null && !(line && p(ChartProps.fitMinY))) 0,
                for (final r in p(ChartProps.referenceLines)) r.value,
              ],
            },
          },
          'marks': [
            // Areas under lines under bars' tops: fills first.
            for (final s in series)
              if (s.kind == ChartSeriesKind.area)
                {'type': 'area', 'y': s.field, 'name': s.name, 'color': _hex(s.color), 'fillOpacity': s.fillOpacity, 'curved': s.curved},
            for (final s in series)
              if (!line && s.kind == ChartSeriesKind.bar)
                {
                  'type': 'bar',
                  'y': s.field,
                  'name': s.name,
                  'color': _hex(s.color),
                  if (s.colorField case final field?) 'colorField': field,
                  'stack': ?s.stack,
                  'radius': p(ChartProps.barRadius),
                },
            for (final s in series)
              if (s.kind != ChartSeriesKind.bar || line)
                {
                  'type': 'line',
                  'y': s.field,
                  'name': s.name,
                  'color': _hex(s.color),
                  'width': s.strokeWidth,
                  'curved': s.curved,
                  if (s.endDot) 'endDot': s.strokeWidth + 1.5,
                },
          ],
          'guides': [
            for (final r in p(ChartProps.referenceLines))
              {
                'y': r.value,
                'color': _hex(r.color),
                'line': r.dashed ? 'dashed' : 'solid',
                'width': r.strokeWidth,
                'label': r.label,
                'labelColor': ?_hexOr(r.labelColor),
                'below': r.labelBelow,
              },
          ],
        },
      ],
      'selection': {...selection, if (!line && band != null) 'band': _hex(band)},
      'crosshair': _noCrosshair,
      'interactions': _still,
      'style': style,
    },
  );
}

double? _num(Object? v) => v is num ? v.toDouble() : null;
String? _colorText(Object? v) => v is String && v.startsWith('#') ? v : null;

/// `lineChart`: a line (and the area under it) through points placed by
/// their numbers, with ticks, lines and markers the chart is told.
ChartGraph lineChartGraph(Node n) {
  T p<T>(api.PropDef<T> def) => n.prop(def);
  final xField = p(LineChartProps.xField), yField = p(LineChartProps.yField);
  final rows = [
    for (final r in p(LineChartProps.data))
      if (r[xField] is num) r,
  ]..sort((a, b) => (a[xField]! as num).compareTo(b[xField]! as num));
  final pad = p(LineChartProps.plotPadding);
  final label = p(LineChartProps.axisLabelStyle);
  final yMin = p(LineChartProps.yMin), yMax = p(LineChartProps.yMax);
  final line = p(LineChartProps.lineColor), top = p(LineChartProps.areaTopColor);
  final selectedX = p(LineChartProps.selectedX);
  final at = selectedX == null ? -1 : rows.indexWhere((r) => r[xField] == selectedX);
  final yTicks = p(LineChartProps.yTicks), xTicks = p(LineChartProps.xTicks);
  final zero = p(LineChartProps.zeroLineColor);
  return (
    data: rows,
    selected: at < 0 ? null : {'index': at},
    spec: {
      'key': xField,
      'animate': p(LineChartProps.animate) ? p(LineChartProps.animationDuration) : 0,
      'animateIn': p(LineChartProps.animateIn),
      'x': {
        'scale': 'linear',
        'field': xField,
        'label': p(LineChartProps.tooltipLabelField).isEmpty ? xField : p(LineChartProps.tooltipLabelField),
        'format': '',
        'min': ?p(LineChartProps.xMin),
        'max': ?p(LineChartProps.xMax),
        'grid': false,
        'labels': xTicks.isNotEmpty,
        'axisHeight': pad.bottom,
        'tickValues': [
          for (final t in xTicks)
            if (_num(t['x']) case final x?) {'value': x, 'label': '${t['label'] ?? ''}'},
        ],
      },
      'panes': [
        {
          'y': {
            'side': 'left',
            'width': pad.left,
            'labels': yTicks.isNotEmpty,
            'decimals': p(LineChartProps.tooltipYDecimals),
            'suffix': p(LineChartProps.tooltipYSuffix),
            if (yMin != null && yMax != null) ...{
              'domain': 'fixed',
              'min': yMin,
              'max': yMax,
            } else ...{
              'domain': 'data',
              'include': [?yMin, ?yMax],
            },
            'tickValues': [
              for (final t in yTicks)
                if (_num(t['y']) case final y?) {'value': y, 'label': '${t['label'] ?? ''}'},
            ],
            if (yTicks.isEmpty) 'ticks': 0,
          },
          'marks': [
            if (top != null && top.alpha > 0)
              {
                'type': 'area',
                'y': yField,
                'color': _hex(top),
                'fillOpacity': 1,
                'fillTo': _hex(p(LineChartProps.areaBottomColor)),
                'curved': p(LineChartProps.smooth),
              },
            {
              'type': 'line',
              'y': yField,
              'name': yField,
              'color': ?_hexOr(line),
              'width': p(LineChartProps.lineWidth),
              'curved': p(LineChartProps.smooth),
            },
          ],
          'guides': [
            for (final b in p(LineChartProps.bands))
              if (_num(b['from']) != null && _num(b['to']) != null)
                {'from': b['from'], 'to': b['to'], 'color': _colorText(b['color']) ?? '#14808080', 'label': '${b['label'] ?? ''}'},
            if (zero != null) {'y': 0, 'color': _hex(zero)},
            for (final r in p(LineChartProps.referenceLines))
              if (_num(r['y']) != null)
                {
                  'y': r['y'],
                  'color': ?_colorText(r['color']),
                  'line': r['dash'] == false ? 'solid' : 'dashed',
                  'width': _num(r['width']) ?? 1,
                  'label': '${r['label'] ?? ''}',
                  'labelColor': ?_colorText(r['labelColor']),
                  'below': r['labelBelow'] == true,
                },
            for (final v in p(LineChartProps.verticalLines))
              if (_num(v['x']) != null)
                {
                  'x': v['x'],
                  'color': ?_colorText(v['color']),
                  'line': v['dash'] == false ? 'solid' : 'dashed',
                  'label': '${v['label'] ?? ''}',
                },
            for (final m in p(LineChartProps.markers))
              if (_num(m['x']) != null && _num(m['y']) != null)
                {
                  'x': m['x'],
                  'y': m['y'],
                  'color': _colorText(m['color']) ?? _hexOr(line),
                  'radius': _num(m['radius']) ?? 4,
                  if (m['filled'] == false) 'fill': _hexOr(p(LineChartProps.markerHollowColor)) ?? '#FFFFFFFF',
                  'label': '${m['label'] ?? ''}',
                  'below': m['above'] == false,
                },
          ],
        },
      ],
      'selection': {
        'on': p(LineChartProps.scrubEnabled) ? 'hover' : 'none',
        'dim': 1,
        'tooltipFill': ?_hexOr(p(LineChartProps.tooltipBackground)),
      },
      'crosshair': _noCrosshair,
      'interactions': _still,
      'style': _style(
        grid: p(LineChartProps.gridColor),
        text: label.color,
        fontSize: label.fontSize,
        fontFamily: label.fontFamily,
        topInset: pad.top,
      ),
    },
  );
}

/// `plotChart`: curves of evenly spaced points over an x stretch, with
/// labels, stretches, markers and lines the chart is told.
ChartGraph plotChartGraph(Node n) {
  T p<T>(api.PropDef<T> def) => n.prop(def);
  final xMin = p(PlotChartProps.xMin), xMax = p(PlotChartProps.xMax);
  final series = p(PlotChartProps.series);
  final curves = <(String, List<double?>, api.Color?, double)>[
    if (p(PlotChartProps.points).isNotEmpty)
      ('y', [...p(PlotChartProps.points)], p(PlotChartProps.lineColor), p(PlotChartProps.lineWidth)),
    for (var i = 0; i < series.length; i++) ('s$i', series[i].points, series[i].color, series[i].width),
  ];
  // Every curve's points are spread evenly from xMin to xMax.
  final byX = <double, Json>{};
  for (final (field, points, _, _) in curves) {
    for (var i = 0; i < points.length; i++) {
      final x = points.length < 2 ? xMin : xMin + (xMax - xMin) * i / (points.length - 1);
      (byX[x] ??= {'x': x})[field] = points[i];
    }
  }
  final rows = byX.values.toList()..sort((a, b) => (a['x']! as double).compareTo(b['x']! as double));
  final yMin = p(PlotChartProps.yMin), yMax = p(PlotChartProps.yMax);
  final label = p(PlotChartProps.labelStyle);
  final stepX = p(PlotChartProps.gridStepX), stepY = p(PlotChartProps.gridStepY);
  final xLabels = p(PlotChartProps.xLabels);
  final fill = p(PlotChartProps.fillColor);
  final selectedX = p(PlotChartProps.selectedX);
  final referenceX = p(PlotChartProps.referenceX);
  var at = -1;
  if (selectedX != null && rows.isNotEmpty) {
    at = 0;
    for (var i = 1; i < rows.length; i++) {
      if (((rows[i]['x']! as double) - selectedX).abs() < ((rows[at]['x']! as double) - selectedX).abs()) at = i;
    }
  }
  List<Json> steps(double from, double to, double? step) => [
        if (step != null && step > 0 && (to - from) / step <= 200)
          for (var k = (from / step).ceil(); k * step <= to + 1e-9; k++) {'value': k * step},
      ];
  return (
    data: rows,
    selected: at < 0 ? null : {'index': at},
    spec: {
      'key': 'x',
      'animate': p(PlotChartProps.animate) ? p(PlotChartProps.animationDuration) : 0,
      'x': {
        'scale': 'linear',
        'field': 'x',
        'label': 'x',
        'format': '',
        'min': xMin,
        'max': xMax,
        'grid': stepX != null,
        'labels': xLabels.isNotEmpty,
        'axisHeight': xLabels.isEmpty ? 0 : p(PlotChartProps.labelHeight) + 4,
        'tickValues': xLabels.isNotEmpty
            ? [for (final l in xLabels) {'value': l.x, 'label': l.label}]
            : steps(xMin, xMax, stepX),
      },
      'panes': [
        {
          'y': {
            'side': 'left',
            'width': p(PlotChartProps.yAxisWidth),
            'labels': p(PlotChartProps.yAxisWidth) > 0,
            'decimals': 1,
            if (yMin != null && yMax != null) ...{
              'domain': 'fixed',
              'min': yMin,
              'max': yMax,
            } else ...{
              'domain': 'data',
              'include': [?yMin, ?yMax],
            },
            if (yMin != null && yMax != null && stepY != null) 'tickValues': steps(yMin, yMax, stepY),
          },
          'marks': [
            if (fill != null && curves.isNotEmpty)
              {'type': 'area', 'y': curves.first.$1, 'color': _hex(fill), 'fillOpacity': 1, 'curved': p(PlotChartProps.smooth)},
            for (final (field, _, color, width) in curves)
              {
                'type': 'line',
                'y': field,
                'name': field,
                'color': ?_hexOr(color),
                'width': width,
                'curved': p(PlotChartProps.smooth),
                if (p(PlotChartProps.endDotRadius) > 0) 'endDot': p(PlotChartProps.endDotRadius),
              },
          ],
          'guides': [
            for (final r in p(PlotChartProps.ranges))
              {'from': r.from, 'to': r.to, 'color': _hex(r.color), 'label': r.label, 'labelColor': ?_hexOr(r.labelColor)},
            for (final l in p(PlotChartProps.yLines))
              {'y': l.y, 'color': _hex(l.color), 'width': l.width, 'line': l.dashed ? 'dashed' : 'solid', 'label': l.label},
            if (referenceX != null)
              {
                'x': referenceX,
                'color': ?_hexOr(p(PlotChartProps.referenceColor)),
                'width': p(PlotChartProps.referenceWidth),
                'line': p(PlotChartProps.referenceDashed) ? 'dashed' : 'solid',
              },
            for (final m in p(PlotChartProps.markers))
              if (m.y != null)
                {
                  'x': m.x,
                  'y': m.y,
                  'color': _hex(m.color),
                  'radius': m.radius ?? p(PlotChartProps.markerRadius),
                  'fill': ?_hexOr(m.fillColor),
                  'label': m.label,
                }
              else
                {'x': m.x, 'color': _hex(m.color), 'label': m.label},
          ],
        },
      ],
      'selection': {
        'on': p(PlotChartProps.selectable) ? 'both' : 'none',
        'dim': 1,
        'dot': p(PlotChartProps.selectionDotRadius),
        'band': ?_hexOr(p(PlotChartProps.selectionColor)),
      },
      'crosshair': _noCrosshair,
      'interactions': _still,
      'style': _style(
        grid: p(PlotChartProps.gridColor),
        text: label.color,
        fontSize: label.fontSize,
        fontFamily: label.fontFamily,
      ),
    },
  );
}
