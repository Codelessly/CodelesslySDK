// The pagination node: its controls show and move the controller it names.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, Json> nodes({int pageSize = 10, String controller = 'rowsPager'}) => {
      'col': {
        'type': 'column',
        'children': ['list', 'pager'],
        'layout': {'width': 1100, 'height': {'hug': 400}},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 400, 'height': 300},
        'bind': {'data': r'${rows}'},
        'props': {
          'pagination': {
            'name': 'rowsPager',
            'mode': 'pages',
            'pageSize': pageSize,
            'pageSizeOptions': [10, 25],
          },
        },
      },
      'row': {'type': 'box', 'layout': {'width': 400, 'height': 30}},
      'pager': {
        'type': 'pagination',
        // Test glyphs are wide: the controls fit on one run.
        'layout': {'width': 1100, 'height': 48},
        'props': {'controller': controller, 'showPageSize': true},
        'actions': [
          reaction('changed', [
            {'type': 'setVariable', 'variable': 'chosen', 'value': r'${result}'},
          ]),
        ],
      },
    };

Variable rows(int count) => v('rows', [for (var i = 0; i < count; i++) {'id': i}], VariableType.list);

void main() {
  late Screen s;
  Future<PaginationController> pump(WidgetTester tester, int count, {String controller = 'rowsPager'}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    s = await show(tester, nodes(controller: controller), variables: [rows(count), v('chosen', '')]);
    await tester.pumpAndSettle();
    return PaginationRegistry.of(s.tree)['rowsPager']!;
  }

  testWidgets('shows and moves its controller', (tester) async {
    final c = await pump(tester, 35);
    expect(find.text('Showing 1–10 of 35'), findsOneWidget);
    for (final page in ['1', '2', '3', '4']) {
      expect(find.text(page), findsOneWidget, reason: page);
    }
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(c.page, 3);
    expect(s['chosen'], '3');
    expect(find.text('Showing 21–30 of 35'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 31–35 of 35'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('First page'));
    await tester.pumpAndSettle();
    expect(c.page, 1);
  });

  testWidgets(
    'controls refresh when asynchronous local data replaces an empty list',
    (tester) async {
      await pump(tester, 0);
      expect(find.text('Showing 0–0 of 0'), findsOneWidget);
      s.scope.set('rows', [
        for (var i = 0; i < 35; i++) {'id': i},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1–10 of 35'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 11–20 of 35'), findsOneWidget);
    },
  );

  testWidgets('previous is disabled on the first page', (tester) async {
    await pump(tester, 35);
    final previous = tester.widget<Semantics>(find
        .ancestor(
          of: find.text('‹'),
          matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Previous page'),
        )
        .first);
    expect(previous.properties.enabled, isFalse);
  });

  testWidgets('long page ranges show ellipses', (tester) async {
    final c = await pump(tester, 200);
    await c.goTo(10);
    await tester.pumpAndSettle();
    // 1 … 9 10 11 … 20
    expect(find.text('…'), findsNWidgets(2));
    expect(find.text('20'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('the page size select changes the page size', (tester) async {
    final c = await pump(tester, 100);
    expect(find.text('Rows per page'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    expect(c.pageSize, 25);
    expect(find.text('Showing 1–25 of 100'), findsOneWidget);
  });

  testWidgets('without a controller it shows a preview', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    s = await show(tester, {'col': nodes(controller: 'missing')['pager']!}, variables: [v('chosen', '')]);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–20 of 200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
