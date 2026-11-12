// A typewriter with a caret height paints its typed text as a Text.rich of
// the typed text and a middle-aligned caret span does, pixel for pixel: the
// last glyph whole (a handwriting 's' overhangs its advance; clipped to the
// typed characters' boxes its edge came out lighter).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/typewriter.dart' show RenderTypewriter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _shot(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(key: key, child: Container(color: const Color(0xFFFFFFFF), width: 300, height: 60, alignment: Alignment.topLeft, child: child)),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d;
  }))!;
  return [for (var i = 0; i < 300 * 60; i++) data.getUint8(i * 4)];
}

void main() {
  testWidgets('typed text and caret as Text.rich paints them', (tester) async {
    final bytes = File('../references/lantern_v2/assets/fonts/Caveat-Regular.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      final loader = FontLoader('HandRich')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 200);
    addTearDown(tester.view.reset);
    const text = 'the Ember, its glow carried up a shaft.';
    const style = TextStyle(fontFamily: 'HandRich', fontSize: 22, height: 1.15, color: Color(0xFF2A1C10));
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['t'],
      'nodes': {
        't': {
          'type': 'text',
          'layout': {'width': 300, 'height': {'hug': 0}},
          'props': {'text': text, 'style': {'fontSize': 22, 'fontFamily': 'HandRich', 'height': 1.15, 'color': '#FF2A1C10'}},
          'typewriter': {'charsPerSecond': 1000, 'holdAtMs': 14, 'caretColor': '#BF2A1C10', 'caretWidth': 9, 'caretHeight': 18, 'caretGap': 2},
        },
      },
    })));
    final sdk = await _shot(tester, NodeView(tree: tree, rootId: 't', interactive: true));
    RenderTypewriter? tw;
    void find(RenderObject o) {
      if (o is RenderTypewriter) tw ??= o;
      o.visitChildren(find);
    }

    find(tree.boxOf('t')!);
    final n = tw!.shownCharacters;
    expect(text[n - 1], 's');
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
    final ref = await _shot(
      tester,
      // A plain default style (no Material: not its fallback's bold).
      DefaultTextStyle(style: const TextStyle(), child: Text.rich(TextSpan(style: style, children: [
        TextSpan(text: text.substring(0, n)),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(width: 9, height: 18, margin: const EdgeInsets.only(left: 2), color: const Color(0xBF2A1C10)),
        ),
      ]))),
    );
    var worst = 0;
    for (var i = 0; i < sdk.length; i++) {
      final d = (sdk[i] - ref[i]).abs();
      if (d > worst) worst = d;
    }
    expect(worst, lessThanOrEqualTo(1));
  });
}
