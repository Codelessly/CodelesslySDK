// The shapes writers gave Cards' named words (the vocabulary loop's Reviews 5
// and 6, D25 and D30): each line below is as an answer of
// tool/vocabulary/corpus-define wrote it (d03 was written with the glossary
// of names; d01 and d02 defined their own words), and each now expands with
// no word left unknown, to a document that validates. What each became is
// what the line says it is.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/vocabulary.dart' show loadDefinitionTexts, loadVocabulary;

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

  NotationResult read(String text) => api.Catalog.run(
      catalog, () => parseNotation(text, catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 1280).open(vocabulary: vocabulary)));

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

  // What the lines below read from the page.
  const state = '''
state stage=1
state steps=[{"label":"Listed","note":"On the market","date":"Mar 2"},{"label":"Offer","note":"Accepted","date":"Mar 20"}]
state events=[{"title":"Planted","date":"Apr 1","note":"Three leaves"},{"title":"Repotted","time":"May 4"}]
state step=0
state progress=0.4
state signature=""
state sel=""
state placing=false
state pins=[{"id":"P1","label":"Crack"},{"id":"P2","label":"Leak"}]
state filter="All"
state photo=""
state attach={"name":"plan.pdf","size":"2 MB","progress":0.5}
''';

  // Each line, the words it is read with (what records it), and what is not
  // to be left unknown.
  final lines = <String, List<String>>{
    'each s in steps\n    TimelineItem "{s.label}" "{s.note}" date={s.date} done={index<stage} current={index==stage}': ['definition TimelineItem'],
    'Timeline items={events}': ['definition Timeline#events'],
    'Timeline events={events} current={stage} onSelect={stage=result}': ['definition Timeline#events', 'alias events>items', 'alias current>selected', 'alias onSelect>onPick'],
    'Stepper steps=["About you","Income","Deductions"] current={step} onSelect={step=result}': ['definition Stepper#steps', 'alias onSelect>onPick'],
    'Stepper @step min=0 max=10 onChange={toast "{result}"}': [],
    'Countdown "Exam ends in" seconds=600 warnBelow=300 onWarn={toast "5 min"} onDone={toast "Time"}': ['definition Countdown#timer', 'alias warnBelow>warnAt', 'alias onDone>onEnd'],
    'ChatBubble "Where is my bag?" mine time="10:02"': ['definition ChatBubble'],
    'Banner "You owe \$1.75 in overdue fines." icon="warning"': [],
    'Banner "Your trial ends in 3 days." icon="hourglass_bottom" actionLabel="Cancel trial" onAction={toast "Cancelled"} onDismiss={toast "Hidden"}': ['alias actionLabel>action'],
    'Banner.warning "Possible interaction with potassium." onDismiss={toast "ok"}': [],
    'Text "11:35" strike=true color=#FF9CA3AF': [],
    'Text "{filter}" strike={stage > 0}': [],
    'FileUploader "Drop photos here or browse" accept="image/*" multiple onPick={toast "pick"}': [],
    'FileUploader accept=["pdf","jpg","png"] multiple': [],
    // An ImageUpload keeps no value (its photos are images=, a pick is onPick): the answer's bind=photo,
    // written @photo, is a mark that binds nothing, and is said.
    'ImageUpload accept="image/*" onPick={photo="meter.jpg"}': ['alias accept>hint'],
    'Donut values=[38,24,16] labels=["Heating","Water heater","Fridge"]': [],
    // status is its tone; a status no tone has, with no string, is what it says.
    'StatusBadge status="Open"': [r'alias status>$text'],
    'StatusBadge "{filter}"': [],
    'Barcode "29034 00718 4421" w=260 h=90': [],
    'Rating 4.5 readonly': ['alias readonly>readOnly'],
    'Rating score=3 max=10': [],
    'StarRating @step max=5': ['alias StarRating>Rating'],
    'AttachmentTile "{attach.name}" "{attach.size}" progress={attach.progress} onRemove={attach={}}': ['definition AttachmentTile'],
    'FlightProgress value={progress} from="SFO" to="NRT"': ['definition FlightProgress'],
    'ChipTabs @filter items=["All","On time","Delayed"]': ['alias items>tabs'],
    'ChoiceChips @filter items=["T-14","T-17"]': ['alias items>options'],
    'SegmentedControl @filter items=["All","call","email"]': ['alias items>options'],
    'StepIndicator steps=["Cart","Pay"] current=1': [],
    'CodeBlock "print(1)" language="python" copy': ['alias copy>copyable'],
    'StatCard "Outstanding" value="\$1,200" caption="3 unpaid invoices"': ['alias caption>note'],
    'Breadcrumb crumbs=["Home","Docs"] onPick={toast "{result}"}': ['alias crumbs>items', 'alias onPick>onNavigate'],
    'MapView center=[51.5,-0.12] zoom=14 markers={pins} onPick={sel=result}': ['definition MapView', 'alias markers>pins', 'alias onPick>onSelect'],
    // Its two variables named (start=@ end=@ in the signature), and neither: then its own.
    'DateRangePicker "Stay" start=@sel end=@photo': ['definition DateRangePicker'],
    'DateRangePicker "Stay"': ['definition DateRangePicker'],
    'Map places={pins} h=300': ['alias Map>MapView', 'definition MapView', 'alias places>pins'],
    'RouteMap points={pins} progress={progress} onPin={toast "{result}"}': ['definition RouteMap', 'alias points>stops', 'alias onPin>onPick'],
    'FloorPlan "Level 1" pins={pins} selected={sel} placing={placing} onPick={sel=result} onPlace={placing=false}': ['definition FloorPlan'],
    'SignaturePad "Sign here" @signature h=140': ['definition SignaturePad'],
    'CameraView "Point at the meter" source="rear" h=240 onCapture={toast "Captured"}': ['definition CameraView'],
    'PhotoPicker "Meter photo" @photo onPick={photo="meter.jpg"}': ['definition PhotoPicker'],
    'Waveform peaks=[0.2,0.8,0.5,0.9] progress={progress} onSeek={toast "{result}"}': ['definition Waveform', 'alias peaks>values', 'alias progress>position'],
    // The names the standalone runs converged on (review 7, D34).
    'StatusBadge "LIVE" status="success"': ['alias status>tone'],
    'StatusDot "Live" color="success"': ['alias color>status'],
    'StatCard "Users" value="3" description="up 4%"': ['alias description>note'],
    'StatCard "Users" value="3" detail="up 4%"': ['alias detail>note'],
    'TimelineItem "Launch" note="On time"': ['definition TimelineItem', 'alias note>detail'],
    'TimelineItem "Launch" description="On time"': ['definition TimelineItem', 'alias description>detail'],
    'InputField "Email" hint="you@example.com" @sel': ['alias hint>placeholder'],
    'ReorderableList "Order" items={pins}': ['alias items>value'],
    'ReorderableList "Order" items=@pins': ['alias items>value'],
    'Legend "Free" color=#FFE9F7EF': ['definition Legend#entry'],
    'Counter "Guests" @step min=1 max=8': [],
    'NumberInput "Exposure" @progress': [],
    'ConnectionStatus "Server" status="connected"': [],
    'SectionHeader "Files" count="3" action="View all" onAction={toast "all"}': [],
    'ListRow "Milk" removable onRemove={toast "removed"}': [],
    'ListRow "Milk" onDelete={toast "removed"}': ['alias onDelete>onRemove'],
    'SearchBar "Find" @sel clearable': [],
    'Banner "Syncing" "3 left" live': [],
    'ChoiceChips @filter options=["18:00","18:30"] disabled={placing}': [],
  };

  for (final e in lines.entries) {
    test(e.key.split('\n').last, () {
      final r = read('${state}Column\n  ${e.key}\n');
      expect(r.issues.map((i) => i.message), isEmpty);
      final records = [
        for (final u in r.vocabulary)
          if (u.kind == 'definition' && u.node != null) 'definition ${u.to}' else if (u.kind == 'alias') 'alias ${u.word}>${u.to}',
      ];
      expect(records, containsAll(e.value));
      // Nothing left unknown: no stand-in, no word dropped.
      expect([for (final u in r.vocabulary) if (!const {'definition', 'alias', 'universal'}.contains(u.kind)) '${u.kind} ${u.on ?? ''}.${u.word}'], isEmpty);
      expect(invalid(r.document), isEmpty);
    });
  }

  String openPrompt({bool glossary = true, bool signatures = true}) => api.Catalog.run(
      catalog,
      () => notationPrompt(
          catalog: catalog,
          options: NotationOptions.fromDesignSystem(ds, width: 1280).define(loadDefinitionTexts('design_systems/cards')),
          designSystem: ds,
          open: true,
          glossary: glossary,
          signatures: signatures));

  test('the open prompt with Cards names its words on one line with --glossary=names; --no-glossary leaves it out (D29)', () {
    final names = api.Catalog.run(catalog, () => notationGlossary(ds, vocabulary, prompt: openPrompt(glossary: false)));
    expect(names, containsAll(['Stepper', 'Timeline', 'Countdown', 'Rating', 'MapView', 'SignaturePad', 'Banner', 'FileUploader']));
    // Taught by the prompt, so not named again.
    expect(names, isNot(anyOf(contains('Button'), contains('Card'), contains('Badge'), contains('StickyNote'))));
    final page = openPrompt(signatures: false);
    expect(page, contains('${notationGlossaryLead()}\n${names.join(' ')}\n\n'));
    expect(page.length - openPrompt(glossary: false).length, lessThan(4000));
  });

  test('by default it gives each of Cards\' words as a line uses it: the shapes the standalone runs could not see (D33)', () {
    final page = openPrompt();
    final at = page.indexOf(notationSignaturesLead(ds.name));
    expect(at, greaterThan(0));
    final lines = page.substring(at + notationSignaturesLead(ds.name).length).trim().split('\n');
    final names = api.Catalog.run(catalog, () => notationGlossary(ds, vocabulary, prompt: openPrompt(glossary: false)));
    // One line for each word, and one more for each further meaning.
    expect(lines.length, greaterThanOrEqualTo(names.length));
    expect({for (final l in lines) l.trim().split(RegExp(r'[ .]')).first}, names.toSet());
    String line(String start) => lines.firstWhere((l) => l.trim().startsWith('$start '), orElse: () => '').trim();
    // Words the runs renamed for want of their shape.
    expect(line('MapView'), startsWith('MapView @picked center=[] zoom=12 pins=[] h=320 onSelect ... : '));
    expect(line('FloorPlan'), startsWith('FloorPlan "name" @picked rooms=[] pins=[] selected placing=false h=360 onPick onPlace ... : '));
    expect(line('Counter'), startsWith('Counter "label" "detail" @value min='));
    expect(line('StatusBadge'), startsWith('StatusBadge "label" tone='));
    expect(lines.where((l) => RegExp(r'^Timeline[ .]').hasMatch(l.trim())), hasLength(3));
    // Every line ends with what the word is, in a few words.
    for (final l in lines.where((l) => l.contains(' : '))) {
      expect(l.split(' : ').last.split(' ').length, lessThanOrEqualTo(7), reason: l);
    }
    // Twenty or so thousand characters: the switch keeps the names.
    expect(page.length - openPrompt(glossary: false).length, lessThan(28000));
  });

  test('what those names become: a tone, an x in a ListRow\'s slot, a SectionHeader\'s action, a whole ChoiceChips off', () {
    // taken is a state worked out: a list, read in parentheses.
    final r = read('''
state taken=filter(["18:00","18:30"],t=>t=="18:30")
${state}Column
  StatusBadge#badge "LIVE" status="success"
  ListRow#row "Milk" onDelete={toast "removed"}
  SectionHeader#head "Files" action="View all" onAction={toast "all"}
  ChoiceChips#chips @filter options=["18:00","18:30"] disabled={placing}
  ChoiceChips#some @filter options=["18:00","18:30"] disabled=["18:30"]
  ChoiceChips#worked @filter options=["18:00","18:30"] disabled={taken}
  ChoiceChips#late @filter options=["18:00","18:30"] disabled={length(taken)>1}
''');
    expect(r.issues, isEmpty);
    Map<String, Object?> node(String id) => ((r.document['nodes']! as Map)[id] as Map).cast<String, Object?>();
    expect(node('badge')['props'], {'label': 'LIVE', 'tone': 'success'});
    final x = ((node(((node('row')['slots'] as Map)['trailing']) as String)['children'] as List).single) as String;
    expect(jsonEncode(node(x)['actions']), contains('removed'));
    final action = ((node(((node('head')['slots'] as Map)['actions']) as String)['children'] as List).single) as String;
    expect(node(action)['props'], containsPair('label', 'View all'));
    expect(jsonEncode(node(action)['actions']), contains('"message":"all"'));
    expect(node('chips')['bind'], {'disabled': r'${= placing}'});
    expect(node('some')['props'], containsPair('disabled', ['18:30']));
    expect((node('worked')['bind']! as Map).keys, ['props.disabled']);
    expect((node('late')['bind']! as Map).keys, ['disabled']);
    expect(invalid(r.document), isEmpty);
  });

  test('a selectable list of TableRows: the row\'s own tap chooses it', () {
    final r = read('state picked=[]\n${state}Column selectable selected=@picked\n  each p in pins\n    TableRow#trow cells={[p.id,p.label]}\n');
    expect(r.issues, isEmpty);
    final row = (r.document['nodes']! as Map)['trow'] as Map;
    final pressed = (row['actions'] as List).single as Map;
    expect(pressed['trigger'], {'type': 'event', 'event': 'onPressed'});
    expect(((pressed['actions'] as List).first as Map)['variable'], 'picked');
    expect(invalid(r.document), isEmpty);
  });

  test('Rating sizes its stars inside its root: no warning wherever it is used', () {
    final r = read('${state}Column\n  Rating "Taste" @progress max=10\n');
    expect(r.issues, isEmpty);
    final warnings = api.Catalog.run(
        catalog,
        () => validateDocument(r.document,
            options: ValidateOptions(
              theme: api.ThemeTokens.fromJson(ds.manifest.theme.toJson()),
              components: ds.components,
              formulas: (f) => (error: FormulaEvaluator.errorOf(f), paths: FormulaEvaluator.referencedPaths(f)),
            )));
    expect([for (final d in warnings) if (d.severity != Severity.info) '${d.code.name} ${d.path}'], isEmpty);
  });

  test('the steps Stepper and the number control are one word with two meanings', () {
    final r = read('${state}Column\n  Stepper#qty "Guests" @step min=1 max=8\n  Stepper steps=["A","B","C"] @step\n');
    expect(r.issues, isEmpty);
    final nodes = r.document['nodes']! as Map;
    expect((nodes['qty'] as Map)['type'], 'Stepper');
    expect([for (final u in r.vocabulary) if (u.kind == 'definition' && u.node != null) u.to], ['Stepper#steps']);
    expect(jsonEncode(r.document), contains(r'[\"A\",\"B\",\"C\"]'));
  });
}
