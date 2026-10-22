import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// isEmpty / isNotEmpty on text variables, the way a form validates its
/// error messages before submitting.
void main() {
  bool check(Map<String, Object?> vars, String path, String operator) {
    final BaseExpression expression = BaseExpression.fromJson({
      'type': 'Expression',
      'leftPart': {'type': 'Variable', 'valueString': '\${$path}'},
      'operator': operator,
      'rightPart': {'type': 'RawValue', 'value': ''},
    });
    return expression.accept<bool>(
          ConditionEvaluator<Object>(
            scopedValues: ScopedValues.preview(
              variables: {
                for (final MapEntry(:key, :value) in vars.entries)
                  key: VariableData(id: key, name: key, value: value),
              },
            ),
          ),
        ) ==
        true;
  }

  test('an empty text variable is empty', () {
    expect(check({'error': ''}, 'error', 'isEmpty'), isTrue);
    expect(check({'error': ''}, 'error', 'isNotEmpty'), isFalse);
  });

  test('a text variable with a value is not empty', () {
    expect(check({'error': 'Incorrect PIN'}, 'error', 'isEmpty'), isFalse);
    expect(check({'error': 'Incorrect PIN'}, 'error', 'isNotEmpty'), isTrue);
  });

  test('a missing variable is empty', () {
    expect(check({}, 'missing', 'isEmpty'), isTrue);
    expect(check({}, 'missing', 'isNotEmpty'), isFalse);
  });

  test('both errors empty, joined with and', () {
    final BaseExpression expression = BaseExpression.fromJson({
      'type': 'ExpressionGroup',
      'join': 'and',
      'leftExpression': {
        'type': 'Expression',
        'leftPart': {'type': 'Variable', 'valueString': r'${idError}'},
        'operator': 'isEmpty',
        'rightPart': {'type': 'RawValue', 'value': ''},
      },
      'rightExpression': {
        'type': 'Expression',
        'leftPart': {'type': 'Variable', 'valueString': r'${pinError}'},
        'operator': 'isEmpty',
        'rightPart': {'type': 'RawValue', 'value': ''},
      },
    });
    expect(
      expression.accept<bool>(
        ConditionEvaluator<Object>(
          scopedValues: ScopedValues.preview(
            variables: {
              'idError': VariableData(id: 'a', name: 'idError', value: ''),
              'pinError': VariableData(id: 'b', name: 'pinError', value: ''),
            },
          ),
        ),
      ),
      isTrue,
    );
  });
}
