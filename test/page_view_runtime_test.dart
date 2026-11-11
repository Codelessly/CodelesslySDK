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

  Future<support.Screen> twoWay(WidgetTester tester) async {
    final nodes = pages(count: 12);
    nodes['col']!['props'] = {
      'itemCount': 12,
      'scrollDirection': 'horizontal',
      'animationDuration': 650,
      'animationCurve': 'linear',
    };
    nodes['col']!['bind'] = {'props.initialPage': r'${bookmark}'};
    nodes['col']!['actions'] = [
      support.reaction('changed', [
        {
          'type': 'setVariable',
          'variable': 'bookmark',
          'value': r'${result.index}',
        },
      ]),
    ];
    return support.show(
      tester,
      nodes,
      variables: [support.v('bookmark', 0, VariableType.integer)],
    );
  }

  testWidgets('two-way page feedback does not cancel a long navigation', (
    tester,
  ) async {
    final screen = await twoWay(tester);
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    screen.scope.set('bookmark', 11);
    await tester.pump();
    // Pump intermediate frames so every onPageChanged write rebuilds the
    // bound pager, as it does while the app animates in a browser.
    for (var frame = 0; frame < 22; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(controller.page, closeTo(11, .001));
    expect(screen.scope.read('bookmark'), 11);
  });

  testWidgets(
    'an external target can replace an in-flight two-way navigation',
    (tester) async {
      final screen = await twoWay(tester);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      screen.scope.set('bookmark', 11);
      await tester.pump();
      for (var frame = 0; frame < 7; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(controller.page, greaterThan(3));
      screen.scope.set('bookmark', 2);
      await tester.pump();
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(controller.page, closeTo(2, .001));
      expect(screen.scope.read('bookmark'), 2);
    },
  );

  testWidgets(
    'a shorter data set keeps the requested page despite clamp feedback',
    (tester) async {
      final nodes = pages(count: 12, initial: 11);
      nodes['col']!['props'] = {
        'initialPage': 11,
        'scrollDirection': 'horizontal',
        'animationDuration': 650,
        'animationCurve': 'linear',
      };
      nodes['col']!['bind'] = {
        'props.initialPage': r'${bookmark}',
        'data': r'${story}',
      };
      nodes['col']!['actions'] = [
        support.reaction('changed', [
          {
            'type': 'setVariable',
            'variable': 'bookmark',
            'value': r'${result.index}',
          },
        ]),
      ];
      final screen = await support.show(
        tester,
        nodes,
        variables: [
          support.v('bookmark', 11, VariableType.integer),
          support.v(
            'story',
            List.generate(12, (index) => index),
            VariableType.list,
          ),
        ],
      );
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      expect(controller.page, 11);
      screen.scope.set('story', [0, 1, 2, 3]);
      screen.scope.set('bookmark', 0);
      await tester.pump();
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(controller.page, closeTo(0, .001));
      expect(screen.scope.read('bookmark'), 0);
    },
  );

  testWidgets('empty page view builds no item', (tester) async {
    await support.show(tester, pages(count: 0, initial: 8));
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
