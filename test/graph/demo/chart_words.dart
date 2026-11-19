// The chart types as documents wrote them before the graph: `barChart`,
// `chart` (bars, a donut), `lineChart` and `plotChart` nodes, unchanged.
// Each is now a word over the graph and is drawn by it.
import 'package:codelessly_sdk/codelessly_sdk.dart';

Json _title(String text, double width) => {
      'type': 'text',
      'layout': {'width': width, 'height': {'hug': 22}},
      'props': {
        'text': text,
        'style': {'fontSize': 14, 'fontWeight': 600, 'color': '#FF111827', 'fontFamily': 'Roboto'},
      },
    };

const _axis = {'fontFamily': 'Roboto', 'fontSize': 11, 'color': '#FF6B7280'};

final Map<String, Json> chartWordNodes = {
  'page': {
    'type': 'column',
    'children': ['row1', 'row2'],
    'layout': {'width': 920, 'height': {'hug': 600}},
  },
  'row1': {
    'type': 'row',
    'children': ['c1', 'c2', 'c3'],
    'layout': {'width': 920, 'height': {'hug': 260}},
  },
  'row2': {
    'type': 'row',
    'children': ['c4', 'c5'],
    'layout': {'width': 920, 'height': {'hug': 280}},
  },
  'c1': {
    'type': 'column',
    'children': ['t1', 'bars'],
    'layout': {'width': 280, 'height': {'hug': 260}},
  },
  't1': _title('barChart', 280),
  'bars': {
    'type': 'barChart',
    'layout': {'width': 260, 'height': 200},
    'props': {
      'values': [3, 5, 4, 6, 2, 7, 5],
      'labels': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      'highlight': 5,
      'color': '#FF2563EB',
      'barRadius': 4,
      'gridLines': 4,
      'max': 8,
      'gridLabels': ['0', '2', '4', '6', '8'],
      'gridLabelWidth': 28,
      'gridLabelsLeft': true,
      'gridColor': '#14000000',
      'labelColor': '#FF6B7280',
      'labelFontFamily': 'Roboto',
      'labelFontSize': 11,
    },
  },
  'c2': {
    'type': 'column',
    'children': ['t2', 'stacked'],
    'layout': {'width': 400, 'height': {'hug': 260}},
  },
  't2': _title('chart, bar: selectOnHover, tooltip, dimUnselected', 400),
  'stacked': {
    'type': 'chart',
    'layout': {'width': 380, 'height': 200},
    'props': {
      'chartType': 'bar',
      'data': [
        {'label': '7A', 'a': 3, 'b': 1},
        {'label': '8A', 'a': 10, 'b': 4},
        {'label': '9A', 'a': 6, 'b': 2},
        {'label': '10A', 'a': 8, 'b': 3},
        {'label': '11A', 'a': 5, 'b': 5},
      ],
      'series': [
        {'field': 'a', 'name': 'General', 'color': '#FF2563EB', 'stack': 's'},
        {'field': 'b', 'name': 'VIP', 'color': '#FFF59E0B', 'stack': 's'},
      ],
      'selectOnHover': true,
      'dimUnselected': true,
      'tooltip': true,
      'showTotals': true,
      'barRadius': 3,
      'gridColor': '#14000000',
      'axisLabelColor': '#FF6B7280',
      'axisFontFamily': 'Roboto',
      'axisFontSize': 11,
      'referenceLines': [
        {'value': 12, 'color': '#FFEF4444', 'label': 'CAPACITY 12', 'dashed': true},
      ],
    },
  },
  'c3': {
    'type': 'column',
    'children': ['t3', 'donut'],
    'layout': {'width': 220, 'height': {'hug': 260}},
  },
  't3': _title('chart, donut', 220),
  'donut': {
    'type': 'chart',
    'layout': {'width': 190, 'height': 190},
    'props': {
      'chartType': 'donut',
      'donutThickness': 0.2,
      'selectOnHover': true,
      'tooltip': true,
      'labelField': 'label',
      'series': [
        {'field': 'value', 'name': 'Spend', 'colorField': 'color'},
      ],
      'data': [
        {'label': 'Rent', 'value': 60, 'color': '#FF2563EB'},
        {'label': 'Food', 'value': 25, 'color': '#FF719AF2'},
        {'label': 'Other', 'value': 15, 'color': '#FFA8C1F7'},
      ],
    },
  },
  'c4': {
    'type': 'column',
    'children': ['t4', 'line'],
    'layout': {'width': 480, 'height': {'hug': 280}},
  },
  't4': _title('lineChart: numeric x, told ticks, markers, lines, scrubEnabled', 480),
  'line': {
    'type': 'lineChart',
    'layout': {'width': 460, 'height': 230},
    'props': {
      'data': [
        {'x': 9, 'y': 12}, {'x': 9.5, 'y': 18}, {'x': 10, 'y': 15}, {'x': 11, 'y': 26}, {'x': 12, 'y': 22},
        {'x': 13, 'y': 31}, {'x': 14.5, 'y': 28}, {'x': 15, 'y': 36}, {'x': 16, 'y': 33},
      ],
      'xMin': 9,
      'xMax': 16,
      'yMin': 0,
      'yMax': 40,
      'plotPadding': [36, 12, 0, 24],
      'lineColor': '#FF2563EB',
      'areaTopColor': '#402563EB',
      'gridColor': '#14000000',
      'axisLabelStyle': _axis,
      'scrubEnabled': true,
      'xTicks': [
        {'x': 9, 'label': '9 AM'}, {'x': 12, 'label': 'Noon'}, {'x': 16, 'label': '4 PM'},
      ],
      'yTicks': [
        {'y': 0, 'label': '0'}, {'y': 20, 'label': '20'}, {'y': 40, 'label': '40'},
      ],
      'markers': [
        {'x': 13, 'y': 31, 'label': 'Peak', 'color': '#FFEF4444'},
      ],
      'verticalLines': [
        {'x': 14.5, 'label': 'Now', 'color': '#FF9CA3AF'},
      ],
      'referenceLines': [
        {'y': 25, 'label': 'Goal', 'color': '#FF10B981'},
      ],
    },
  },
  'c5': {
    'type': 'column',
    'children': ['t5', 'plot'],
    'layout': {'width': 420, 'height': {'hug': 280}},
  },
  't5': _title('plotChart: points over a stretch, a range, selectable', 420),
  'plot': {
    'type': 'plotChart',
    'layout': {'width': 400, 'height': 230},
    'props': {
      'points': [2, 3.5, 3, 4.6, 4.1, 5.2, 4.8, 6.1, 5.4, 6.8, 7.2],
      'xMin': 0,
      'xMax': 10,
      'yMin': 0,
      'yMax': 8,
      'lineColor': '#FF7C3AED',
      'fillColor': '#227C3AED',
      'lineWidth': 2.5,
      'smooth': true,
      'gridColor': '#14000000',
      'gridStepX': 2,
      'gridStepY': 2,
      'yAxisWidth': 28,
      'labelStyle': _axis,
      'xLabels': [
        {'x': 0, 'label': 'Start'}, {'x': 5, 'label': 'Halfway'}, {'x': 10, 'label': 'End'},
      ],
      'ranges': [
        {'from': 6, 'to': 8, 'color': '#1FF59E0B', 'label': 'Sprint'},
      ],
      'selectedX': 4,
    },
  },
};
