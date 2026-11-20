// A formula the engine cannot parse is said (tool/notation/formula_check.dart):
// by expand where it was written, by render on its node (formula_invalid).
// Before, it gave nothing with no word: test 10's kanban board drew no cards.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/formula_check.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const _board = '''
state cards=[{"title":"A","col":"todo"}]
state cols=[{"id":"todo"}]
state draft=""
Row gap=8
  each col in cols
    Column
      each c in sortBy(filter(cards,x=>x.col==col.id)),x=>x.title)
        Text "{c.title}"
      Button "Add" onTap={draft!="" ? cards=append(cards,{"title":draft,"col":col.id}); draft="" : toast "Type a title first"}
''';

void main() {
  test('the kanban board: the extra ")" is an issue of its line, and the branch of two unbraced actions a formula that does not parse', () {
    final r = api.Catalog.run(api.standardCatalog, () => parseNotation(_board));
    expect(r.issues.map((i) => '${i.line}:${i.column}: ${i.message}'), contains(startsWith('7:54: the list\'s formula ends at column 54')));
    final bad = unreadableFormulas(r.document);
    expect([for (final f in bad) f.expression], [startsWith('sortBy(filter(cards,'), '"" : toast "Type a title first"']);
    expect(bad.first.field, 'bind.data');
    // expand says each where it was written; a line an issue said is not said again.
    final notes = formulaNotes(r.document, {'pages/board.txt': _board});
    expect(notes, [startsWith('pages/board.txt:7:17: the formula does not parse, so node'), startsWith('pages/board.txt:9:')]);
    expect(formulaNotes(r.document, {'pages/board.txt': _board}, said: {'pages/board.txt:7'}), [startsWith('pages/board.txt:9:')]);
  });

  // The NOCD chat: `"replyTo": null` in site.json is a text variable; the map
  // set into it was kept as its JSON text and {replyTo.first_name} drew
  // nothing, with no word.
  test('a variable null with no type read by a field is said, with the type to write', () {
    const page = '''
state pick=null
state note=null
state typed:map=null
Column
  Text#a "{pick.name}"
  Text#b "{note}"
  Text#c "{replyTo.first_name} {typed.name}"
  Button#d "Set" onTap={pick={name: 'x'}}
''';
    final site = {
      'replyTo': {'type': 'text'},
      'shown': {'type': 'text', 'value': ''},
    };
    final r = api.Catalog.run(api.standardCatalog, () => parseNotation(page, options: NotationOptions(projectVariables: site)));
    expect(r.issues, isEmpty);
    expect(nullTextVariableNotes(r.document, site: site), [
      'state pick=null has no type, so it is a text variable, and node a reads pick.name from it: a field of text is nothing, '
          'and a map or list set into it is kept as its JSON text. Say its type: state pick:map=null (or :list).',
      'the site\'s variable "replyTo" (null in site.json) has no type, so it is a text variable, and node c reads replyTo.first_name from it: '
          'a field of text is nothing, and a map or list set into it is kept as its JSON text. Say its type: "replyTo": {"type": "map", "value": null} (or "list").',
    ]);
  });

  testWidgets('render: formula_invalid on the node, with the field and the expression', (tester) async {
    final out = Directory.systemTemp.createTempSync('formula_check_test');
    addTearDown(() => out.deleteSync(recursive: true));
    final doc = api.Catalog.run(api.standardCatalog, () => parseNotation(_board)).document;
    File('${out.path}/board.json').writeAsStringSync(jsonEncode(doc));
    final report = await runRender(tester, RenderArgs(inputs: ['${out.path}/board.json'], out: '${out.path}/o', sizes: const [Size(390, 844)]));
    final bad = [for (final d in report.diagnostics) if (d['code'] == 'formula_invalid') d];
    expect(bad, isNotEmpty);
    final list = bad.firstWhere((d) => (d['message'] as String).contains('sortBy(filter('));
    expect(list['nodeId'], isA<String>());
    expect(list['message'], contains('(bind.data)'));
    expect(list['severity'], 'warning');
  });
}
