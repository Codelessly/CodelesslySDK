import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VariableData list(String name, String value) =>
      VariableData(id: name, name: name, type: VariableType.list, value: value);

  test('initial.<name> reads a variable as published, not as changed', () {
    final CodelesslyContext context = CodelesslyContext.empty();
    context.variables['txns'] = Observable(list('txns', '[3]'));
    context.initialVariables['txns'] = list('txns', '[1, 2]');
    final ScopedValues scope = ScopedValues.preview(
      variables: const {},
      codelesslyContext: context,
    );

    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        'initial.txns',
        scopedValues: scope,
      ),
      [1, 2],
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        'txns',
        scopedValues: scope,
      ),
      [3],
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        'initial.txns.length',
        scopedValues: scope,
      ),
      2,
    );
    context.dispose();
  });

  test('on a design canvas initial.<name> is the variable itself', () {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'seq': VariableData(
          id: 'seq',
          name: 'seq',
          type: VariableType.integer,
          value: '7',
        ),
      },
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        'initial.seq',
        scopedValues: scope,
      ),
      7,
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        'initial.missing',
        scopedValues: scope,
      ),
      isNull,
    );
  });

  test('initial is a predefined variable', () {
    expect(predefinedVariableNames, contains('initial'));
  });
}
