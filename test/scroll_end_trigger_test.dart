import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A 600px-tall scrolling list of [count] 64px rows under a detector whose
/// reaction counts its runs.
Future<List<String>> pumpList(WidgetTester tester, ValueNotifier<int> count) async {
  final calls = <String>[];
  final codelesslyContext = CodelesslyContext.empty()
    ..functions = {'more': (context, reference, params) => calls.add('more')};
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: ActionChainHost(
          child: ScrollEndDetector(
            reactions: [
              Reaction(
                trigger: TriggerModel(type: TriggerType.scrollEnd),
                action: CallFunctionAction(name: 'more'),
              ),
            ],
            child: ValueListenableBuilder<int>(
              valueListenable: count,
              builder: (context, n, _) => ListView(
                children: [
                  for (int i = 0; i < n; i++)
                    SizedBox(height: 64, child: Text('row $i')),
                  // A nested scrollable reaching its end doesn't count.
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [SizedBox(width: 10)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  test('lists, grids and rows/columns offer Reached End', () {
    expect(TriggerType.scrollEnd.prettify, 'Reached End');
    final list = ListViewNode(
      id: 'l',
      name: 'l',
      basicBoxLocal: NodeBox(0, 0, 1, 1),
      children: const [],
      properties: ListViewProperties(),
    );
    expect(list.triggerTypes, contains(TriggerType.scrollEnd));
    expect(
      TriggerModel.fromJson({'type': 'scrollEnd'}).type,
      TriggerType.scrollEnd,
    );
  });

  testWidgets('runs near the end, once per content length', (tester) async {
    final count = ValueNotifier<int>(20); // 20 × 64 = 1280px of rows.
    final calls = await pumpList(tester, count);
    expect(calls, isEmpty);

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(calls, isEmpty, reason: 'still far from the end');

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(calls, ['more']);

    // Scrolling about near the same end doesn't run it again.
    await tester.drag(find.byType(ListView).first, const Offset(0, 50));
    await tester.drag(find.byType(ListView).first, const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(calls, ['more']);

    // The next page arrives: reaching the new end runs it again.
    count.value = 40;
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(calls, ['more', 'more']);
  });

  testWidgets('runs at once when the content does not fill the view', (
    tester,
  ) async {
    final calls = await pumpList(tester, ValueNotifier<int>(3));
    expect(calls, ['more']);
  });
}
