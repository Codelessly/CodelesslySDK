// tool/notation/migrate.dart from codelessly_api 33's bindings to 34's
// (migrate_bind.dart): `bind=` rewritten as `@`, the state lines a screen
// needs added at its head, everything else kept byte for byte, idempotent,
// in each kind of file the notation is kept in; and answers of the corpus,
// rewritten, read with no binding issue.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/migrate_bind.dart';

BindMigration _m([Set<String> declared = const {}]) => BindMigration(api.standardCatalog, declared: declared);

/// The issues of [text] the rewrite answers for: the old form, a mark in
/// the wrong place, an undeclared variable.
List<String> _bindingIssues(String text) {
  final r = api.Catalog.run(api.standardCatalog, () => parseNotation(text, catalog: api.standardCatalog, options: const NotationOptions(width: 1280).open()));
  return [
    for (final i in r.issues)
      if (i.message.contains('bound with @') || i.message.contains('nothing declares') || i.message.contains('One @name a line') || i.message.contains('to bind:')) '$i',
  ];
}

void main() {
  test('a page: each binding as @, the state lines it needs at the head of its screen, the rest as it was', () {
    const old = '### Settings\n'
        'state volume=40\n'
        'Column gap=8\n'
        '  Slider bind=volume min=0 max=100\n'
        '  Input "Email" bind={email}\n'
        '  Slider bind=lo bindEnd=hi max=50\n'
        '  Column selectable bind=picked\n'
        '    each r in rows\n'
        '      Checkbox "{r.name}" bind=r.done\n'
        '  Progress bind={done/total}\n'
        '### Other\n'
        'Column\n'
        '  Toggle "On" bind=on\n';
    final m = _m();
    final got = m.notation(old);
    expect(got, '### Settings\n'
        'state volume=40\n'
        'state email=""\n'
        'state lo=0\n'
        'state hi=50\n'
        'state picked=[]\n'
        'Column gap=8\n'
        '  Slider @volume min=0 max=100\n'
        '  Input "Email" @email\n'
        '  Slider @lo @hi max=50\n'
        '  Column selectable selected=@picked\n'
        '    each r in rows\n'
        '      Checkbox "{r.name}" @r.done\n'
        '  Progress value={done/total}\n'
        '### Other\n'
        'state on=false\n'
        'Column\n'
        '  Toggle "On" @on\n');
    expect(m.log, isNotEmpty);
    // Again: nothing to do.
    expect(_m().notation(got), got);
  });

  test('line endings and every other byte are kept; a site\'s variable gets no state line', () {
    const old = '// A card.\r\nCard  gap=12\r\n  Input "Name" bind=name   hint="x"\r\n  Select bind=plan items=["a"]\r\n';
    final got = _m({'plan'}).notation(old);
    expect(got, '// A card.\r\nstate name=""\r\nCard  gap=12\r\n  Input "Name" @name   hint="x"\r\n  Select @plan items=["a"]\r\n');
  });

  test('a file of definitions: its signatures and lines rewritten, no state line added', () {
    const old = '// A box to write code in.\nCodeEditor bind=code h=200\n  state code=""\n  Input multiline bind=code h={h}\n';
    expect(_m().notation(old), '// A box to write code in.\nCodeEditor @code h=200\n  state code=""\n  Input multiline @code h={h}\n');
    // A page's own definitions after its screen: the signature too.
    const page = 'state q=""\nColumn\n  Search bind=q\ndefine Search bind=value\n  Input "Find" bind=value\n';
    expect(_m().notation(page), 'state q=""\nColumn\n  Search @q\ndefine Search @value\n  Input "Find" @value\n');
  });

  test('Markdown: a fenced block as a page, a code span and prose line by line', () {
    const old = 'A slider keeps its value with `Slider bind=volume`, and `bind=name` names it.\n\n```\nColumn\n  Toggle "On" bind=on\n```\n\n```dart\nfinal bind=1;\n```\n';
    final got = _m().markdown(old);
    expect(got, 'A slider keeps its value with `Slider @volume`, and `@name` names it.\n\n```\nstate on=false\nColumn\n  Toggle "On" @on\n```\n\n```dart\nfinal bind=1;\n```\n');
  });

  test('Dart and Python: string literals, one line alone, several as a page', () {
    const dart = "final a = parse('Column\\n  Slider bind=v\\n');\nconst b = '''\nColumn\n  Toggle bind=t\n''';\n// bind=x in a comment\nfinal c = 'Input bind=q'; final bind = 2;\n";
    expect(_m().code(dart, python: false),
        "final a = parse('state v=0\\nColumn\\n  Slider @v\\n');\nconst b = '''\nstate t=false\nColumn\n  Toggle @t\n''';\n// bind=x in a comment\nfinal c = 'Input @q'; final bind = 2;\n");
    const py = "page = '''\nColumn\n  Input bind=q\n'''\nline = f\"Slider bind={name}\"  # bind=x\n";
    expect(_m().code(py, python: true), "page = '''\nstate q=\"\"\nColumn\n  Input @q\n'''\nline = f\"Slider @name\"  # bind=x\n");
  });

  test('JSON: a string that holds notation', () {
    const json = '{"doc": "A player: NowPlaying bind=playing title=\\"x\\" (flips your playing variable).", "n": 1}';
    expect(_m().json(json), '{"doc":"A player: NowPlaying @playing title=\\"x\\" (flips your playing variable).", "n": 1}'.replaceFirst('"doc":', '"doc": '));
  });

  test('what it cannot rewrite is listed', () {
    expect(BindMigration.left('Column\n  Thing bind={a+1}\n  Text "ok"\n'), [2]);
    expect(BindMigration.left('Column\n  Slider @v\n'), isEmpty);
  });

  test('answers of the corpus, rewritten, read with no binding issue', () {
    final corpus = Directory('tool/vocabulary/corpus/2026-11-16-sonnet/answers');
    if (!corpus.existsSync()) return;
    final files = corpus.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList()..sort((a, b) => a.path.compareTo(b.path));
    var read = 0;
    for (final f in files.take(6)) {
      final text = f.readAsStringSync();
      if (!text.contains('bind=')) continue;
      final got = _m().notation(text);
      expect(got.contains(RegExp(r'(?<![A-Za-z0-9_.@-])bind(?:End)?=')), isFalse, reason: f.path);
      // Each screen of the answer read alone, as the tools read it.
      for (final screen in got.split(RegExp(r'^(?=### )', multiLine: true))) {
        expect(_bindingIssues(screen), isEmpty, reason: '${f.path}\n$screen');
      }
      expect(_m().notation(got), got, reason: 'idempotent: ${f.path}');
      read++;
    }
    expect(read, greaterThan(0));
  });
}
