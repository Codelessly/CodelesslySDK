// A growing typewriter part-way is as tall as the typed text laid out on its
// own (how a hand-written reference shows it): no pixel more or less.
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/typewriter.dart' show RenderTypewriter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('held part-way, a growing line is as tall as its typed text alone', (tester) async {
    final bytes = File('../references/lantern_v2/assets/fonts/Caveat-Regular.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      final loader = FontLoader('HandTest')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    const text = 'GREYFEN SURVEY, VOL. IV. The hill had a light once. The fen-walkers called it the Greyfen Light: '
        'a beacon fed from deep inside the hill, by something the miners only ever called the Ember, its glow carried up a shaft.';
    const style = TextStyle(fontFamily: 'HandTest', fontSize: 22, height: 1.15);
    for (final n in [40, 120, 192]) {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['t'],
        'nodes': {
          't': {
            'type': 'text',
            'layout': {'width': 298, 'height': {'hug': 0}},
            'props': {'text': text, 'style': {'fontSize': 22, 'fontFamily': 'HandTest', 'height': 1.15}},
            'typewriter': {'charsPerSecond': 1000, 'grow': true, 'holdAtMs': n},
          },
        },
      })));
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't', interactive: true))));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      RenderTypewriter? tw;
      void find(RenderObject o) {
        if (o is RenderTypewriter) tw ??= o;
        o.visitChildren(find);
      }

      find(tree.boxOf('t')!);
      final alone = TextPainter(text: TextSpan(text: text.substring(0, tw!.shownCharacters), style: style), textDirection: TextDirection.ltr)
        ..layout(maxWidth: 298);
      // ignore: avoid_print
      print('n=${tw!.shownCharacters} grown=${tw!.size.height} alone=${alone.height}');
      expect(tw!.size.height, closeTo(alone.height, 0.5));
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    }
  });
}
