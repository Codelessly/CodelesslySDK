// Texts centered in a hugging column, centered on a 390 px screen, land
// where Flutter's Column(mainAxisSize: min) puts them.
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final late in [false, true]) {
    testWidgets('centered texts in a hugging column match Flutter to the pixel${late ? ', fonts loading late' : ''}', (tester) async {
    Future<void> font(String family, String file) async {
      final bytes = File('../references/lantern_v2/assets/fonts/$file').readAsBytesSync();
      await tester.runAsync(() => (FontLoader(family)..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))))).load());
    }

    Future<void> fonts() async {
      await font('FellSC${late ? 'L' : ''}', 'IMFellEnglishSC-Regular.ttf');
      await font('FellIt${late ? 'L' : ''}', 'IMFellEnglish-Italic.ttf');
      await font('Hand${late ? 'L' : ''}', 'Caveat-Regular.ttf');
    }

    if (!late) await fonts();
    final sfx = late ? 'L' : '';
    final texts = [('Lantern', 58.0, 3.0, 'FellSC$sfx', 1.1), ('The Greyfen Survey', 20.0, 0.0, 'FellIt$sfx', 1.4), ('an adventure in seventeen rooms', 20.0, 0.0, 'Hand$sfx', 1.15)];
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['page'],
      'nodes': {
        // As the title page: a scrolling column that fills the viewport,
        // padded 20, around a full-width column of centered children.
        'page': {'type': 'column', 'layout': {'width': 390, 'height': 240, 'padding': [20, 20, 20, 20]},
                 'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center', 'scrollable': true, 'fillViewport': true},
                 'children': ['inner']},
        'inner': {'type': 'column', 'layout': {'width': {'fill': 1}, 'height': {'hug': 0}}, 'props': {'crossAxisAlignment': 'center'},
                  'children': ['words', 'wide']},
        'wide': {'type': 'box', 'layout': {'width': {'fill': 1}, 'height': 10}},
        'words': {'type': 'column', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}, 'props': {'crossAxisAlignment': 'center'},
                  'children': [for (var i = 0; i < texts.length; i++) 't$i']},
        for (var i = 0; i < texts.length; i++)
          't$i': {'type': 'text', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
                  'props': {'text': texts[i].$1, 'style': {'fontSize': texts[i].$2, 'letterSpacing': texts[i].$3, 'fontFamily': texts[i].$4, 'height': texts[i].$5,
                    if (i == 0) 'shadows': [{'type': 'dropShadow', 'color': '#99FFB54A', 'offset': [0, 0], 'blurRadius': 24}]}}},
      },
    })));
    addTearDown(tree.dispose);
    final keys = [for (var i = 0; i < texts.length; i++) GlobalKey()];
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: Column(children: [
      SizedBox(height: 250, child: NodeView(tree: tree, rootId: 'page')),
      SizedBox(width: 390, child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < texts.length; i++)
          Text(texts[i].$1, key: keys[i], style: TextStyle(fontSize: texts[i].$2, letterSpacing: texts[i].$3, fontFamily: texts[i].$4, height: texts[i].$5,
              shadows: i == 0 ? const [Shadow(color: Color(0x99FFB54A), blurRadius: 24)] : null)),
      ])),
    ]))));
    if (late) {
      await fonts();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    for (var i = 0; i < texts.length; i++) {
      final node = tree.boxOf('t$i')!.localToGlobal(Offset.zero).dx;
      final flutter = (tester.renderObject(find.byKey(keys[i])) as RenderBox).localToGlobal(Offset.zero).dx;
      expect(node, closeTo(flutter, 0.01));
    }
  });
  }
}
