// O4 (Formsmith v2): a list template of input islands (switches, text
// fields) has its layout replaced in the same frame its view is taken out
// of the tree (another page opening over it) and put back: no assertion,
// and the islands show again afterwards.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _doc(int rules, {String label = 'Rule'}) => LayoutDocument.fromJson({
      'roots': ['col'],
      'nodes': {
        'col': {'type': 'column', 'children': ['list'], 'layout': {'width': 400, 'height': 600}},
        'list': {
          'type': 'listView',
          'children': ['row'],
          'layout': {'width': 400, 'height': 600},
          'props': {'itemCount': rules},
        },
        'row': {'type': 'row', 'children': ['on', 'say'], 'layout': {'width': 400, 'height': 48}},
        'on': {'type': 'switch', 'layout': {'width': 32, 'height': 18}, 'props': {'value': true, 'trackRadius': 4}},
        'say': {
          'type': 'textField',
          'layout': {'width': 300, 'height': 34},
          'props': {'initialValue': label},
        },
      },
    });

void main() {
  for (final interactive in [false, true])
  testWidgets('islands in a list survive a layout replaced as their view leaves and returns (interactive: $interactive)',
      (tester) async {
    final source = DocumentSource(_doc(5));
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    final key = GlobalKey();
    Widget app(bool shown, {bool moved = false}) => MaterialApp(
          home: Scaffold(
            body: shown
                ? (moved
                    ? Padding(padding: const EdgeInsets.all(8), child: NodeView(key: key, tree: tree, rootId: 'col', interactive: interactive))
                    : NodeView(key: key, tree: tree, rootId: 'col', interactive: interactive))
                : const Text('another page'),
          ),
        );
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.byType(Switch).evaluate().length + find.byType(CustomPaint).evaluate().length, greaterThan(0));

    for (var round = 0; round < 4; round++) {
      // Replace the layout and take the view away in the same frame.
      source.document = _doc(5 - round % 2, label: 'Rule $round');
      await tester.pumpWidget(app(false));
      // Back, under another parent (reparented by its key), with a new layout.
      source.document = _doc(4 + round % 2, label: 'Again $round');
      await tester.pumpWidget(app(true, moved: round.isOdd));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Again 3'), findsWidgets);
  });
}
