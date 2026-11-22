// Lines of an app that are read as written (codelessly_api
// notation_writers_lines_test.dart), drawn: a gradient from a list of the
// state, a motion on one side of a condition, a table of records written on
// its line, a list reordered through the record it is a field of, and a
// range slider bound to two fields of an each's item. Each shows what it
// should, with nothing shown wrong.
import 'package:codelessly_api/codelessly_api.dart' show parseNotation, standardCatalog;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<UiSession> _show(WidgetTester tester, String notation) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Localizations(
    locale: const Locale('en'),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 600, height: 600, child: CodelesslyView(session: session))),
    ),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  await tester.pumpAndSettle();
  expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
  expect(result.errors, isEmpty, reason: '${result.errors}');
  expect([for (final d in session.shownDiagnostics()) if (d.error) '${d.code}: ${d.message}'], isEmpty);
  return session;
}

String _texts(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return out.toString();
}

Object? _eval(String expression, Map<String, Object?> vars) => FormulaEvaluator.evaluate(expression, (path) => vars[path]);

void main() {
  test('the fill a gradient of a list of the state is bound to: a stop a color, spread from the first to the last', () {
    final r = parseNotation('state cs=["#FF112233","#FF445566","#FF778899"]\nColumn\n  Box#b h=96 gradient={cs}\n', catalog: standardCatalog);
    expect(r.issues, isEmpty);
    final bound = (((r.document['nodes'] as Map)['b'] as Map)['bind'] as Map)['decoration.fills'] as String;
    final formula = bound.substring(4, bound.length - 1).trim();
    final fills = _eval(formula, {'cs': ['#FF112233', '#FF445566', '#FF778899']}) as List;
    final stops = ((fills.single as Map)['stops'] as List).cast<Map>();
    expect([for (final s in stops) s['color']], ['#FF112233', '#FF445566', '#FF778899']);
    expect([for (final s in stops) (s['position'] as num).toDouble()], [0.0, 0.5, 1.0]);
  });

  testWidgets('a gradient from a list of an item, from one of two lists and from a list written without braces is drawn with nothing shown wrong', (tester) async {
    final session = await _show(tester, '''
state ps=[{"id":1,"c1":"#FF112233","c2":"#FF445566","grad":["#FF112233","#FF445566"]}]
state view=0
Column gap=8 pad=16
  each p in ps
    Box h=40 gradient={p.grad}
    Box h=40 gradient=[p.c1,p.c2]
    Box h=40 gradient={view==0 ? [p.c1,p.c2] : [p.c2,p.c1]}
''');
    expect(session.shownDiagnostics().where((d) => d.code == 'value_not_computed'), isEmpty);
  });

  testWidgets('a motion on one side of a condition, a table of records on its line, and lists reordered through their record', (tester) async {
    final session = await _show(tester, '''
state reduced=true
state autos=[{"id":1,"name":"Morning","conds":[{"id":1,"t":"Sunrise"},{"id":2,"t":"Weekday"}],"heat":18,"cool":24}]
state at=1
Column gap=8 pad=16
  Text "Heading" animate={reduced ? "" : "slide-up"} duration={reduced ? 0 : 500}
  DataTable rows=[{"name":"mode","type":"char | word"},{"name":"timeout","type":"number"}] columns=[{"key":"name","label":"Option"},{"key":"type","label":"Type"}] h=160
  each a in autos
    Column gap=4
      each c in a.conds reorder
        Row gap=8
          Handle
          Text "{c.t}"
    Slider @a.heat @a.cool min=16 max=30
  Column gap=4
    each t in find(autos,x=>x.id==at).conds reorder
      Row gap=8
        Handle
        Text "again {t.t}"
''');
    final texts = _texts(tester);
    for (final shown in ['Heading', 'mode', 'timeout', 'Sunrise', 'again Weekday']) {
      expect(texts, contains(shown));
    }
    expect(session.notationIssues, isEmpty);
  });
}
