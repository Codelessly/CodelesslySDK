import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => FormulaClock.pinned = null);

  test('a computed variable that reads the clock is not cached', () {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'endsAt': VariableData(
          id: 'endsAt',
          name: 'endsAt',
          type: VariableType.text,
          value: '2026-10-22T13:30:00Z',
        ),
        'left': VariableData(
          id: 'left',
          name: 'left',
          value: r'${= diffSeconds(now(), endsAt)}',
        ),
      },
    );
    Object? left() => PropertyValueDelegate.getVariableValueFromPath<Object>(
      'left',
      scopedValues: scope,
    );

    FormulaClock.pinned = DateTime.parse('2026-10-22T13:20:00Z');
    expect(left(), 600);
    FormulaClock.pinned = DateTime.parse('2026-10-22T13:20:05Z');
    expect(left(), 595);
  });
}
