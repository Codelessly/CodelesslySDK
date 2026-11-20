// A condition holds when its value is something: a formula that failed, a
// name nothing has, "" and an empty list are no (each left the node as
// written, so both branches of an `if` drew), and a render names the node
// whose formula failed and the formula (formula_failed).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _text(String text, {String? visible}) => {
      'type': 'text',
      'layout': {
        'width': {'fill': 0},
        'height': {'hug': 0},
      },
      'props': {
        'text': text,
        'style': {'color': '#FF000000'},
      },
      if (visible != null) 'bind': {'visible': visible},
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_conditions_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(Set<String>, RenderReport)> shown(WidgetTester tester, Map<String, Map<String, Object?>> nodes, {List<Object?> variables = const []}) async {
    final file = File('${out.path}/page.json')
      ..writeAsStringSync(jsonEncode({
        'schema': 3,
        'id': 'page',
        'roots': ['page'],
        'nodes': {
          'page': {
            'type': 'canvas',
            'slots': {'body': 'col'},
            'layout': {'width': 400, 'height': 600},
            'decoration': {
              'fills': [
                {'color': '#FFFFFFFF'},
              ],
            },
          },
          'col': {
            'type': 'column',
            'children': [...nodes.keys],
            'layout': {
              'width': {'fill': 0},
              'height': {'hug': 0},
            },
          },
          ...nodes,
        },
        'variables': {'page': variables},
      }));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(400, 600)], dumpLayout: true));
    final boxes = (jsonDecode(File('${out.path}/o/page@400x600.layout.json').readAsStringSync()) as List).cast<Map>();
    return (
      {
        for (final b in boxes)
          if ((b['h'] as num) > 0) b['id'] as String,
      },
      report
    );
  }

  testWidgets('when a formula fails neither "if length(x)==0" nor "if length(x)>0" draws, and the render says which', (tester) async {
    final (ids, report) = await shown(tester, {
      'none': _text('No cards', visible: r'${= length(sortBy(cards, c => sortKey(c))) == 0}'),
      'some': _text('Cards', visible: r'${= length(sortBy(cards, c => sortKey(c))) > 0}'),
      'plain': _text('Always'),
    }, variables: [
      {
        'name': 'cards',
        'type': 'list',
        'value': [
          {'id': 1},
        ],
      },
    ]);
    expect(ids, contains('plain'));
    expect(ids, isNot(contains('none')));
    expect(ids, isNot(contains('some')));
    final said = report.diagnostics.where((d) => d['code'] == 'formula_failed').toList();
    expect(said, hasLength(2));
    expect(said.first['severity'], 'warning');
    expect(said.map((d) => '$d'), everyElement(contains('sortKey')));
    expect(said.first['message'], contains('is not shown'));
    expect('${said.first}', contains('none'));
    expect('${said.last}', contains('some'));
  });

  testWidgets('a condition is yes for something and no for nothing: a text, a record, a missing one', (tester) async {
    final (ids, report) = await shown(tester, {
      'hasText': _text('quoted', visible: r'${= reply && reply.body}'),
      'noParent': _text('missing', visible: r'${= parent0 && parent0.body}'),
      'emptyText': _text('empty', visible: r'${name}'),
      'emptyList': _text('none', visible: r'${rows}'),
      'record': _text('record', visible: r'${reply}'),
      'no': _text('no', visible: r'${= 1 > 2}'),
    }, variables: [
      {
        'name': 'reply',
        'type': 'map',
        'value': {'body': 'hello'},
      },
      {'name': 'name', 'type': 'text', 'value': ''},
      {'name': 'rows', 'type': 'list', 'value': <Object?>[]},
    ]);
    expect(ids, containsAll(['hasText', 'record']));
    for (final hidden in ['noParent', 'emptyText', 'emptyList', 'no']) {
      expect(ids, isNot(contains(hidden)), reason: hidden);
    }
    expect(report.diagnostics.where((d) => d['code'] == 'formula_failed'), isEmpty);
  });
}
