// A one-line text field with a fixed height (a 50 px search box in a stack,
// the save sheet's name field in a column) is that tall in a running app.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> field() => {
      'type': 'textField',
      'layout': {'width': {'fill': 300}, 'height': 50},
      'props': {
        'textAlignVertical': 'center',
        'decoration': {
          'hintText': 'Search', 'filled': true, 'fillColor': '#FFF6F4EF', 'isDense': true, 'contentPadding': [14, 0, 14, 0],
          'enabledBorder': {'type': 'outline', 'borderSide': {'color': '#00000000', 'width': 2}, 'borderRadius': 12},
        },
      },
    };

void main() {
  for (final parent in ['stack', 'column']) {
    testWidgets('a 50 px field in a $parent is 50 px tall', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['p'],
        'nodes': {
          'p': {
            'type': parent, 'children': ['f'],
            'layout': {'width': 300, 'height': parent == 'stack' ? 50 : {'hug': 50}},
            if (parent == 'column') 'props': {'crossAxisAlignment': 'stretch'},
          },
          'f': field(),
        },
      });
      final tree = NodeTree(NodeValues(DocumentSource(doc)));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'p', interactive: true)),
      ));
      await tester.pump();
      expect(tester.getSize(find.byType(TextField)).height, 50);
    });
  }
}
