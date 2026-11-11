import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart' as support;

Map<String, Json> pages({
  String direction = 'horizontal',
  bool reverse = false,
  int count = 4,
  int initial = 0,
  bool motion = false,
}) => {
  'col': {
    'type': 'pageView',
    'children': ['item'],
    'layout': {'width': 300, 'height': 200},
    'props': {
      'scrollDirection': direction,
      'itemCount': count,
      'initialPage': initial,
      'reverse': reverse,
      if (motion) 'pageMotion': {'rotateY': 25, 'opacity': 0.6},
    },
  },
  'item': {
    'type': 'text',
    'layout': {
      'width': {'fill': 300},
      'height': {'fill': 200},
    },
    'props': {'text': r'Page ${index} / ${pageOffset}'},
  },
};

void main() {
  testWidgets('runtime pages swipe, snap and provide per-page offset', (
    tester,
  ) async {
    final screen = await support.show(tester, pages(motion: true));
    final pager = find.byType(PageView);
    expect(pager, findsOneWidget);
    final controller = tester.widget<PageView>(pager).controller!;
    expect(controller.page, 0);
    await tester.drag(pager, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    final scope = screen.tree.binder!.scopeFor(
      screen.tree.source,
      'item',
      const ProvidedItem('page', null, 'col', 1),
    );
    expect(scope!.read('index'), 1);
    expect(scope.read('pageOffset'), closeTo(0, 0.001));
    await tester.drag(pager, const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical reversed pages honor initial page and boundaries', (
    tester,
  ) async {
    await support.show(
      tester,
      pages(direction: 'vertical', reverse: true, initial: 1, count: 2),
    );
    final pager = find.byType(PageView);
    final controller = tester.widget<PageView>(pager).controller!;
    expect(controller.page, 1);
    await tester.drag(pager, const Offset(0, -170));
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    await tester.drag(pager, const Offset(0, -170));
    await tester.pumpAndSettle();
    expect(controller.page, 0);
  });

  testWidgets('bound page changes animate and bound data supplies page items', (
    tester,
  ) async {
    final nodes = pages();
    nodes['col']!['bind'] = {
      'props.initialPage': r'${bookmark}',
      'data': r'${story}',
    };
    nodes['col']!['props'] = {
      'scrollDirection': 'horizontal',
      'animationDuration': 120,
    };
    nodes['item']!['props'] = {'text': r'${item.title}'};
    final screen = await support.show(
      tester,
      nodes,
      variables: [
        support.v('bookmark', 0, VariableType.integer),
        support.v('story', [
          {'title': 'The first page'},
          {'title': 'The second page'},
          {'title': 'The last page'},
        ], VariableType.list),
      ],
    );
    final pager = find.byType(PageView);
    final controller = tester.widget<PageView>(pager).controller!;
    screen.scope.set('bookmark', 2);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(controller.page, 2);
    expect(
      support.textsUnder(tester.renderObject(pager)),
      contains('The last page'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty page view builds no item', (tester) async {
    await support.show(tester, pages(count: 0, initial: 8));
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
