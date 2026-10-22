import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// `add` appends without an index: one item, or each item of a list.
void main() {
  Future<List?> add(WidgetTester tester, String newValue) async {
    final Observable<VariableData> items = Observable(
      VariableData(
        id: 'items',
        name: 'items',
        type: VariableType.list,
        value: [1],
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['items'] = items;
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    FunctionsRepository.setVariableFromAction(
      context,
      SetVariableAction(
        variable: VariableData(
          id: 'items',
          name: 'items',
          type: VariableType.list,
        ),
        listOperation: ListOperation.add,
        newValue: newValue,
      ),
    );
    return items.value.getValue() as List?;
  }

  testWidgets('adds one map', (tester) async {
    expect(await add(tester, '{"id": "a"}'), [
      1,
      {'id': 'a'},
    ]);
  });

  testWidgets('adds a number', (tester) async {
    expect(await add(tester, '2'), [1, 2]);
  });

  testWidgets('adds each item of a list', (tester) async {
    expect(await add(tester, '[2, 3]'), [1, 2, 3]);
  });
}
