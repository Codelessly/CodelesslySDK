import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;

// Runtime of the widgets area's features.

Future<(NodeTree, RenderObject)> show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root,
    {double width = 800, double height = 600}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Object?> box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

// A running list that pages, groups into sections or swipes
// (DataListView): its items over bound data, its pagination's variable,
// paginate actions, footers, pull to refresh, sections and swipe actions.

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
        ...extraList,
        'props': {'pagination': ?pagination, ...?extraList['props'] as Map?},
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
        'actions': [if (buttonActions.isNotEmpty) lists.reaction('click', buttonActions)],
      },
      ...extra,
    };

List<String> rows(WidgetTester tester) =>
    lists.textsUnder(lists.listBox(tester)).where((t) => t.startsWith('P')).toList();

String status(lists.Screen s) => lists.textsUnder(s.tree.boxOf('status')!).single;

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

List<String> texts(WidgetTester tester) => lists.textsUnder(lists.listBox(tester));

void main() {
  group('slots', () {
    testWidgets('a list with footer and section header slots still shows its items', (tester) async {
      final (tree, view) = await show(tester, {
        'l': {
          'type': 'listView',
          'children': ['item'],
          'slots': {'loading': 'more', 'sectionHeader': 'header'},
          'layout': {'width': 100, 'height': 200},
          'props': {
            'itemCount': 3,
            'pagination': {'name': 'p', 'pullToRefresh': true},
            'sections': {'groupBy': 'letter'},
            'swipeActions': {'endActions': [{'id': 'delete'}]},
            'reorder': {},
          },
        },
        'item': box(100, 40),
        'more': box(100, 20),
        'header': box(100, 20),
      }, 'l');
      expect(tree.boxOf('item')!.rectIn(view), const Rect.fromLTWH(0, 0, 100, 40));
      expect(tree.boxOf('more'), isNull);
    });
  
  });

  testWidgets('a plain bound list scrolls without paging or sections', (tester) async {
    await lists.show(tester, screen(), variables: [Variable(name:'people',type:VariableType.list,value:people(30))]);
    // Drawn by render objects alone: no sliver scroll view.
    expect(find.byType(CustomScrollView), findsNothing);
    final scroll = lists.listScroll(tester);
    expect(scroll.maxScrollExtent, greaterThan(0));
    await lists.dragList(tester, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(scroll.pixels, greaterThan(0));
  });

  testWidgets('an endless list shows its first page and loads the next near the end', (tester) async {
    final s = await lists.show(tester, screen(pagination: {'name': 'contacts', 'pageSize': 10}),
        variables: [lists.v('people', people(25), VariableType.list)]);
    await tester.pump();
    expect(rows(tester).first, 'P0');
    // Built items near the end of the loaded ones load the next page.
    await tester.pumpAndSettle();
    expect(s['contacts.itemCount'], greaterThanOrEqualTo(20));
    await lists.dragList(tester, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(s['contacts.itemCount'], 25);
    expect(s['contacts.hasMore'], false);
    expect(rows(tester).last, 'P24');
    expect(status(s), '3/3 25');
  });

  testWidgets('a paged list shows one page at a time and moves by paginate actions', (tester) async {
    final s = await lists.show(
      tester,
      screen(
        pagination: {'name': 'contacts', 'pageSize': 5, 'mode': 'pages'},
        buttonActions: [
          {'type': 'paginate', 'controller': 'contacts', 'command': 'next'},
        ],
      ),
      variables: [lists.v('people', people(12), VariableType.list)],
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

  testWidgets('paginate actions go to a page, change the page size and jump to the first and last page', (tester) async {
    final s = await lists.show(tester, screen(pagination: {'name': 'contacts', 'pageSize': 5, 'mode': 'pages'}),
        variables: [lists.v('people', people(30), VariableType.list)]);
    await tester.pumpAndSettle();
    Future<void> run(Json action) async {
      final node = Node.fromJson({'type': 'box', 'actions': [lists.reaction('click', [action])]}, id: 'x')!;
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

  testWidgets('a list loading from an API shows its loading, end and error footers, and a tap on the error retries', (tester) async {
    final api = FakeApi(15)..gate = Completer();
    final s = await lists.show(
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
    await lists.dragList(tester, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(rows(tester).last, 'P14');
    expect(texts(tester).last, 'The end');
    expect(texts(tester), isNot(contains('Loading')));

    // A refresh that fails shows the error footer; tapping it retries.
    api.fail = true;
    await const CodelesslyActions().run(
        Node.fromJson({'type': 'box', 'actions': [lists.reaction('click', [{'type': 'paginate', 'controller': 'contacts', 'command': 'refresh'}])]}, id: 'x')!,
        'click',
        s.context);
    await tester.pumpAndSettle();
    expect(texts(tester).last, startsWith('Failed'));
    expect(s['contacts.error'], isNotNull);
    api.fail = false;
    final scroll = lists.listRect(tester);
    await tester.tapAt(Offset(scroll.center.dx, scroll.bottom - 10));
    await tester.pumpAndSettle();
    expect(s['contacts.error'], isNull);
  });

  testWidgets('pulling to refresh reloads the first page and runs the refresh reactions', (tester) async {
    final api = FakeApi(30);
    final s = await lists.show(
      tester,
      screen(
        pagination: apiPagination(pull: true),
        extraList: {
          'bind': <String, String>{},
          'actions': [
            lists.reaction('refresh', [
              {'type': 'setVariable', 'variable': 'refreshed', 'op': 'add', 'value': '1'},
            ]),
          ],
        },
      ),
      services: api,
      variables: [lists.v('refreshed', 0, VariableType.integer)],
    );
    await tester.pumpAndSettle();
    final before = api.calls.length;
    await lists.flingList(tester, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(s['refreshed'], 1);
    expect(api.calls.length, greaterThan(before));
    expect(api.calls.skip(before).first['offset'], '0');
    expect(rows(tester).first, 'P0');
  });

  for (final how in ['pullToRefresh', 'a refresh reaction alone']) {
    testWidgets('a list without paging can be pulled to refresh: $how', (tester) async {
      final s = await lists.show(
        tester,
        screen(
          extraList: {
            'props': {if (how == 'pullToRefresh') 'pullToRefresh': true},
            'actions': [
              lists.reaction('refresh', [
                {'type': 'setVariable', 'variable': 'refreshed', 'op': 'add', 'value': '1'},
              ]),
            ],
          },
        ),
        variables: [lists.v('people', people(5), VariableType.list), lists.v('refreshed', 0, VariableType.integer)],
      );
      await tester.pumpAndSettle();
      expect(rows(tester), hasLength(5));
      await lists.flingList(tester, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(s['refreshed'], 1);
    });
  }

  testWidgets('a sectioned list shows a header per group', (tester) async {
    await lists.show(
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
      variables: [lists.v('people', people(5), VariableType.list)],
    );
    await tester.pumpAndSettle();
    expect(texts(tester), ['#A 3', 'P0', 'P1', 'P2', '#B 2', 'P3', 'P4']);
  });

  testWidgets('swiping an item past the threshold runs its first action, with undo', (tester) async {
    final s = await lists.show(
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
            lists.reaction('swipeAction', [
              {'type': 'setVariable', 'variable': 'last', 'value': r'${result.action} ${result.item.name} ${result.index}'},
            ]),
          ],
        },
      ),
      variables: [lists.v('people', people(3), VariableType.list), lists.v('last', '')],
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

  testWidgets('on the design canvas a data list stays at rest', (tester) async {
    await lists.show(tester, screen(pagination: {'name': 'contacts', 'pageSize': 10}),
        variables: [lists.v('people', people(25), VariableType.list)], interactive: false);
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('loading earlier items keeps the rows on screen where they are', (tester) async {
    final api = FakeApi(200);
    final s = await lists.show(
      tester,
      screen(
        pagination: {...apiPagination(pageSize: 20, mode: 'bidirectional'), 'initialPage': 5, 'thresholdItems': 0},
        extraList: {'bind': <String, String>{}},
      ),
      services: api,
    );
    await tester.pumpAndSettle();
    // The anchor page (items 80–99) shows first, at the top.
    expect(rows(tester).first, 'P80');
    Offset at(int i) => s.center('row', instance: ProvidedItem('row', null, 'list', i));
    final before = at(82).dy;
    // Load the page before it: it goes above, and row 82 doesn't move.
    await PaginationRegistry.of(s.tree)['contacts']!.loadPrevious();
    await tester.pumpAndSettle();
    expect(s['contacts.itemCount'], greaterThanOrEqualTo(40));
    expect(at(82).dy, before);
    // Scrolling up shows the earlier rows.
    await lists.dragList(tester, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(rows(tester), contains('P78'));
  });

  testWidgets('the index bar jumps to a section', (tester) async {
    final contacts = [
      for (final letter in ['A', 'B', 'C', 'D'])
        for (var i = 0; i < 10; i++) {'id': '$letter$i', 'name': 'P$letter$i', 'group': letter},
    ];
    final s = await lists.show(
      tester,
      screen(
        extraList: {
          'props': {
            'sections': {'groupBy': 'group', 'indexBar': true},
          },
          'slots': {'sectionHeader': 'header'},
        },
        extra: {
          'header': {'type': 'text', 'layout': {'width': 300, 'height': 30}, 'props': {'text': r'#${item.key}'}},
        },
      ),
      variables: [lists.v('people', contacts, VariableType.list)],
    );
    await tester.pumpAndSettle();
    expect(find.byType(SectionIndexBar), findsOneWidget);
    final state = tester.state<DataListViewState>(find.byType(DataListView));
    state.jumpToSection(2);
    await tester.pumpAndSettle();
    // Items 40 long, headers 30.
    expect(state.scrollController.offset, 2 * (30 + 400));
    expect(texts(tester), contains('PC0'));
    // Tapping D on the bar; a pinned header stays at the top.
    final bar = tester.getRect(find.byType(SectionIndexBar));
    await tester.tapAt(Offset(bar.center.dx, bar.bottom - 5));
    await tester.pumpAndSettle();
    final header = s.tree.boxOf('header', instance: const ProvidedItem('section', null, 'list', 'D'))!;
    expect(header.localToGlobal(Offset.zero).dy, lists.listRect(tester).topLeft.dy);
  });

  testWidgets('a swipe action is offered only on the items its condition allows', (tester) async {
    final s = await lists.show(
      tester,
      screen(
        extraList: {
          'props': {
            'swipeActions': {
              'radius': 18,
              'armedScale': 1.12,
              'startActions': [
                {'id': 'in', 'label': 'CHECK IN', 'when': r'${= !item.done}', 'removes': false, 'inline': true},
              ],
              'endActions': [
                {'id': 'undo', 'label': 'UNDO', 'when': r'${= item.done}', 'removes': false},
                {'id': 'open', 'label': 'OPEN', 'when': r'${= !item.done}', 'removes': false},
              ],
            },
          },
          'actions': [
            lists.reaction('swipeAction', [
              {'type': 'setVariable', 'variable': 'last', 'value': r'${result.action} ${result.item.name}'},
            ]),
          ],
        },
      ),
      variables: [
        lists.v('people', [
          {'id': 0, 'name': 'P0', 'done': false},
          {'id': 1, 'name': 'P1', 'done': true},
        ], VariableType.list),
        lists.v('last', ''),
      ],
    );
    await tester.pumpAndSettle();
    Offset row(int i) => s.center('row', instance: ProvidedItem('row', null, 'list', i));
    // Toward the start: P0 isn't done, so OPEN runs; P1 is, so UNDO.
    await tester.dragFrom(row(0), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(s['last'], 'open P0');
    await tester.dragFrom(row(1), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(s['last'], 'undo P1');
    // Toward the end: P1 is done, so nothing is offered and nothing runs.
    await tester.dragFrom(row(1), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(s['last'], 'undo P1');
    await tester.dragFrom(row(0), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(s['last'], 'in P0');
  });

  testWidgets('a grid loads its pages as it nears its end', (tester) async {
    final s = await lists.show(
      tester,
      {
        'col': {
          'type': 'column',
          'children': ['grid'],
          'layout': {'width': 300, 'height': {'hug': 400}},
        },
        'grid': {
          'type': 'gridView',
          'children': ['tile'],
          'layout': {'width': 300, 'height': 400},
          'bind': {'data': r'${photos}'},
          'props': {
            'crossAxisCount': 3,
            'mainAxisExtent': 100,
            'pagination': {'name': 'photoPages', 'pageSize': 30},
          },
        },
        'tile': {'type': 'text', 'layout': {'width': 100, 'height': 100}, 'props': {'text': r'T${item.id}'}},
      },
      variables: [lists.v('photos', [for (var i = 0; i < 1000; i++) {'id': i}], VariableType.list)],
    );
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    final pager = PaginationRegistry.of(s.tree)['photoPages']!;
    expect(pager.items.length, 30);
    expect(lists.textsUnder(lists.listBox(tester)).length, lessThan(40));
    // Scroll to the end of the first page's 10 rows.
    await lists.dragList(tester, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(pager.items.length, 60);
  });

  testWidgets('a list loading from cloud data pages its query and reports its status', (tester) async {
    final services = Services();
    for (var i = 0; i < 12; i++) {
      await services.cloud.addDocument('people', {'name': 'P$i', 'n': i}, id: 'd${i.toString().padLeft(2, '0')}');
    }
    final s = await lists.show(
      tester,
      screen(
        pagination: {'name': 'contacts', 'source': 'cloud', 'pageSize': 5, 'mode': 'pages'},
        extraList: {
          'bind': <String, String>{},
          'props': {
            'query': {
              'enabled': true,
              'collectionPath': 'people',
              'orderByFilters': [
                {'field': 'n', 'sortType': 'ascending'},
              ],
              'statusVariable': {'name': 'status'},
            },
          },
        },
      ),
      services: services,
      variables: [lists.v('status', '')],
    );
    await tester.pumpAndSettle();
    expect(rows(tester), ['P0', 'P1', 'P2', 'P3', 'P4']);
    expect(s['contacts.totalCount'], 12);
    expect(s['status'], 'loaded');
    await PaginationRegistry.of(s.tree)['contacts']!.goTo(3);
    await tester.pumpAndSettle();
    expect(rows(tester), ['P10', 'P11']);
  });
}
