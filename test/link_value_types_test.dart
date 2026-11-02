import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('link parameters take their variable\'s type', () {
    for (final String yes in ['1', 'true', 'TRUE', 'yes', 'on']) {
      expect(
        Codelessly.linkValueFor(VariableType.boolean, yes),
        isTrue,
        reason: yes,
      );
    }
    for (final String no in ['0', 'false', 'no', 'off', '']) {
      expect(
        Codelessly.linkValueFor(VariableType.boolean, no),
        isFalse,
        reason: no,
      );
    }
    expect(Codelessly.linkValueFor(VariableType.integer, '10'), 10);
    expect(Codelessly.linkValueFor(VariableType.integer, '2.6'), 3);
    expect(Codelessly.linkValueFor(VariableType.decimal, '18.2'), 18.2);
    expect(Codelessly.linkValueFor(VariableType.text, '1'), '1');
    expect(
      Codelessly.linkValueFor(VariableType.text, 'kind-of-blue'),
      'kind-of-blue',
    );
  });
}
