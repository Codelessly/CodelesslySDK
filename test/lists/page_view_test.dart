import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/collections_layout.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;

// The collections group beyond what parity sees: the goldens record each
// node once (a list's first item), so the other items' placement, endless
// lists and the declarations are checked here.

/// Renders a stack holding [view] (laid out at 10, 20) with [item] as its
/// first child, and returns the rects of the items it built, by index.
Future<Map<int, Rect>> _items(
  WidgetTester tester,
  Map<String, Object?> view,
  Map<String, Object?> item, {
  Size screen = const Size(400, 600),
  int max = 50,
  int first = 0,
}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {
      's': {
        'type': 'stack',
        'children': ['v'],
        'layout': {'width': screen.width, 'height': screen.height},
      },
      'v': {
        ...view,
        'children': ['it'],
        'layout': {
          ...(view['layout'] as Map? ?? {}),
          'x': {'start': 10},
          'y': {'start': 20},
        },
      },
      'it': item,
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: NodeView(tree: tree, rootId: 's'),
    ),
  );
  await tester.pump();
  final root = tester.renderObject(find.byType(NodeView));
  final out = <int, Rect>{};
  for (var i = 0; i < max; i++) {
    for (final scope in [null, ('item', null, 'v', i)]) {
      final r = tree.boxOf('it', instance: scope)?.rectIn(root);
      if (r != null && (scope != null || i == first)) out[i] = r;
    }
  }
  out[-1] = tree.boxOf('v')!.rectIn(root)!;
  return out;
}

const _box = {
  'type': 'box',
  'layout': {'width': 100, 'height': 40},
};

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

/// The render objects of type [T] under [root].
List<T> renderOf<T>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o as T);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

Map<String, Object?> box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

// A page view that turns like a book: the page leaving turns over about its
// left edge (`pageMotionBefore`, not mirrored) and stays over the page it
// reveals (`paintOrder: reverse`); the next page lies still beneath
// (`pageMotion: {shiftX: -1}`); past 90 degrees a `backfaceHidden` page
// isn't drawn.

const book = {
  'paintOrder': 'reverse',
  'pageMotion': {'shiftX': -1},
  'pageMotionBefore': {'shiftX': 1, 'rotateY': -100, 'originX': -1, 'perspective': 0.9, 'backfaceHidden': true},
};

Map<String, Json> turningPages() => {
      'col': {
        'type': 'pageView',
        'children': ['item'],
        'layout': {'width': 300, 'height': 200},
        'props': {'itemCount': 3, 'scrollDirection': 'horizontal', ...book},
        'actions': [],
      },
      'item': {
        'type': 'text',
        'layout': {'width': {'fill': 300}, 'height': {'fill': 200}},
        'props': {'text': r'Page ${index}'},
        'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        'actions': [
          lists.reaction('click', [
            {'type': 'setVariable', 'variable': 'tapped', 'value': r'${index}'},
          ]),
        ],
      },
    };

/// The render paragraph drawing [text].
RenderParagraph paragraph(WidgetTester tester, String text) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text) found = o;
    o.visitChildren(visit);
  }

  visit(tester.binding.renderView);
  return found!;
}

void main() {
  testWidgets('a page view shows its initial page and builds the pages beside it', (tester) async {
    final r = await _items(
      tester,
      {
        'type': 'pageView',
        'layout': {'width': 300, 'height': 100},
        'props': {'scrollDirection': 'horizontal', 'viewportFraction': 0.5, 'initialPage': 2, 'padEnds': false},
      },
      _box,
      first: 2,
    );
    expect(r.containsKey(1), isFalse);
    expect(r[2], const Rect.fromLTWH(10, 20, 150, 100));
    expect(r[3], const Rect.fromLTWH(160, 20, 150, 100));
    expect(r.containsKey(4), isFalse);
  });

  group('a running page view', () {
    testWidgets('swipes, snaps to a page and tells each page how far it is from the current one', (
      tester,
    ) async {
      final screen = await lists.show(tester, pages(motion: true));
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

    testWidgets('set vertical and reversed keeps to its initial page and its ends', (
      tester,
    ) async {
      await lists.show(
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

    testWidgets('animates to a bound page, and bound data supplies its pages', (
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
      final screen = await lists.show(
        tester,
        nodes,
        variables: [
          lists.v('bookmark', 0, VariableType.integer),
          lists.v('story', [
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
        lists.textsUnder(tester.renderObject(pager)),
        contains('The last page'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('turns pages with a mouse drag as with a touch swipe', (
      tester,
    ) async {
      await lists.show(tester, pages());
      final pager = find.byType(PageView);
      final controller = tester.widget<PageView>(pager).controller!;
      final start = tester.getCenter(pager) + const Offset(96, 0);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      for (var step = 1; step <= 20; step++) {
        await tester.pump(const Duration(milliseconds: 32));
        await gesture.moveTo(start - Offset(192 * step / 20, 0));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      await tester.drag(pager, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 0, reason: 'touch remains enabled alongside mouse');
    });

    testWidgets('builds nothing when it has no pages', (tester) async {
      await lists.show(tester, pages(count: 0, initial: 8));
      expect(find.byType(PageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('page poses', () {
    testWidgets('poses the pages beside the current one', (tester) async {
      final (_, root) = await show(tester, {
        'pv': {
          'type': 'pageView',
          'children': ['page'],
          'layout': {'width': 300, 'height': 200},
          'props': {
            'scrollDirection': 'horizontal',
            'viewportFraction': 0.5,
            'itemCount': 3,
            'padEnds': false,
            'pageMotion': {'scale': 0.5},
          },
        },
        'page': box(150, 200),
      }, 'pv');
      final view = renderOf<RenderPageItems>(root).single;
      final pages = view.children;
      expect(pages, hasLength(2));
      // The current page at rest; the next one half its size about its center.
      Rect shown(RenderBox page) => MatrixUtils.transformRect(page.getTransformTo(view), Offset.zero & page.size);
      expect(shown(pages[0]), const Rect.fromLTWH(0, 0, 150, 200));
      expect(shown(pages[1]), const Rect.fromLTWH(187.5, 50, 75, 100));
    });

  
  

    testWidgets('with pages stacked in reverse order, the turning page lies on top of the next one and takes taps', (tester) async {
      final screen = await lists.show(tester, turningPages(), variables: [lists.v('tapped', -1, api.VariableType.integer)]);
      expect(tester.renderObjectList(find.byType(Scrollable)).isNotEmpty, isTrue);
      expect(find.byType(PageView), findsNothing, reason: 'reverse paint order uses its own pager');
      final viewport = tester.renderObject<RenderBox>(find.byType(Viewport));
      final origin = viewport.localToGlobal(Offset.zero);

      // Hold a drag halfway through the first turn.
      final gesture = await tester.startGesture(origin + const Offset(280, 100));
      await tester.pump();
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Page 1 sits at the pager's left edge (it doesn't slide in).
      final page1 = paragraph(tester, 'Page 1');
      expect(page1.localToGlobal(Offset.zero).dx, closeTo(origin.dx, 0.5));
      // Page 0 is still drawn, turned about its left edge: its left edge stays.
      final page0 = paragraph(tester, 'Page 0');
      expect(page0.localToGlobal(Offset.zero).dx, closeTo(origin.dx, 0.5));
      // Its far edge has swung in (foreshortened), but not past the spine.
      final far = page0.localToGlobal(Offset(page0.size.width, 100));
      expect(far.dx, lessThan(origin.dx + 300));
      expect(far.dx, greaterThan(origin.dx));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(screen.scope.read('tapped'), -1);

      // Settled on page 1; turn back halfway and tap near the spine: the page
      // on top (page 0, turning back over) gets it.
      final back = await tester.startGesture(origin + const Offset(20, 100));
      await back.moveBy(const Offset(20, 0));
      await back.moveBy(const Offset(130, 0));
      await tester.pump();
      await back.up();
      await tester.pumpAndSettle();
      await tester.tapAt(origin + const Offset(10, 100));
      await tester.pump();
      expect(screen.scope.read('tapped'), 0);
      expect(tester.takeException(), isNull);
    });
  
  });

}
