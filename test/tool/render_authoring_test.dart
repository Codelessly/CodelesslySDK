// The render command (tool/render): fixes that came out of authoring with
// it (taps, image maps, tables, controls, keys). Run in-process on
// test/tool/fixtures/authoring.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const fixtures = 'test/tool/fixtures';
const a0 = '$fixtures/authoring';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_authoring_test'));
  tearDown(() => out.deleteSync(recursive: true));

  group('authoring fixes', () {
    const a = '$fixtures/authoring';
    List<Map> diag(RenderReport r, String code) => [for (final d in r.diagnostics) if (d['code'] == code) d];

    testWidgets('a tap step reveals its target below an overlaid header and hits it', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'target'), Step('tap', 'target')], dumpLayout: true, label: 'two'));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(diag(report, 'tap_no_reaction'), isEmpty);
      // The header was not tapped (its menu would open); the counter shows 2.
      final boxes = jsonDecode(File('${out.path}/taps@390x844-two.layout.json').readAsStringSync()) as List;
      final target = boxes.firstWhere((b) => b['id'] == 'target') as Map;
      expect(target['y'] as num, greaterThan(64), reason: 'below the header');
      expect(File('${out.path}/diagnostics-two.json').existsSync(), isTrue, reason: 'a labeled run keeps its own diagnostics');
      expect(File('${out.path}/diagnostics.json').existsSync(), isFalse);
    });

    testWidgets('a tap on a node with a margin hits its content; a tap with no reaction is reported', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'margined'), Step('tap', 'plain')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(diag(report, 'tap_no_reaction').map((d) => d['nodeId']), ['plain']);
    });

    testWidgets('a tap on a control the SDK draws reacts: only a button or tile with no reaction on its node is reported (test 4: 13 of 13 builds)', (tester) async {
      // Buttons, switches, dropdowns and the rest are render objects that
      // take the tap themselves; the tool used to look only for a reactions
      // layer or a widget's gesture handler and called every such tap dead.
      final report = await runRender(tester, RenderArgs(inputs: ['$a/control_taps.json'], out: out.path, sizes: const [Size(390, 844)], steps: const [
        Step('tap', 'go'), Step('tap', 'sw'), Step('tap', 'seg'), Step('tap', 'check'), Step('tap', 'tileGo'), Step('tap', 'drop'), //
      ]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(diag(report, 'tap_no_reaction'), isEmpty, reason: '${diag(report, 'tap_no_reaction')}');
      final dead = await runRender(tester, RenderArgs(inputs: ['$a/control_taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'bare'), Step('tap', 'tile')], label: 'dead'));
      expect(diag(dead, 'tap_no_reaction').map((d) => d['nodeId']), ['bare', 'tile']);
    });

    testWidgets('--image-map reads a network image from a folder; a mapped URL with no file there is image_failed', (tester) async {
      final dir = Directory('${out.path}/im/art/cards')..createSync(recursive: true);
      // A 1x1 PNG.
      File('${dir.path}/post card.png').writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));
      File('${out.path}/im/doc.json').writeAsStringSync(jsonEncode({
        'schema': 3, 'roots': ['c'],
        'nodes': {
          'c': {'type': 'canvas', 'layout': {'width': 100, 'height': 100}, 'slots': {'body': 'img'},
            'decoration': {'fills': [{'color': '#FFFFFFFF'}]}},
          'img': {'type': 'box', 'layout': {'width': 50, 'height': 50}, 'decoration': {'fills': [
            {'type': 'image', 'image': {'url': 'https://cdn.example.com/art/cards/post%20card.png?v=3', 'fit': 'cover'}},
          ]}},
        },
      }));
      final mapped = await runRender(tester, RenderArgs(inputs: ['${out.path}/im/doc.json'], out: '${out.path}/im/o1',
          sizes: const [Size(100, 100)], imageMap: {'https://cdn.example.com/art/': '${out.path}/im/art'}));
      expect(diag(mapped, 'image_network'), isEmpty);
      expect(diag(mapped, 'image_failed'), isEmpty);
      final missing = await runRender(tester, RenderArgs(inputs: ['${out.path}/im/doc.json'], out: '${out.path}/im/o2',
          sizes: const [Size(100, 100)], imageMap: {'https://cdn.example.com/art/': '${out.path}/im/nothere'}));
      expect(diag(missing, 'image_failed').single['message'], contains('nothere/cards/post card.png'));
    });

    testWidgets('a running table shows new data with as many rows (its cells move to their new items)', (tester) async {
      Directory('${out.path}/tv').createSync(recursive: true);
      File('${out.path}/tv/doc.json').writeAsStringSync(jsonEncode({
        'schema': 3, 'roots': ['c'],
        'variables': {'page_variables': [
          {'name': 'rows', 'type': 'list', 'value': [{'name': 'A', 'status': 'Awaiting'}, {'name': 'B', 'status': 'Awaiting'}]},
        ]},
        'nodes': {
          'c': {'type': 'canvas', 'layout': {'width': 400, 'height': 300}, 'slots': {'body': 'tbl'},
            'decoration': {'fills': [{'color': '#FFFFFFFF'}]}},
          'tbl': {'type': 'tableView', 'layout': {'width': {'fill': 1}, 'height': {'fill': 1}}, 'bind': {'data': r'${rows}'},
            'props': {'columns': [{'key': 'name', 'label': 'Name'}, {'key': 'status', 'label': 'Status'}]},
            'slots': {'cell': 'cellText'}},
          'cellText': {'type': 'text', 'props': {'text': r'${item.value}', 'style': {'color': '#FF000000'}}},
        },
      }));
      await runRender(tester, RenderArgs(inputs: ['${out.path}/tv/doc.json'], out: '${out.path}/tv/o', sizes: const [Size(400, 300)],
          dumpLayout: true, steps: const [Step('set', 'rows', '[{"name":"A","status":"Declared"},{"name":"B","status":"Counted"}]')]));
      final boxes = jsonDecode(File('${out.path}/tv/o/c@400x300.layout.json').readAsStringSync()) as List;
      final texts = [for (final b in boxes.cast<Map>()) if (b['id'] == 'cellText') b['text']];
      expect(texts, ['A', 'Declared', 'B', 'Counted']);
    });

    testWidgets('a screen with nothing painted behind part of it is reported; a canvas with a fill is not', (tester) async {
      Directory('${out.path}/bg').createSync(recursive: true);
      String doc(bool fill) => jsonEncode({
            'schema': 3, 'roots': ['c'],
            'nodes': {
              'c': {'type': 'canvas', 'layout': {'width': 390, 'height': 844}, 'slots': {'body': 'b'},
                if (fill) 'decoration': {'fills': [{'color': '#FFFFFFFF'}]}},
              'b': {'type': 'box', 'layout': {'width': 100, 'height': 100}, 'decoration': {'fills': [{'color': '#FF336699'}]}},
            },
          });
      File('${out.path}/bg/bare.json').writeAsStringSync(doc(false));
      File('${out.path}/bg/filled.json').writeAsStringSync(doc(true));
      final bare = await runRender(tester, RenderArgs(inputs: ['${out.path}/bg/bare.json'], out: '${out.path}/bg/o1', sizes: const [Size(390, 844)]));
      expect(diag(bare, 'transparent_background').map((d) => d['nodeId']), ['c']);
      final filled = await runRender(tester, RenderArgs(inputs: ['${out.path}/bg/filled.json'], out: '${out.path}/bg/o2', sizes: const [Size(390, 844)]));
      expect(diag(filled, 'transparent_background'), isEmpty);
    });

    testWidgets('a part of a control is tapped with @n: the second segment is chosen, and a part that is not there is named (test 4: seven builds)', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/control_taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'seg@1')], label: 'part', dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(report.diagnostics.where((d) => d['severity'] == 'warning'), isEmpty, reason: '${report.diagnostics}');
      // The text shown only when the second segment is chosen is laid out.
      final boxes = jsonDecode(File('${out.path}/s@390x844-part.layout.json').readAsStringSync()) as List;
      expect(boxes.any((b) => (b as Map)['id'] == 'picked'), isTrue, reason: 'the tap chose segment B');
      final missing = await runRender(tester, RenderArgs(inputs: ['$a/control_taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'seg@5'), Step('tap', 'go@0')], label: 'nopart'));
      final messages = [for (final d in missing.diagnostics) '${d['message']}'];
      expect(messages.any((m) => m.contains('"seg" has 2 parts (@0 to @1)')), isTrue, reason: '$messages');
      expect(messages.any((m) => m.contains('"go" has no parts to name with @')), isTrue, reason: '$messages');
    });

    testWidgets('a key reaction on a text field fires while that field is typed in (test 4: ArrowDown in a search field)', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/field_keys.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('focus', 'field'), Step('key', 'ArrowDown')], label: 'keys', dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File('${out.path}/s@390x844-keys.layout.json').readAsStringSync()) as List;
      expect(boxes.any((b) => (b as Map)['id'] == 'picked'), isTrue, reason: 'the field\'s own ArrowDown reaction ran');
    });

    testWidgets('a slider whose value label always shows renders and is torn down without an exception (test 4)', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/slider_label.json'], out: out.path, sizes: const [Size(390, 300)], label: 'slider'));
      expect(report.errors, 0, reason: '${report.diagnostics}');
    });

  });
}
