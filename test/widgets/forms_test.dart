// Forms as Flutter has them: a field's validator (TextFormField.validator),
// its autovalidate mode, a Form around fields, FormState.validate() as the
// validate action, and the form's errors for a summary.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

const _emailValidator = r"${= value == '' ? 'Enter your email.' : !contains(value, '@') ? 'Enter a valid email.' : ''}";
const _nameValidator = r"${= trim(value) == '' ? 'Enter your name.' : ''}";

Json _field(String validator, {String? mode, String? label}) => {
      'type': 'textField',
      'layout': {'width': 300, 'height': {'hug': 56}},
      'props': {
        'validator': validator,
        'autovalidateMode': ?mode,
        'decoration': {'labelText': ?label},
      },
    };

/// A form column (with [formMode]) of a name and an email field, a send
/// box that validates it and sets `sent` when all are valid, and a summary
/// text of the form's errors.
Map<String, Json> _form({String? formMode, String? emailMode}) => {
      'col': {
        'type': 'column',
        'children': ['name', 'email', 'send', 'summary'],
        'layout': {'width': 320, 'height': {'hug': 400}},
        'form': {'autovalidateMode': ?formMode},
      },
      'name': _field(_nameValidator, label: 'Name'),
      'email': _field(_emailValidator, mode: emailMode, label: 'Email'),
      'send': {
        'type': 'box',
        'layout': {'width': 120, 'height': 40},
        'decoration': {'fills': [{'color': '#FF000000'}]},
        'actions': [
          harness.reaction('click', [
            {'type': 'validate'},
            {
              'type': 'if',
              'condition': {'left': r'${result}', 'op': 'isTrue'},
              'then': [
                {'type': 'setVariable', 'variable': 'sent', 'value': r'${= true}'},
              ],
            },
          ]),
        ],
      },
      'summary': {
        'type': 'text',
        'layout': {'width': 300, 'height': {'hug': 20}},
        'props': {'text': '', 'style': {'fontSize': 12, 'color': '#FF000000'}},
        'bind': {'props.text': r"${= form.valid ? 'ok' : length(form.errors) + ' to fix'}"},
      },
    };

Finder _editable(int i) => find.byType(EditableText).at(i);

bool _focused(WidgetTester tester, int i) => tester.widget<EditableText>(_editable(i)).focusNode.hasFocus;

void main() {
  testWidgets('a field set to validate on unfocus shows its error when the focus leaves, not while typing', (tester) async {
    await harness.show(tester, _form(emailMode: 'onUnfocus'), variables: [harness.v('sent', false, VariableType.boolean)]);
    await tester.enterText(_editable(1), 'ada');
    await tester.pump();
    expect(find.text('Enter a valid email.'), findsNothing);
    await tester.showKeyboard(_editable(0));
    await tester.pump();
    expect(find.text('Enter a valid email.'), findsOneWidget);
    // It stays until it is validated again (Flutter's onUnfocus).
    await tester.enterText(_editable(1), 'ada@example.com');
    await tester.showKeyboard(_editable(0));
    await tester.pump();
    expect(find.text('Enter a valid email.'), findsNothing);
  });

  testWidgets('validating the form shows every error, focuses the first invalid field and stops the submit', (tester) async {
    final s = await harness.show(tester, _form(), variables: [harness.v('sent', false, VariableType.boolean)]);
    await tester.pump();
    expect(harness.textOf(s.tree, 'summary'), isNot('ok'), reason: 'the empty fields are not valid yet');
    expect(find.text('Enter your name.'), findsNothing, reason: 'nothing is shown before validating');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(harness.textOf(s.tree, 'summary'), '2 to fix');
    expect(_focused(tester, 0), isTrue, reason: 'the first invalid field takes the focus');
    expect(s['sent'], false);

    await tester.enterText(_editable(0), 'Ada');
    await tester.enterText(_editable(1), 'ada@example.com');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsNothing);
    expect(harness.textOf(s.tree, 'summary'), 'ok');
    expect(s['sent'], true);
  });

  testWidgets('the form\'s errors focus the first field shown, top to bottom, that fails', (tester) async {
    final s = await harness.show(tester, _form(), variables: [harness.v('sent', false, VariableType.boolean)]);
    await tester.enterText(_editable(0), 'Ada');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(harness.textOf(s.tree, 'summary'), '1 to fix');
    expect(_focused(tester, 1), isTrue);
  });

  testWidgets('a form validating on user interaction checks a field as it is typed in, and clears the error once fixed', (tester) async {
    await harness.show(tester, _form(formMode: 'onUserInteraction'), variables: [harness.v('sent', false, VariableType.boolean)]);
    expect(find.text('Enter a valid email.'), findsNothing);
    await tester.enterText(_editable(1), 'ada');
    await tester.pump();
    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Enter your name.'), findsNothing, reason: 'the name field was not touched');
    await tester.enterText(_editable(1), 'ada@example.com');
    await tester.pump();
    expect(find.text('Enter a valid email.'), findsNothing);
  });

  testWidgets('a field validating always shows its error from the start', (tester) async {
    await harness.show(tester, {
      'col': {'type': 'column', 'children': ['email'], 'layout': {'width': 320, 'height': {'hug': 100}}},
      'email': _field(_emailValidator, mode: 'always'),
    });
    await tester.pump();
    expect(find.text('Enter your email.'), findsOneWidget);
  });

  testWidgets('radios in a radio group share its value, and choosing one runs the group\'s changed reaction', (tester) async {
    Json radio(String value) => {'type': 'radio', 'layout': {'width': 24, 'height': 24}, 'props': {'value': value}};
    final s = await harness.show(tester, {
      'col': {
        'type': 'column',
        'children': ['small', 'large'],
        'layout': {'width': 100, 'height': {'hug': 60}},
        'radioGroup': {'groupValue': ''},
        'bind': {'radioGroup.groupValue': r'${budget}'},
        'actions': [
          harness.reaction('changed', [
            {'type': 'setVariable', 'variable': 'budget', 'value': r'${result}'},
          ]),
        ],
      },
      'small': radio('small'),
      'large': radio('large'),
    }, variables: [harness.v('budget', 'small')]);
    RadioGroup<String> groupOf(String id) => tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>).at(id == 'small' ? 0 : 1));
    expect(groupOf('small').groupValue, 'small');
    expect(groupOf('large').groupValue, 'small');
    await tester.tapAt(s.center('large'));
    await tester.pumpAndSettle();
    expect(s['budget'], 'large');
    expect(groupOf('small').groupValue, 'large', reason: 'every radio of the group follows its value');
  });

  testWidgets('an outlined field that sets no padding keeps its text off the border, as Flutter does', (tester) async {
    final s = await harness.show(tester, {
      'col': {'type': 'column', 'children': ['email'], 'layout': {'width': 320, 'height': {'hug': 100}}},
      'email': {
        'type': 'textField',
        'layout': {'width': 300, 'height': 56},
        'props': {
          'initialValue': 'ada',
          'decoration': {'border': {'type': 'outline', 'borderRadius': 8}},
        },
      },
    });
    final field = s.tree.boxOf('email')!.localToGlobal(Offset.zero);
    final text = tester.getTopLeft(find.byType(EditableText));
    expect(text.dx - field.dx, closeTo(12, 0.5));
  });
}
