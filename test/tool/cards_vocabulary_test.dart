// The words Cards defines in the notation itself (design_systems/cards/
// vocabulary/*.txt; codelessly_api docs/design/20-defined-words.md): every
// definition reads, expands with its defaults to a document that validates,
// and the corpus's own lines that use one expand with no issue of the
// definition's; a page of them renders.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/vocabulary.dart' show loadDefinitionTexts, loadVocabulary, screensOf;

void main() {
  late api.DesignSystem ds;
  late api.Catalog catalog;
  late NotationVocabulary vocabulary;

  setUpAll(() async {
    final problems = <String>[];
    ds = await api.DesignSystem.load((ref) async {
      final f = File('design_systems/cards/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    expect(problems, isEmpty);
    catalog = ds.catalogOver(api.standardCatalog);
    vocabulary = loadVocabulary(dir: 'design_systems/cards');
  });

  List<String> invalid(Map<String, Object?> doc) => [
        for (final d in api.Catalog.run(
            catalog,
            () => validateDocument(doc,
                options: ValidateOptions(
                  theme: api.ThemeTokens.fromJson(ds.manifest.theme.toJson()),
                  components: ds.components,
                  formulas: (f) => (error: FormulaEvaluator.errorOf(f), paths: FormulaEvaluator.referencedPaths(f)),
                ))))
          if (d.severity == Severity.error) '${d.code.name} ${d.path}: ${d.message}',
      ];

  test('every definition reads, and none uses a word the notation already has', () {
    final texts = loadDefinitionTexts('design_systems/cards');
    final read = readDefinitions(texts);
    expect(read.problems, isEmpty);
    final meanings = [for (final defs in read.words.values) ...defs];
    expect(meanings.length, greaterThanOrEqualTo(25));
    for (final e in read.words.entries) {
      final w = e.key;
      expect(catalog.widget('${w[0].toLowerCase()}${w.substring(1)}') == null && !notationTypes.containsKey(w), isTrue, reason: '$w is a word the notation has');
      // A component's word takes only named meanings beside the component
      // (codelessly_api docs/design/20 section 5: Stepper#steps).
      if (catalog.widget(w) != null) expect(e.value.every((d) => d.name != null), isTrue, reason: '$w is a Cards component: its meanings here are named');
    }
    // Each meaning of a word with several is named.
    for (final defs in read.words.values.where((d) => d.length > 1)) {
      expect(defs.every((d) => d.name != null), isTrue, reason: defs.first.word);
    }
  });

  test('each expands with its defaults, closed, with no issue, to a document that validates', () {
    final problems = api.Catalog.run(
        catalog, () => checkDefinitions(vocabulary, catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 1280), validate: invalid));
    expect(problems, isEmpty);
  });

  test('the corpus\'s lines that use them expand with no issue of a definition\'s', () {
    final said = <String>[];
    var uses = 0;
    for (final dir in Directory('tool/vocabulary/corpus').listSync().whereType<Directory>()) {
      final answers = Directory('${dir.path}/answers');
      if (!answers.existsSync()) continue;
      for (final f in answers.listSync().whereType<File>().where((f) => f.path.endsWith('.txt'))) {
        for (final s in screensOf(f.readAsStringSync(), 'screen')) {
          final r = api.Catalog.run(
              catalog,
              () => parseNotation(s.text,
                  catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 1280, screen: s.id).open(vocabulary: vocabulary)));
          uses += r.vocabulary.where((u) => u.kind == 'definition' && u.node != null).length;
          for (final i in r.issues) {
            // A use's own words a definition reads (an animate= written
            // with a condition) are the answer's: those are not counted.
            if (RegExp(r'^[A-Z][A-Za-z]*\.txt:\d+: ').hasMatch(i.message) && !i.message.contains('animate')) said.add('${f.uri.pathSegments.last}/${s.name}: $i');
          }
        }
      }
    }
    expect(uses, greaterThan(100));
    expect(said, isEmpty);
  });

  testWidgets('a page of them renders, with nothing said and no error', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
    const page = '''
state notes=[{"text":"Buy milk","color":"#FFFDE68A"},{"text":"Call Ada","color":"#FFFFE4E6"}]
state left=30
state range=[0, 100]
Column pad=24 gap=16
  Row gap=12
    each n in notes
      StickyNote "{n.text}" fill={n.color}
  FlipCard
    Front
      Text "Front"
    Back
      Text "Back"
  AvatarStack names=["Ada","Grace","Alan","Edsger","Barbara"] max=3
  Table columns=["Year","Length"] rows=[["1920","24.6"],["2024","20.8"]]
  Timeline.vertical
    TimelineItem "Planted" "3 leaves"
    TimelineItem "Repotted" time="2 weeks"
  Countdown value={left} total=60
  ColorPicker onPick={toast "{result}"}
  RangeSlider @range min=0 max=100 labels
  AttachmentTile "report.pdf" subtitle="2 MB" onDownload={toast "saved"}
  QuoteBlock "Ada" "See you at six"
  Kbd "Ctrl K"
''';
    final result = await session.applyNotation(Stream.value(page), options: NotationOptions.fromDesignSystem(ds, width: 1280, named: true).open(vocabulary: vocabulary));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    expect(tester.takeException(), isNull);
    expect(session.node('stickyNote1')?.type, 'column');
    expect(session.node('flipCard1')?.type, 'stack');
  });
}
