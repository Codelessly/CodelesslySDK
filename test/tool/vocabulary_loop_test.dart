// The vocabulary loop (codelessly_api docs/design/19-open-vocabulary.md): a
// page written with words the notation does not have renders, with Cards,
// and the corpus tool's pieces read what they are given.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/vocabulary.dart' show loadVocabulary, screensOf;
import '../../tool/notation/vocabulary_harvest.dart' show Harvest;

// A page as a model writes it from the open prompt: unknown types (with
// lines under them, with nothing under them, over the page), parameters,
// flags, events, verbs and a variant we do not have, names we have under
// another name, and a Cards component called its own way.
const _page = '''
state q=""
state n=2 persist
state stars=4
Shortcut "ctrl+k" onPress={open palette}
App
  Sidebar
    Brand "Proscenium" icon="theater_comedy"
    NavItem "Seats" icon="event_seat" selected={true}
  Main
    Nav
      Heading "Choose your seats"
      Row gap=8
        Input#find "Find a row" bind=q clearable
        Button.danger "Clear" disabled={n==0} onTap={n=0; haptic}
    Column pad=24 gap=16
      SeatMap#plan "Stalls" rows={seats} chosen={picked} selectable max=8 h=120 fill=#FF111827 radius=12 onChange={n=length(result)}
        Legend "Premium" color=#FFD4A64A
        Text#under "Use the arrow keys to move between rows."
      Waveform seed=7 color=#66FFFFFF
      Row gap=12 middle
        Text#count "{n} seats"
        Rating value=4.6 readonly
        Tabs bind=view items=["Plan","List"]
      ListTile "Row A" subtitle="Two seats left" onTap={vibrate find}
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
    expect(aliases.types.keys, containsAll(['Shortcut', 'RangeSlider', 'ConfirmDialog']));
    expect(aliases.parameters['*'], {'disabled': '!enabled', 'readonly': 'readOnly'});
    expect(loadVocabulary(dir: 'design_systems/cards', builtIn: false).types, isEmpty);
  });

  test('an open page with Cards: nothing is an issue, the document validates, and every word is recorded', () {
    final r = expand(_page);
    expect(r.issues.map((i) => '$i'), isEmpty);
    final invalid = api.Catalog.run(
        catalog,
        () => validateDocument(r.document,
            options: ValidateOptions(theme: api.ThemeTokens.fromJson(ds.manifest.theme.toJson()), components: ds.components))).where((d) => d.severity == Severity.error);
    expect(invalid.map((d) => '${d.code.name} ${d.path}: ${d.message}'), isEmpty);
    List<String> of(String kind) => [for (final u in r.vocabulary) if (u.kind == kind) '${u.on == null ? '' : '${u.on}.'}${u.word}'];
    expect(of('type'), ['SeatMap', 'Waveform', 'QuickSwitcher']);
    // Words Cards defines in the notation (its vocabulary/*.txt) are words we
    // have; what a use gives that its definition does not take is recorded.
    expect(of('definition'), ['Legend', 'CommandItem']);
    expect(of('parameter'), ['Legend.string1']);
    // A universal word (codelessly_api docs/design/21) on a defined word goes on its root;
    // clearable is an Input's own now.
    expect(of('universal'), contains('Legend.color'));
    expect(of('flag'), isEmpty);
    expect(of('verb'), ['Button.haptic', 'ListTile.vibrate']);
    expect(of('variant'), ['Button.Button.danger']);
    // Cards' Rating needs a label, which the line did not give.
    expect(of('missing'), ['Rating.label']);
    expect(of('alias').toSet(), {'state.persist', 'Shortcut', 'Button.disabled', 'Rating.readonly', 'Tabs.items', 'ListTile.subtitle'});
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
    h.answer('dj', '### Deck\nApp\n  Knob "Gain"\n\n// A rotary dial.\ndefine Knob "label" bind=value min=0 max=12 color=#FF22D3EE\n  Column gap=4\n    Ring {value/max} w=56 color={color}\n    Text "{label}"\n');
    h.answer('seq', 'Column\n  Knob "Swing"\ndefine Knob "label" bind=value low=0 max=100 unit=""\n  Column\n    Pip\n    Slider bind=value min={low} max={max}\ndefine Pip\n  Box w=4 h=4\n');
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
    expect(md, contains('```\n// A rotary dial.\ndefine Knob "label" bind=value min=0 max=12 color=#FF22D3EE\n  Column gap=4\n'));
    expect(md, contains('| Knob | dj, seq | synth |'));
    expect(((h.toJson()['definedInMoreThanOne'] as List).single as Map)['answers'], 2);
  });

  test('a corpus file is its screens, each under a ### line; a file without one is one screen', () {
    final screens = screensOf('### What\'s on\nPage\n  Section\n\n### Cook mode\nstate n=1\nApp\n  Main\n### Cook mode\nPage\n', 'file');
    expect([for (final s in screens) (s.name, s.id, s.from)], [("What's on", 'whats-on', 2), ('Cook mode', 'cook-mode', 6), ('Cook mode', 'cook-mode-2', 10)]);
    expect(screens[1].text, 'state n=1\nApp\n  Main');
    final one = screensOf('Column\n  Text "x"\n', 'card');
    expect([for (final s in one) (s.name, s.id)], [('card', 'card')]);
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
