// A chain of worked-out states where each reads the one before twice (a
// power by squaring: a mortgage's monthly payment), as codelessly_api reads
// it (notation_formula_chain_test.dart: the states read again are kept by
// name, variables with a formula): the page shows the value the chain
// works out.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _page = '''
state price=300000
state dep=10
state rate=4.5
state years=25
state lnf=0.003742986
state loan={price*(1-dep/100)}
state mr={rate/1200}
state mn={years*12}
state ex={mn*lnf}
state q0={1+ex/1024}
state q1={q0*q0}
state q2={q1*q1}
state q3={q2*q2}
state q4={q3*q3}
state q5={q4*q4}
state q6={q5*q5}
state q7={q6*q6}
state q8={q7*q7}
state q9={q8*q8}
state q10={q9*q9}
state monthly={loan*mr*q10/(q10-1)}
state interest={monthly*mn-loan}
Column
  Text "m={round(monthly,2)}"
  Text "i={round(interest,0)}"
''';

void main() {
  testWidgets('the monthly payment of a known loan, worked out through ten squarings', (tester) async {
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
    final watch = Stopwatch()..start();
    final result = await session.applyNotation(Stream.value(_page));
    await tester.pumpAndSettle();
    expect(watch.elapsedMilliseconds, lessThan(3000));
    expect(session.notationIssues, isEmpty, reason: '${session.notationIssues}');
    expect(result.errors, isEmpty, reason: '${result.errors}');

    // The same sums in Dart.
    const loan = 300000 * (1 - 10 / 100), mr = 4.5 / 1200, mn = 25 * 12;
    var q = 1 + mn * 0.003742986 / 1024;
    for (var k = 0; k < 10; k++) {
      q = q * q;
    }
    final monthly = loan * mr * q / (q - 1);
    final texts = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) texts.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(CodelesslyView)));
    final shown = double.parse(texts.firstWhere((t) => t.startsWith('m=')).substring(2));
    expect(shown, closeTo(monthly, 0.01));
    expect(monthly, closeTo(1501, 2), reason: 'about £1,501 a month');
    final interest = double.parse(texts.firstWhere((t) => t.startsWith('i=')).substring(2));
    expect(interest, closeTo(monthly * mn - loan, 1));
  });
}
