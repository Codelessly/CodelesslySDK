// The render command's gesture steps: a --drag that is a swipe, --long-press
// and --right-click, and --reload, which starts the app again with what it
// kept on the device.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _set(String trigger, String variable, Object value) => {
      'trigger': {'type': trigger},
      'actions': [
        {'type': 'setVariable', 'variable': variable, 'value': value},
      ],
    };

Map<String, Object?> _pad(String id, List<Map<String, Object?>> actions) => {
      'type': 'box',
      'layout': {'width': 300, 'height': 80},
      'decoration': {
        'fills': [
          {'color': '#FFDDDDDD'},
        ],
      },
      'actions': actions,
    };

final _doc = {
  'schema': 3,
  'id': 'page',
  'roots': ['page'],
  'variables': {
    'page': [
      {'name': 'swiped', 'type': 'text', 'value': 'none'},
      {'name': 'pressed', 'type': 'text', 'value': 'none'},
      {'name': 'kept', 'type': 'integer', 'value': 0, 'persist': true},
      {'name': 'lost', 'type': 'integer', 'value': 0},
      {'name': 'keys', 'type': 'text', 'value': ''},
      {'name': 'typed', 'type': 'text', 'value': ''},
    ],
  },
  'nodes': {
    'page': {
      'type': 'canvas',
      'slots': {'body': 'col'},
      'layout': {'width': 390, 'height': 600},
      'decoration': {
        'fills': [
          {'color': '#FFFFFFFF'},
        ],
      },
      // Shortcuts as the notation writes them (`key ? onPress={…}`).
      'actions': [
        for (final k in ['?', '/', 'F2', 'mod+k'])
          {
            'trigger': {'type': 'keyDown', 'key': k},
            'actions': [
              {'type': 'setVariable', 'variable': 'keys', 'value': '\${= keys + "[$k]"}'},
            ],
          },
      ],
    },
    'col': {
      'type': 'column',
      'children': ['label', 'swipe', 'context', 'count', 'keysLabel', 'field'],
      'layout': {'width': {'fill': 390}, 'height': {'fill': 600}},
      'props': {'spacing': 8},
    },
    'label': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': r'swiped ${swiped}, pressed ${pressed}, kept ${kept}, lost ${lost}',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'swipe': _pad('swipe', [
      _set('swipeLeft', 'swiped', 'left'),
      _set('swipeRight', 'swiped', 'right'),
      _set('swipeUp', 'swiped', 'up'),
    ]),
    'context': _pad('context', [_set('longPress', 'pressed', 'long'), _set('secondaryClick', 'pressed', 'secondary')]),
    'count': _pad('count', [
      {
        'trigger': {'type': 'click'},
        'actions': [
          {'type': 'setVariable', 'variable': 'kept', 'value': r'${= kept + 1}'},
          {'type': 'setVariable', 'variable': 'lost', 'value': r'${= lost + 1}'},
          {'type': 'announce', 'message': r'Counted ${kept}'},
        ],
      },
    ]),
    'keysLabel': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'live': true,
        'text': r'keys ${keys}, typed ${typed}',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'field': {
      'type': 'textField',
      'layout': {'width': 300, 'height': 48},
      'bind': {'props.initialValue': r'${typed}'},
    },
  },
};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_gesture_steps_test'));
  tearDown(() => out.deleteSync(recursive: true));

  late RenderReport last;
  Future<String> label(WidgetTester tester, List<Step> steps, {String id = 'label', bool clean = true}) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc));
    final report = last = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 600)], steps: steps, dumpLayout: true));
    if (clean) expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/o/page@390x600.layout.json').readAsStringSync()) as List;
    return '${boxes.cast<Map>().firstWhere((b) => b['id'] == id)['text']}';
  }

  testWidgets('--key takes printable characters, F keys and mod, and types a character into a focused field', (tester) async {
    expect(
        await label(tester, const [Step('key', '?'), Step('key', '/'), Step('key', 'F2'), Step('key', 'mod+k')], id: 'keysLabel'),
        'keys [?][/][F2][mod+k], typed ');
    expect(await label(tester, const [Step('focus', 'field'), Step('key', 'o'), Step('key', 'shift+k'), Step('key', '?')], id: 'keysLabel'),
        'keys , typed oK?');
  });

  testWidgets('the report lists what was announced and what a live region said, after which step', (tester) async {
    await label(tester, const [Step('tap', 'count'), Step('key', '/'), Step('tap', 'count')]);
    expect([for (final a in last.announcements) '${a['source']} ${a['text']} (${a['politeness']}) after ${a['after']}'], [
      'announce Counted 1 (polite) after --tap count',
      'live keys [/], typed (polite) after --key /',
      'announce Counted 2 (polite) after --tap count',
    ]);
    expect(formatReport(last), contains('announced "Counted 1" (polite) after --tap count'));
  });

  testWidgets('--long-press on a node with no long press reaction says its tap ran', (tester) async {
    expect(await label(tester, const [Step('long-press', 'count')], clean: false), endsWith('kept 1, lost 1'));
    expect(last.diagnostics.single['code'], 'long_press_no_reaction');
    expect(await label(tester, const [Step('long-press', 'context')]), contains('pressed long,'));
  });

  testWidgets('the options parse', (tester) async {
    final a = parseArgs(['site', '--out', 'o', '--long-press', 'row#0', '--right-click', 'row#1', '--reload', '--drag', 'row=-140,0']);
    expect(a.steps.map((s) => '$s'), ['--long-press row#0', '--right-click row#1', '--reload ', '--drag row=-140,0']);
  });

  testWidgets('--drag by a distance fires the swipe that way', (tester) async {
    expect(await label(tester, const [Step('drag', 'swipe', '-140,0')]), startsWith('swiped left,'));
    expect(await label(tester, const [Step('drag', 'swipe', '140,0')]), startsWith('swiped right,'));
    expect(await label(tester, const [Step('drag', 'swipe', '0,-60')]), startsWith('swiped up,'));
  });

  testWidgets('--long-press and --right-click fire their reactions', (tester) async {
    expect(await label(tester, const [Step('long-press', 'context')]), contains('pressed long,'));
    expect(await label(tester, const [Step('right-click', 'context')]), contains('pressed secondary,'));
  });

  testWidgets('a sheet with stops: --drag on it and --tap <sheet>/handle move it to the next stop', (tester) async {
    final doc = {
      'schema': 3,
      'roots': ['page', 'sheet'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'slots': {'body': 'open'},
          'layout': {'width': 390, 'height': 600},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        },
        'open': {
          ..._pad('open', [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'openModal', 'to': 'sheet', 'presentation': 'bottomSheet', 'showDragHandle': true, 'maxHeightFactor': 0.9, 'snapHeights': [0.5, 0.9]},
              ],
            },
          ]),
        },
        'sheet': {
          'type': 'canvas',
          'slots': {'body': 'list'},
          'layout': {'width': 390, 'height': {'fill': 0}},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        },
        'list': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
          'props': {'scrollable': true, 'spacing': 8},
          'children': [for (var i = 0; i < 30; i++) 'row$i'],
        },
        for (var i = 0; i < 30; i++) 'row$i': _pad('row$i', const []),
      },
    };
    Future<num> sheetTop(List<Step> steps) async {
      final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(doc));
      final report = await runRender(tester,
          RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 600)], steps: [const Step('tap', 'open'), ...steps], dumpLayout: true));
      expect(report.diagnostics.where((d) => d['severity'] == 'error'), isEmpty, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File('${out.path}/o/page@390x600.layout.json').readAsStringSync()) as List;
      return boxes.cast<Map>().firstWhere((b) => b['id'] == 'sheet')['y'] as num;
    }

    expect(await sheetTop(const []), closeTo(300, 1));
    expect(await sheetTop(const [Step('drag', 'sheet', '0,-200')]), closeTo(60, 1));
    expect(await sheetTop(const [Step('tap', 'sheet/handle')]), closeTo(60, 1));
    expect(await sheetTop(const [Step('key', 'alt+ArrowUp')]), closeTo(60, 1));
  });

  testWidgets('--reload keeps what is marked saved and starts everything else over', (tester) async {
    const taps = [Step('tap', 'count'), Step('tap', 'count')];
    expect(await label(tester, taps), endsWith('kept 2, lost 2'));
    expect(await label(tester, [...taps, const Step('reload', '')]), endsWith('kept 2, lost 0'));
    expect(await label(tester, [...taps, const Step('reload', ''), const Step('tap', 'count')]), endsWith('kept 3, lost 1'));
    // Each capture starts with nothing stored.
    expect(await label(tester, const []), endsWith('kept 0, lost 0'));
  });
}
