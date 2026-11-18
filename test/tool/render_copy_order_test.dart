// Writers' cases through the render tool (tool/render): steps that name copies and rows,
// and a list that sticks to its end with no height: `card#n` counts the copies
// of nested lists in the document's order, the outer list's first (a
// board's cards column by column; test 9, kanban: `cardBox#7` opened the
// second card of the first column); a tap that names a row lands where no
// press target inside it is (test 9, admin: `--tap memberTable-row#0` hit
// the name's own link).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const _page = '''
state picked="none"
state cols=[{"cards":["a","b","c"]},{"cards":["d"]}]
Column gap=12 pad=16
  Text#label "picked {picked}"
  Row#board gap=12 top
    each col in cols
      Column#lane w=120 gap=4
        each k in col.cards
          Box#card w=120 h=30 fill=#FFDDDDDD onTap={picked=k}
  Row#row w=300 h=40 gap=8 middle fill=#FFEEEEEE onTap={picked="row"}
    Box#spacerLeft w=4 h=4
    Text#link "Open" w=220 onTap={picked="link"}
''';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_copy_order_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<String> run(WidgetTester tester, List<Step> steps) async {
    final r = parseNotation(_page, catalog: api.standardCatalog, options: const NotationOptions(width: 390, screen: 'page', reflow: false));
    expect(r.issues, isEmpty);
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(r.document));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
    expect(report.diagnostics.where((d) => d['severity'] == 'error'), isEmpty, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/o/page@390x700.layout.json').readAsStringSync()) as List;
    return '${boxes.cast<Map>().firstWhere((b) => b['id'] == 'label')['text']}';
  }

  testWidgets('the n-th copy of nested lists is counted column by column', (tester) async {
    expect(await run(tester, const [Step('tap', 'card#1')]), 'picked b');
    expect(await run(tester, const [Step('tap', 'card#3')]), 'picked d');
  });

  testWidgets('a tap that names a row lands on the row, not on a press target inside it', (tester) async {
    expect(await run(tester, const [Step('tap', 'row')]), 'picked row');
  });

  testWidgets('a list that sticks to its end with no height of its own, in a column that scrolls, is its items (it threw)', (tester) async {
    final r = parseNotation('''
state msgs=["one","two","three"]
Column#body h=300 scroll
  Text "Comments"
  ListView#comments stickToEnd gap=8
    each m in msgs
      Text "{m}"
''', catalog: api.standardCatalog, options: const NotationOptions(width: 390, screen: 'page', reflow: false));
    expect(r.issues, isEmpty);
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(r.document));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)]));
    expect(report.diagnostics.where((d) => d['code'] == 'render_exception'), isEmpty, reason: '${report.diagnostics}');
  });
}
