// Forms as Flutter has them: a field's validator (TextFormField.validator),
// its autovalidate mode, a Form around fields, FormState.validate() as the
// validate action, and the form's errors for a summary.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:codelessly_sdk/src/render/controls/text_field.dart' show RenderTextField;

import '../support/fields.dart';
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

RenderTextField _editable(WidgetTester tester, int i) => textField(tester, i);

bool _focused(WidgetTester tester, int i) => _editable(tester, i).focusNode.hasFocus;

/// How many fields show [message] under them.
int _shown(WidgetTester tester, String message) => textFields(tester).where((f) => f.belowText == message).length;

Future<void> _type(WidgetTester tester, int i, String text) => typeInto(tester, text, field: _editable(tester, i));

Future<void> _focusField(WidgetTester tester, int i) async {
  _editable(tester, i).requestFocus();
  await tester.pump();
}

void main() {
  testWidgets('a field set to validate on unfocus shows its error when the focus leaves, not while typing', (tester) async {
    await harness.show(tester, _form(emailMode: 'onUnfocus'), variables: [harness.v('sent', false, VariableType.boolean)]);
    await _type(tester, 1, 'ada');
    await tester.pump();
    expect(_shown(tester, 'Enter a valid email.'), 0);
    await _focusField(tester, 0);
    await tester.pump();
    expect(_shown(tester, 'Enter a valid email.'), 1);
    // It stays until it is validated again (Flutter's onUnfocus).
    await _type(tester, 1, 'ada@example.com');
    await _focusField(tester, 0);
    await tester.pump();
    expect(_shown(tester, 'Enter a valid email.'), 0);
  });

  testWidgets('validating the form shows every error, focuses the first invalid field and stops the submit', (tester) async {
    final s = await harness.show(tester, _form(), variables: [harness.v('sent', false, VariableType.boolean)]);
    await tester.pump();
    expect(harness.textOf(s.tree, 'summary'), isNot('ok'), reason: 'the empty fields are not valid yet');
    expect(_shown(tester, 'Enter your name.'), 0, reason: 'nothing is shown before validating');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(_shown(tester, 'Enter your name.'), 1);
    expect(_shown(tester, 'Enter your email.'), 1);
    expect(harness.textOf(s.tree, 'summary'), '2 to fix');
    expect(_focused(tester, 0), isTrue, reason: 'the first invalid field takes the focus');
    expect(s['sent'], false);

    await _type(tester, 0, 'Ada');
    await _type(tester, 1, 'ada@example.com');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(_shown(tester, 'Enter your name.'), 0);
    expect(harness.textOf(s.tree, 'summary'), 'ok');
    expect(s['sent'], true);
  });

  testWidgets('the form\'s errors focus the first field shown, top to bottom, that fails', (tester) async {
    final s = await harness.show(tester, _form(), variables: [harness.v('sent', false, VariableType.boolean)]);
    await _type(tester, 0, 'Ada');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(harness.textOf(s.tree, 'summary'), '1 to fix');
    expect(_focused(tester, 1), isTrue);
  });

  testWidgets('a form validating on user interaction checks a field as it is typed in, and clears the error once fixed', (tester) async {
    await harness.show(tester, _form(formMode: 'onUserInteraction'), variables: [harness.v('sent', false, VariableType.boolean)]);
    expect(_shown(tester, 'Enter a valid email.'), 0);
    await _type(tester, 1, 'ada');
    await tester.pump();
    expect(_shown(tester, 'Enter a valid email.'), 1);
    expect(_shown(tester, 'Enter your name.'), 0, reason: 'the name field was not touched');
    await _type(tester, 1, 'ada@example.com');
    await tester.pump();
    expect(_shown(tester, 'Enter a valid email.'), 0);
  });

  testWidgets('a field validating always shows its error from the start', (tester) async {
    await harness.show(tester, {
      'col': {'type': 'column', 'children': ['email'], 'layout': {'width': 320, 'height': {'hug': 100}}},
      'email': _field(_emailValidator, mode: 'always'),
    });
    await tester.pump();
    expect(_shown(tester, 'Enter your email.'), 1);
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

  testWidgets('arrow keys move the choice between the radios of a group, wrapping at the ends, as Flutter\'s RadioGroup does',
      (tester) async {
    Json radio(String value) => {'type': 'radio', 'layout': {'width': 24, 'height': 24}, 'props': {'value': value}};
    final s = await harness.show(tester, {
      'col': {
        'type': 'column',
        'children': ['small', 'medium', 'large'],
        'layout': {'width': 100, 'height': {'hug': 90}},
        'radioGroup': {'groupValue': ''},
        'bind': {'radioGroup.groupValue': r'${budget}'},
        'actions': [
          harness.reaction('changed', [
            {'type': 'setVariable', 'variable': 'budget', 'value': r'${result}'},
          ]),
        ],
      },
      'small': radio('small'),
      'medium': radio('medium'),
      'large': radio('large'),
    }, variables: [harness.v('budget', 'small')]);
    // Tab to the first radio.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.byType(Radio<String>).first)).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(s['budget'], 'medium');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(s['budget'], 'large');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(s['budget'], 'small', reason: 'past the last it wraps to the first');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(s['budget'], 'large', reason: 'before the first it wraps to the last');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(s['budget'], 'medium');
    expect(Focus.of(tester.element(find.byType(Radio<String>).at(1))).hasFocus, isTrue, reason: 'the focus moves with the choice');
  });

  testWidgets('fields a list repeats inside a form belong to it: validating checks each, and the form counts them', (tester) async {
    final s = await harness.show(tester, {
      'col': {
        'type': 'column',
        'children': ['guests', 'send', 'summary'],
        'layout': {'width': 320, 'height': {'hug': 400}},
        'form': {},
      },
      'guests': {
        'type': 'listView',
        'children': ['guest'],
        'layout': {'width': 320, 'height': {'hug': 200}},
        'bind': {'data': r'${= ["a", "b", "c"]}'},
      },
      'guest': _field(_nameValidator, label: 'Guest'),
      'send': _form()['send']!,
      'summary': _form()['summary']!,
    }, variables: [harness.v('sent', false, VariableType.boolean)]);
    await tester.pump();
    expect(textFields(tester), hasLength(3));
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(_shown(tester, 'Enter your name.'), 3);
    expect(harness.textOf(s.tree, 'summary'), '3 to fix');
    expect(s['sent'], false);
    // The form follows its fields as they change, without validating again.
    for (var i = 0; i < 3; i++) {
      await _type(tester, i, 'Guest $i');
      await tester.pumpAndSettle();
    }
    expect(harness.textOf(s.tree, 'summary'), 'ok');
    await tester.tapAt(s.center('send'));
    await tester.pumpAndSettle();
    expect(s['sent'], true);
  });

  testWidgets('a form a list repeats holds only the fields of its own item', (tester) async {
    final s = await harness.show(tester, {
      'col': {'type': 'column', 'children': ['cards'], 'layout': {'width': 320, 'height': {'hug': 400}}},
      'cards': {
        'type': 'listView',
        'children': ['card'],
        'layout': {'width': 320, 'height': {'hug': 300}},
        'bind': {'data': r'${= ["a", "b"]}'},
      },
      'card': {
        'type': 'column',
        'children': ['name', 'send'],
        'layout': {'width': 320, 'height': {'hug': 120}},
        'form': {},
      },
      'name': _field(_nameValidator, label: 'Name'),
      'send': _form()['send']!,
    }, variables: [harness.v('sent', false, VariableType.boolean)]);
    await tester.pump();
    final sends = s.tree.boxesOf('send').toList();
    expect(sends, hasLength(2));
    final first = sends.first.localToGlobal(sends.first.size.center(Offset.zero));
    await tester.tapAt(first);
    await tester.pumpAndSettle();
    expect(_shown(tester, 'Enter your name.'), 1, reason: 'only the first card\'s field is checked');
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
    final f = textField(tester);
    final text = f.localToGlobal(f.textRect.topLeft);
    expect(text.dx - field.dx, closeTo(12, 0.5));
  });
}
