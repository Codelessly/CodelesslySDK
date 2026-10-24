import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design canvas values read sample route params', () {
    final ScopedValues values = ScopedValues.preview(
      variables: const {},
      routeParams: const {'title': 'Log black tank dump?', 'danger': true},
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${route.title}',
        scopedValues: values,
      ),
      'Log black tank dump?',
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${= upper(route.title)}',
        scopedValues: values,
      ),
      'LOG BLACK TANK DUMP?',
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<bool>(
        r'${route.danger}',
        scopedValues: values,
      ),
      isTrue,
    );
  });
}
