import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// On the design canvas a list inside another list's row reads the outer
/// row as `parent.item`, as it does at runtime: a card's money list converts
/// into that card's currency.
void main() {
  tearDown(() => VariablePreview.scopeResolver = null);

  testWidgets('a nested row previews its outer row as parent.item', (
    tester,
  ) async {
    VariablePreview.scopeResolver = (_) =>
        ScopedValues.preview(variables: const {});
    late BuildContext inner;
    await tester.pumpWidget(
      IndexedItemProvider(
        item: IndexedItem(1, const {'currency': 'JPY'}),
        child: IndexedItemProvider(
          item: IndexedItem(2, 50),
          child: Builder(
            builder: (c) {
              inner = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final ScopedValues? values = VariablePreview.scopeOf(null, context: inner);
    expect(values?.indexedItem?.item, 50);
    expect(values?.parentIndexedItem?.item, {'currency': 'JPY'});
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${parent.item.currency}',
        scopedValues: values!,
      ),
      'JPY',
    );
  });
}
