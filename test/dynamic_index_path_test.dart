import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// A binding that indexes a map by a list item's field, such as an icon's
// `iconColor: ${kindPal[item.kind]}`, reads the entry for that item.

void main() {
  final ScopedValues values = ScopedValues.preview(
    variables: {
      'kindPal': VariableData(
        id: 'k',
        name: 'kindPal',
        type: VariableType.map,
        value: <String, dynamic>{'gate': '#C96F1C', 'cancel': '#B83A32'},
      ),
      'rows': VariableData(
        id: 'r',
        name: 'rows',
        type: VariableType.list,
        value: <dynamic>['a', 'b'],
      ),
    },
    indexedItem: IndexedItem(1, {'kind': 'cancel'}),
  );

  Object? read<R extends Object>(String path) =>
      PropertyValueDelegate.getVariableValueFromPath<R>(
        path,
        scopedValues: values,
      );

  test('a map indexed by an item field', () {
    expect(read<Object>(r'${kindPal[item.kind]}'), '#B83A32');
    expect(
      read<ColorRGBA>(r'${kindPal[item.kind]}'),
      read<ColorRGBA>(r'${= kindPal[item.kind]}'),
    );
    expect(read<ColorRGBA>(r'${kindPal[item.kind]}'), isNotNull);
  });

  test('a list indexed by index', () {
    expect(read<Object>(r'${rows[index]}'), 'b');
  });

  test('literal paths are unchanged', () {
    expect(read<Object>(r'${kindPal.gate}'), '#C96F1C');
    expect(read<Object>(r'${rows[0]}'), 'a');
    expect(read<Object>(r'${kindPal[item.missing]}'), isNull);
  });
}
