import 'package:flutter/widgets.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TextSpan span(String text, int start, int end) =>
      TextUtils.buildTextSpanForProp(
        null,
        text,
        node: null,
        prop: StartEndProp(start: start, end: end),
        tapGestureRecognizer: null,
        variablesOverrides: const [],
        nullSubstitutionMode: NullSubstitutionMode.noChange,
        replaceVariableWithSymbol: false,
      );

  test('a range inside the text takes its characters', () {
    expect(span('Swell report', 0, 5).toPlainText(), 'Swell');
  });

  test('a range past the end of the text is clamped instead of throwing', () {
    expect(span('Swell', 0, 9).toPlainText(), 'Swell');
    expect(span('Swell', 7, 9).toPlainText(), '');
  });
}
