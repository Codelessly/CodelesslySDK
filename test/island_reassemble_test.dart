import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final withIsland in [false, true]) {
    testWidgets(
      'island owner survives repeated reassembly (island: $withIsland)',
      (tester) async {
        final doc = LayoutDocument.fromJson({
          'roots': ['root'],
          'nodes': {
            'root': {
              'type': 'column',
              'layout': {'width': 200, 'height': 200},
              'children': [if (withIsland) 'field'],
            },
            if (withIsland)
              'field': {
                'type': 'textField',
                'layout': {'width': 180, 'height': 48},
              },
          },
        });
        final tree = NodeTree(DocumentSource(doc));
        addTearDown(tree.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: NodeView(tree: tree, rootId: 'root'),
          ),
        );
        for (var i = 0; i < 3; i++) {
          tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
          await tester.pumpWidget(
            MaterialApp(
              home: NodeView(tree: tree, rootId: 'root'),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
