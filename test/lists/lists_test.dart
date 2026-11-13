import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument, Variable, VariableType;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/collections_layout.dart';
import 'package:flutter/material.dart' hide Variable;
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

// A list's `spacing` puts that much room between its items along the list,
// like a column's spacing, without also naming a separator.

Variable _v(String name, Object? value, VariableType type) =>
    Variable(id: name, name: name, type: type, value: type.coerce(value));

/// Renders [list] (holding a 40×20 box as its item) and returns the rects
/// of its first three items.
Future<List<Rect>> _spacedItems(WidgetTester tester, Map<String, Object?> list, {NodeBinder? binder}) async {
  final tree = NodeTree(
    DocumentSource(LayoutDocument.fromJson({
      'roots': ['v'],
      'nodes': {
        'v': {'type': 'listView', ...list, 'children': ['it']},
        'it': {'type': 'box', 'layout': {'width': 40, 'height': 20}},
      },
    })),
    binder: binder,
  );
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 'v')),
  ));
  await tester.pump();
  final root = tester.renderObject(find.byType(NodeView));
  return [
    for (var i = 0; i < 3; i++)
      (tree.boxOf('it', instance: ('item', null, 'v', i)) ?? (i == 0 ? tree.boxOf('it') : null))!.rectIn(root)!,
  ];
}

// A running app's list shows no items while its data is null (a script
// still answering), not its template with `${item...}` in it.

// A list that scrolls sideways and hugs its height is as tall as its items
// (a row of filter chips), not its design size.

// A sideways list that doesn't clip (clipBehavior: none) in a padded
// scrolling column draws its overflowing items into the column's padding,
// as Flutter's ListView in a padded SingleChildScrollView does (the send
// sheet's people row: the fifth tile peeks in at the screen's edge).

class Grid extends MultiChildRenderObjectWidget {
  const Grid({super.key, required super.children, this.shortest = false});
  final bool shortest;
  @override
  RenderGridItems createRenderObject(BuildContext context) => RenderGridItems()
    ..crossAxisCount = 2
    ..masonry = true
    ..masonryShortest = shortest
    ..crossAxisSpacing = 10
    ..mainAxisSpacing = 12
    ..itemCount = 4
    ..hugMain = true;
}

void main() {
  testWidgets('a list with a fixed count spaces its items and centers them across', (tester) async {
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

  testWidgets('a list that hugs is as long as its items until it runs out of room, then scrolls', (tester) async {
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

  testWidgets('negative spacing overlaps the items, each over the one before', (tester) async {
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

  testWidgets('an endless list builds only the items that cover its view', (tester) async {
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

  testWidgets('a wrapping list flows its items onto the next line', (tester) async {
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

  group('spacing', () {
    for (final scrollable in [true, false]) {
      testWidgets('a ${scrollable ? 'scrolling' : 'built-out'} list spaces its items by its spacing', (tester) async {
        final r = await _spacedItems(tester, {
          'layout': {'width': 40, 'height': {'hug': 300}},
          'props': {'itemCount': 3, 'spacing': 10, 'scrollable': scrollable},
        });
        expect(r[1].top - r[0].bottom, 10);
        expect(r[2].top - r[1].bottom, 10);
      });
    }

    testWidgets('a bound list follows a bound spacing', (tester) async {
      final vars = VariableScope([
        _v('rows', ['a', 'b', 'c'], VariableType.list),
        _v('gap', 10, VariableType.integer),
      ]);
      final r = await _spacedItems(
        tester,
        {
          'layout': {'width': 40, 'height': 300},
          'bind': {'data': r'${rows}', 'props.spacing': r'${gap}'},
        },
        binder: NodeBinder(scope: vars),
      );
      expect(r[1].top - r[0].bottom, 10);
      expect(r[2].top - r[1].bottom, 10);
    });

      testWidgets('a grid spaces its items by its row and column spacing', (tester) async {
      final r = await _spacedItems(tester, {
        'type': 'gridView',
        'layout': {'width': 90, 'height': 300},
        'props': {'itemCount': 3, 'crossAxisCount': 2, 'mainAxisSpacing': 10, 'crossAxisSpacing': 10, 'childAspectRatio': 2},
      });
      expect(r[1].left - r[0].right, 10);
      expect(r[2].top - r[0].bottom, 10);
    });
  });

  group('missing data', () {
    for (final preview in [false, true]) {
      testWidgets('a list bound to no data shows no items in ${preview ? 'a design preview' : 'a running app'}', (tester) async {
        final doc = LayoutDocument.fromJson({
          'roots': ['list'],
          'nodes': {
            'list': {
              'type': 'listView', 'children': ['row'], 'layout': {'width': 300, 'height': 300},
              'props': {'scrollable': false}, 'bind': {'data': r'${rows}'},
            },
            'row': {'type': 'text', 'props': {'text': r'${item.name}'}, 'layout': {'width': 200, 'height': 20}},
          },
        });
        final scope = VariableScope([Variable(id: 'rows', name: 'rows', type: VariableType.list, value: null)]);
        final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope, preview: preview));
        addTearDown(tree.dispose);
        await tester.pumpWidget(MaterialApp(
          home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'list', interactive: !preview)),
        ));
        expect(tree.boxOf('row') != null, preview, reason: 'the template shows only in a design preview');
        scope.set('rows', [{'name': 'Aquarium'}, {'name': 'Ashby Park'}]);
        await tester.pump();
        expect(tree.boxOf('row'), isNotNull);
      });
    }
  });

  group('sizing', () {
    testWidgets('a sideways list that hugs its height is as tall as its tallest item', (tester) async {
      final s = await lists.show(tester, {
        'col': {'type': 'column', 'children': ['list'], 'layout': {'width': 360, 'height': 400}},
        'list': {
          'type': 'listView',
          'children': ['chip'],
          'layout': {'width': {'fill': 360}, 'height': {'hug': 10}},
          'props': {'scrollable': true, 'scrollDirection': 'horizontal', 'spacing': 8},
          'bind': {'data': r'${chips}'},
        },
        'chip': {'type': 'box', 'layout': {'width': 120, 'height': 38}},
      }, variables: [lists.v('chips', ['a', 'b', 'c', 'd'], VariableType.list)]);
      final list = s.tree.boxOf('list')!;
      expect(list.size.height, 38);
      expect(list.size.width, 360);
      // Wider than the screen: it still scrolls.
      final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(state.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('a list with clipping off draws its items past its own box', (tester) async {
      final s = await lists.show(tester, {
        'col': {
          'type': 'column',
          'children': ['tiles'],
          'layout': {'width': 300, 'height': 400, 'padding': [16, 8, 16, 8]},
          'props': {'scrollable': true},
        },
        'tiles': {
          'type': 'listView',
          'children': ['tile'],
          'layout': {'width': {'fill': 268}, 'height': 90},
          'props': {'scrollDirection': 'horizontal', 'separator': 'space', 'spacing': 8, 'clipBehavior': 'none'},
          'bind': {'data': r'${items}'},
        },
        'tile': {'type': 'box', 'layout': {'width': 80, 'height': 90}},
      }, variables: [lists.v('items', [1, 2, 3, 4, 5], VariableType.list)]);
      await tester.pumpAndSettle();
      final boxes = s.tree.boxesOf('tile').where((b) => b.attached && b.hasSize).toList()
        ..sort((a, b) => a.localToGlobal(Offset.zero).dx.compareTo(b.localToGlobal(Offset.zero).dx));
      // The fourth tile (x 280–360) overflows the list (16–284) into the padding.
      final tile = boxes[3];
      final clips = <String>[];
      RenderObject child = tile;
      for (var p = tile.parent; p != null; child = p, p = p.parent) {
        final clip = p.describeApproximatePaintClip(child);
        if (clip != null && p is RenderBox) {
          final global = MatrixUtils.transformRect(p.getTransformTo(null), clip);
          if (global.right < 300) clips.add('${p.runtimeType} ${global.right}');
        }
      }
      expect(clips, isEmpty);
    });
  });

  group('a masonry grid', () {
    testWidgets(
      'keeps each item\'s own height and fills each lane on its own',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 210,
                child: Grid(
                  children: [
                    SizedBox(height: 40),
                    SizedBox(height: 90),
                    SizedBox(height: 60),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
        final g = tester.renderObject<RenderGridItems>(find.byType(Grid));
        final list = g.children;
        expect(list.map((x) => x.size.height).toList(), [40, 90, 60, 20]);
        expect(
          (list[2].parentData as CollectionParentData).offset,
          const Offset(0, 52),
        );
        expect(
          (list[3].parentData as CollectionParentData).offset,
          const Offset(110, 102),
        );
        expect(g.size.height, 122);
      },
    );

    testWidgets('set to shortest lane puts each item in the lane that ends first', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 210,
              child: Grid(
                shortest: true,
                children: [
                  SizedBox(height: 100),
                  SizedBox(height: 20),
                  SizedBox(height: 30),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
      final g = tester.renderObject<RenderGridItems>(find.byType(Grid));
      Offset at(int i) => (g.children[i].parentData as CollectionParentData).offset;
      // Lane 1 ends at 32 after the 20, so the 30 and the 40 go there too.
      expect(at(1), const Offset(110, 0));
      expect(at(2), const Offset(110, 32));
      expect(at(3), const Offset(110, 74));
      expect(g.size.height, 114);
    });
  });
}
