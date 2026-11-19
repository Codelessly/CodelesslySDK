// A card can be designed and still show a broken value (a sum over a field
// the data does not have). The session reports it from what is on screen,
// so a host can ask for another try before showing the card.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _codes(WidgetTester tester, String notation) async {
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 400, child: CodelesslyView(session: session))),
  ));
  final result = await session.applyNotation(Stream.value(notation));
  await tester.pumpAndSettle();
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return [for (final d in session.shownDiagnostics()) d.code];
}

void main() {
  testWidgets('a value that came out as nothing is reported from the screen', (tester) async {
    final codes = await _codes(tester, '''
state items=[{"name":"Tea","price":"four"},{"name":"Cake"}]
state x={"a":1}
Card gap=8
  Text.heading "Your order"
  Text "Total: {items[0].price*2}"
  Text "{items[1].note!="" ? items[1].note : ""}"
''');
    expect(codes, contains('value_not_computed'));
  });

  testWidgets('a card whose values are right reports nothing of the kind', (tester) async {
    final codes = await _codes(tester, '''
state items=[{"name":"Tea","price":4},{"name":"Cake","price":3}]
Card gap=8
  Text.heading "Null Island tea room"
  Text "Total: {sum(items,i=>i.price*2)}"
''');
    expect(codes, isNot(contains('value_not_computed')));
  });

  testWidgets('a word of the data a text reads (a reference that says "or null") is not a value that failed', (tester) async {
    // The data is set at load, as a site's data is given with the page: the
    // page's document does not have the words.
    final codes = await _codes(tester, '''
state ret=""
on load={ret="Updated text, or nu" + "ll if nothing matched."}
Card gap=8
  Text "Returns · {ret}"
''');
    expect(codes, isNot(contains('value_not_computed')));
  });
}
