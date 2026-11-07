// A running list that pages, groups into sections or swipes (SDK 8.x's
// DataListView): its items over bound data, its pagination's variable,
// paginate actions, footers, pull to refresh, sections and swipe actions.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<Object?> people(int n) => [for (var i = 0; i < n; i++) {'id': i, 'name': 'P$i', 'group': i < 3 ? 'A' : 'B'}];

/// A column: a status text over a 300×400 list of 40-high rows showing
/// `${item.name}`, bound to `people`, and a "next" button.
Map<String, Json> screen({Json? pagination, Json extraList = const {}, Map<String, Json> extra = const {}, List<Json> buttonActions = const []}) => {
      'col': {
        'type': 'column',
        'children': ['status', 'list', 'button'],
        'layout': {'width': 300, 'height': {'hug': 500}},
      },
      'status': {
        'type': 'text',
        'layout': {'width': 300, 'height': 20},
        'props': {'text': r'${contacts.page}/${contacts.pageCount} ${contacts.itemCount}'},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 300, 'height': 400},
        'bind': {'data': r'${people}'},
        'props': {'pagination': ?pagination},
        ...extraList,
      },
      'row': {
        'type': 'text',
        'layout': {'width': 300, 'height': 40},
        'props': {'text': r'${item.name}'},
      },
      'button': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'decoration': {'fills': [{'color': '#FF2196F3'}]},
        'actions': [if (buttonActions.isNotEmpty) reaction('click', buttonActions)],
      },
      ...extra,
    };

List<String> rows(WidgetTester tester) =>
    textsUnder(tester.renderObject(find.byType(CustomScrollView))).where((t) => t.startsWith('P')).toList();

String status(Screen s) => textsUnder(s.tree.boxOf('status')!).single;

void main() {
  testWidgets('infinite: the first page shows, the next loads near the end', (tester) async {
    final s = await show(tester, screen(pagination: {'name': 'contacts', 'pageSize': 10}),
        variables: [v('people', people(25), VariableType.list)]);
    await tester.pump();
    expect(rows(tester).first, 'P0');
    // Built items near the end of the loaded ones load the next page.
    await tester.pumpAndSettle();
    expect(s['contacts.itemCount'], greaterThanOrEqualTo(20));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(s['contacts.itemCount'], 25);
    expect(s['contacts.hasMore'], false);
    expect(rows(tester).last, 'P24');
    expect(status(s), '3/3 25');
  });

  testWidgets('pages: one page at a time, moved by paginate actions', (tester) async {
    final s = await show(
      tester,
      screen(
        pagination: {'name': 'contacts', 'pageSize': 5, 'mode': 'pages'},
        buttonActions: [
          {'type': 'paginate', 'controller': 'contacts', 'command': 'next'},
        ],
      ),
      variables: [v('people', people(12), VariableType.list)],
    );
    await tester.pumpAndSettle();
    expect(rows(tester), ['P0', 'P1', 'P2', 'P3', 'P4']);
    expect(status(s), '1/3 5');
    await tester.tapAt(s.center('button'));
    await tester.pumpAndSettle();
    expect(rows(tester), ['P5', 'P6', 'P7', 'P8', 'P9']);
    expect(s['contacts.from'], 6);
    await tester.tapAt(s.center('button'));
    await tester.pumpAndSettle();
    expect(rows(tester), ['P10', 'P11']);
    expect(s['contacts.hasMore'], false);
    expect(status(s), '3/3 2');
    // The bound data changes: the page is cut again.
    s.scope.set('people', people(11));
    await tester.pumpAndSettle();
    expect(rows(tester), ['P10']);
  });

  testWidgets('goTo, setPageSize, first and last', (tester) async {
    final s = await show(tester, screen(pagination: {'name': 'contacts', 'pageSize': 5, 'mode': 'pages'}),
        variables: [v('people', people(30), VariableType.list)]);
    await tester.pumpAndSettle();
    Future<void> run(Json action) async {
      final node = Node.fromJson({'type': 'box', 'actions': [reaction('click', [action])]}, id: 'x')!;
      await const CodelesslyActions().run(node, 'click', s.context);
      await tester.pumpAndSettle();
    }

    await run({'type': 'paginate', 'controller': 'contacts', 'command': 'goTo', 'page': '4'});
    expect(rows(tester).first, 'P15');
    await run({'type': 'paginate', 'controller': 'contacts', 'command': 'setPageSize', 'pageSize': '10'});
    // The first item shown stays on screen.
    expect(s['contacts.page'], 2);
    expect(rows(tester).first, 'P10');
    await run({'type': 'paginate', 'controller': 'contacts', 'command': 'last'});
    expect(rows(tester).first, 'P20');
    await run({'type': 'paginate', 'controller': '\${"con" + "tacts"}', 'command': 'first'});
    expect(rows(tester).first, 'P0');
  });
}
