import 'package:codelessly_sdk/src/render/controls/text_field.dart' show fieldInputFormatter;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A field's inputFormatter of the kinds its property documents
// (`{"type": "email"|"phone"|"regex"}`): email and phone were accepted and
// let every edit through.

String _typed(Map<String, Object?> formatter, String text) => fieldInputFormatter(formatter)!
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)))
    .text;

void main() {
  test('email: no spaces in an address', () {
    expect(_typed({'type': 'email'}, 'member @example.com '), 'member@example.com');
  });

  test('phone: digits and what a number is written with', () {
    expect(_typed({'type': 'phone'}, '+1 (555) 010-99x9'), '+1 (555) 010-999');
  });

  test('regex as before; none and an empty one: no formatter', () {
    expect(_typed({'type': 'regex', 'pattern': r'[0-9]', 'allow': true}, 'a1b2'), '12');
    expect(fieldInputFormatter({'type': 'none'}), isNull);
    expect(fieldInputFormatter(const {}), isNull);
  });
}
