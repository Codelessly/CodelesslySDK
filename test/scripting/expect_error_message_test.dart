// A script test's expectError matches the error's type, its message, or
// "Type: message" (Petri v2: "loading a missing slide fails with No slide x").
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final failed = ScriptRunResult.failure('Error', 'No slide nope');
  ScriptTest t(String e) => ScriptTest(name: 't', expectError: e);

  test('type, message or both pass; anything else fails', () {
    expect(scriptTestFailure(t('Error'), failed), isNull);
    expect(scriptTestFailure(t('No slide nope'), failed), isNull);
    expect(scriptTestFailure(t('Error: No slide nope'), failed), isNull);
    expect(scriptTestFailure(t('RangeError'), failed), contains('Expected a RangeError'));
    expect(scriptTestFailure(t('No slide'), failed), isNotNull);
  });
}
