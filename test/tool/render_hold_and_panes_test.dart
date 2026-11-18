// The render command (test 9, mail): `--drag <id>=<dx>,<dy>,hold` captures
// a drag still in progress (a row swiped part of the way), and `--full-page`
// on a window of panes that each scroll captures the window, not one pane's
// length.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _lines(String prefix, int n) => {
      for (var i = 0; i < n; i++)
        '$prefix$i': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': 40},
          'props': {'text': '$prefix $i', 'style': {'fontSize': 14, 'color': '#FF000000'}},
        },
    };

Map<String, Object?> _pane(String id, String prefix, num width) => {
      'type': 'column',
      'layout': {'width': width, 'height': {'fill': 0}},
      'props': {'scrollable': true},
      'children': [for (var i = 0; i < 60; i++) '$prefix$i'],
    };

/// The width and height a PNG says it is.
(int, int) _pngSize(String path) {
  final b = ByteData.sublistView(File(path).readAsBytesSync());
  return (b.getUint32(16), b.getUint32(20));
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('render_hold_and_panes_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('--full-page on a window of two scrolling panes captures the window', (tester) async {
    File('${dir.path}/mail.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'id': 'mail',
      'roots': ['mail'],
      'nodes': {
        'mail': {
          'type': 'canvas',
          'slots': {'body': 'win'},
          'layout': {'width': 1280, 'height': {'fill': 800}},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        },
        'win': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
          'props': {'crossAxisAlignment': 'stretch'},
          'children': ['list', 'reader'],
        },
        'list': _pane('list', 'm', 400),
        'reader': {..._pane('reader', 'r', 0), 'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'flex': 1}},
        ..._lines('m', 60),
        ..._lines('r', 60),
      },
    }));
    final out = Directory('${dir.path}/out')..createSync();
    await runRender(tester, RenderArgs(inputs: ['${dir.path}/mail.json'], out: out.path, sizes: const [Size(1280, 800)], fullPage: true));
    // The reader (840 of 1280) is wide enough to be the page: as a page, it is
    // captured whole. Narrowed below 60 % it is a pane, and the window is.
    final (w, h) = _pngSize('${out.path}/mail@1280x800.png');
    expect(w, 1280);
    expect(h, greaterThan(800));
    final doc = jsonDecode(File('${dir.path}/mail.json').readAsStringSync()) as Map<String, Object?>;
    ((doc['nodes'] as Map)['reader'] as Map)['layout'] = {'width': 500, 'height': {'fill': 0}};
    File('${dir.path}/mail.json').writeAsStringSync(jsonEncode(doc));
    await runRender(tester, RenderArgs(inputs: ['${dir.path}/mail.json'], out: out.path, sizes: const [Size(1280, 800)], fullPage: true));
    expect(_pngSize('${out.path}/mail@1280x800.png'), (1280, 800));
  });

  testWidgets('--drag …,hold leaves the pointer down for the capture, and lets go after', (tester) async {
    File('${dir.path}/s.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'id': 's',
      'roots': ['s'],
      'variables': {
        's': [
          {'name': 'v', 'type': 'decimal', 'value': 0},
        ],
      },
      'nodes': {
        's': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 400, 'height': 200}},
        'col': {'type': 'column', 'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'padding': 20}, 'children': ['slider', 'label']},
        'slider': {
          'type': 'slider',
          'layout': {'width': 300, 'height': 40},
          'props': {'min': 0, 'max': 100},
          'bind': {'props.value': r'${v}'},
          'actions': [
            {'trigger': {'type': 'changed'}, 'actions': [{'type': 'setVariable', 'variable': 'v', 'value': r'${result}'}]},
          ],
        },
        'label': {'type': 'text', 'layout': {'width': 200, 'height': 20}, 'props': {'text': r'at ${v}', 'style': {'fontSize': 14, 'color': '#FF000000'}}},
      },
    }));
    final out = Directory('${dir.path}/out')..createSync();
    final report = await runRender(tester, RenderArgs(inputs: ['${dir.path}/s.json'], out: out.path, sizes: const [Size(400, 200)], steps: const [Step('drag', 'slider', '120,0,hold')], dumpLayout: true));
    expect(report.diagnostics.where((d) => d['severity'] == 'error'), isEmpty, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/s@400x200.layout.json').readAsStringSync()) as List;
    final label = boxes.map((b) => (b as Map)['text']).whereType<String>().firstWhere((t) => t.startsWith('at '));
    expect(label, isNot('at 0'));
  });
}
