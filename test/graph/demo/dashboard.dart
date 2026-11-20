// An analytics dashboard written as a document: three `graph` nodes (stacked
// bars, a donut, a line) and the texts that read what they publish. Nothing
// here is a widget of its own: the page is JSON, shown by a NodeView.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';

const _still = {'dragPan': false, 'wheelZoom': false, 'pinchZoom': false, 'axisScale': false, 'doubleTapReset': false};
const _ink = '#FF111827', _muted = '#FF6B7280';

Json _text(String text, {double size = 13, int weight = 400, String color = _ink, double width = 440, String? bind}) => {
      'type': 'text',
      'layout': {'width': width, 'height': {'hug': size * 1.5}},
      'props': {
        'text': text,
        'style': {'fontSize': size, 'fontWeight': weight, 'color': color, 'fontFamily': 'Roboto'},
      },
      if (bind != null) 'bind': {'props.text': bind},
    };

Json _set(String variable) => {
      'trigger': {'type': 'changed'},
      'actions': [
        {'type': 'setVariable', 'variable': variable, 'value': r'${result.selection}'},
      ],
    };

const _style = {'fontFamily': 'Roboto', 'text': _muted, 'grid': '#14000000'};

final Map<String, Json> dashboardNodes = {
  'page': {
    'type': 'column',
    'children': ['title', 'top', 'sessionsTitle', 'sessionsRead', 'sessions'],
    'layout': {'width': 920, 'height': {'hug': 700}},
  },
  'title': _text('Analytics', size: 22, weight: 700, width: 920),
  'top': {
    'type': 'row',
    'children': ['revenueCard', 'trafficCard'],
    'layout': {'width': 920, 'height': {'hug': 320}},
  },
  'revenueCard': {
    'type': 'column',
    'children': ['revenueTitle', 'revenueRead', 'revenue'],
    'layout': {'width': 560, 'height': {'hug': 320}},
  },
  'revenueTitle': _text('Revenue by channel', size: 15, weight: 600, width: 560),
  'revenueRead': _text('', color: _muted, width: 560, bind: r"${= rev.label == null ? 'Hover a month, or tap to pin it' : rev.label + ': web $' + rev.row.web + 'k, store $' + rev.row.store + 'k, partners $' + rev.row.partners + 'k' + (rev.pinned ? ' (pinned)' : '')}"),
  'revenue': {
    'type': 'graph',
    'layout': {'width': 540, 'height': 260},
    'props': {
      'rowKey': 'month',
      'data': [
        {'month': 'Jan', 'web': 42, 'store': 18, 'partners': 9},
        {'month': 'Feb', 'web': 48, 'store': 21, 'partners': 11},
        {'month': 'Mar', 'web': 55, 'store': 19, 'partners': 14},
        {'month': 'Apr', 'web': 51, 'store': 24, 'partners': 13},
        {'month': 'May', 'web': 63, 'store': 26, 'partners': 17},
        {'month': 'Jun', 'web': 70, 'store': 23, 'partners': 21},
        {'month': 'Jul', 'web': 66, 'store': 28, 'partners': 19},
        {'month': 'Aug', 'web': 78, 'store': 31, 'partners': 24},
      ],
      'xAxis': {'label': 'month', 'fit': 'bars', 'axisHeight': 24, 'grid': false},
      'yAxis': {'width': 44, 'decimals': 0},
      'marks': [
        {'type': 'bar', 'y': 'web', 'name': 'Web', 'color': '#FF2563EB', 'stack': 'r', 'radius': 4},
        {'type': 'bar', 'y': 'store', 'name': 'Store', 'color': '#FF60A5FA', 'stack': 'r', 'radius': 4},
        {'type': 'bar', 'y': 'partners', 'name': 'Partners', 'color': '#FFBFDBFE', 'stack': 'r', 'radius': 4},
      ],
      'selection': {'on': 'both', 'band': '#0F111827', 'total': true},
      'crosshair': {'enabled': false},
      'interactions': _still,
      'style': _style,
    },
    'actions': [_set('rev')],
  },
  'trafficCard': {
    'type': 'column',
    'children': ['trafficTitle', 'trafficRead', 'traffic'],
    'layout': {'width': 340, 'height': {'hug': 320}},
  },
  'trafficTitle': _text('Traffic sources', size: 15, weight: 600, width: 340),
  'trafficRead': _text('', color: _muted, width: 340, bind: r"${= src.label == null ? 'Hover a slice' : src.label + ': ' + src.value + '% of visits'}"),
  'traffic': {
    'type': 'graph',
    'layout': {'width': 260, 'height': 260},
    'props': {
      'rowKey': 'source',
      'coord': 'polar',
      'data': [
        {'source': 'Search', 'share': 46},
        {'source': 'Direct', 'share': 24},
        {'source': 'Social', 'share': 17},
        {'source': 'Email', 'share': 9},
        {'source': 'Other', 'share': 4},
      ],
      'xAxis': {'label': 'source', 'axisHeight': 0},
      'yAxis': {'width': 0, 'decimals': 0},
      'marks': [
        {
          'type': 'arc',
          'y': 'share',
          'name': 'Visits',
          'inner': 0.62,
          'gap': 1.5,
          'colors': ['#FF2563EB', '#FF10B981', '#FFF59E0B', '#FFEF4444', '#FF9CA3AF'],
        },
      ],
      'selection': {'on': 'both', 'by': 'mark', 'grow': 6},
      'crosshair': {'enabled': false},
      'style': _style,
    },
    'actions': [_set('src')],
  },
  'sessionsTitle': _text('Sessions, last 30 days', size: 15, weight: 600, width: 920),
  'sessionsRead': _text('', color: _muted, width: 920, bind: r"${= ses.label == null ? 'Hover the line' : 'Day ' + ses.label + ': ' + ses.row.sessions + ' sessions, ' + ses.row.signups + ' signups'}"),
  'sessions': {
    'type': 'graph',
    'layout': {'width': 900, 'height': 240},
    'props': {
      'rowKey': 'day',
      'data': [
        for (var d = 1; d <= 30; d++)
          {
            'day': d,
            'sessions': 1200 + (d * 37) % 410 + d * 22 + (d % 7 == 0 ? -380 : 0),
            'signups': 90 + (d * 13) % 60 + d * 2,
          },
      ],
      'xAxis': {'label': 'day', 'format': '', 'fit': 'points', 'axisHeight': 24, 'grid': false, 'tickEvery': 5},
      'panes': [
        {
          'yAxis': {'width': 52, 'decimals': 0, 'include': [0]},
          'marks': [
            {'type': 'area', 'y': 'sessions', 'name': 'Sessions', 'color': '#FF2563EB', 'fade': true, 'fillOpacity': 0.22},
            {'type': 'line', 'y': 'sessions', 'name': 'Sessions', 'color': '#FF2563EB', 'width': 2},
            {'type': 'line', 'y': 'signups', 'name': 'Signups', 'color': '#FF10B981', 'width': 2},
          ],
        },
      ],
      'selection': {'on': 'both', 'band': '#0F111827', 'title': 'day'},
      'crosshair': {'enabled': false},
      'interactions': _still,
      'style': _style,
    },
    'actions': [_set('ses')],
  },
};

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.nodes, this.root = 'page', this.width = 920});

  /// The document shown; the dashboard's when not given.
  final Map<String, Json>? nodes;
  final String root;
  final double width;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final NodeTree tree;
  late final TreeReactions reactions;

  @override
  void initState() {
    super.initState();
    final doc = LayoutDocument.fromJson({
      'schema': 3,
      'roots': [widget.root],
      'nodes': widget.nodes ?? dashboardNodes,
    });
    final scope = VariableScope([
      for (final name in const ['rev', 'src', 'ses']) Variable(name: name, type: VariableType.map, value: const <String, Object?>{}),
    ]);
    final values = NodeValues(DocumentSource(doc));
    tree = NodeTree(values, binder: NodeBinder(scope: scope));
    final context = RuntimeActionContext(
        scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
    reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
    tree.interactions = reactions;
  }

  @override
  void dispose() {
    reactions.dispose();
    tree.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: NodeView(tree: tree, rootId: widget.root, interactive: true),
      );
}
