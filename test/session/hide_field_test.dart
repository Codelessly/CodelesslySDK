// A form hidden by a condition after it was shown (test 4: six builds hit
// "X and NodeBox are not in the same render tree" in the render tool).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hiding a form with a text field, a dropdown and a button after it was shown raises nothing, and showing it again works', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 600, child: CodelesslyView(session: session))),
    ));
    final r = session.apply({
      'ops': [
        {'op': 'roots', 'roots': ['s']},
        {'op': 'vars', 'scope': 's', 'set': {'sent': {'type': 'boolean', 'value': false}}},
        {'op': 'set', 'id': 's', 'node': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 600}}},
        {'op': 'set', 'id': 'col', 'node': {'type': 'column', 'children': ['form', 'done'], 'layout': {'width': {'fill': 390}, 'height': {'hug': 0}}}},
        {'op': 'set', 'id': 'form', 'node': {'type': 'column', 'children': ['name', 'pick', 'send'], 'form': <String, Object?>{}, 'bind': {'visible': r'${= !sent}'}, 'layout': {'width': {'fill': 390}, 'height': {'hug': 0}}}},
        {'op': 'set', 'id': 'name', 'node': {'type': 'textField', 'props': {'decoration': {'labelText': 'Name'}}, 'layout': {'width': {'fill': 390}, 'height': {'hug': 0}}}},
        {'op': 'set', 'id': 'pick', 'node': {'type': 'dropdown', 'props': {'items': ['a', 'b']}, 'layout': {'width': 200, 'height': {'hug': 0}}}},
        {'op': 'set', 'id': 'send', 'node': {'type': 'filledButton', 'props': {'label': 'Send'}, 'actions': [{'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'sent', 'value': r'${= true}'}]}]}},
        {'op': 'set', 'id': 'done', 'node': {'type': 'text', 'bind': {'visible': r'${sent}'}, 'props': {'text': 'Thanks', 'style': {'fontSize': 16, 'color': '#FF111827'}}, 'layout': {'width': {'fill': 390}, 'height': {'hug': 0}}}},
      ],
    });
    expect(r.errors, isEmpty, reason: '${r.errors}');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CodelesslyView), 'x').catchError((_) {});
    session.apply({'ops': [{'op': 'vars', 'scope': 's', 'set': {'sent': true}}]});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    session.apply({'ops': [{'op': 'vars', 'scope': 's', 'set': {'sent': false}}]});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
