// How a step names the node the writer means: `#n` counts the copies a list
// shows (not those a condition hides), a node inside a component instance is
// reached by its own id or the end of its path when that names one node on
// screen (several: the error lists their full paths), and a step whose node
// is not found lists the ids it may have meant.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _text(String text) => {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': text,
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    };

// A list of six rows; the even ones hidden by a condition (as `if` in the
// notation writes it), the odd ones shown.
final _listPage = {
  'schema': 3,
  'id': 'page',
  'roots': ['page'],
  'variables': {
    'page': [
      {'name': 'picked', 'type': 'integer', 'value': -1},
      {
        'name': 'rows',
        'type': 'list',
        'value': [for (var i = 0; i < 6; i++) {'n': i, 'show': i.isOdd}],
      },
    ],
  },
  'nodes': {
    'page': {
      'type': 'canvas',
      'slots': {'body': 'col'},
      'layout': {'width': 390, 'height': 700},
      'decoration': {
        'fills': [
          {'color': '#FFFFFFFF'},
        ],
      },
    },
    'col': {
      'type': 'column',
      'children': ['label', 'list'],
      'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
    },
    'label': _text(r'picked ${picked}'),
    'list': {
      'type': 'listView',
      'children': ['message'],
      'layout': {'width': {'fill': 390}, 'height': {'hug': 0}},
      'props': {'scrollable': false},
      'bind': {'data': r'${rows}'},
    },
    'message': {
      'type': 'box',
      'layout': {'width': {'fill': 390}, 'height': 40},
      'decoration': {
        'fills': [
          {'color': '#FFDDDDDD'},
        ],
      },
      'bind': {'visible': r'${= item.show}'},
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setVariable', 'variable': 'picked', 'value': r'${= item.n}'},
          ],
        },
      ],
    },
  },
};

Map<String, Object?> _hitsProp() => {
      'key': 'hits',
      'type': {
        'kind': 'variable',
        'of': {'kind': 'integer', 'flutter': 'int'},
      },
      'default': '',
    };

// A component (FieldAction) whose button `action` is called inside another
// (FieldSeason, as `joinSeason`), called on a page once or twice: the
// button's full path is `<call>/joinSeason/action`.
final _fieldAction = {
  'schema': 3,
  'id': 'FieldAction',
  'roots': ['fa'],
  'widget': {
    'type': 'FieldAction',
    'props': [_hitsProp()],
  },
  'nodes': {
    'fa': {
      'type': 'column',
      'children': ['action'],
      'layout': {'width': {'fill': 390}, 'height': {'hug': 0}},
    },
    'action': {
      'type': 'box',
      'layout': {'width': 120, 'height': 40},
      'decoration': {
        'fills': [
          {'color': '#FF999999'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setVariable', 'variable': 'props.hits', 'op': 'add', 'value': '1'},
          ],
        },
      ],
    },
  },
};

final _fieldSeason = {
  'schema': 3,
  'id': 'FieldSeason',
  'roots': ['season'],
  'widget': {
    'type': 'FieldSeason',
    'props': [_hitsProp()],
  },
  'nodes': {
    'season': {
      'type': 'column',
      'children': ['joinSeason'],
      'layout': {'width': {'fill': 390}, 'height': {'hug': 0}},
    },
    'joinSeason': {
      'type': 'FieldAction',
      'layout': {'width': {'fill': 390}, 'height': 50},
      'props': {'hits': 'props.hits'},
    },
  },
};

Map<String, Object?> _sitePage(List<String> calls) => {
      'schema': 3,
      'id': 'page',
      'roots': ['page'],
      'variables': {
        'page': [
          {'name': 'hits', 'type': 'integer', 'value': 0},
        ],
      },
      'nodes': {
        'page': {
          'type': 'canvas',
          'slots': {'body': 'col'},
          'layout': {'width': 390, 'height': 700},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'col': {
          'type': 'column',
          'children': ['label', ...calls],
          'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
        },
        'label': _text(r'hits ${hits}'),
        for (final c in calls)
          c: {
            'type': 'FieldSeason',
            'layout': {'width': {'fill': 390}, 'height': 50},
            'props': {'hits': 'hits'},
          },
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_step_addressing_test'));
  tearDown(() => out.deleteSync(recursive: true));

  String labelOf(RenderReport report) {
    final boxes = jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List;
    return '${boxes.cast<Map>().firstWhere((b) => b['id'] == 'label')['text']}';
  }

  String messageOf(RenderReport r, String code) => r.diagnostics.firstWhere((d) => d['code'] == code)['message'] as String;

  Future<RenderReport> runList(WidgetTester tester, List<Step> steps) {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_listPage));
    return runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
  }

  Future<RenderReport> runSite(WidgetTester tester, List<String> calls, List<Step> steps) {
    final site = Directory('${out.path}/site')..createSync();
    Directory('${site.path}/components').createSync();
    File('${site.path}/site.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'pages': ['page.json'],
      'components': ['components/FieldSeason.json', 'components/FieldAction.json'],
    }));
    File('${site.path}/page.json').writeAsStringSync(jsonEncode(_sitePage(calls)));
    File('${site.path}/components/FieldSeason.json').writeAsStringSync(jsonEncode(_fieldSeason));
    File('${site.path}/components/FieldAction.json').writeAsStringSync(jsonEncode(_fieldAction));
    return runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
  }

  group('#n counts the copies a list shows', () {
    testWidgets('message#1 is the second row shown, not the second row of the data', (tester) async {
      final report = await runList(tester, const [Step('tap', 'message#1')]);
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(labelOf(report), 'picked 3');
    });

    testWidgets('past the copies shown: the error counts the copies shown', (tester) async {
      final report = await runList(tester, const [Step('tap', 'message#3')]);
      expect(messageOf(report, 'interaction_failed'), contains('3 copies of "message" on screen (#0 to #2)'));
    });
  });

  testWidgets('a checkbox drawn for show in a row that takes the press (a Table\'s): the tap reaches the row', (tester) async {
    final doc = jsonDecode(jsonEncode(_listPage)) as Map<String, Object?>;
    final nodes = doc['nodes']! as Map<String, Object?>;
    (nodes['message']! as Map)
      ..['type'] = 'row'
      ..['children'] = ['check'];
    nodes['check'] = {
      'type': 'checkbox',
      'layout': {'width': 16, 'height': 16},
      'ignorePointer': true,
      'focusable': false,
    };
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(doc));
    final report = await runRender(tester,
        RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: const [Step('tap', 'check#2')], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(labelOf(report), 'picked 5');
  });

  group('a node inside a component instance', () {
    testWidgets('by its own id, or the end of its path, when one node on screen has it', (tester) async {
      final report = await runSite(tester, ['FieldSeason1'], const [
        Step('tap', 'action'),
        Step('tap', 'joinSeason/action'),
        Step('tap', 'FieldSeason1/joinSeason/action'),
        // The root of the inner component, by its call and its own id.
        Step('tap', 'joinSeason/fa'),
      ]);
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(labelOf(report), 'hits 4');
    });

    testWidgets('several instances have it: the error lists their full paths', (tester) async {
      final report = await runSite(tester, ['FieldSeason1', 'FieldSeason2'], const [Step('tap', 'joinSeason/action')]);
      expect(messageOf(report, 'interaction_failed'), allOf(contains('FieldSeason1/joinSeason/action'), contains('FieldSeason2/joinSeason/action')));
    });

    testWidgets('a node not found lists the ids it may have meant', (tester) async {
      final report = await runSite(tester, ['FieldSeason1'], const [Step('tap', 'joinSeasn/action')]);
      expect(messageOf(report, 'interaction_failed'), contains('Perhaps: FieldSeason1/joinSeason/action'));
    });
  });
}
