import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Switchboard's ticket rows are a computed list over the app clock
/// (`nowAt`, which reads `now()`). Clock formulas were never cached, so
/// every read worked the list out again and gave a new list, and the list
/// view rebuilt every row on each keystroke anywhere in the app.
void main() {
  tearDown(() => FormulaClock.pinned = null);

  test('a computed list over the clock is the same list within a second', () {
    final ScopedValues values = ScopedValues.preview(
      variables: {
        'items': VariableData(
          id: 'items',
          name: 'items',
          type: VariableType.list,
          value: '[1, 2, 3]',
        ),
        'nowAt': VariableData(id: 'nowAt', name: 'nowAt', value: r'${= now()}'),
        'rows': VariableData(
          id: 'rows',
          name: 'rows',
          type: VariableType.list,
          value: r'${= concat(items, [nowAt])}',
        ),
      },
    );
    Object? rows() => PropertyValueDelegate.getVariableValueFromPath<Object>(
      'rows',
      scopedValues: values,
    );

    FormulaClock.pinned = DateTime(2026, 10, 30, 14, 0, 0, 100);
    final Object? first = rows();
    expect((first! as List).length, 4);
    FormulaClock.pinned = DateTime(2026, 10, 30, 14, 0, 0, 900);
    expect(rows(), same(first));

    FormulaClock.pinned = DateTime(2026, 10, 30, 14, 0, 1, 100);
    expect(rows(), isNot(same(first)));
  });
}
