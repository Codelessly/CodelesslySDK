import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// Quoted text in formulas: 'single' or "double" quotes, with backslash
// escapes, so a label can say "Doesn't fit".
void main() {
  Object? eval(String expression) => FormulaEvaluator.evaluate(
    expression,
    (path) => {'fits': false, 'name': 'Juniper'}[path],
  );
  String sub(String text) => FormulaEvaluator.substitute(
    text,
    (path) => {'fits': false, 'name': 'Juniper'}[path],
  );

  test('double quotes hold a single quote', () {
    expect(eval('''fits ? "Fits" : "Doesn't fit"'''), "Doesn't fit");
    expect(sub(r'''${= fits ? "Fits" : "Doesn't fit"}'''), "Doesn't fit");
  });

  test('a backslash escapes a quote', () {
    expect(eval(r"'Doesn\'t fit'"), "Doesn't fit");
    expect(eval(r'"Say \"hi\""'), 'Say "hi"');
    expect(sub(r"${= fits ? 'Fits' : 'Doesn\'t fit'}!"), "Doesn't fit!");
    expect(sub(r"${= name + '\'s rig'}"), "Juniper's rig");
  });

  test('a backslash escapes a backslash and writes newlines and tabs', () {
    expect(eval(r'"\\"'), r'\');
    expect(eval(r"'a\\'"), r'a\');
    expect(eval(r"'a\nb\tc'"), 'a\nb\tc');
  });

  test('an escaped quote does not end the text', () {
    expect(eval(r"'it\'s' + ' ok'"), "it's ok");
    expect(eval(r"'unclosed\'"), isNull);
  });

  test('paths are found next to escaped quotes', () {
    expect(
      FormulaEvaluator.referencedPathsInText(r"${= name + '\'s'} ${= fits}"),
      {'name', 'fits'},
    );
  });

  _delegate();
}

void _delegate() {
  test('escapes survive variable substitution in a text', () {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'fits': VariableData(
          id: 'fits',
          name: 'fits',
          type: VariableType.boolean,
          value: false,
        ),
      },
    );
    expect(
      PropertyValueDelegate.substituteVariables(
        r"${= fits ? 'Fits' : 'Doesn\'t fit'}",
        scopedValues: scope,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
      "Doesn't fit",
    );
  });
}
