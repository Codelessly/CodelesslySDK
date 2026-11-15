// Switchboard's reply composer: its changed reactions keep the draft from
// `${field.value}` and open the mention popup from `${field.word}`, the word
// ending at the cursor; picking a mention replaces that word.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fields.dart';
import '../support/screen.dart';

void main() {
  testWidgets('changed reactions read the text and the word at the cursor in field', (tester) async {
    final s = await show(
      tester,
      {
        'col': {
          'type': 'column',
          'children': ['composer', 'pick'],
          'layout': {'width': 400, 'height': 300},
        },
        'composer': {
          'type': 'textField',
          'layout': {
            'width': {'fill': 400},
          },
          'props': {'maxLines': 6, 'minLines': 2, 'keyboardType': 'multiline'},
          'actions': [
            reaction('changed', [
              {'type': 'setVariable', 'variable': 'draft', 'value': r'${field.value}'},
              {'type': 'setVariable', 'variable': 'acWord', 'value': r'${= field.word}'},
              {'type': 'setVariable', 'variable': 'cursor', 'value': r'${field.cursor}'},
            ]),
          ],
        },
        'pick': {
          'type': 'row',
          'layout': {'width': 40, 'height': 40},
          'actions': [
            reaction('click', [
              {'type': 'editText', 'node': 'composer', 'operation': 'replaceWord', 'text': r"${= '@' + 'priya' + ' '}"},
            ]),
          ],
        },
      },
      variables: [v('draft', ''), v('acWord', ''), v('cursor', 0, VariableType.integer)],
    );
    await typeInto(tester, 'Thanks, now @pri');
    await tester.pumpAndSettle();
    expect(s['draft'], 'Thanks, now @pri');
    expect(s['acWord'], '@pri');
    expect(s['cursor'], 16);

    await tester.tapAt(s.center('pick'));
    await tester.pumpAndSettle();
    expect(textField(tester).editor.text, 'Thanks, now @priya ');
    expect(s['draft'], 'Thanks, now @priya ', reason: 'an edit like typing runs the changed reactions');
    expect(s['acWord'], '');
  });
}
