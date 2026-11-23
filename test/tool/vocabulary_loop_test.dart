// The vocabulary loop (codelessly_api docs/design/19-open-vocabulary.md): a
// page written with words the notation does not have renders, with Cards,
// and the corpus tool's pieces read what they are given.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/vocabulary.dart' show loadVocabulary, screensOf;
import '../../tool/notation/vocabulary_harvest.dart' show Harvest;
import '../../tool/notation/vocabulary_words.dart' show CorpusWords, countLine, countOf;

// A page as a model writes it from the open prompt: unknown types (with
// lines under them, with nothing under them, over the page), parameters,
// flags, events, verbs and a variant we do not have, names we have under
// another name, and a Cards component called its own way.
const _page = '''
state q=""
state n=2 saved
state stars=4
state view=""
key ctrl+k onPress={open palette}
App
  Sidebar
    Text.strong "Proscenium"
    Text "Seats"
  Main
    Nav
      Text.heading3 "Choose your seats"
      Row gap=8
        Input#find "Find a row" @q clearable
        Button.danger "Clear" disabled={n==0} onTap={n=0; haptic}
    Column pad=24 gap=16
      SeatMap#plan "Stalls" rows={seats} chosen={picked} selectable max=8 h=120 fill=#FF111827 radius=12 onChange={n=length(result)}
        Legend "Premium" color=#FFD4A64A
        Text#under "Use the arrow keys to move between rows."
      Waveform seed=7 color=#66FFFFFF
      Row gap=12 middle
        Text#count "{n} seats"
        Rating value=4.6 readonly
        Tabs @view items=["Plan","List"]
      ListTile "Row A" "Two seats left" onTap={vibrate find}
      Progress {n/8}
QuickSwitcher#palette "Commands"
  CommandItem "Best available" onTap={n=2; close}
''';

void main() {
  late api.DesignSystem ds;
  late api.Catalog catalog;
  late NotationVocabulary aliases;

  setUpAll(() async {
    final problems = <String>[];
    ds = await api.DesignSystem.load((ref) async {
      final f = File('design_systems/cards/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    expect(problems, isEmpty);
    catalog = ds.catalogOver(api.standardCatalog);
    aliases = loadVocabulary(dir: 'design_systems/cards');
  });

  NotationResult expand(String text, {bool named = false}) => api.Catalog.run(
      catalog,
      () => parseNotation(text,
          catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 1280, named: named).open(vocabulary: aliases)));

  test('Cards has its own aliases, over the built-in ones', () {
    expect(aliases.parameters['Tabs'], {'items': 'tabs'});
    expect(aliases.flags['Rating'], {'readonly': 'readOnly'});
    expect(aliases.parameters['*'], {'disabled': '!enabled', 'readonly': 'readOnly'});
    // Cards' own names for its words (the vocabulary loop's Review 5, D25), and none of the built-in ones.
    final own = loadVocabulary(dir: 'design_systems/cards', builtIn: false).types.keys;
    expect(own, containsAll(['StarRating', 'Map']));
    expect(own, isNot(contains('RangeSlider')));
  });

  test('an open page with Cards: nothing is an issue, and every word is recorded', () {
    final r = expand(_page);
    expect(r.issues.map((i) => '$i'), isEmpty);
    List<String> of(String kind) => [for (final u in r.vocabulary) if (u.kind == kind) '${u.on == null ? '' : '${u.on}.'}${u.word}'];
    // Waveform is Cards' stand-in since the harvest (Review 5, D25).
    expect(of('type'), ['SeatMap', 'QuickSwitcher']);
    // Words Cards defines in the notation (its vocabulary/*.txt) are words we
    // have; what a use gives that its definition does not take is recorded.
    expect(of('definition'), ['Legend', 'Waveform', 'CommandItem']);
    // Legend "Premium" color=… is a key's entry (Legend#entry, review 7).
    expect(of('parameter'), ['Waveform.seed']);
    // A universal word (codelessly_api docs/design/21) on a defined word goes on its root;
    // clearable is an Input's own now.
    expect(of('universal'), contains('Waveform.color'));
    expect(of('flag'), isEmpty);
    // haptic is an action of the catalog, and every action is a verb by its type name (codelessly_api
    // docs/design/22, 2.3): only vibrate, which is no action, is recorded.
    expect(of('verb'), ['ListTile.vibrate']);
    expect(of('variant'), ['Button.Button.danger']);
    // Cards' Rating no longer needs a label (Review 6, D30).
    expect(of('missing'), isEmpty);
    expect(of('alias').toSet(), {'Button.disabled', 'Rating.readonly', 'Tabs.items'});
    final seat = r.vocabulary.firstWhere((u) => u.word == 'SeatMap');
    expect(seat.path, ['App', 'Main', 'Column']);
    expect(seat.children, ['Legend', 'Text']);
    expect(seat.parameters.keys, containsAll(['rows', 'chosen', 'max', 'h', 'fill', 'radius']));
    final palette = r.vocabulary.firstWhere((u) => u.word == 'QuickSwitcher');
    expect(palette.node, 'palette');
    expect(r.document['roots'], contains('palette'));
  });

  testWidgets('…and it renders: the stand-in shows its text and the lines under it, with no error', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
    final result = await session.applyNotation(
      Stream.value(_page),
      options: NotationOptions.fromDesignSystem(ds, width: 1280, named: true).open(vocabulary: aliases),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    expect(tester.takeException(), isNull);
    // The stand-in is laid out where it was written, as big as it said, with
    // the line under it inside it and what comes after it below it.
    final boxes = <String, NodeBox>{};
    void visit(RenderObject o) {
      if (o is NodeBox) boxes.putIfAbsent(o.id, () => o);
      o.visitChildren(visit);
    }

    for (final v in tester.binding.renderViews) {
      visit(v);
    }
    Rect rect(String id) => boxes[id]!.localToGlobal(Offset.zero) & boxes[id]!.size;
    expect(boxes.keys, containsAll(['plan', 'under', 'count', 'find']));
    expect(session.node('plan')?.type, 'column');
    expect(rect('plan').height, greaterThanOrEqualTo(120));
    expect(rect('plan').width, greaterThan(300));
    expect(rect('under').width, greaterThan(100));
    expect(rect('plan').contains(rect('under').center), isTrue);
    expect(rect('count').top, greaterThanOrEqualTo(rect('plan').bottom));
    expect(session.node('palette')?.type, 'canvas');
  });

  test('the harvest: a word defined in more than one answer, side by side, with what each leans on and where they disagree', () {
    final h = Harvest(kindOf: (w) => const {'Column', 'Row', 'Text', 'Ring', 'Slider', 'Box'}.contains(w) ? 'core' : 'unknown');
    h.answer('dj', '### Deck\nApp\n  Knob "Gain"\n\n// A rotary dial.\ndefine Knob "label" @value min=0 max=12 color=#FF22D3EE\n  Column gap=4\n    Ring {value/max} w=56 color={color}\n    Text "{label}"\n');
    h.answer('seq', 'Column\n  Knob "Swing"\ndefine Knob "label" @value low=0 max=100 unit=""\n  Column\n    Pip\n    Slider @value min={low} max={max}\ndefine Pip\n  Box w=4 h=4\n');
    h.answer('synth', 'Column\n  Knob "Cutoff"\n');
    h.unknown('Knob', 'synth');
    h.unknown('Knob', 'dj');
    final words = h.words;
    expect(words.map((e) => e.key), ['Knob']);
    final defs = words.single.value;
    expect(defs.map((d) => d.file), ['dj', 'seq']);
    expect(defs.first.definition.doc, 'A rotary dial.');
    expect(defs.first.uses, {'core': {'Column', 'Ring', 'Text'}, 'universal': {'color'}});
    expect(defs.last.uses, {'core': {'Column', 'Slider'}, 'defined': {'Pip'}});
    expect(Harvest.disagreements(defs), [
      'named by some answers only: color (1), low (1), min (1), unit (1)',
      'maybe one parameter under two names: low / min (both default 0)',
    ]);
    // A definition one answer wrote resolves the word another used with none.
    expect([for (final w in h.wouldResolve) '${w.word}: ${w.definedIn} / ${w.unknownIn}'], ['Knob: [dj, seq] / [synth]']);
    final md = h.markdown();
    expect(md, contains('### Knob (2 answers)'));
    expect(md, contains('```\n// A rotary dial.\ndefine Knob "label" @value min=0 max=12 color=#FF22D3EE\n  Column gap=4\n'));
    expect(md, contains('| Knob | dj, seq | synth |'));
    expect(((h.toJson()['definedInMoreThanOne'] as List).single as Map)['answers'], 2);
  });

  test('the count: a primitive stands in, a word a definition never reads is not resolved, the unknown types apart (Review 7, D32)', () {
    const answer = '''
### Plan
state at=""
App
  Main
    Column pad=24
      FloorPlan2 "Level 2" rooms=["a"] onPick={at=result}
      GoKey "Go" shortcut="space" onTap={at="go"}
      Waveform2 seed=3

// A plan that placed items are dragged about on: no line draws one.
primitive FloorPlan2 "name" rooms=[] onPick
define GoKey "label" shortcut="" onTap
  Button "{label}" onTap={onTap}
''';
    final corpus = CorpusWords(components: {for (final c in ds.list) c.type});
    final defined = readPageDefinitions(answer, others: aliases.definitions).words;
    final reads = {
      for (final defs in defined.values)
        for (final d in defs) d.label: definitionReads(d),
    };
    expect(reads['GoKey']!.warnings, ['page:12: GoKey names shortcut and never reads it: a use\'s shortcut= does nothing.']);
    for (final s in screensOf(answer, 'plan')) {
      final r = api.Catalog.run(
          catalog,
          () => parseNotation(s.text,
              catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 1280).open(vocabulary: aliases), definitions: answer));
      expect(r.issues, isEmpty);
      expect([for (final u in r.vocabulary) if (u.kind == 'primitive' || u.kind == 'definition' || u.kind == 'type') '${u.kind} ${u.word}'],
          ['primitive FloorPlan2', 'definition GoKey', 'type Waveform2']);
      corpus.screen('plan', s.text, r, reads: reads);
    }
    String how(String kind, String? on, String word) => corpus.words['$kind ${on ?? ''} $word']!.resolved;
    expect(how('type', null, 'FloorPlan2'), 'primitive');
    expect(how('parameter', 'FloorPlan2', 'rooms'), 'primitive');
    expect(how('type', null, 'GoKey'), 'definition');
    expect(how('text', 'GoKey', 'text1'), 'definition');
    expect(how('parameter', 'GoKey', 'shortcut'), 'unread');
    expect(how('event', 'GoKey', 'onTap'), 'definition');
    expect(how('type', null, 'Waveform2'), 'unknown');
    expect(how('parameter', 'Waveform2', 'seed'), 'unknown');
    final count = countOf(corpus, primitives: 1);
    expect(count, containsPair('primitivesDeclared', 1));
    expect(count, containsPair('primitiveUses', 1));
    // FloorPlan2, its string, rooms and onPick.
    expect(count['standIn'], 4);
    expect(count['unread'], 1);
    expect((count['unknownTypes'], count['unknownOther']), (1, 1));
    expect(count['resolved'], count['words']! - 4 - 1 - 2);
    expect(countLine(count), endsWith('stand-in 4 (1 primitives declared, 1 uses), never read 1, unknown 2 (1 types, 1 other words: parameters, texts, flags, events, variants, verbs, functions)'));
  });

  test('a corpus file is its screens, each under a ### line; a file without one is one screen', () {
    final screens = screensOf('### What\'s on\nPage\n  Section\n\n### Cook mode\nstate n=1\nApp\n  Main\n### Cook mode\nPage\n', 'file');
    expect([for (final s in screens) (s.name, s.id, s.from)], [("What's on", 'whats-on', 2), ('Cook mode', 'cook-mode', 6), ('Cook mode', 'cook-mode-2', 10)]);
    expect(screens[1].text, 'state n=1\nApp\n  Main');
    final one = screensOf('Column\n  Text "x"\n', 'card');
    expect([for (final s in one) (s.name, s.id)], [('card', 'card')]);
  });

  test('state and overlays before the first ### line are every screen\'s, not a screen; a page there is still one', () {
    final screens = screensOf('state recipes=[]\nstate q="" saved\nstate total=sum(recipes,r=>r.n)\nDialog#about "About"\n  Text "x"\n\n### Recipes\nColumn\n  Text "a"\n### Saved\nColumn\n  Text "b"\n', 'file');
    // `from` stays the file's line of each screen's own first line.
    expect([for (final s in screens) (s.id, s.from + 3)], [('recipes', 8), ('saved', 11)]);
    expect(screens[0].text, 'project recipes=[]\nproject q="" saved\nstate total=sum(recipes,r=>r.n)\nColumn\n  Text "a"\nDialog#about "About"\n  Text "x"');
    final page = screensOf('Column\n  Text "home"\n### Other\nColumn\n', 'file');
    expect([for (final s in page) s.id], ['file', 'other']);
  });

  test('the first corpus is there with the tool\'s output, which says how each word resolved', () {
    const corpus = 'tool/vocabulary/corpus/2026-11-16-sonnet';
    expect(Directory('$corpus/answers').listSync().where((f) => f.path.endsWith('.txt')), hasLength(20));
    expect(Directory('$corpus/briefs').listSync().where((f) => f.path.endsWith('.txt')), hasLength(20));
    final out = jsonDecode(File('$corpus/vocabulary.json').readAsStringSync()) as Map;
    expect(out['files'], 20);
    expect(out['screens'], 105);
    final lines = out['lines'] as Map;
    expect(lines['core'] + lines['component'] + lines['alias'] + lines['unknown'], lines['nodes']);
    // A word is listed once for each way it resolved.
    final types = {for (final w in out['types'] as List) '${(w as Map)['word']} ${w['resolved']}': w};
    expect(types.keys, containsAll(['Column core', 'Shortcut alias', 'Table unknown', 'RangeSlider alias', 'RangeSlider unknown']));
    expect(types['Shortcut alias']!['to'], 'key');
    final md = File('$corpus/VOCABULARY.md').readAsStringSync();
    for (final heading in ['## Words we do not have', '## Names that may be one word', '## Aliases used', '## Parameters we do not have', '## Action verbs we do not have', '## Grammar issues']) {
      expect(md, contains(heading));
    }
  });
}
