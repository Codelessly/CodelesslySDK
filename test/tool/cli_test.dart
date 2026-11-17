// The toolkit's own commands (tool/cli): trees flattened, the reference looked up, outlines built from layout dumps,
// sheet rows, a states manifest's steps and the MCP server's protocol. The render command itself is tested by the
// other tests here.
@TestOn('linux || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/docs.dart';
import '../../tool/cli/src/flatten.dart';
import '../../tool/cli/src/outline.dart';
import '../../tool/cli/src/states.dart';
import '../../tool/render/src/sheet.dart';

Map<String, Object?> nodesOf(Map<String, Object?> doc) => (doc['nodes'] as Map).cast<String, Object?>();
Map nodeOf(Map<String, Object?> doc, String id) => nodesOf(doc)[id] as Map;

void main() {
  group('flatten', () {
    test('a tree that is not a canvas goes in a canvas body', () {
      final doc = flatten({
        'type': 'column', 'key': 'page',
        'children': [
          {'type': 'text', 'key': 'title', 'props': {'text': 'A'}},
          {'type': 'text', 'props': {'text': 'B'}},
        ],
      }, size: (390, 844));
      expect(doc['schema'], 3);
      expect(doc['roots'], ['screen']);
      expect(nodeOf(doc, 'screen')['slots'], {'body': 'page'});
      expect(nodeOf(doc, 'screen')['layout'], {'width': 390, 'height': 844});
      expect(nodeOf(doc, 'page')['children'], ['title', 'text']);
      expect(nodesOf(doc).keys.first, 'screen', reason: 'canvases first');
    });

    test('"@key" becomes the id everywhere; a repeated key gets a fresh id', () {
      final doc = flatten({
        'type': 'column',
        'children': [
          {'type': 'text', 'key': 'msg'},
          {'type': 'filledButton', 'key': 'msg', 'actions': [{'trigger': 'click', 'actions': [{'type': 'setValue', 'node': '@msg'}]}]},
        ],
      });
      final ids = [for (final e in nodesOf(doc).entries) if (!{'canvas', 'column'}.contains((e.value as Map)['type'])) e.key];
      expect(ids, ['msg', 'msg1']);
      expect((((nodeOf(doc, 'msg1')['actions'] as List).first as Map)['actions'] as List).first, containsPair('node', 'msg1'));
    });

    test('trees per breakpoint are one screen, each tree its own key scope, and their key maps are given', () {
      Map<String, Object?> tree() => {
            'type': 'column',
            'children': [
              {'type': 'filledButton', 'key': 'retry', 'states': {'pressed': {'@retry': {'opacity': 0.5}}}},
            ],
          };
      final keys = <String, Map<String, String>>{};
      final doc = flatten({
        'trees': {'mobile': tree(), 'desktop': tree()},
        'variables': [{'name': 'n', 'type': 'integer', 'value': 0}],
      }, screen: 'home', keysOut: keys);
      expect(doc['roots'], ['home_mobile', 'home_desktop']);
      expect(nodeOf(doc, 'home_desktop')['props'], {'screen': 'home', 'breakpoint': 'desktop'});
      expect(nodeOf(doc, 'home_desktop')['layout'], {'width': 1440, 'height': 900});
      expect(doc['variables'], {'page_variables': [{'name': 'n', 'type': 'integer', 'value': 0}]});
      final buttons = [for (final e in nodesOf(doc).entries) if ((e.value as Map)['type'] == 'filledButton') e.key];
      expect(buttons, ['retry', 'retry1']);
      for (final b in buttons) {
        expect(((nodeOf(doc, b)['states'] as Map)['pressed'] as Map).keys, [b], reason: 'its own node, not the other tree\'s');
      }
      expect(keys, {'mobile': {'retry': 'retry'}, 'desktop': {'retry': 'retry1'}});
    });

    test('a document with nested children keeps its ids', () {
      final doc = flatten({
        'schema': 3, 'roots': ['c'],
        'nodes': {
          'c': {'type': 'canvas', 'slots': {'body': {'type': 'column', 'key': 'col', 'children': ['t']}}},
          't': {'type': 'text'},
        },
      });
      expect(nodeOf(doc, 'c')['slots'], {'body': 'col'});
      expect(nodeOf(doc, 'col')['children'], ['t']);
      expect(nodesOf(doc).containsKey('t'), isTrue);
    });
  });

  group('docs', () {
    Reference? ref;
    try {
      ref = Reference(findReference());
    } catch (_) {}

    test('a name finds its section, which stops at the next heading of its level', () {
      final (file, anchor) = ref!.exact('row')!;
      final body = ref.section(file, anchor);
      expect(body.join('\n'), allOf(contains('`row`'), contains('mainAxisAlignment')));
      expect(body.any((l) => l.startsWith('### `column`')), isFalse);
    }, skip: ref == null ? 'no codelessly_api reference beside the SDK' : false);

    test('words find a need', () {
      final hits = ref!.search(['sticky', 'header']);
      expect(hits, isNotEmpty);
      expect(hits.first.anchor, contains('sticky'));
    }, skip: ref == null ? 'no codelessly_api reference beside the SDK' : false);
  });

  test('outline: the tree, boxes, texts and problems', () {
    final d = Directory.systemTemp.createTempSync('cli_outline');
    addTearDown(() => d.deleteSync(recursive: true));
    File('${d.path}/doc.json').writeAsStringSync(jsonEncode({
      'schema': 3, 'roots': ['home'],
      'nodes': {
        'home': {'type': 'canvas', 'slots': {'body': 'col'}},
        'col': {'type': 'column', 'children': ['a', 'b']},
        'a': {'type': 'text'},
        'b': {'type': 'box'},
      },
    }));
    final out = Directory('${d.path}/out')..createSync();
    File('${out.path}/home@390x844.png.layout.json').writeAsStringSync(jsonEncode([
      {'id': 'home', 'x': 0, 'y': 0, 'w': 390, 'h': 844},
      {'id': 'col', 'x': 0, 'y': 0, 'w': 390, 'h': 100},
      {'id': 'a', 'x': 0, 'y': 0, 'w': 100, 'h': 20, 'text': 'Hello'},
      {'id': 'b', 'x': 0, 'y': 20, 'w': 0, 'h': 0},
    ]));
    File('${out.path}/diagnostics.json').writeAsStringSync(jsonEncode({
      'diagnostics': [
        {'code': 'text_clipped', 'severity': 'warning', 'nodeId': 'a', 'screen': 'home', 'size': '390x844', 'message': 'clipped'},
      ],
    }));
    final lines = outlineCapture(
        jsonDecode(File('${out.path}/home@390x844.png.layout.json').readAsStringSync()) as List,
        DocumentTree.load(['${d.path}/doc.json']),
        captureDiagnostics(out.path, 'home@390x844'));
    expect(lines[0], startsWith('canvas home'));
    expect(lines[1], startsWith('  column col'));
    expect(lines[2], allOf(contains('text a'), contains('"Hello"')));
    expect(lines[3].trim(), '! text_clipped: clipped');
    expect(lines[4], allOf(startsWith('    box b'), contains('(empty: draws nothing)')));
  });

  test('states: steps become render options; paths are the manifest\'s', () {
    expect(stepArgs([{'tap': 'go'}, {'unfocus': true}, ['--wait', '300'], {'set': 'n=1'}]),
        ['--tap', 'go', '--unfocus', '--wait', '300', '--set', 'n=1']);
    expect(absolutizeArgs('/m', ['--fonts', 'f', '--fonts', 'system', '--image-map', 'urls.json=art', '--image-map', 'https://x/=a']),
        ['--fonts', '/m/f', '--fonts', 'system', '--image-map', '/m/urls.json=/m/art', '--image-map', 'https://x/=/m/a']);
  });

  test('sheet: one row per state, narrowest size first', () {
    final files = [for (final s in ['1440x900', '390x844']) for (final l in ['', '-saved']) '/x/home@$s$l.png'];
    expect(sheetRows(files).map((r) => r.map((f) => f.split('/').last).toList()).toList(), [
      ['home@390x844.png', 'home@1440x900.png'],
      ['home@390x844-saved.png', 'home@1440x900-saved.png'],
    ]);
  });

  test('the MCP server: initialize, the tools, flatten, an unknown method', () async {
    final work = Directory.systemTemp.createTempSync('cli_mcp');
    addTearDown(() => work.deleteSync(recursive: true));
    final p = await Process.start('tool/codelessly', ['mcp'], environment: {'CODELESSLY_MCP_WORK': work.path});
    final msgs = [
      {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}},
      {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
      {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
      {'jsonrpc': '2.0', 'id': 3, 'method': 'tools/call', 'params': {'name': 'codelessly_flatten', 'arguments': {'tree': {'type': 'column'}}}},
      {'jsonrpc': '2.0', 'id': 4, 'method': 'nope'},
    ];
    for (final m in msgs) {
      p.stdin.writeln(jsonEncode(m));
    }
    await p.stdin.close();
    final lines = await p.stdout.transform(utf8.decoder).transform(const LineSplitter()).toList();
    await p.exitCode;
    final answers = {for (final l in lines) (jsonDecode(l) as Map)['id']: jsonDecode(l) as Map};
    expect(answers.keys, [1, 2, 3, 4], reason: 'the notification gets no answer');
    expect((answers[1]!['result'] as Map)['protocolVersion'], '2025-06-18');
    expect([for (final t in ((answers[2]!['result'] as Map)['tools'] as List)) (t as Map)['name']],
        ['codelessly_docs', 'codelessly_render', 'codelessly_flatten', 'codelessly_states']);
    final doc = jsonDecode((((answers[3]!['result'] as Map)['content'] as List).first as Map)['text'] as String) as Map;
    expect(doc['roots'], ['screen']);
    expect((answers[4]!['error'] as Map)['code'], -32601);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
