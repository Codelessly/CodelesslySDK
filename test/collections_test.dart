// The collections group beyond what parity sees: the goldens record each
// node once (a list's first item), so the other items' placement, endless
// lists and the declarations are checked here.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('a counted list spaces its items and centers them across', (tester) async {
    final r = await _items(tester, {
      'type': 'listView',
      'layout': {
        'width': 200,
        'height': {'hug': 300},
        'padding': [0, 6, 0, 6],
      },
      'props': {'itemCount': 3, 'separator': 'space', 'spacing': 8},
    }, _box);
    expect(r[-1], const Rect.fromLTWH(10, 20, 200, 6 + 40 * 3 + 16 + 6));
    expect(r[0], const Rect.fromLTWH(60, 26, 100, 40));
    expect(r[1], const Rect.fromLTWH(60, 74, 100, 40));
    expect(r[2], const Rect.fromLTWH(60, 122, 100, 40));
    expect(r.containsKey(3), isFalse);
  });

  testWidgets('a running flexible list hugs its items within its room, then scrolls', (tester) async {
    // A column: the list (flexible), then a box that follows its last item.
    Future<(Rect list, Rect after)> layout(int count, {bool interactive = true}) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['c'],
        'nodes': {
          'c': {
            'type': 'column',
            'children': ['v', 'after'],
            'layout': {'width': 300, 'height': 400},
          },
          'v': {
            'type': 'listView',
            'children': ['it'],
            'layout': {'width': {'fill': 300}, 'height': {'flexible': 360}},
            'props': {'itemCount': count},
          },
          'it': _box,
          'after': {
            'type': 'box',
            'layout': {'width': 300, 'height': 40},
          },
        },
      });
      final tree = NodeTree(DocumentSource(doc));
      addTearDown(tree.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(300, 400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: NodeView(tree: tree, rootId: 'c', interactive: interactive), key: ValueKey('$count $interactive')),
      );
      await tester.pump();
      final root = tester.renderObject(find.byType(NodeView));
      return (tree.boxOf('v')!.rectIn(root)!, tree.boxOf('after')!.rectIn(root)!);
    }

    final (few, afterFew) = await layout(3);
    expect(few.height, 120);
    expect(afterFew.top, 120);
    // More than fits: the list takes the room left and the box stays below.
    final (many, afterMany) = await layout(20);
    expect(many.height, 360);
    expect(afterMany.top, 360);
    // A design canvas shows it at its design size, as the editor did.
    final (design, _) = await layout(3, interactive: false);
    expect(design.height, 360);
  });

  testWidgets('a reversed list starts at its end', (tester) async {
    final r = await _items(tester, {
      'type': 'listView',
      'layout': {'width': 200, 'height': 300},
      'props': {'itemCount': 2, 'reverse': true},
    }, _box);
    expect(r[0], const Rect.fromLTWH(60, 280, 100, 40));
    expect(r[1], const Rect.fromLTWH(60, 240, 100, 40));
  });

  testWidgets('negative spacing overlaps the items, each over the last', (tester) async {
    final r = await _items(
      tester,
      {
        'type': 'listView',
        'layout': {'width': 400, 'height': 40},
        'props': {'itemCount': 3, 'separator': 'space', 'spacing': -16, 'scrollDirection': 'horizontal'},
      },
      const {
        'type': 'box',
        'layout': {'width': 40, 'height': 40},
      },
    );
    expect(r[1]!.left - r[0]!.left, 24);
    expect(r[2]!.left - r[1]!.left, 24);
  });

  testWidgets('an endless list builds the items that cover its viewport', (tester) async {
    final r = await _items(
      tester,
      {
        'type': 'listView',
        'layout': {
          'width': 200,
          'height': {'fill': 100},
        },
      },
      _box,
      max: 100,
    );
    // The viewport and 250 px of cache are covered; no more is built.
    final built = r.keys.where((k) => k >= 0).length;
    expect(built, greaterThanOrEqualTo((r[-1]!.height + 250) ~/ 40));
    expect(built, lessThan(40));
    expect(r[5], Rect.fromLTWH(60, r[-1]!.top + 200, 100, 40));
  });

  testWidgets('a grid places its cells by row and column', (tester) async {
    final r = await _items(tester, {
      'type': 'gridView',
      'layout': {'width': 320, 'height': 400, 'padding': 10},
      'props': {
        'crossAxisCount': 3,
        'crossAxisSpacing': 10,
        'mainAxisSpacing': 5,
        'mainAxisExtent': 50,
        'itemCount': 5,
      },
    }, _box);
    // (300 - 20) / 3 wide cells.
    const w = 280 / 3;
    expect(r[0], const Rect.fromLTWH(20, 30, w, 50));
    expect(r[2]!.left, closeTo(20 + 2 * (w + 10), 0.01));
    expect(r[3], const Rect.fromLTWH(20, 85, w, 50));
    expect(r.containsKey(5), isFalse);
  });

  testWidgets('a page view shows the pages around its initial page', (tester) async {
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

  testWidgets('a wrapping list flows its items onto runs', (tester) async {
    final r = await _items(tester, {
      'type': 'listView',
      'layout': {
        'width': 230,
        'height': {'hug': 0},
      },
      'props': {'itemCount': 5, 'wrap': true, 'wrapSpacing': 10, 'runSpacing': 4, 'scrollDirection': 'horizontal'},
    }, _box);
    expect(r[1], const Rect.fromLTWH(120, 20, 100, 40));
    expect(r[2], const Rect.fromLTWH(10, 64, 100, 40));
    expect(r[-1], const Rect.fromLTWH(10, 20, 230, 40 * 3 + 8));
  });

  test('collection props decode with Flutter defaults and encode sparsely', () {
    final n = api.Node.fromJson({
      'type': 'listView',
      'props': {'itemCount': 3, 'separator': 'divider', 'spacing': -4, 'bogus': 1},
    })!;
    expect(n.prop(api.CollectionScrollProps.itemCount), 3);
    expect(n.prop(api.ListViewProps.separator), api.ListSeparator.divider);
    expect(n.prop(api.ListViewProps.spacing), -4);
    expect(n.prop(api.ListViewProps.scrollable), isTrue);
    expect(n.prop(api.CollectionScrollProps.clipBehavior), api.Clip.hardEdge);
    expect(n.toJson()['props'], {'itemCount': 3, 'separator': 'divider', 'spacing': -4, 'bogus': 1});
    final g = api.Node.fromJson({
      'type': 'gridView',
      'props': {'crossAxisCount': 0, 'mainAxisExtent': 'x'},
    })!;
    expect(g.prop(api.GridViewProps.crossAxisCount), 1);
    expect(g.prop(api.GridViewProps.mainAxisExtent), isNull);
  });
}
