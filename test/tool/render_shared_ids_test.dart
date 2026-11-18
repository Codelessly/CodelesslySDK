// A page's node and a component's node of the same id (a generated
// `listView1Item`, a `row3`): a step under the page's canvas reaches the
// page's, a list copy by index is never counted across the two, and a
// diagnostic names the page's file for the page's node (test 9: a step
// meant for a table's row toggled a filter chip, an overflow of a page's row
// was reported in a component's file).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  late Directory site;
  setUp(() {
    site = Directory.systemTemp.createTempSync('render_shared_ids_test');
    Directory('${site.path}/components').createSync();
    Directory('${site.path}/pages').createSync();
    File('${site.path}/site.json').writeAsStringSync(jsonEncode({'schema': 3, 'pages': ['pages/home.json']}));
    for (final name in ['Card.json']) {
      File('${site.path}/components/$name').writeAsStringSync(File('test/tool/fixtures/components/components/$name').readAsStringSync());
    }
    final home = jsonDecode(File('test/tool/fixtures/components/pages/home.json').readAsStringSync()) as Map<String, Object?>;
    final nodes = home['nodes']! as Map<String, Object?>;
    // The page's own `btn`, beside the Card calls whose root holds theirs.
    (nodes['col']! as Map)['children'] = ['card1', 'card2', 'btn', 'status'];
    nodes['btn'] = {
      'type': 'box',
      'layout': {'width': 120, 'height': 36},
      'decoration': {
        'fills': [
          {'color': '#FF00AA00'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setVariable', 'variable': 'last', 'value': 'the page'},
          ],
        },
      ],
    };
    File('${site.path}/pages/home.json').writeAsStringSync(jsonEncode(home));
  });
  tearDown(() => site.deleteSync(recursive: true));

  String status(Directory out) {
    final boxes = jsonDecode(File('${out.path}/home@390x844.layout.json').readAsStringSync()) as List;
    return boxes.map((b) => (b as Map)['text']).whereType<String>().firstWhere((t) => t.startsWith('Last pressed'));
  }

  testWidgets('a path from the canvas is the page\'s own node', (tester) async {
    final out = Directory('${site.path}/out')..createSync();
    final report = await runRender(tester,
        RenderArgs(inputs: [site.path], out: out.path, sizes: const [Size(390, 844)], steps: const [Step('tap', 'home/btn')], dumpLayout: true));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(status(out), 'Last pressed: the page');
  });

  testWidgets('a copy by index is not counted across a page\'s node and a component\'s', (tester) async {
    final out = Directory('${site.path}/out')..createSync();
    final report = await runRender(tester, RenderArgs(inputs: [site.path], out: out.path, sizes: const [Size(390, 844)], steps: const [Step('tap', 'btn#1')]));
    final failed = [for (final d in report.diagnostics) if (d['code'] == 'interaction_failed') '${d['message']}'];
    expect(failed.single, allOf(contains('ambiguous'), contains('home/btn#1')));
  });
}
