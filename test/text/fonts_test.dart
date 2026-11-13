import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A font that loads after the first layout: hugging parents follow the
/// text's new width (no overflow, no stale design size).

void main() {
  group('a font that loads late', () {
    testWidgets('hugging rows and columns re-measure their text when its font loads', (tester) async {
      final source = DocumentSource(LayoutDocument.fromJson({
        'roots': ['root'],
        'nodes': {
          'root': {'type': 'row', 'children': ['nav'], 'layout': {'width': 800, 'height': 52}},
          'nav': {'type': 'column', 'children': ['tab', 'bar'], 'layout': {'width': {'hug': 10}, 'height': 52},
                  'props': {'crossAxisAlignment': 'stretch'}},
          'tab': {'type': 'row', 'children': ['t'], 'layout': {'width': {'hug': 10}, 'height': {'fill': 49}},
                  'props': {'crossAxisAlignment': 'center'}},
          'bar': {'type': 'box', 'layout': {'width': {'fill': 10}, 'height': 3}},
          't': {'type': 'text', 'layout': {'width': {'hug': 10}, 'height': {'hug': 10}},
                'props': {'text': 'MOMENTS', 'style': {'fontSize': 40, 'fontFamily': 'LateSerif'}}},
        },
      }));
      final scope = VariableScope(const []);
      final tree = NodeTree(source, binder: NodeBinder(scope: scope));
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
      final before = tree.boxOf('nav')!.size.width;
      final textBefore = tree.boxOf('t')!.size.width;

      final bytes = File('../references/tally_v2/assets/fonts/Newsreader-400.ttf').readAsBytesSync();
      await tester.runAsync(() async {
        final loader = FontLoader('LateSerif')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
        await loader.load();
      });
      await tester.pump();
      await tester.pump();
      final text = tree.boxOf('t')!;
      final after = tree.boxOf('nav')!.size.width;
      // ignore: avoid_print
      print('nav $before -> $after, text $textBefore -> ${text.size.width}');
      expect(text.size.width, isNot(textBefore), reason: 'the font changed the text width');
      expect(after, closeTo(text.size.width, 0.5));
      expect(tree.boxOf('tab')!.size.width, closeTo(text.size.width, 0.5));
      tree.dispose();
      scope.dispose();
    });
  });
}
