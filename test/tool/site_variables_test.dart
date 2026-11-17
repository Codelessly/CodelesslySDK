// A site's variables written by name ({"cart": [], "count": 2}) or as
// records without a type: the render command, the runtime and the notation's
// expander read them as the values they are, and a record none of them can
// read is never thrown.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _page(String text) => {
      'schema': 3,
      'roots': ['home'],
      'nodes': {
        'home': {
          'type': 'canvas',
          'slots': {'body': 'label'},
          'layout': {'width': 390, 'height': 200},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'label': {
          'type': 'text',
          'layout': {
            'width': {'fill': 390},
            'height': {'hug': 20},
          },
          'props': {
            'text': text,
            'style': {'fontSize': 14, 'color': '#FF000000'},
          },
        },
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('site_variables_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, String)> render(WidgetTester tester, Object? variables) async {
    final dir = Directory('${out.path}/site')..createSync();
    File('${dir.path}/home.json')
        .writeAsStringSync(jsonEncode(_page(r'${= length(cart)} items, ${= count + 1} next, ${plan}, ${= length(tags)} tags')));
    File('${dir.path}/site.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'pages': ['home.json'],
      'variables': variables,
    }));
    final report =
        await runRender(tester, RenderArgs(inputs: [dir.path], out: '${out.path}/o', sizes: const [Size(390, 200)], dumpLayout: true));
    final file = File('${out.path}/o/home@390x200.layout.json');
    final boxes = file.existsSync() ? jsonDecode(file.readAsStringSync()) as List : const [];
    final text = boxes.cast<Map>().where((b) => b['id'] == 'label').map((b) => '${b['text']}').firstOrNull ?? '';
    return (report, text);
  }

  testWidgets('variables by name: a list is a list, a number a number', (tester) async {
    final (report, text) = await render(tester, {
      'cart': [
        {'name': 'Tea'},
        {'name': 'Milk'},
      ],
      'count': 2,
      'plan': 'pro',
      'tags': {'value': ['a', 'b', 'c'], 'persist': true},
    });
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(text, '2 items, 3 next, pro, 3 tags');
  });

  testWidgets('records without a type have the type of their value', (tester) async {
    final (report, text) = await render(tester, [
      {'name': 'cart', 'value': [1, 2, 3, 4]},
      {'name': 'count', 'value': 9},
      {'name': 'plan', 'value': 'team'},
      {'name': 'tags', 'value': []},
    ]);
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(text, '4 items, 10 next, team, 0 tags');
  });

  // The notation's expander beside a site.json whose variables are written
  // by name: the page uses them without declaring them, and nothing throws.
  test('expand.dart reads a site\'s variables written by name', () async {
    final root = Platform.environment['FLUTTER_ROOT'];
    final dart = root == null ? null : File('$root/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}');
    if (dart == null || !dart.existsSync()) {
      markTestSkipped('No Dart SDK under FLUTTER_ROOT.');
      return;
    }
    final dir = Directory('${out.path}/site')..createSync();
    File('${dir.path}/site.json').writeAsStringSync(jsonEncode({
      'schema': 3,
      'pages': ['home.json'],
      'variables': {'cart': [], 'plan': 'pro', 'count': 2},
    }));
    File('${dir.path}/home.txt').writeAsStringSync('Column\n  Text "{length(cart)} in the cart on {plan}"\n  Button "Add" onTap={cart=append(cart,count)}\n');
    final r = await Process.run(dart.path, ['run', 'tool/notation/expand.dart', '${dir.path}/home.txt', '--out', '${dir.path}/home.json']);
    expect(r.stderr, isNot(contains('Unhandled exception')));
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final doc = jsonDecode(File('${dir.path}/home.json').readAsStringSync()) as Map;
    expect(jsonEncode(doc['variables'] ?? const {}), isNot(contains('"cart"')), reason: 'the site\'s variable is not declared again on the page');

    // A manifest whose variables are unreadable: no stack trace.
    File('${dir.path}/site.json').writeAsStringSync(jsonEncode({'schema': 3, 'variables': 'cart'}));
    final bad = await Process.run(dart.path, ['run', 'tool/notation/expand.dart', '${dir.path}/home.txt', '--out', '${dir.path}/home.json']);
    expect(bad.stderr, isNot(contains('Unhandled exception')));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
