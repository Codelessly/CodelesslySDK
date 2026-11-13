// A text's padding is space inside its box, around its lines, as
// `Padding(child: Text(...))` (a Container with padding): a hugging text
// grows by it, a fixed one keeps its size with the lines inset.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> doc(Map<String, Object?> layout, {int schema = 3}) => {
      'schema': schema,
      'roots': ['frame'],
      'nodes': {
        'frame': {
          'type': 'column',
          'children': ['t', 'after'],
          'layout': {'width': 400, 'height': 400},
          'props': {'crossAxisAlignment': 'start'},
        },
        't': {
          'type': 'text',
          'layout': layout,
          'props': {
            'text': 'Hello padding',
            'style': {'fontSize': 16, 'height': 1.5, 'color': '#FF000000'},
          },
        },
        'after': {'type': 'box', 'layout': {'width': 10, 'height': 10}},
      },
    };

void main() {
  const style = TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF000000));
  const pad = EdgeInsets.fromLTRB(4, 8, 12, 26);

  Future<Rect> flutter(WidgetTester tester, {double? width, double? height}) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          key: const ValueKey('t'),
          width: width,
          height: height,
          padding: pad,
          alignment: width == null && height == null ? null : Alignment.topLeft,
          child: const Text('Hello padding', style: style),
        ),
      ),
    ));
    return tester.getRect(find.byKey(const ValueKey('t')));
  }

  Future<(Rect, Rect)> ours(WidgetTester tester, Map<String, Object?> layout, {int schema = 3}) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc(layout, schema: schema))));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
    final view = tester.renderObject(find.byType(NodeView));
    return (tree.boxOf('t')!.rectIn(view)!, tree.boxOf('after')!.rectIn(view)!);
  }

  testWidgets('a hugging text grows by its padding (the next sibling moves down by it)', (tester) async {
    final want = await flutter(tester);
    final (got, after) = await ours(tester, {'width': {'hug': 100}, 'height': {'hug': 24}, 'padding': [4, 8, 12, 26]});
    expect(got.size, want.size);
    expect(after.top, got.bottom);
  });

  testWidgets('a fixed text keeps its size, its lines inset by the padding', (tester) async {
    final want = await flutter(tester, width: 300, height: 80);
    final (got, _) = await ours(tester, {'width': 300, 'height': 80, 'padding': [4, 8, 12, 26]});
    expect(got.size, want.size);
  });

  testWidgets('a text without padding is unchanged', (tester) async {
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: Text('Hello padding', key: ValueKey('t'), style: style))));
    final want = tester.getRect(find.byKey(const ValueKey('t')));
    final (got, _) = await ours(tester, {'width': {'hug': 100}, 'height': {'hug': 24}});
    expect(got.size, want.size);
  });

  testWidgets('schema 2: a text\'s padding did nothing, and after the migration still does nothing', (tester) async {
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: Text('Hello padding', key: ValueKey('t'), style: style))));
    final want = tester.getRect(find.byKey(const ValueKey('t')));
    final (got, after) = await ours(tester, {'width': {'hug': 100}, 'height': {'hug': 24}, 'padding': [4, 8, 12, 26]}, schema: 2);
    expect(got.size, want.size);
    expect(after.top, got.bottom);
    final (fixed, _) = await ours(tester, {'width': 300, 'height': 80, 'padding': [4, 8, 12, 26]}, schema: 2);
    expect(fixed.size, const Size(300, 80));
  });
}
