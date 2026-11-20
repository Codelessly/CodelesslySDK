// Boxes that drew in the wrong place or at the wrong size: a child that
// fills its Stack placed off the Stack's start (its place was not read), and
// a one-line field whose text is taller than the kit's box (it was cut).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_drawing_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<Map<String, Map>> boxes(WidgetTester tester, Map<String, Object?> nodes, {List<Object?> variables = const []}) async {
    final file = File('${out.path}/page.json')
      ..writeAsStringSync(jsonEncode({
        'schema': 3,
        'id': 'page',
        'roots': ['page'],
        'nodes': {
          'page': {
            'type': 'canvas',
            'slots': {'body': 'col'},
            'layout': {'width': 800, 'height': 600},
            'decoration': {
              'fills': [
                {'color': '#FFFFFFFF'},
              ],
            },
          },
          ...nodes,
        },
        'variables': {'page': variables},
      }));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(800, 600)], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final list = (jsonDecode(File('${out.path}/o/page@800x600.layout.json').readAsStringSync()) as List).cast<Map>();
    return {for (final b in list) b['id'] as String: b};
  }

  testWidgets('a child that fills its Stack, placed by a y that is worked out, is the Stack\'s size from there', (tester) async {
    final b = await boxes(tester, {
      'col': {
        'type': 'column',
        'children': ['stage'],
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
      },
      'stage': {
        'type': 'stack',
        'children': ['cover', 'page2'],
        'layout': {'width': 400, 'height': 120},
      },
      // `Column w=fill h=fill x=0 y=0`: it covers the stage, as before.
      'cover': {
        'type': 'column',
        'layout': {
          'width': {'fill': 0},
          'height': {'fill': 0},
          'x': 0,
          'y': 0,
        },
      },
      // `Column w=fill h=fill x=0 y={(2 - position) * 40 + 10}`.
      'page2': {
        'type': 'column',
        'layout': {
          'width': {'fill': 0},
          'height': {'fill': 0},
          'x': 0,
        },
        'bind': {'layout.y': r'${= (2 - position) * 40 + 10}'},
      },
    }, variables: [
      {'name': 'position', 'type': 'integer', 'value': 1},
    ]);
    final sx = b['stage']!['x'] as num, sy = b['stage']!['y'] as num;
    expect([b['cover']!['x'] - sx, b['cover']!['y'] - sy, b['cover']!['w'], b['cover']!['h']], [0, 0, 400, 120]);
    expect([b['page2']!['x'] - sx, b['page2']!['y'] - sy, b['page2']!['w'], b['page2']!['h']], [0, 50, 400, 120]);
  });

  testWidgets('a one-line field whose text is taller than the kit\'s box is as tall as its line', (tester) async {
    final b = await boxes(tester, {
      'col': {
        'type': 'column',
        'children': ['title', 'plain'],
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
      },
      'title': {
        'type': 'textField',
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
        'props': {
          'initialValue': 'A long note title',
          'decoration': {
            'border': {'type': 'none'},
            'filled': false,
          },
          'style': {'fontSize': 44},
        },
      },
      'plain': {
        'type': 'textField',
        'layout': {
          'width': {'fill': 0},
          'height': {'hug': 0},
        },
        'props': {'initialValue': 'Plain'},
      },
    });
    expect(b['title']!['h'], greaterThanOrEqualTo(52));
    // A field at the kit's size is the kit's box, as before.
    expect(b['plain']!['h'], lessThan(44));
  });
}
