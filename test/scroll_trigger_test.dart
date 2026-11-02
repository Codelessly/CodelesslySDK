import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A scrolling row, column or canvas runs its Scroll reactions on every
/// scroll update with `${result.offset}`, `${result.max}` and
/// `${result.fraction}`, so a header can collapse as the page scrolls.
void main() {
  test('Rows, columns and canvases offer the scroll trigger', () {
    final column = ColumnNode(
      id: 'c',
      name: 'c',
      basicBoxLocal: NodeBox(0, 0, 100, 100),
      children: const [],
    );
    expect(column.triggerTypes, contains(TriggerType.scroll));
    expect(TriggerModel.fromJson({'type': 'scroll'}).type, TriggerType.scroll);
  });

  testWidgets('Scrolling runs the reactions with the offset', (tester) async {
    final offsets = <Object?>[];
    final context = CodelesslyContext.empty()
      ..functions = {
        'onScroll': (context, reference, params) =>
            offsets.add(params['offset']),
      };
    final column = ColumnNode(
      id: 'list',
      name: 'list',
      basicBoxLocal: NodeBox(0, 0, 300, 400),
      children: const [],
      isScrollable: true,
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.scroll),
          action: CallFunctionAction(
            name: 'onScroll',
            params: {'offset': r'${result.offset}'},
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: ActionChainHost(
            child: SizedBox(
              height: 400,
              child: buildScrollView(
                node: column,
                child: Column(
                  children: [
                    // A nested horizontal scroll view doesn't count.
                    SizedBox(
                      height: 100,
                      child: ListView(
                        key: const Key('inner'),
                        scrollDirection: Axis.horizontal,
                        children: const [SizedBox(width: 2000)],
                      ),
                    ),
                    const SizedBox(height: 2000),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const Key('inner')), const Offset(-200, 0));
    await tester.pump();
    expect(offsets, isEmpty);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(offsets, isNotEmpty);
    expect(num.parse('${offsets.last}'), greaterThan(100));
  });
}
