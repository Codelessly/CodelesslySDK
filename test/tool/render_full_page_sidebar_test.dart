// A full-page capture of an app frame: a sidebar as tall as the window
// beside a pane that scrolls. The capture is taller than the window, and the
// sidebar's background carries on under it (nothing is left unpainted); what
// is in the sidebar shows once, in the first window.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

const _doc = {
  'schema': 3,
  'id': 'app',
  'roots': ['app'],
  'nodes': {
    'app': {
      'type': 'canvas',
      'slots': {'body': 'frame'},
      'layout': {'width': 600, 'height': {'fill': 400}},
      'decoration': {
        'fills': [
          {'color': '#FFF0F0F0'},
        ],
      },
    },
    'frame': {
      'type': 'row',
      'children': ['side', 'main'],
      'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
      'props': {'crossAxisAlignment': 'stretch'},
    },
    'side': {
      'type': 'column',
      'children': ['mark'],
      'layout': {'width': 200, 'height': {'fill': 0}},
      'decoration': {
        'fills': [
          {'color': '#FF103050'},
        ],
      },
    },
    'mark': {
      'type': 'box',
      'layout': {'width': 200, 'height': 300},
      'decoration': {
        'fills': [
          {'color': '#FFFF0000'},
        ],
      },
    },
    'main': {
      'type': 'column',
      'children': ['a', 'b'],
      'layout': {'flex': 1, 'width': {'fill': 0}, 'height': {'fill': 0}},
      'props': {'scrollable': true},
    },
    'a': {
      'type': 'box',
      'layout': {'width': {'fill': 0}, 'height': 700},
      'decoration': {
        'fills': [
          {'color': '#FF00A000'},
        ],
      },
    },
    'b': {
      'type': 'box',
      'layout': {'width': {'fill': 0}, 'height': 500},
      'decoration': {
        'fills': [
          {'color': '#FF0000A0'},
        ],
      },
    },
  },
};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_full_page_sidebar_test'));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('the sidebar\'s background carries on under the first window; its content shows once', (tester) async {
    final file = File('${out.path}/app.json')..writeAsStringSync(jsonEncode(_doc));
    final report =
        await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(600, 400)], fullPage: true));
    expect(report.diagnostics.map((d) => d['code']), isNot(contains('transparent_background')), reason: '${report.diagnostics}');
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final p = (await tester.runAsync(() => decodePng(File(report.images.single).readAsBytesSync())))!;
    expect([p.width, p.height], [600, 1200], reason: 'the window, then what the pane scrolls');
    int rgba(int x, int y) {
      final i = (y * p.width + x) * 4;
      return (p.rgba[i + 3] << 24) | (p.rgba[i] << 16) | (p.rgba[i + 1] << 8) | p.rgba[i + 2];
    }

    // The sidebar's column, top to bottom: its content once, then its fill.
    expect(rgba(100, 100), 0xFFFF0000);
    expect(rgba(100, 350), 0xFF103050);
    for (final y in [400, 401, 700, 1000, 1199]) {
      expect(rgba(100, y).toRadixString(16), 'ff103050', reason: 'row $y under the sidebar');
    }
    // The pane beside it is the whole page.
    expect(rgba(400, 650), 0xFF00A000);
    expect(rgba(400, 1150), 0xFF0000A0);
  });
}
