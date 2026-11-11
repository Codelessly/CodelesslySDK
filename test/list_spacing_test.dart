// A list's `spacing` puts that much room between its items along the list,
// like a column's spacing, without also naming a separator.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Variable _v(String name, Object? value, VariableType type) =>
    Variable(id: name, name: name, type: type, value: type.coerce(value));

/// Renders [list] (holding a 40×20 box as its item) and returns the rects
/// of its first three items.
Future<List<Rect>> _items(WidgetTester tester, Map<String, Object?> list, {NodeBinder? binder}) async {
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

void main() {
  for (final scrollable in [true, false]) {
    testWidgets('a ${scrollable ? 'scrolling' : 'built-out'} vertical list spaces its items by spacing', (tester) async {
      final r = await _items(tester, {
        'layout': {'width': 40, 'height': {'hug': 300}},
        'props': {'itemCount': 3, 'spacing': 10, 'scrollable': scrollable},
      });
      expect(r[1].top - r[0].bottom, 10);
      expect(r[2].top - r[1].bottom, 10);
    });
  }

  testWidgets('a horizontal list spaces its items by spacing', (tester) async {
    final r = await _items(tester, {
      'layout': {'width': 300, 'height': 20},
      'props': {'itemCount': 3, 'spacing': 10, 'scrollDirection': 'horizontal'},
    });
    expect(r[1].left - r[0].right, 10);
    expect(r[2].left - r[1].right, 10);
  });

  testWidgets('a bound list with bound spacing spaces its items', (tester) async {
    final vars = VariableScope([
      _v('rows', ['a', 'b', 'c'], VariableType.list),
      _v('gap', 10, VariableType.integer),
    ]);
    final r = await _items(
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

    testWidgets('a grid spaces its items by its axis spacings', (tester) async {
    final r = await _items(tester, {
      'type': 'gridView',
      'layout': {'width': 90, 'height': 300},
      'props': {'itemCount': 3, 'crossAxisCount': 2, 'mainAxisSpacing': 10, 'crossAxisSpacing': 10, 'childAspectRatio': 2},
    });
    expect(r[1].left - r[0].right, 10);
    expect(r[2].top - r[0].bottom, 10);
  });
}
