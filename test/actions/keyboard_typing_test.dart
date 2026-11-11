// A screen's key shortcuts don't take keys that type into a focused text
// field.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart';

void main() {
  testWidgets('a letter shortcut waits while a text field has focus; Escape still runs', (tester) async {
    final s = await show(
      tester,
      {
        'col': {
          'type': 'column',
          'children': ['field'],
          'layout': {'width': 300, 'height': 200},
          'actions': [
            reaction('keyDown', [
              {'type': 'setVariable', 'variable': 'hits', 'op': 'add', 'value': '1'},
            ], extra: {'key': 'c'}),
            reaction('keyDown', [
              {'type': 'setVariable', 'variable': 'escapes', 'op': 'add', 'value': '1'},
            ], extra: {'key': 'Escape'}),
          ],
        },
        'field': {'type': 'textField', 'layout': {'width': 300, 'height': 48}},
      },
      variables: [v('hits', 0, VariableType.integer), v('escapes', 0, VariableType.integer)],
    );
    await tester.pumpAndSettle();
    // No focus: the shortcut runs.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    expect(s['hits'], 1);
    // Typing into the field: the letter is the field's.
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    expect(s['hits'], 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(s['escapes'], 1);
  });
}
