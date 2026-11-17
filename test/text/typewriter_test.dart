import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/typewriter.dart' show RenderTypewriter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument page(Map<String, Map<String, Object?>> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

Future<(NodeTree, RenderObject)> show(WidgetTester tester, LayoutDocument doc, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

void main() {

  testWidgets('a typewriter types its text out without moving the layout', (tester) async {
    Map<String, Map<String, Object?>> nodes(String text, {String key = '', bool skip = false, bool enabled = true}) => {
          't': {
            'type': 'text',
            'layout': {'width': 200},
            'props': {'text': text, 'style': {'fontSize': 14}},
            'typewriter': {'charsPerSecond': 100, 'delayMs': 50, 'playKey': key, 'skip': skip, 'enabled': enabled},
          },
        };
    RenderTypewriter tw() {
      final found = <RenderTypewriter>[];
      void visit(RenderObject o) {
        if (o is RenderTypewriter) found.add(o);
        o.visitChildren(visit);
      }

      visit(tester.renderObject(find.byType(NodeView)));
      return found.single;
    }

    // The design canvas shows it all.
    final (rest, view) = await show(tester, page(nodes('The wind owns the hilltop.')));
    expect(tw().shownCharacters, 26);
    expect(tw().typing, isFalse);
    final designRect = rest.boxOf('t')!.rectIn(view);

    final (tree, runningView) = await show(tester, page(nodes('The wind owns the hilltop.')), interactive: true);
    expect(tw().shownCharacters, 0);
    expect(tree.boxOf('t')!.rectIn(runningView), designRect);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150)); // 50 ms delay, then 10 characters
    expect(tw().shownCharacters, inInclusiveRange(9, 11));
    expect(tw().typing, isTrue);
    expect(find.byType(NodeView), paints..rect());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tw().shownCharacters, 26);
    expect(tw().typing, isFalse);

    // Appending types only the new characters.
    (tree.source as DocumentSource).document = page(nodes('The wind owns the hilltop. A cairn.'));
    await tester.pump();
    expect(tw().shownCharacters, 26);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tw().shownCharacters, 35);

    // A new key types it again; skip shows it all; disabled shows it all.
    (tree.source as DocumentSource).document = page(nodes('The wind owns the hilltop. A cairn.', key: 'b'));
    await tester.pump();
    expect(tw().shownCharacters, 0);
    (tree.source as DocumentSource).document = page(nodes('The wind owns the hilltop. A cairn.', key: 'b', skip: true));
    await tester.pump();
    expect(tw().shownCharacters, 35);
    (tree.source as DocumentSource).document = page(nodes('Other text', key: 'b', enabled: false));
    await tester.pump();
    expect(tw().shownCharacters, 10);
    expect(tw().typing, isFalse);
    expect(api.Typewriter.fromJson(nodes('x', key: 'k')['t']!['typewriter'])!.playKey, 'k');
  });

  testWidgets('a typewriter set to grow is only as tall as the lines typed so far', (tester) async {
    LayoutDocument doc({bool grow = true}) => page({
          't': {
            'type': 'text',
            'layout': {'width': 120, 'height': {'hug': 0}},
            'props': {'text': 'one two three four five six seven eight nine ten', 'style': {'fontSize': 14}},
            'typewriter': {'charsPerSecond': 100, 'grow': grow},
          },
        });
    final (designTree, designView) = await show(tester, doc());
    final full = designTree.boxOf('t')!.rectIn(designView)!.height;
    expect(full, greaterThan(40), reason: 'several lines');

    final (tree, view) = await show(tester, doc(), interactive: true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tree.boxOf('t')!.rectIn(view)!.height, 0, reason: 'nothing typed yet');
    await tester.pump(const Duration(milliseconds: 60)); // a few characters: the first line
    final oneLine = tree.boxOf('t')!.rectIn(view)!.height;
    expect(oneLine, greaterThan(10));
    expect(oneLine, lessThan(full / 2));
    await tester.pump(const Duration(seconds: 1));
    expect(tree.boxOf('t')!.rectIn(view)!.height, full, reason: 'the whole text once typed');

    // Without grow it keeps the whole size from the start.
    final (still, stillView) = await show(tester, doc(grow: false), interactive: true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(still.boxOf('t')!.rectIn(stillView)!.height, full);
  });
}
