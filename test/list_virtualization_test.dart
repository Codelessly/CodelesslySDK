import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Long data lists build only the items near the viewport, and an item
/// template with a fixed height gives every item that extent, so the list
/// lays out any offset without building the items before it.
void main() {
  final VariableData rows = VariableData(
    id: 'rows',
    name: 'rows',
    type: VariableType.list,
    value: [
      for (int i = 0; i < 10000; i++) {'id': 'r$i', 'name': 'Row $i'},
    ],
  );

  Future<void> pumpList(
    WidgetTester tester, {
    SizeFit itemFit = SizeFit.fixed,
    bool separators = false,
    Map<String, String> itemVariables = const {},
  }) async {
    final List<BaseNode> nodes = [
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 300, 400),
        properties: ListViewProperties(
          hasSeparator: separators,
          separatorSpacing: separators ? 8 : 0,
        ),
        variables: {'data': r'${rows}'},
        children: ['row'],
      )..parentID = kRootNode,
      RectangleNode(
        id: 'row',
        name: 'row',
        basicBoxLocal: NodeBox(0, 0, 300, 56),
        verticalFit: itemFit,
      )
        ..parentID = 'list'
        ..variables.addAll(itemVariables),
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty().copyWith(
          variables: {rows.id: Observable(rows)},
        ),
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  nodes.first,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  List<int> builtIndexes(WidgetTester tester) => [
    for (final Element e in find.byType(IndexedItemProvider).evaluate())
      (e.widget as IndexedItemProvider).item.index,
  ]..sort();

  testWidgets('a 10,000 item list builds only the items it shows', (
    tester,
  ) async {
    await pumpList(tester);
    final List<int> built = builtIndexes(tester);
    // 400 / 56 is about 7 items, plus the cache extent's worth on each side.
    expect(built.first, 0);
    expect(built.length, lessThan(20));
  });

  testWidgets('a fixed-height item template gives every item its extent', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.byType(SliverFixedExtentList), findsOneWidget);

    // Jumping deep into the list builds only the items around the target.
    final ScrollableState scrollable = tester.state(find.byType(Scrollable));
    scrollable.position.jumpTo(56.0 * 9000);
    await tester.pump();
    final List<int> built = builtIndexes(tester);
    expect(built, contains(9000));
    expect(built.length, lessThan(20));
    expect(built.first, greaterThan(8900));
  });

  testWidgets('separators keep the fixed extent', (tester) async {
    await pumpList(tester, separators: true);
    expect(find.byType(SliverVariedExtentList), findsOneWidget);
    final ScrollableState scrollable = tester.state(find.byType(Scrollable));
    // Each item and the 8 pixel gap after it take 64 pixels.
    scrollable.position.jumpTo(64.0 * 5000);
    await tester.pump();
    expect(builtIndexes(tester), contains(5000));
    final Rect first = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is IndexedItemProvider && w.item.index == 5000,
      ),
    );
    expect(first.top, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hugging item template is measured item by item', (
    tester,
  ) async {
    await pumpList(tester, itemFit: SizeFit.shrinkWrap);
    expect(find.byType(SliverFixedExtentList), findsNothing);
    expect(builtIndexes(tester).length, lessThan(30));
  });

  testWidgets('a bound height keeps the items measured', (tester) async {
    await pumpList(tester, itemVariables: {'height': r'${item.h}'});
    expect(find.byType(SliverFixedExtentList), findsNothing);
  });
}
