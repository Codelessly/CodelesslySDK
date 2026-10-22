import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stacked survives JSON and is off by default', () {
    final props = ListViewProperties(stacked: true);
    expect(ListViewProperties.fromJson(props.toJson()).stacked, isTrue);
    expect(ListViewProperties().toJson().containsKey('stacked'), isFalse);
    expect(props.copyWith().stacked, isTrue);
  });

  testWidgets('Stacked items overlap, and the first one is on top', (
    tester,
  ) async {
    final items = ['a', 'b', 'c'];
    final taps = <String>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: StackedItems(
              itemCount: items.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => taps.add(items[index]),
                child: Container(
                  width: 100,
                  height: 100,
                  color: const Color(0xFF000000),
                  child: Text(items[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final Offset a = tester.getTopLeft(find.text('a'));
    expect(tester.getTopLeft(find.text('b')), a);
    expect(tester.getTopLeft(find.text('c')), a);
    // Placed at the top center of the box.
    final Offset box = tester.getTopLeft(find.byType(StackedItems));
    expect(a, box + const Offset(50, 0));

    await tester.tap(find.text('a'));
    expect(taps, ['a']);
  });
}
