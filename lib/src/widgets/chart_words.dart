// The chart types as words over the graph: `barChart`, `lineChart`, `chart`
// and `plotChart` are each written out as a graph (its spec and rows) and
// drawn by it. Nothing here draws: a chart's look is the graph's, and what
// a chart type says that the graph has no word for is not drawn.
//
// A node that leaves a key out draws as its type always has: nothing of a
// chart's look is chosen here. What a chart asks for by a key of its own
// (a legend, a rounded scale, dots, a fading area, the total in a donut's
// hole, a tooltip) is said in the graph's words; the words of the notation
// that write those keys are codelessly_api's.
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

/// A line up the plot through the row under the pointer, and nothing else
/// of a crosshair: what a line chart shows while it is read.
const _rowLine = {
  'enabled': true,
  'on': 'hover',
  'horizontal': false,
  'line': 'solid',
  'timeLabel': 'none',
  'priceTag': false,
};

/// Room above a rounded scale's top line, so the line and its figure are
/// whole.
const _headroom = 6.0;

/// A chart's legend: none unless it asks; then under a plot when there are
/// two or more named series, and for slices ([polar]) always, beside the
/// ring or under it.
Json _legend(bool show, {bool polar = false}) => {'show': !show ? 'none' : (polar ? 'always' : 'auto')};

Json _style({api.Color? grid, api.Color? text, double? fontSize, String? fontFamily, double topInset = 0}) => {
      'grid': ?_hexOr(grid),
      // The line through the row under the pointer is as quiet as the grid.
      'crosshair': ?_hexOr(grid),
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
  // Round lines over its largest value, each labeled with its own, where
  // the chart asks for them and gives neither a top nor labels.
  final round = p(BarChartProps.gridValues) && max <= 0 && gridLabels.isEmpty && lines > 0;
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
            if (round) ...{
              'domain': 'data',
              'include': [0],
              'nice': true,
            } else ...{
              'domain': 'fixed',
              'min': 0,
              'max': top + p(BarChartProps.barHeadroom) * 0,
            },
            'side': p(BarChartProps.gridLabelsLeft) ? 'left' : 'right',
            'width': gridLabels.isEmpty && !round ? 0 : p(BarChartProps.gridLabelWidth),
            'labels': gridLabels.isNotEmpty || round,
            'decimals': p(BarChartProps.valueDecimals) ?? 0,
            'suffix': p(BarChartProps.valueSuffix),
            // The lines the chart asks for, evenly from zero to the top,
            // with the labels it gives them.
            'ticks': lines,
            if (lines > 0 && !round)
              'tickValues': [
                for (var k = 0; k <= lines; k++)
                  {'value': top * k / lines, if (k < gridLabels.length) 'label': gridLabels[k]},
              ],
          },
          'marks': [
            {
              'type': 'bar',
              'y': 'value',
              'color': ?_hexOr(color),
              if (colors.isNotEmpty) 'colors': [for (final c in colors) _hex(c)],
              'radius': p(BarChartProps.barRadius),
              'labels': p(BarChartProps.showValues),
            },
          ],
        },
      ],
      // Drawn, not offered, unless the chart asks for its tooltip: then the
      // bar under the pointer (or a finger) says its value.
      'selection': p(BarChartProps.tooltip)
          ? {'on': 'hover', 'dim': p(BarChartProps.dimmedOpacity)}
          : {'on': 'none', 'dim': p(BarChartProps.dimmedOpacity), 'tooltip': false},
      'crosshair': _noCrosshair,
      'interactions': _still,
      'legend': _legend(false),
      'style': _style(
        grid: p(BarChartProps.gridColor),
        text: p(BarChartProps.labelColor),
        fontSize: fontSize,
        // An empty family is none of the chart's own.
        fontFamily: p(BarChartProps.labelFontFamily).isEmpty ? null : p(BarChartProps.labelFontFamily),
        // Room over a rounded scale's top line, as a series chart has.
        topInset: round ? _headroom : 0,
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
            'y': {'width': 0, 'decimals': 0, 'prefix': p(ChartProps.yLabelPrefix), 'suffix': p(ChartProps.yLabelSuffix)},
            'marks': [
              {
                'type': 'arc',
                'y': first?.field ?? 'value',
                'name': ?(first == null || first.name.isEmpty ? null : first.name),
                // A series that says no color: each slice the palette's next.
                if (first != null && (first.toJson() as Map).containsKey('color')) 'color': _hex(first.color),
                if (first?.colorField case final field?) 'colorField': field,
                // The ring is this share of the diameter thick.
                'inner': (1 - 2 * p(ChartProps.donutThickness)).clamp(0.0, 0.96),
                'gap': p(ChartProps.sliceGap),
                'startAngle': p(ChartProps.startAngle),
                // The whole in the hole, when the chart says what it is.
                if (p(ChartProps.centerLabel) case final label?) ...{'center': 'total', 'centerLabel': label},
              },
            ],
          },
        ],
        'selection': {...selection, 'by': 'mark', 'grow': 4},
        'crosshair': _noCrosshair,
        // Its slices' labels with their shares, beside it where its box has
        // the room.
        'legend': _legend(p(ChartProps.legend), polar: true),
        'style': style,
      },
    );
  }

  final line = type == ChartType.line;
  final inset = p(ChartProps.plotInset) ?? 0;
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
        // The widest a bar is drawn, where the chart says one.
        if (!line) 'maxBarWidth': ?p(ChartProps.maxBarWidth),
        // A line's ends and their dots stand whole inside the plot.
        if (line && inset > 0) 'inset': inset,
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
              // Out to the grid's lines: the plot starts and ends on one.
              'nice': p(ChartProps.roundScale) && p(ChartProps.gridLines) > 0,
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
                {
                  'type': 'area',
                  'y': s.field,
                  'name': s.name,
                  'color': _hex(s.color),
                  // Strongest under the line, gone at the foot of the plot.
                  'fillOpacity': s.fillOpacity,
                  'fade': s.fade,
                  'curved': s.curved,
                },
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
                  // Few enough points to tell apart: a dot on each.
                  if (rows.length <= p(ChartProps.dots) && !s.endDot) 'dots': s.strokeWidth + 1,
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
      'crosshair': line && hover && p(ChartProps.cursorLine) ? _rowLine : _noCrosshair,
      'interactions': _still,
      'legend': _legend(p(ChartProps.legend)),
      'style': {...style, if (inset > 0) 'topInset': inset},
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
  final written = p(LineChartProps.data);
  // Rows whose x is a name (a day, a month) and no number: in the order
  // written, a step apart, each labelled by it under the plot. (They were
  // left out, and the chart drew nothing.)
  final named = written.isNotEmpty && written.every((r) => r[xField] is! num) && written.any((r) => r[xField] != null);
  const place = '_x';
  final x = named ? place : xField;
  final rows = named
      ? [
          for (var i = 0; i < written.length; i++) {...written[i], place: i},
        ]
      : ([
          for (final r in written)
            if (r[xField] is num) r,
        ]..sort((a, b) => (a[xField]! as num).compareTo(b[xField]! as num)));
  final pad = p(LineChartProps.plotPadding);
  final label = p(LineChartProps.axisLabelStyle);
  final yMin = p(LineChartProps.yMin), yMax = p(LineChartProps.yMax);
  final line = p(LineChartProps.lineColor), top = p(LineChartProps.areaTopColor);
  final selectedX = p(LineChartProps.selectedX);
  final at = selectedX == null ? -1 : rows.indexWhere((r) => r[xField] == selectedX);
  final yTicks = p(LineChartProps.yTicks), xTicks = p(LineChartProps.xTicks);
  final zero = p(LineChartProps.zeroLineColor);
  // Where the chart asks for them and gives no ticks of its own: round
  // ones with their numbers, in the room it keeps left of the plot.
  final ownTicks = p(LineChartProps.gridValues) && yTicks.isEmpty && pad.left >= 24;
  final whole = rows.every((r) => r[yField] is! num || r[yField] == (r[yField]! as num).roundToDouble());
  final scrub = p(LineChartProps.scrubEnabled);
  return (
    data: rows,
    selected: at < 0 ? null : {'index': at},
    spec: {
      'key': x,
      'animate': p(LineChartProps.animate) ? p(LineChartProps.animationDuration) : 0,
      'animateIn': p(LineChartProps.animateIn),
      'x': {
        'scale': 'linear',
        'field': x,
        'label': p(LineChartProps.tooltipLabelField).isEmpty ? xField : p(LineChartProps.tooltipLabelField),
        'format': '',
        'min': ?p(LineChartProps.xMin),
        'max': ?p(LineChartProps.xMax),
        'grid': false,
        'labels': xTicks.isNotEmpty || named,
        'axisHeight': pad.bottom,
        'tickValues': [
          if (named && xTicks.isEmpty)
            for (var i = 0; i < written.length; i++) {'value': i, 'label': '${written[i][xField] ?? ''}'},
          for (final t in xTicks)
            if (_num(t['x']) case final x?) {'value': x, 'label': '${t['label'] ?? ''}'},
        ],
      },
      'panes': [
        {
          'y': {
            'side': 'left',
            'width': pad.left,
            'labels': yTicks.isNotEmpty || ownTicks,
            'decimals': ownTicks && whole && !n.props.has(LineChartProps.tooltipYDecimals) ? 0 : p(LineChartProps.tooltipYDecimals),
            'suffix': p(LineChartProps.tooltipYSuffix),
            if (yMin != null && yMax != null) ...{
              'domain': 'fixed',
              'min': yMin,
              'max': yMax,
            } else ...{
              'domain': 'data',
              'include': [?yMin, ?yMax],
              'nice': ownTicks,
            },
            'tickValues': [
              for (final t in yTicks)
                if (_num(t['y']) case final y?) {'value': y, 'label': '${t['label'] ?? ''}'},
            ],
            if (yTicks.isEmpty) 'ticks': ownTicks ? 4 : 0,
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
        'on': scrub ? 'hover' : 'none',
        'dim': 1,
        'tooltip': p(LineChartProps.tooltip),
        'tooltipFill': ?_hexOr(p(LineChartProps.tooltipBackground)),
      },
      'crosshair': scrub && p(LineChartProps.cursorLine) ? _rowLine : _noCrosshair,
      'interactions': _still,
      'legend': _legend(false),
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
