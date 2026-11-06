import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Builds [nodes] (the first is the root's child) with [variables].
Future<CodelesslyContext> pumpNodes(
  WidgetTester tester,
  List<BaseNode> nodes, {
  List<VariableData> variables = const [],
  Size size = const Size(800, 600),
}) async {
  final registry = NodeRegistry()
    ..setNodes({for (final node in nodes) node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final CodelesslyContext codelessly = CodelesslyContext.empty().copyWith(
    variables: {for (final v in variables) v.id: Observable(v)},
  );
  final List<BaseNode> roots = [
    for (final node in nodes)
      if (node.parentID == kRootNode) node,
  ];
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelessly,
      child: MaterialApp(
        home: Material(
          child: SizedBox.fromSize(
            size: size,
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final BaseNode root in roots)
                    manager.buildWidgetFromNode(
                      root,
                      context,
                      settings: const WidgetBuildSettings(debugLabel: 'test'),
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
  return codelessly;
}

void main() {
  group('Pagination node', () {
    List<BaseNode> nodes({int count = 35, int pageSize = 10}) => [
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 400, 300),
        properties: ListViewProperties(),
        variables: {'data': r'${rows}'},
        children: const ['row'],
        pagination: PaginationModel(
          name: 'rowsPager',
          mode: PaginationMode.pages,
          pageSize: pageSize,
          pageSizeOptions: const [10, 25],
        ),
      )..parentID = kRootNode,
      RectangleNode(
        id: 'row',
        name: 'row',
        basicBoxLocal: NodeBox(0, 0, 400, 30),
      )..parentID = 'list',
      PaginationNode(
        id: 'pager',
        name: 'pager',
        basicBoxLocal: NodeBox(0, 0, 800, 48),
        controller: 'rowsPager',
        properties: PaginationProperties(showPageSize: true),
      )..parentID = kRootNode,
    ];

    VariableData rows(int count) => VariableData(
      id: 'rows',
      name: 'rows',
      type: VariableType.list,
      value: [
        for (int i = 0; i < count; i++) {'id': i},
      ],
    );

    testWidgets('shows and moves its controller', (tester) async {
      final CodelesslyContext codelessly = await pumpNodes(
        tester,
        nodes(),
        variables: [rows(35)],
      );
      expect(find.text('Showing 1–10 of 35'), findsOneWidget);
      for (final String page in ['1', '2', '3', '4']) {
        expect(find.text(page), findsOneWidget, reason: page);
      }
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(codelessly.pagination['rowsPager']!.page, 3);
      expect(find.text('Showing 21–30 of 35'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 31–35 of 35'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('First page'));
      await tester.pumpAndSettle();
      expect(codelessly.pagination['rowsPager']!.page, 1);
    });

    testWidgets('previous is disabled on the first page', (tester) async {
      await pumpNodes(tester, nodes(), variables: [rows(35)]);
      final Semantics previous = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('‹'),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label == 'Previous page',
              ),
            )
            .first,
      );
      expect(previous.properties.enabled, isFalse);
    });

    testWidgets('long page ranges show ellipses', (tester) async {
      final CodelesslyContext codelessly = await pumpNodes(
        tester,
        nodes(),
        variables: [rows(200)],
      );
      await codelessly.pagination['rowsPager']!.goTo(10);
      await tester.pumpAndSettle();
      // 1 … 9 10 11 … 20
      expect(find.text('…'), findsNWidgets(2));
      expect(find.text('20'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('the page size select changes the page size', (tester) async {
      final CodelesslyContext codelessly = await pumpNodes(
        tester,
        nodes(),
        variables: [rows(100)],
      );
      expect(find.text('Rows per page'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      expect(codelessly.pagination['rowsPager']!.pageSize, 25);
      expect(find.text('Showing 1–25 of 100'), findsOneWidget);
    });

    testWidgets('without a controller it shows a preview', (tester) async {
      await pumpNodes(tester, [
        PaginationNode(
          id: 'pager',
          name: 'pager',
          basicBoxLocal: NodeBox(0, 0, 800, 48),
          controller: 'missing',
          properties: PaginationProperties(),
        )..parentID = kRootNode,
      ]);
      expect(find.text('Showing 1–20 of 200'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Table view', () {
    List<BaseNode> table() => [
      TableViewNode(
        id: 'table',
        name: 'table',
        basicBoxLocal: NodeBox(0, 0, 600, 400),
        variables: {'data': r'${rows}'},
        children: const ['cell', 'colHeader', 'rowHeader'],
        properties: TableViewProperties(
          columns: [
            for (int c = 0; c < 50; c++)
              TableColumnModel(key: 'c$c', label: 'Col $c'),
          ],
          cellNodeId: 'cell',
          columnHeaderNodeId: 'colHeader',
          rowHeaderNodeId: 'rowHeader',
          columnWidth: 100,
          rowHeaderWidth: 80,
          rowHeight: 40,
          headerHeight: 40,
        ),
      )..parentID = kRootNode,
      TextNode(
        id: 'cell',
        name: 'cell',
        basicBoxLocal: NodeBox(0, 0, 100, 20),
        data: r'${item.value}',
        textMixedProps: [
          StartEndProp(start: 0, end: r'${item.value}'.length, fontSize: 12),
        ],
      )..parentID = 'table',
      TextNode(
        id: 'colHeader',
        name: 'colHeader',
        basicBoxLocal: NodeBox(0, 0, 100, 20),
        data: r'${item.label}',
        textMixedProps: [
          StartEndProp(start: 0, end: r'${item.label}'.length, fontSize: 12),
        ],
      )..parentID = 'table',
      TextNode(
        id: 'rowHeader',
        name: 'rowHeader',
        basicBoxLocal: NodeBox(0, 0, 80, 20),
        data: r'R${item.rowIndex}',
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: r'R${item.rowIndex}'.length,
            fontSize: 12,
          ),
        ],
      )..parentID = 'table',
    ];

    final VariableData rows = VariableData(
      id: 'rows',
      name: 'rows',
      type: VariableType.list,
      value: [
        for (int r = 0; r < 1000; r++)
          {for (int c = 0; c < 50; c++) 'c$c': 'r${r}c$c'},
      ],
    );

    testWidgets('builds only the cells on screen', (tester) async {
      await pumpNodes(tester, table(), variables: [rows]);
      expect(tester.takeException(), isNull);
      expect(find.text('r0c0', findRichText: true), findsOneWidget);
      expect(find.text('Col 0', findRichText: true), findsOneWidget);
      // 1,000 × 50 cells; about 10 rows × 6 columns are on screen.
      final int built = find.byType(IndexedItemProvider).evaluate().length;
      expect(built, lessThan(200));
      expect(find.text('r999c49', findRichText: true), findsNothing);
    });

    testWidgets('pins the header row and column while scrolling', (
      tester,
    ) async {
      await pumpNodes(tester, table(), variables: [rows]);
      // Scroll down 400 rows and right 20 columns.
      await tester.drag(
        find.text('r2c2', findRichText: true),
        const Offset(-2000, -16000),
      );
      await tester.pumpAndSettle();
      expect(find.text('r0c0', findRichText: true), findsNothing);
      // The header row still shows column labels at the top...
      final Finder header = find.textContaining('Col ', findRichText: true);
      expect(header, findsWidgets);
      expect(tester.getTopLeft(header.first).dy, lessThan(40));
      // ... and the header column row labels at the left.
      final Finder rowHeader = find.textContaining(
        RegExp(r'^R\d+$'),
        findRichText: true,
      );
      expect(rowHeader, findsWidgets);
      expect(tester.getTopLeft(rowHeader.first).dx, lessThan(80));
      expect(tester.takeException(), isNull);
    });
  });
}
