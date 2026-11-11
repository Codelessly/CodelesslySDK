// A running list that pages, groups into sections or swipes
// (DataListView): its items over bound data, its pagination's variable,
// paginate actions, footers, pull to refresh, sections and swipe actions.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
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
  testWidgets('ordinary bound lists scroll without pagination or sections', (tester) async {
    await show(tester, screen(), variables: [Variable(name:'people',type:VariableType.list,value:people(30))]);
    final view=find.byType(CustomScrollView);
    expect(view, findsOneWidget);
    final state=tester.state<ScrollableState>(find.descendant(of:view,matching:find.byType(Scrollable)));
    expect(state.position.maxScrollExtent,greaterThan(0));
    await tester.drag(view,const Offset(0,-240));
    await tester.pumpAndSettle();
    expect(state.position.pixels,greaterThan(0));
  });

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

  for (final how in ['pullToRefresh', 'a refresh reaction alone']) {
    testWidgets('a list without pagination pulls to refresh: $how', (tester) async {
      final s = await show(
        tester,
        screen(
          extraList: {
            'props': {if (how == 'pullToRefresh') 'pullToRefresh': true},
            'actions': [
              reaction('refresh', [
                {'type': 'setVariable', 'variable': 'refreshed', 'op': 'add', 'value': '1'},
              ]),
            ],
          },
        ),
        variables: [v('people', people(5), VariableType.list), v('refreshed', 0, VariableType.integer)],
      );
      await tester.pumpAndSettle();
      expect(rows(tester), hasLength(5));
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(s['refreshed'], 1);
    });
  }

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

  testWidgets('two-way loading keeps the rows on screen in place', (tester) async {
    final api = FakeApi(200);
    final s = await show(
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(rows(tester), contains('P78'));
  });

  testWidgets('sections: the index bar jumps to a section', (tester) async {
    final contacts = [
      for (final letter in ['A', 'B', 'C', 'D'])
        for (var i = 0; i < 10; i++) {'id': '$letter$i', 'name': 'P$letter$i', 'group': letter},
    ];
    final s = await show(
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
      variables: [v('people', contacts, VariableType.list)],
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
    expect(header.localToGlobal(Offset.zero).dy, tester.getTopLeft(find.byType(CustomScrollView)).dy);
  });

  testWidgets('index bar: its own keys, muted absent ones, and a jump that pages a data list in', (tester) async {
    final contacts = [
      for (final letter in ['A', 'C', 'E'])
        for (var i = 0; i < 40; i++) {'id': '$letter$i', 'name': 'P$letter$i', 'group': letter},
    ];
    await show(
      tester,
      screen(
        pagination: {'name': 'contacts', 'pageSize': 10},
        extraList: {
          'props': {
            'sections': {
              'groupBy': 'group',
              'indexBar': true,
              'indexKeys': ['A', 'B', 'C', 'D', 'E'],
              'indexStyle': {'fontSize': 13, 'color': '#FFF7F5F0'},
              'indexMutedColor': '#FF63636D',
              'indexWidth': 30,
              'indexBubble': true,
            },
          },
          'slots': {'sectionHeader': 'header'},
        },
        extra: {
          'header': {'type': 'text', 'layout': {'width': 300, 'height': 30}, 'props': {'text': r'#${item.key}'}},
        },
      ),
      variables: [v('people', contacts, VariableType.list)],
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<SectionIndexBar>(find.byType(SectionIndexBar));
    expect(bar.keys, ['A', 'B', 'C', 'D', 'E']);
    expect(bar.present, {'A', 'C', 'E'});
    expect(bar.width, 30);
    Color colorOf(String key) => tester.widget<Text>(find.descendant(of: find.byType(SectionIndexBar), matching: find.text(key))).style!.color!;
    expect(colorOf('B'), const Color(0xFF63636D));
    expect(colorOf('C'), const Color(0xFFF7F5F0));
    // E starts at item 80, pages away.
    final state = tester.state<DataListViewState>(find.byType(DataListView));
    expect(state.controller!.items.length, lessThan(80));
    final rect = tester.getRect(find.byType(SectionIndexBar));
    final gesture = await tester.startGesture(Offset(rect.center.dx, rect.bottom - 5));
    // The tap competes with a drag along the bar: it lands after the press timeout.
    await tester.pump(const Duration(milliseconds: 150));
    // The bubble shows the touched key.
    expect(find.descendant(of: find.byType(SectionIndexBar), matching: find.text('E')), findsNWidgets(2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.controller!.items.length, greaterThan(80));
    expect(texts(tester), contains('PE0'));
    // A muted key does nothing.
    final offset = state.scrollController.offset;
    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.3));
    await tester.pumpAndSettle();
    expect(state.scrollController.offset, offset);
  });

  testWidgets('swipe actions: an action is offered per item by its when', (tester) async {
    final s = await show(
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
            reaction('swipeAction', [
              {'type': 'setVariable', 'variable': 'last', 'value': r'${result.action} ${result.item.name}'},
            ]),
          ],
        },
      ),
      variables: [
        v('people', [
          {'id': 0, 'name': 'P0', 'done': false},
          {'id': 1, 'name': 'P1', 'done': true},
        ], VariableType.list),
        v('last', ''),
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

  testWidgets('a grid with pagination pages lazily and loads near its end', (tester) async {
    final s = await show(
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
      variables: [v('photos', [for (var i = 0; i < 1000; i++) {'id': i}], VariableType.list)],
    );
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    final pager = PaginationRegistry.of(s.tree)['photoPages']!;
    expect(pager.items.length, 30);
    expect(textsUnder(tester.renderObject(find.byType(CustomScrollView))).length, lessThan(40));
    // Scroll to the end of the first page's 10 rows.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(pager.items.length, 60);
  });

  testWidgets('a cloud source pages its query by cursor and reports its status', (tester) async {
    final services = Services();
    for (var i = 0; i < 12; i++) {
      await services.cloud.addDocument('people', {'name': 'P$i', 'n': i}, id: 'd${i.toString().padLeft(2, '0')}');
    }
    final s = await show(
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
      variables: [v('status', '')],
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
