import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a computed text that gives nothing has no characters', () {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'title': VariableData(id: 'title', name: 'title', value: r'${= null}'),
      },
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<Object>(
        'title[0]',
        scopedValues: scope,
      ),
      isNull,
    );
  });
}
