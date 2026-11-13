import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/typewriter.dart' show RenderTypewriter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A typewriter with a caret height paints its typed text as a Text.rich of
// the typed text and a middle-aligned caret span does, pixel for pixel: the
// last glyph whole (a handwriting 's' overhangs its advance; clipped to the
// typed characters' boxes its edge came out lighter).

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
  testWidgets('typed text and its caret paint as Flutter\'s rich text does', (tester) async {
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
