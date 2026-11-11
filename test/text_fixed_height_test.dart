// A text with a fixed height is that height, like Flutter's
// `SizedBox(height: h, child: Text(...))`: longer text doesn't grow it (or
// its parent) and the paragraph clips what doesn't fit.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = 'A long line of words that wraps onto many more lines than '
    'sixty-four pixels can hold at this size, five or more of them.';

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> text, {Map<String, Object?> col = const {}}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['c'],
    'nodes': {
      'c': {
        'type': 'column',
        'children': ['t', 'after'],
        'layout': {'width': 120, 'height': {'hug': 100}},
        'props': {'crossAxisAlignment': 'start'},
        ...col,
      },
      't': {
        'type': 'text',
        'props': {'text': _long, 'style': {'fontSize': 16}},
        ...text,
      },
      'after': {'type': 'box', 'layout': {'width': 120, 'height': 10}},
    },
  })));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 'c')),
  ));
  return tree;
}

RenderParagraph _paragraph(NodeTree tree, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

void main() {
  testWidgets('a fixed-height text keeps its height and clips its overflow', (tester) async {
    final tree = await _show(tester, {
      'layout': {'width': 120, 'height': 64},
    });
    expect(tester.takeException(), isNull);
    final root = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('t')!.rectIn(root)!.height, 64);
    expect(tree.boxOf('c')!.rectIn(root)!.height, 74);
    expect(tree.boxOf('after')!.rectIn(root)!.top, 64);
    final p = _paragraph(tree, 't');
    // Laid out to the box, so RenderParagraph clips the lines past it (its
    // overflow is clip), as Flutter's Text in a SizedBox does.
    expect(p.size.height, lessThanOrEqualTo(64));
    expect(p.getMaxIntrinsicHeight(120), greaterThan(64));
  });

  testWidgets('a fixed-height text inside a fixed column does not overflow it', (tester) async {
    final tree = await _show(
      tester,
      {
        'layout': {'width': 120, 'height': 64},
      },
      col: {
        'layout': {'width': 120, 'height': 74},
      },
    );
    expect(tester.takeException(), isNull);
    final root = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('t')!.rectIn(root)!.height, 64);
  });

  testWidgets('a fixed-height text centers short text vertically', (tester) async {
    final tree = await _show(tester, {
      'layout': {'width': 120, 'height': 64},
      'props': {'text': 'Hi', 'style': {'fontSize': 16}, 'textAlignVertical': 'center'},
    });
    final root = tester.renderObject(find.byType(NodeView));
    final box = tree.boxOf('t')!.rectIn(root)!;
    expect(box.height, 64);
    final p = _paragraph(tree, 't');
    final top = p.localToGlobal(Offset.zero, ancestor: root).dy;
    expect(top - box.top, closeTo((64 - p.size.height) / 2, 0.5));
  });

  testWidgets('a hugging text still grows with its lines', (tester) async {
    final tree = await _show(tester, {
      'layout': {'width': 120, 'height': {'hug': 20}},
    });
    final root = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('t')!.rectIn(root)!.height, greaterThan(64));
  });
}
