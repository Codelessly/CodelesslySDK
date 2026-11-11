// A typewriter caret with a height sits where a middle-aligned WidgetSpan
// block would (Lantern's reference: a 9x18 Container, 2 px after the text,
// PlaceholderAlignment.middle), in its color as given (not faded).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/typewriter.dart' show RenderTypewriter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a caret with a height is centered like a middle-aligned span', (tester) async {
    final bytes = File('../references/lantern_v2/assets/fonts/Caveat-Regular.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      final loader = FontLoader('HandCaret')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.reset);
    const text = 'The fen-walkers called it the Light.';
    const style = TextStyle(fontFamily: 'HandCaret', fontSize: 22, height: 1.4, color: Color(0xFF000000));
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['t'],
      'nodes': {
        't': {
          'type': 'text',
          'layout': {'width': 300, 'height': {'hug': 0}},
          'props': {'text': text, 'style': {'fontSize': 22, 'fontFamily': 'HandCaret', 'height': 1.4, 'color': '#FF000000'}},
          'typewriter': {
            'charsPerSecond': 100, 'holdAtMs': 200, 'caretColor': '#FFFF0000',
            'caretWidth': 9, 'caretHeight': 18, 'caretGap': 2,
          },
        },
      },
    })));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 't', interactive: true))),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    RenderTypewriter? tw;
    void find(RenderObject o) {
      if (o is RenderTypewriter) tw ??= o;
      o.visitChildren(find);
    }

    find(tree.boxOf('t')!);
    final n = tw!.shownCharacters;
    expect(n, inInclusiveRange(12, 25));

    // Where Flutter puts an 11x18 (9 + 2 margin) middle-aligned span.
    final ref = TextPainter(
      text: TextSpan(style: style, children: [TextSpan(text: text.substring(0, n)), const WidgetSpan(alignment: ui.PlaceholderAlignment.middle, child: SizedBox())]),
      textDirection: TextDirection.ltr,
    )
      ..setPlaceholderDimensions(const [PlaceholderDimensions(size: Size(11, 18), alignment: ui.PlaceholderAlignment.middle)])
      ..layout(maxWidth: 300);
    final box = ref.inlinePlaceholderBoxes!.first;

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return d;
    }))!;
    final w = boundary.size.width.toInt(), h = boundary.size.height.toInt();
    var minX = w, minY = h, maxX = -1, maxY = -1, full = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final r = data.getUint8(i), g = data.getUint8(i + 1), a = data.getUint8(i + 3);
        if (r > 200 && g < 60 && a > 200) {
          full++;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    // ignore: avoid_print
    print('n=$n "${text.substring(0, n)}" caret ($minX,$minY)-(${maxX + 1},${maxY + 1}) span ${box.toRect()}');
    expect(full, greaterThan(7 * 16));
    expect(minX.toDouble(), closeTo(box.left + 2, 1));
    expect((maxX + 1).toDouble(), closeTo(box.right, 1));
    expect(minY.toDouble(), closeTo(box.top, 1));
    expect((maxY + 1).toDouble(), closeTo(box.bottom, 1));
    // Opaque red as given: not faded to 80%.
    final cx = (minX + maxX) ~/ 2, cy = (minY + maxY) ~/ 2;
    expect(data.getUint8((cy * w + cx) * 4 + 3), 255);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets('with caretAlignStyle, centered as a span under a paragraph in that style', (tester) async {
    final hand = File('../references/lantern_v2/assets/fonts/Caveat-Regular.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      final loader = FontLoader('HandCaret2')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(hand))));
      await loader.load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.reset);
    const text = 'The fen-walkers called it the Light.';
    const style = TextStyle(fontFamily: 'HandCaret2', fontSize: 22, height: 1.15, color: Color(0xFF000000));
    const align = TextStyle(fontSize: 40, height: 1.45);
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['t'],
      'nodes': {
        't': {
          'type': 'text',
          'layout': {'width': 300, 'height': {'hug': 0}},
          'props': {'text': text, 'style': {'fontSize': 22, 'fontFamily': 'HandCaret2', 'height': 1.15, 'color': '#FF000000'}},
          'typewriter': {
            'charsPerSecond': 100, 'holdAtMs': 200, 'caretColor': '#FFFF0000',
            'caretWidth': 9, 'caretHeight': 18, 'caretGap': 2, 'caretAlignStyle': {'fontSize': 40, 'height': 1.45},
          },
        },
      },
    })));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 't', interactive: true))),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    RenderTypewriter? tw;
    void find(RenderObject o) {
      if (o is RenderTypewriter) tw ??= o;
      o.visitChildren(find);
    }

    find(tree.boxOf('t')!);
    final n = tw!.shownCharacters;
    // The reference: the typed text and the span under a paragraph in the
    // align style.
    final ref = TextPainter(
      text: TextSpan(style: align, children: [TextSpan(text: text.substring(0, n), style: style), const WidgetSpan(alignment: ui.PlaceholderAlignment.middle, child: SizedBox())]),
      textDirection: TextDirection.ltr,
    )
      ..setPlaceholderDimensions(const [PlaceholderDimensions(size: Size(11, 18), alignment: ui.PlaceholderAlignment.middle)])
      ..layout(maxWidth: 300);
    final expectedTop = ref.inlinePlaceholderBoxes!.first.top;

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return d;
    }))!;
    final w = boundary.size.width.toInt(), h = boundary.size.height.toInt();
    var minY = h, maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (data.getUint8(i) > 200 && data.getUint8(i + 1) < 60 && data.getUint8(i + 3) > 200) {
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    // ignore: avoid_print
    print('caret rows $minY-${maxY + 1}, expected top $expectedTop');
    expect(minY.toDouble(), closeTo(expectedTop, 1));
    // (Its foot may be cut by the text's own box, as here.)
    expect((maxY + 1).toDouble(), lessThanOrEqualTo(expectedTop + 18 + 1));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
