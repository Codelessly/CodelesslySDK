import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A text inside a stretched child of a hugging column (a nav tab over its
/// underline): when the text's font loads after the first layout, the
/// hugging column measures again instead of keeping the fallback width.
void main() {
  testWidgets('a hugging column with stretched children follows a font that loads late', (tester) async {
    final source = DocumentSource(LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'row', 'children': ['nav'], 'layout': {'width': 800, 'height': 60},
                 'props': {'crossAxisAlignment': 'start'}},
        'nav': {'type': 'column', 'children': ['tab', 'bar'], 'layout': {'width': {'hug': 10}, 'height': {'hug': 10}},
                'props': {'crossAxisAlignment': 'stretch'}},
        'tab': {'type': 'row', 'children': ['t'], 'layout': {'width': {'hug': 10}, 'height': {'hug': 10}}},
        'bar': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': 3}},
        't': {'type': 'text', 'layout': {'width': {'hug': 10}, 'height': {'hug': 10}},
              'props': {'text': 'MOMENTS', 'style': {'fontSize': 40, 'fontFamily': 'LateSerif2'}}},
      },
    }));
    final scope = VariableScope(const []);
    final tree = NodeTree(source, binder: NodeBinder(scope: scope));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    final bytes = File('../references/tally_v2/assets/fonts/Newsreader-400.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      await (FontLoader('LateSerif2')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))))).load();
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final text = tree.boxOf('t')!.size.width;
    expect(tree.boxOf('nav')!.size.width, closeTo(text, 0.5));
    expect(tree.boxOf('bar')!.size.width, closeTo(text, 0.5));
    tree.dispose();
    scope.dispose();
  });
}
