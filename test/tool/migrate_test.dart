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

  test('Markdown: a fenced block as a page, a code span that is a notation line; prose about the old form is left, and said', () {
    const old = 'A slider keeps its value with `Slider bind=volume`, and `bind=name` names it.\n\n```\nColumn\n  Toggle "On" bind=on\n```\n\n```dart\nfinal bind=1;\n```\n';
    final m = _m();
    final got = m.markdown(old);
    expect(got, 'A slider keeps its value with `Slider @volume`, and `bind=name` names it.\n\n```\nstate on=false\nColumn\n  Toggle "On" @on\n```\n\n```dart\nfinal bind=1;\n```\n');
    expect(m.notes, [startsWith('line 1: mentions bind= in prose, left'), startsWith('line 9: mentions bind= in prose, left')]);
  });

  test('Dart and Python: string literals, one line alone, several as a page', () {
    const dart = "final a = parse('Column\\n  Slider bind=v\\n');\nconst b = '''\nColumn\n  Toggle bind=t\n''';\n// bind=x in a comment\nfinal c = 'Input bind=q'; final bind = 2;\n";
    expect(_m().code(dart, python: false),
        "final a = parse('state v=0\\nColumn\\n  Slider @v\\n');\nconst b = '''\nstate t=false\nColumn\n  Toggle @t\n''';\n// bind=x in a comment\nfinal c = 'Input @q'; final bind = 2;\n");
    const py = "page = '''\nColumn\n  Input bind=q\n'''\nline = \"Slider bind=v\"  # bind=x\n";
    expect(_m().code(py, python: true), "page = '''\nstate q=\"\"\nColumn\n  Input @q\n'''\nline = \"Slider @v\"  # bind=x\n");
  });

  // Defects found where the first version of the tool ran over the repository
  // (docs/design/13-compact-notation.md section 3.1 is what 33 read as a
  // binding): each with the line that must come out.
  group('what 33 did not read as a binding is left as written', () {
    test('1. a value in braces is shown, one way, on every key', () {
      const old = '### A\nstate s=3\nPage\n  Rating value={s} readonly\n  Stepper.progress steps=["A","B"] value={step}\n  Progress value={s}\n  Slider value={s}\n';
      final m = _m();
      expect(m.notation(old), old);
      expect(m.log, isEmpty);
    });

    test('2. a RangeSlider\'s ends in braces stay as written; bare names are the range', () {
      const old = '### A\nstate lo=1\nstate hi=2\nPage\n  RangeSlider lo={lo} hi={hi} min=0 max=9\n';
      expect(_m().notation(old), old);
      expect(_m().notation('state a=1\nstate b=2\nColumn\n  RangeSlider low=a high=b\n'), 'state a=1\nstate b=2\nColumn\n  RangeSlider @a @b\n');
    });

    test('3. a reordered list\'s bind= is no selection: the each\'s list is what is reordered', () {
      const old = '### A\nstate xs=[]\nPage\n  Column reorder bind=xs onReorder={xs=result}\n    each x in xs\n      Text "{x}"\n';
      expect(_m().notation(old), '### A\nstate xs=[]\nPage\n  Column reorder onReorder={xs=result}\n    each x in xs\n      Text "{x}"\n');
      // Selected from as well: its selection.
      expect(_m().notation('state xs=[]\nColumn selectable reorder bind=picked\n  each x in xs\n    Text "{x}"\n'),
          'state xs=[]\nstate picked=[]\nColumn selectable reorder selected=@picked\n  each x in xs\n    Text "{x}"\n');
    });

    test('4. a signature\'s value with its default is one bound value, @value=0, and a use\'s variable starts there', () {
      const old = '### A\nPage\n  Bar "a" bind=v\n\ndefine Bar "label" value=0 bind=value\n  Slider bind=value\n';
      expect(_m().notation(old), '### A\nstate v=0\nPage\n  Bar "a" @v\n\ndefine Bar "label" @value=0\n  Slider @value\n');
    });

    test('5. a further variable with its default is name=@default, and the definition\'s lines call it by that name', () {
      const old = 'state cropX=0.5\nDialog#crop "Crop"\n  CropFrame src="a.jpg" bindX=cropX bindY=cropY\n'
          'define CropFrame src="" zoom=1 bindX=0.5 bindY=0.5\n  state fx=0.5\n  Column\n    Slider bind=fx onChange={bindX=result}\n    Text "{bindY}"\n';
      expect(
          _m().notation(old),
          'state cropX=0.5\nstate cropY=0.5\nDialog#crop "Crop"\n  CropFrame src="a.jpg" x=@cropX y=@cropY\n'
          'define CropFrame src="" zoom=1 x=@0.5 y=@0.5\n  state fx=0.5\n  Column\n    Slider @fx onChange={x=result}\n    Text "{y}"\n');
    });

    test('6. a name the runtime reserves is not bound with a state line: left, and said', () {
      const old = '### A\nPage\n  SegmentedButton items=["Light","Dark"] bind=theme\n  Select items=["a","b"] bind=device\n';
      final m = _m();
      expect(m.notation(old), old);
      expect(m.notes, [contains('line 3: binds theme, a name the runtime reserves'), contains('line 4: binds device')]);
    });

    test('7. a defined word\'s variable starts at the definition\'s default, the design system\'s or the page\'s own', () {
      final cards = BindDefinition.read('// A slider with two thumbs keeping one list variable [low, high].\n'
          'RangeSlider @range min=0 max=100\n  state range=[0, 100]\n  Slider @low @high\n', definitionFile: true);
      final m = BindMigration(api.standardCatalog, definitions: cards);
      expect(m.notation('Column\n  RangeSlider bind=range\n'), 'state range=[0,100]\nColumn\n  RangeSlider @range\n');
      // Two ends are our Slider's, at its own ends.
      expect(m.notation('Column\n  RangeSlider bind=lo bindEnd=hi max=9\n'), 'state lo=0\nstate hi=9\nColumn\n  RangeSlider @lo @hi max=9\n');
      // The page's own definition, in 33's form.
      expect(_m().notation('Column\n  Pick bind=p\ndefine Pick bind=value\n  state value="a"\n  Select @value items=["a"]\n'),
          'state p="a"\nColumn\n  Pick @p\ndefine Pick @value\n  state value="a"\n  Select @value items=["a"]\n');
    });

    test('8. a docstring that quotes the notation is prose: its code span rewritten, no state line', () {
      const py = 'def f(doc):\n    """SSUI\'s SortMenu is the body of a menu. Written on\n    a page (`SortMenu bind=sort options=[...]`) it drew that panel open."""\n    return doc\n';
      final m = _m();
      expect(m.code(py, python: true), py.replaceFirst('bind=sort', '@sort'));
      expect(m.notes, isEmpty);
      // A multi-line literal that is a page gets its state lines.
      expect(_m().code("page = '''\nColumn\n  Input bind=q\n'''\n", python: true), "page = '''\nstate q=\"\"\nColumn\n  Input @q\n'''\n");
    });

    test('10. an @ already in a fence is no binding of the rewrite: no state line, in a fence that is no notation least of all', () {
      const md = 'Files:\n\n```\na.json    the source + @targets\nOwned by: @Codelessly\n```\n\n```\nColumn\n  Slider @v\n```\n';
      final m = _m();
      expect(m.markdown(md), md);
      expect(m.log, isEmpty);
      // A fence of prose that writes bind= gets no state line either: said.
      final p = _m();
      expect(p.markdown('```\nThe slider: Slider bind=v keeps it.\nAnother line of prose.\n```\n'), '```\nThe slider: Slider @v keeps it.\nAnother line of prose.\n```\n');
      expect(p.notes.single, contains('no state line was added'));
    });

    test('11. prose that names the old form is left; a code span that is a notation line is rewritten', () {
      final m = _m();
      const md = '`bind=name` is gone: write `Slider bind=volume` as the new form says, and bind=x in a sentence too.\n';
      expect(m.markdown(md), '`bind=name` is gone: write `Slider @volume` as the new form says, and bind=x in a sentence too.\n');
      expect(m.notes.single, contains('mentions bind= in prose, left'));
      // HTML and one-line strings: a line that starts with a type word.
      final h = _m();
      expect(h.loose('<p>Then write bind=x.</p>\n<pre>  Toggle "On" bind=on</pre>\n'), '<p>Then write bind=x.</p>\n<pre>  Toggle "On" @on</pre>\n');
      expect(h.notes.single, startsWith('line 1: mentions bind= in prose'));
    });

    test('12. bind= put together by code is left and said', () {
      final d = _m();
      const dart = "final a = '  Slider bind=\$key min=0';\nfinal b = 'Toggle bind=\${name}';\nfinal c = 'Input bind=' + k;\n";
      expect(d.code(dart, python: false), dart);
      expect(d.notes, [contains('line 1: bind= built in code'), contains('line 2: bind= built in code'), contains('line 3: bind= built in code')]);
      final p = _m();
      const py = "line = f\"Slider bind={name}\"\nother = 'Slider bind=%s' % name\nkeep = f\"{pad}Toggle bind=on\"\n";
      expect(p.code(py, python: true), "line = f\"Slider bind={name}\"\nother = 'Slider bind=%s' % name\nkeep = f\"{pad}Toggle @on\"\n");
      expect(p.notes, hasLength(2));
    });
  });

  group('displays', () {
    test('13. a display with a value of its own keeps it: the bind is dropped, never a second value=', () {
      expect(_m().notation('Column\n  Progress bind=x value=0.5\n  Progress bind={0} value={done/total}\n  Progress bind=share\n'),
          'Column\n  Progress value=0.5\n  Progress value={done/total}\n  Progress value={share}\n');
    });

    test('14. prose and patterns read a display as a page does: value={done}', () {
      final m = _m();
      const py = r"pattern = re.compile(r'A bar \(or Progress bind=done\) shows it')" '\n';
      expect(m.code(py, python: true), py.replaceFirst('Progress bind=done', 'Progress value={done}'));
      expect(_m().markdown('Write `Progress bind=done`.\n'), 'Write `Progress value={done}`.\n');
      expect(_m().loose('(as Progress bind=done) here\n'), '(as Progress value={done}) here\n');
    });
  });

  // 9: each heuristic of the file rewrite, with what it must not touch.
  group('left as it is', () {
    test('code: comments, code that names bind, literals with no notation', () {
      const dart = "// Slider bind=x in a comment\nfinal bind = 1; f(bind: 2);\nfinal s = 'a binding=3';\nfinal t = 'onTap={bindX=1}';\n";
      expect(_m().code(dart, python: false), dart);
      const py = "# Slider bind=x\nkw = dict(bind=bind or None)\nx = 'Text \"bind=x is old\"'\n";
      expect(_m().code(py, python: true), py);
    });

    test('JSON: strings with no notation line, keys named bind', () {
      const json = '{"bind": "x", "note": "write bind=name", "n": "Box w={bindW}"}';
      final m = _m();
      expect(m.json(json), json);
      expect(m.notes.single, contains('mentions bind= in prose'));
    });

    test('a page: state lines, statements, loops, existing marks and declared variables', () {
      const page = 'state on=false\nlet bindX=1\nColumn\n  Toggle @on\n  Slider @free\n  each bind in rows\n    Text "{bind}"\n  Button "Go" onTap={bindX=2}\n';
      final m = _m();
      expect(m.notation(page), page);
      expect(m.log, isEmpty);
    });

    test('a fence of another language, and a fence with no notation in it', () {
      const md = '```dart\nSlider bind=x\n```\n\n```\nsrc/\n  bind=3.txt\n```\n';
      final m = _m();
      expect(m.markdown(md), '```dart\nSlider @x\n```\n\n```\nsrc/\n  bind=3.txt\n```\n');
    });

    test('a file of definitions is not taken for a page, nor a page for one', () {
      expect(_m().notation('Column\n  Toggle bind=on\n'), 'state on=false\nColumn\n  Toggle @on\n');
      expect(_m().notation('Knob bind=value min=0\n  Slider bind=value\n'), 'Knob @value min=0\n  Slider @value\n');
    });

    test('a site\'s variable and a variable declared after its line get no state line', () {
      expect(_m({'q'}).notation('Column\n  Input bind=q\n'), 'Column\n  Input @q\n');
      expect(_m().notation('Column\n  Input bind=q\nstate q=""\n'), 'Column\n  Input @q\nstate q=""\n');
    });
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
      // The corpus is itself rewritten to this grammar: an answer already in
      // it is read as it is, and rewriting it again changes nothing.
      final text = f.readAsStringSync();
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
