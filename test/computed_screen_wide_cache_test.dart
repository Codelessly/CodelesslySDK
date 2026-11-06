import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a computed chain reading screen-wide values (storage, screen) stays cached', () {
    final Map<String, VariableData> variables = {
      'saved': VariableData(id: 'saved', name: 'saved', value: r'${= coalesce(storage.pp, {})}'),
      'wide': VariableData(id: 'wide', name: 'wide', value: r'${= screen.width > 700}'),
      'heavy': VariableData(
        id: 'heavy',
        name: 'heavy',
        value: r'${= map(range(0, 2000), i => {i: i, n: length(keys(saved)), w: wide})}',
      ),
    };
    ScopedValues scope(double width) =>
        ScopedValues.preview(variables: variables, screenSize: Size(width, 800));
    Object? heavy(ScopedValues s) =>
        PropertyValueDelegate.getVariableValueFromPath<Object>('heavy', scopedValues: s);

    final ScopedValues phone = scope(390);
    final Object? first = heavy(phone);
    expect(first, isA<List>());
    // Read again with nothing changed: the same list, not worked out again.
    expect(identical(heavy(phone), first), isTrue);
    expect(identical(heavy(scope(390)), first), isTrue);
    // The screen changed: worked out again.
    final Object? wider = heavy(scope(1200));
    expect(identical(wider, first), isFalse);
    expect(((wider as List).first as Map)['w'], isTrue);
  });

  test('item-dependent formulas are still not cached', () {
    final Map<String, VariableData> variables = {
      'twice': VariableData(id: 'twice', name: 'twice', value: r'${= item * 2}'),
    };
    Object? at(int item) => PropertyValueDelegate.getVariableValueFromPath<Object>(
          'twice',
          scopedValues: ScopedValues.preview(variables: variables, indexedItem: IndexedItem(0, item)),
        );
    expect(at(2), 4);
    expect(at(5), 10);
  });
}
