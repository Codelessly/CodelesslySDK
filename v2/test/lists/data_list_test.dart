// A running list that pages, groups into sections or swipes (SDK 8.x's
// DataListView): its items over bound data, its pagination's variable,
// paginate actions, footers, pull to refresh, sections and swipe actions.
import 'dart:async';

import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
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

/// An API of [total] people, a page per call (`offset`, `limit`), that
/// can be held or made to fail.
class FakeApi implements CodelesslyServices {
  FakeApi(this.total);
  final int total;
  final List<Json> calls = [];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async {
    calls.add({'api': apiId, ...params});
    await gate?.future;
    if (fail) return {'isSuccess': false, 'statusCode': 500};
    final offset = int.parse('${params['offset']}'), limit = int.parse('${params['limit']}');
    return {
      'isSuccess': true,
      'data': {
        'results': people(total).skip(offset).take(limit).toList(),
        'count': total,
      },
    };
  }

  @override
  Future<bool> openUrl(String url) async => false;
}

Json apiPagination({String mode = 'infinite', int pageSize = 10, bool pull = false}) => {
      'name': 'contacts',
      'mode': mode,
      'source': 'api',
      'apiId': 'people',
      'pageSize': pageSize,
      'parameters': {'offset': r'${page.offset}', 'limit': r'${page.pageSize}'},
      'itemsPath': 'results',
      'totalPath': 'count',
      'pullToRefresh': pull,
    };

/// Footer nodes: loading, error and end texts.
Map<String, Json> footers() => {
      'loading': {'type': 'text', 'layout': {'width': 300, 'height': 30}, 'props': {'text': 'Loading'}},
      'error': {'type': 'text', 'layout': {'width': 300, 'height': 30}, 'props': {'text': r'Failed ${contacts.error}'}},
      'end': {'type': 'text', 'layout': {'width': 300, 'height': 30}, 'props': {'text': 'The end'}},
    };

List<String> texts(WidgetTester tester) => textsUnder(tester.renderObject(find.byType(CustomScrollView)));

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

  testWidgets('an API source: loading, end and error footers (slots), a tap on the error retries', (tester) async {
    final api = FakeApi(15)..gate = Completer();
    final s = await show(
      tester,
      screen(
        pagination: apiPagination(),
        extraList: {
          'slots': {'loading': 'loading', 'error': 'error', 'end': 'end'},
          'bind': <String, String>{},
        },
        extra: footers(),
      ),
      services: api,
    );
    await tester.pump();
    expect(texts(tester), contains('Loading'));
    expect(s['contacts.isLoading'], true);
    api.gate!.complete();
    api.gate = null;
    await tester.pumpAndSettle();
    expect(api.calls.first, {'api': 'people', 'offset': '0', 'limit': '10'});
    expect(s['contacts.totalCount'], 15);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(rows(tester).last, 'P14');
    expect(texts(tester).last, 'The end');
    expect(texts(tester), isNot(contains('Loading')));

    // A refresh that fails shows the error footer; tapping it retries.
    api.fail = true;
    await const CodelesslyActions().run(
        Node.fromJson({'type': 'box', 'actions': [reaction('click', [{'type': 'paginate', 'controller': 'contacts', 'command': 'refresh'}])]}, id: 'x')!,
        'click',
        s.context);
    await tester.pumpAndSettle();
    expect(texts(tester).last, startsWith('Failed'));
    expect(s['contacts.error'], isNotNull);
    api.fail = false;
    final scroll = tester.getRect(find.byType(CustomScrollView));
    await tester.tapAt(Offset(scroll.center.dx, scroll.bottom - 10));
    await tester.pumpAndSettle();
    expect(s['contacts.error'], isNull);
  });

  testWidgets('pull to refresh reloads the first page and runs the refresh reactions', (tester) async {
    final api = FakeApi(30);
    final s = await show(
      tester,
      screen(
        pagination: apiPagination(pull: true),
        extraList: {
          'bind': <String, String>{},
          'actions': [
            reaction('refresh', [
              {'type': 'setVariable', 'variable': 'refreshed', 'op': 'add', 'value': '1'},
            ]),
          ],
        },
      ),
      services: api,
      variables: [v('refreshed', 0, VariableType.integer)],
    );
    await tester.pumpAndSettle();
    final before = api.calls.length;
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(s['refreshed'], 1);
    expect(api.calls.length, greaterThan(before));
    expect(api.calls.skip(before).first['offset'], '0');
    expect(rows(tester).first, 'P0');
  });

  testWidgets('sections: a header per group, reading the section as item', (tester) async {
    await show(
      tester,
      screen(
        extraList: {
          'props': {
            'sections': {'groupBy': 'group'},
          },
          'slots': {'sectionHeader': 'header'},
        },
        extra: {
          'header': {
            'type': 'text',
            'layout': {'width': 300, 'height': 24},
            'props': {'text': r'#${item.key} ${item.count}'},
          },
        },
      ),
      variables: [v('people', people(5), VariableType.list)],
    );
    await tester.pumpAndSettle();
    expect(texts(tester), ['#A 3', 'P0', 'P1', 'P2', '#B 2', 'P3', 'P4']);
  });

  testWidgets('swipe actions: a swipe past the threshold runs the first action, with undo', (tester) async {
    final s = await show(
      tester,
      screen(
        extraList: {
          'props': {
            'swipeActions': {
              'endActions': [
                {'id': 'delete', 'label': 'Delete'},
              ],
              'apply': 'variable',
              'undoMs': 1000,
            },
          },
          'actions': [
            reaction('swipeAction', [
              {'type': 'setVariable', 'variable': 'last', 'value': r'${result.action} ${result.item.name} ${result.index}'},
            ]),
          ],
        },
      ),
      variables: [v('people', people(3), VariableType.list), v('last', '')],
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(s.center('row', instance: const ProvidedItem('row', null, 'list', 1)), const Offset(-250, 0));
    await tester.pumpAndSettle();
    // Gone from the list, waiting for the Undo bar.
    expect(rows(tester), ['P0', 'P2']);
    expect(find.text('Delete'), findsOneWidget);
    expect(s['last'], '');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(rows(tester), ['P0', 'P1', 'P2']);
    await tester.dragFrom(s.center('row', instance: const ProvidedItem('row', null, 'list', 1)), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(s['last'], 'delete P1 1');
    expect((s['people'] as List).length, 2);
    expect(rows(tester), ['P0', 'P2']);
  });

  testWidgets('a design canvas keeps the list at rest', (tester) async {
    await show(tester, screen(pagination: {'name': 'contacts', 'pageSize': 10}),
        variables: [v('people', people(25), VariableType.list)], interactive: false);
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
  });
}
