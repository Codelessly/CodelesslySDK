import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [IndexedItemProvider.parentOf] finds the outer list's provider once per
/// item (it walked up to the root on every binding read), and still reads
/// that list's current item.
void main() {
  testWidgets('parentOf reads the current outer item, and null without one', (
    tester,
  ) async {
    IndexedItem? parent;
    IndexedItem? lone;
    Widget tree(int outer) => Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          IndexedItemProvider(
            item: IndexedItem(outer, 'outer $outer'),
            child: IndexedItemProvider(
              item: IndexedItem(0, 'inner'),
              child: Builder(
                builder: (context) {
                  parent = IndexedItemProvider.parentOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
          IndexedItemProvider(
            item: IndexedItem(0, 'alone'),
            child: Builder(
              builder: (context) {
                lone = IndexedItemProvider.parentOf(context);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(tree(1));
    expect(parent, IndexedItem(1, 'outer 1'));
    expect(lone, isNull);

    await tester.pumpWidget(tree(2));
    expect(parent, IndexedItem(2, 'outer 2'));
  });
}
