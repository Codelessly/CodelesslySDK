// The vocabulary record `expand` keeps by default, and what says the words
// that stood in (codelessly_api docs/design/19-open-vocabulary.md, section
// 15): tool/notation/vocabulary_record.dart, vocabulary_sites.dart (the
// harvest across runs), notation_site.dart (component files that were
// skipped with no word), and the render's placeholder_word.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/outline.dart' show outlineText;
import '../../tool/notation/notation_site.dart';
import '../../tool/notation/vocabulary_record.dart';
import '../../tool/notation/vocabulary_sites.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

late Directory _root;

void _write(String path, String text) => File('${_root.path}/$path')
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(text);

ExpandSettings _settings({bool open = true}) => (width: 1440, reflow: false, named: false, nearestColors: false, open: open, aliases: NotationVocabulary.core);

/// The site at [_root] expanded as `expand <folder>` does, its record merged
/// into vocabulary.json at [time]; the snapshot.
Future<(NotationSite, RecordSnapshot)> _expand({bool open = true, required DateTime time, bool write = false}) async {
  final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
  final expander = NotationExpander(site: site, settings: _settings(open: open));
  final snap = siteSnapshot(site, open: open, dir: site.home);
  final x = expandSitePages(expander, site);
  for (final c in x.components) {
    snap.file(recordPath(c.path, site.home), File(c.path).readAsStringSync(), x.componentResults[c.type]!, extra: site.definitionText, page: c.type);
  }
  for (final (i, p) in x.pages.indexed) {
    snap.file(recordPath(p.path, site.home), File(p.path).readAsStringSync(), x.results[i], extra: site.definitionText, page: p.name);
    if (write) {
      File(site.pageOut(p.path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(p.document));
    }
  }
  saveRecord('${site.home}/vocabulary.json', snap, whole: true, time: time);
  return (site, snap);
}

Map<String, Object?> _record() => jsonDecode(File('${_root.path}/vocabulary.json').readAsStringSync()) as Map<String, Object?>;

Map<String, Object?> _word(String kind, String word, {String? on}) => ((_record()['words'] as List).cast<Map>().firstWhere(
      (w) => w['kind'] == kind && w['word'] == word && w['on'] == on,
      orElse: () => throw StateError('no $kind ${on ?? ''}.$word in the record'),
    ))
    .cast<String, Object?>();

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('vocabulary_record_test');
    _write('site/site.json', jsonEncode({'schema': 3, 'pages': ['home.json', 'about.json'], 'variables': {'n': 0}}));
    _write('components/Tag.txt', 'component Tag "A tag."\n  param label="x"\nRow#tag\n  Text "{props.label}"\n');
    // Definitions in components/: the site's, read by every page.
    _write('components/Pill.txt', '// A rounded label.\ndefine Pill "label" tone="neutral" onTap\n  Box pad=6 radius=12 onTap={onTap}\n    Text "{label}"\n');
    _write('pages/home.txt', [
      'state q=""',
      'key mod+k onPress={n=1}',
      'Column gap=8',
      '  Tag label="a"',
      '  Pill "New" tone="info"',
      '  Shortcut "ctrl+j" onPress={n=2}',
      '  MiniMonth "June" days=[1,2] onPick={n=3}',
      '    Text "under it"',
      '  Badge "3" wobble=2',
      '  Note "x"',
      'define Note "text"',
      '  Text.caption "{text}"',
      'primitive Map "place"',
    ].join('\n'));
    _write('pages/about.txt', 'Column\n  Text "about"\n  Masthead\n');
  });
  tearDown(() => _root.deleteSync(recursive: true));

  test('the record of a site folder: every word, how it resolved, its shapes, lines and definition', () async {
    await _expand(time: DateTime.utc(2026, 11, 18, 9));
    final r = _record();
    expect(r['record'], recordMarker);
    expect(File('${_root.path}/VOCABULARY.md').existsSync(), isTrue);
    expect(_word('type', 'Column')['resolved'], 'core');
    expect(_word('type', 'Tag')['resolved'], 'site');
    expect((_word('type', 'Tag')['definition'] as Map)['file'], 'components/Tag.txt');
    final pill = _word('type', 'Pill');
    expect((pill['resolved'], pill['definedBy']), ('definition', 'site'));
    expect((pill['definition'] as Map)['text'], startsWith('// A rounded label.\ndefine Pill "label" tone="neutral" onTap\n'));
    final note = _word('type', 'Note');
    expect((note['resolved'], note['definedBy']), ('definition', 'page'));
    expect((note['definition'] as Map)['file'], 'pages/home.txt');
    expect(_word('type', 'Map')['status'], 'defined, not used');
    expect((_word('type', 'Shortcut')['resolved'], _word('type', 'Shortcut')['to']), ('alias', 'key'));
    final month = _word('type', 'MiniMonth');
    expect(month['resolved'], 'unknown');
    expect(month['files'], {
      'pages/home.txt': {
        'lines': [7],
        'how': {'unknown': 1},
        'signatures': {'MiniMonth "text" days= onPick ...': 1},
      },
    });
    expect((month['signatures'] as List).single, containsPair('signature', 'MiniMonth "text" days= onPick ...'));
    expect(_word('parameter', 'wobble', on: 'Badge')['resolved'], 'unknown');
    expect(_word('key', 'mod+k')['resolved'], 'core');
    expect(_word('type', 'Masthead')['files'], contains('pages/about.txt'));
    // Each placeholder, with its node and its page, for render and validate.
    final held = (r['placeholders'] as List).cast<Map>();
    expect([for (final p in held) '${p['word']} ${p['kind']} ${p['file']}:${p['line']} ${p['page']}'], unorderedEquals(['MiniMonth type pages/home.txt:7 home', 'Masthead type pages/about.txt:3 about']));
    expect(held.every((p) => p['node'] is String), isTrue);
  });

  test('closed: a word an issue names is refused, with the message; the placeholders list has the refused type', () async {
    await _expand(open: false, time: DateTime.utc(2026, 11, 18, 9));
    final month = _word('type', 'MiniMonth');
    expect(month['resolved'], 'refused');
    expect(month['messages'], [startsWith('No node type "MiniMonth"')]);
    expect(_word('parameter', 'days', on: 'MiniMonth')['resolved'], 'refused');
    expect(_word('parameter', 'wobble', on: 'Badge')['resolved'], 'refused');
    expect([for (final p in (_record()['placeholders'] as List).cast<Map>()) '${p['word']} ${p['kind']}'], unorderedEquals(['MiniMonth refused', 'Masthead refused']));
  });

  test('the record accumulates: a word rewritten away is still there, no longer used, with when it was first and last seen', () async {
    await _expand(time: DateTime.utc(2026, 11, 18, 9));
    // The writer defines MiniMonth and drops Masthead.
    _write('pages/home.txt', '${File('${_root.path}/pages/home.txt').readAsStringSync()}\ndefine MiniMonth "title" days=[] onPick\n  Column\n    Text "{title}"\n    ...\n');
    _write('pages/about.txt', 'Column\n  Text "about"\n');
    await _expand(time: DateTime.utc(2026, 11, 18, 10));
    final mast = _word('type', 'Masthead');
    expect(mast['status'], 'no longer used');
    expect((mast['first'], mast['last']), ('2026-11-18T09:00:00Z', '2026-11-18T09:00:00Z'));
    expect((mast['history'] as Map).keys, ['unknown']);
    final month = _word('type', 'MiniMonth');
    expect(month['resolved'], 'definition');
    expect(month['history'], {
      'unknown': {'first': '2026-11-18T09:00:00Z', 'last': '2026-11-18T09:00:00Z'},
      'definition': {'first': '2026-11-18T10:00:00Z', 'last': '2026-11-18T10:00:00Z'},
    });
    expect((month['definition'] as Map)['text'], startsWith('define MiniMonth "title" days=[] onPick'));
    expect((_record()['expands'] as List), hasLength(2));
    expect(File('${_root.path}/VOCABULARY.md').readAsStringSync(), contains('## No longer used'));
    expect((_record()['placeholders'] as List), isEmpty);
    // One file expanded alone keeps the others' words as they were.
    final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
    final snap = siteSnapshot(site, open: true, dir: site.home);
    final text = File('${_root.path}/pages/about.txt').readAsStringSync();
    snap.file('pages/about.txt', text, NotationExpander(site: site, settings: _settings()).expand(text, path: 'about.txt', screen: 'about'));
    saveRecord('${site.home}/vocabulary.json', snap, time: DateTime.utc(2026, 11, 18, 11));
    expect(_word('type', 'Pill')['status'], 'used');
  });

  group('no silent component file', () {
    test('a components/*.txt that is neither a component nor definitions is said, and what calls it is said too', () async {
      _write('components/Masthead.txt', 'Nav\n  Brand "Slow Atlas"\n');
      final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
      expect(site.skipped.map((s) => s.message), [allOf(startsWith('components/Masthead.txt is not read'), contains('`define Masthead`'))]);
      final text = File('${_root.path}/pages/about.txt').readAsStringSync();
      final open = NotationExpander(site: site, settings: _settings()).expand(text, path: 'about.txt', screen: 'about');
      expect(vocabularyNotes(open, site: site), [allOf(contains('"Masthead"'), contains('placeholder'), contains('Masthead.txt in components/ would give it'))]);
      final closed = NotationExpander(site: site, settings: _settings(open: false)).expand(text, path: 'about.txt', screen: 'about');
      expect(vocabularyNotes(closed, site: site), [contains('Masthead.txt in components/ would give it')]);
    });

    test('a components/*.txt of define blocks is the site\'s: every page calls it, its signature from its define line', () async {
      final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
      expect(site.skipped, isEmpty);
      expect(site.definedWords.keys, ['Pill']);
      expect(site.definedWords['Pill'], endsWith('Pill.txt'));
      final text = File('${_root.path}/pages/home.txt').readAsStringSync();
      final r = NotationExpander(site: site, settings: _settings(open: false)).expand(text, path: 'home.txt', screen: 'home');
      expect([for (final u in r.vocabulary) if (u.kind == 'definition') u.word], containsAll(['Pill', 'Note']));
      expect(r.issues.where((i) => i.message.contains('Pill')), isEmpty);
    });

    test('what a file of definitions has wrong is said, naming its file and line', () async {
      _write('components/Bad.txt', 'define Bad "x"\n  Text "{x}"\nColumn\n  Text "stray"\n');
      final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
      expect(site.skipped.map((s) => s.message), [startsWith('components/Bad.txt: line 3: `Column` is in no definition')]);
      // An issue in a site definition's lines names its file, not `page:N`.
      expect(site.placeDefinitionLine('page:6: Pill: "focusable" is not a flag the notation has.', 'Column\n'), startsWith('components/Pill.txt:'));
    });

    test('a built-in word wins: a site\'s primitive or component named like one is not used, said at its file, and recorded built-in', () async {
      // The kanban board's: every Shortcut line became a labelled box.
      _write('components/Shortcut.txt', '// Listens for the key.\nprimitive Shortcut "key" onPress\n');
      _write('components/Rail.txt', 'component Rail\nColumn\n  Text "rail"\n');
      final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
      expect(site.skipped.map((s) => s.message), [
        startsWith('components/Rail.txt: line 1: The notation already has Rail, a word of the page'),
        allOf(startsWith('components/Shortcut.txt: line 2: The notation already has Shortcut, read as the notation\'s shortcut line'),
            contains('So this primitive of Shortcut is not used')),
      ]);
      expect(site.definedWords.keys, isNot(contains('Shortcut')));
      final text = File('${_root.path}/pages/home.txt').readAsStringSync();
      final r = NotationExpander(site: site, settings: _settings()).expand(text, path: 'home.txt', screen: 'home');
      expect([for (final u in r.vocabulary) if (u.kind == 'primitive') u.word], isEmpty);
      expect([for (final u in r.vocabulary) if (u.kind == 'alias') u.word], contains('Shortcut'));
      await _expand(time: DateTime.utc(2026, 11, 18, 9));
      final w = _word('type', 'Shortcut');
      expect((w['resolved'], w['status'], w['definedBy']), ('built-in', 'used', 'site'));
      expect((w['definition'] as Map)['builtIn'], startsWith('Shortcut, read as'));
      expect((w['definition'] as Map)['text'], contains('primitive Shortcut "key" onPress'));
    });

    test('a second file of one component, and a component JSON site.json lists that nothing writes, are said', () async {
      _write('components/Tag2.txt', 'component Tag "Again."\nRow\n');
      _write('site/site.json', jsonEncode({'schema': 3, 'pages': ['home.json'], 'components': ['components/Tag.json', 'components/Ghost.json']}));
      final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
      expect(site.skipped.map((s) => s.message), [
        contains('writes component Tag, which components/Tag.txt already writes'),
        startsWith('site.json lists components/Ghost.json, which is not there'),
      ]);
    });

    test('a page whose first line is `### name` is read without it; several are said', () async {
      _write('pages/home.txt', '### Home\nColumn\n  Text "hi"\n');
      final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
      final r = NotationExpander(site: site, settings: _settings(open: false)).expand(File('${_root.path}/pages/home.txt').readAsStringSync(), path: 'home.txt', screen: 'home');
      expect(r.issues, isEmpty);
      expect(pageHeadingsNote('### Home\nColumn\n'), isNull);
      expect(pageHeadingsNote('### A\nColumn\n### B\nColumn\n'), startsWith('lines 1, 3: `### Name` lines split this file into 2 screens'));
    });
  });

  test('placeholder lines: one per word, with its uses, and the total pointing to the record', () async {
    final (_, snap) = await _expand(time: DateTime.utc(2026, 11, 18, 9));
    final held = [
      for (final f in snap.files.values)
        for (final p in f.placeholders) (word: '${p['word']}', kind: '${p['kind']}', file: f.path, line: p['line'] as int, node: p['node'] as String?, source: '${p['source']}', children: false),
    ];
    expect(placeholderLines(held, leftOut: 1, record: 'vocabulary.json'), [
      'placeholder: Masthead (type) pages/about.txt:3 (1 use)',
      'placeholder: MiniMonth (type) pages/home.txt:7 (1 use)',
      '2 words stood in as placeholders (2 uses), 1 more left out; every word is in the vocabulary record, vocabulary.json.',
    ]);
  });

  test('validate: the placeholders and the words beyond the core, as data', () async {
    final (_, snap) = await _expand(time: DateTime.utc(2026, 11, 18, 9));
    final v = validationOf(snap, issues: const []);
    expect(v['ok'], isTrue);
    final held = {for (final p in (v['placeholders'] as List).cast<Map>()) p['word']: p};
    expect(held['MiniMonth'], {
      'word': 'MiniMonth',
      'kind': 'type',
      'resolution': 'placeholder',
      'signatures': ['MiniMonth "text" days= onPick ...'],
      'where': ['pages/home.txt:7'],
      'nodes': [
        {'page': 'home', 'node': isA<String>()},
      ],
      'uses': 1,
    });
    final words = {for (final w in (v['words'] as List).cast<Map>()) '${w['kind']} ${w['on'] ?? ''}.${w['word']}': w};
    expect(words.keys, containsAll(['type .Pill', 'type .Note', 'type .Tag', 'parameter Badge.wobble', 'type .Shortcut']));
    expect(words['type .Pill']!['definedBy'], 'site');
  });

  test('the harvest: runs merged, a word several writers made up ranked first, with its shapes', () async {
    HarvestRun run(String id, String app, List<Map<String, Object?>> words) => (id: id, app: app, source: id, record: {'words': words}, skipped: const []);
    Map<String, Object?> w(String word, String how, {String? sig, String? def}) => {
          'kind': 'type',
          'word': word,
          'status': 'used',
          'uses': 2,
          'how': {how: 2},
          'files': {
            'pages/a.txt': {'lines': [3, 9]},
          },
          'signatures': [if (sig != null) {'signature': sig}],
          if (def != null) 'definition': {'file': 'components/$word.txt', 'line': 1, 'text': def, 'by': 'site'},
          if (def != null) 'definedBy': 'site',
        };
    final words = mergeRuns([
      run('mail/1', 'mail', [w('Masthead', 'definition', def: 'define Masthead "title" sticky\n  Nav\n'), w('Waveform', 'unknown', sig: 'Waveform seed=')]),
      run('mail/2', 'mail', [w('Masthead', 'site', sig: 'Masthead "text" sticky')]),
      run('chat/1', 'chat', [w('Masthead', 'unknown', sig: 'Masthead "text"'), w('Column', 'core')]),
    ]);
    expect(words.keys, isNot(contains(contains('Column'))));
    final ranked = rankCandidates(words.values);
    expect(ranked.map((w) => w.word), ['Masthead']);
    final m = ranked.single;
    expect((m.runs, m.apps.length, m.agreement.agree), (3, 2, 3));
    expect(m.agreement.core, ['sticky', 'text1']);
    expect(m.shapeGroups, {
      'sticky text1': ['mail/1', 'mail/2'],
      'text1': ['chat/1'],
    });
  });

  test('expand.dart saves the record of a site folder by default, says each placeholder, and validate gives them as JSON', () async {
    final root = Platform.environment['FLUTTER_ROOT'];
    final dart = root == null ? null : File('$root/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}');
    if (dart == null || !dart.existsSync()) {
      markTestSkipped('No Dart SDK under FLUTTER_ROOT.');
      return;
    }
    _write('components/Masthead.txt', 'Nav\n  Brand "Slow Atlas"\n');
    // A components file that cannot be loaded fails the expand, --open too.
    final open = await Process.run(dart.path, ['run', 'tool/notation/expand.dart', _root.path, '--open']);
    expect(open.exitCode, 1, reason: '${open.stderr}');
    final said = '${open.stderr}';
    expect(said, contains('components/Masthead.txt is not read'));
    expect(said, contains('pages/about.txt: line 3:3: "Masthead" is a word the notation, the design system and the site do not have: a placeholder stands in for it'));
    expect(said, contains('placeholder: MiniMonth (type) pages/home.txt:7 (1 use)'));
    expect(said, contains('2 words stood in as placeholders (2 uses)'));
    expect('${open.stdout}', contains('components/Pill.txt -> defines Pill'));
    expect(_word('type', 'MiniMonth')['resolved'], 'unknown');
    expect(File('${_root.path}/site/home.json').existsSync(), isTrue);
    // Closed: the same words, refused; the skipped file is an issue.
    final closed = await Process.run(dart.path, ['run', 'tool/notation/expand.dart', _root.path]);
    expect(closed.exitCode, 1);
    expect('${closed.stderr}', contains('refused: Masthead (type) pages/about.txt:3 (1 use)'));
    expect((_record()['expands'] as List), hasLength(2));
    // validate writes nothing and prints JSON.
    File('${_root.path}/vocabulary.json').deleteSync();
    final v = await Process.run(dart.path, ['run', 'tool/notation/expand.dart', _root.path, '--open', '--validate']);
    expect(v.exitCode, 1, reason: '${v.stderr}');
    final json = jsonDecode('${v.stdout}') as Map;
    expect(json['ok'], isFalse);
    expect([for (final p in (json['placeholders'] as List).cast<Map>()) p['word']], unorderedEquals(['Masthead', 'MiniMonth']));
    expect((json['skipped'] as List).single, containsPair('file', 'components/Masthead.txt'));
    expect(File('${_root.path}/vocabulary.json').existsSync(), isFalse);
    // A word nobody defined stays a placeholder and, with --open, a warning.
    File('${_root.path}/components/Masthead.txt').deleteSync();
    final placeholders = await Process.run(dart.path, ['run', 'tool/notation/expand.dart', _root.path, '--open']);
    expect(placeholders.exitCode, 0, reason: '${placeholders.stderr}');
    expect('${placeholders.stderr}', contains('placeholder: Masthead (type) pages/about.txt:3 (1 use)'));
    File('${_root.path}/vocabulary.json').deleteSync();
    // --no-record saves none.
    await Process.run(dart.path, ['run', 'tool/notation/expand.dart', _root.path, '--open', '--no-record']);
    expect(File('${_root.path}/vocabulary.json').existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('render: each placeholder is a placeholder_word warning on its node, counted in the summary and marked in the outline', (tester) async {
    late NotationSite site;
    await tester.runAsync(() async {
      (site, _) = await _expand(time: DateTime.utc(2026, 11, 18, 9), write: true);
    });
    final out = '${_root.path}/out';
    final report = await runRender(tester, RenderArgs(inputs: [site.dir], out: out, sizes: const [Size(1440, 900)], screens: const ['about'], dumpLayout: true));
    final held = [for (final d in report.diagnostics) if (d['code'] == 'placeholder_word') d];
    final mast = held.firstWhere((d) => (d['message'] as String).startsWith('"Masthead"'));
    expect((mast['severity'], mast['screen'], mast['file']), ('warning', 'about', 'pages/about.txt'));
    expect(mast['nodeId'], isA<String>());
    expect(mast['message'], contains('Define it, or it is recorded for support'));
    expect(formatReport(report), contains(RegExp(r'; 2 placeholder words \((Masthead, MiniMonth|MiniMonth, Masthead)\)\.')));
    expect(outlineText(out, [site.dir]), contains('[placeholder: Masthead]'));
  });
}
