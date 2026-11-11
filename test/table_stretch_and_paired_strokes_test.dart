// A table's last column can stretch to the table's width (at rest and
// running); a box's stroke can rule a pair of opposite sides.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/collections_layout.dart' show RenderTableItems;
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

Map<String, Object?> table({bool stretch = true}) => {
      'roots': ['t'],
      'nodes': {
        't': {
          'type': 'tableView',
          'layout': {'width': {'fill': 100}, 'height': {'fill': 100}},
          'props': {
            'rowHeight': 30, 'headerHeight': 30, 'stretchLastColumn': stretch,
            'columns': [{'key': 'x', 'label': 'x', 'width': 80}, {'key': 'y', 'label': 'y', 'width': 100}],
          },
          'bind': {'data': r'${rows}'},
          'slots': {'cell': 'cell', 'columnHeader': 'head'},
        },
        'cell': {'type': 'text', 'props': {'text': r'${item.value}'}},
        'head': {'type': 'text', 'props': {'text': r'${item.label}'}},
      },
    };

Future<NodeTree> show(WidgetTester tester, Map<String, Object?> doc, {required bool interactive}) async {
  final scope = VariableScope([
    Variable(name: 'rows', type: api.VariableType.list, value: [{'x': '1', 'y': '2'}]),
  ]);
  final tree = NodeTree(NodeValues(DocumentSource(LayoutDocument.fromJson(doc))), binder: NodeBinder(scope: scope));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
      child: SizedBox(width: 400, height: 200, child: NodeView(tree: tree, rootId: 't', interactive: interactive)))));
  await tester.pump();
  return tree;
}

void main() {
  testWidgets('at rest the last column takes the leftover width', (tester) async {
    await show(tester, table(), interactive: false);
    final t = tester.renderObject(find.byType(NodeView));
    RenderTableItems? items;
    void visit(RenderObject o) {
      if (o is RenderTableItems) items = o;
      o.visitChildren(visit);
    }

    visit(t);
    expect(items!.columnWidths, [80, 320]);
  });

  testWidgets('without it the columns keep their widths', (tester) async {
    final tree = await show(tester, table(stretch: false), interactive: false);
    RenderTableItems? items;
    void visit(RenderObject o) {
      if (o is RenderTableItems) items = o;
      o.visitChildren(visit);
    }

    visit(tree.boxOf('t')!);
    expect(items!.columnWidths, [80, 100]);
  });

  testWidgets('running, the last column takes the leftover width', (tester) async {
    await show(tester, table(), interactive: true);
    await tester.pumpAndSettle();
    final view = tester.widget<TableView>(find.byType(TableView));
    final delegate = view.delegate as TableCellBuilderDelegate;
    expect((delegate.buildColumn(1)!.extent as FixedTableSpanExtent).pixels, 320);
  });

  testWidgets('topBottom rules the top and bottom edges, not the sides', (tester) async {
    final doc = {
      'roots': ['b'],
      'nodes': {
        'b': {
          'type': 'box',
          'layout': {'width': 100, 'height': 40},
          'decoration': {
            'fills': [{'color': '#FFFFFFFF'}],
            'strokes': [{'color': '#FF000000'}],
            'strokeWidth': 2,
            'strokeSides': 'topBottom',
          },
        },
      },
    };
    final tree = NodeTree(NodeValues(DocumentSource(LayoutDocument.fromJson(doc))));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
        child: RepaintBoundary(key: const ValueKey('r'), child: NodeView(tree: tree, rootId: 'b', interactive: false)))));
    await tester.pump();
    late ByteData bytes;
    late int w;
    await tester.runAsync(() async {
      final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('r'))).toImage();
      w = image.width;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    int red(int x, int y) => bytes.getUint8((y * w + x) * 4);
    expect(red(50, 0), lessThan(60), reason: 'top rule');
    expect(red(50, 39), lessThan(60), reason: 'bottom rule');
    expect(red(0, 20), greaterThan(200), reason: 'no left rule');
    expect(red(99, 20), greaterThan(200), reason: 'no right rule');
  });
}
