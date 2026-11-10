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

  test('list link parameters split on commas or read JSON', () {
    expect(Codelessly.linkValueFor(VariableType.list, 'Tired,Wired'), [
      'Tired',
      'Wired',
    ]);
    expect(Codelessly.linkValueFor(VariableType.list, ' Tired , Wired ,'), [
      'Tired',
      'Wired',
    ]);
    expect(Codelessly.linkValueFor(VariableType.list, '3,7'), [3, 7]);
    expect(Codelessly.linkValueFor(VariableType.list, '["a,b","c"]'), [
      'a,b',
      'c',
    ]);
    expect(Codelessly.linkValueFor(VariableType.list, ''), isEmpty);
    expect(Codelessly.linkValueFor(VariableType.list, 'Focused'), ['Focused']);
  });

  test('map link parameters read JSON', () {
    expect(Codelessly.linkValueFor(VariableType.map, '{"a":1}'), {'a': 1});
    expect(Codelessly.linkValueFor(VariableType.map, 'plain'), 'plain');
  });
}
