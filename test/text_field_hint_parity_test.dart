// A field's hint sits on its content's baseline, as Flutter's InputDecorator
// lays the hint and the input out on one baseline: a smaller hint style is
// lowered, not top-aligned with the line.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the hint\'s baseline is the content\'s', (tester) async {
    final bytes = File('../references/lantern_v2/assets/fonts/CourierPrime-Regular.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      final loader = FontLoader('HintMono')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 200);
    addTearDown(tester.view.reset);
    const value = TextStyle(fontFamily: 'HintMono', fontSize: 30, height: 1.35);
    const hint = TextStyle(fontFamily: 'HintMono', fontSize: 16, height: 1.35);
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'schema': 3,
      'roots': ['f'],
      'nodes': {
        'f': {
          'type': 'textField',
          'layout': {'width': 300, 'height': 60},
          'props': {
            'style': {'fontFamily': 'HintMono', 'fontSize': 30, 'color': '#FF000000', 'height': 1.35},
            'decoration': {
              'hintText': 'HHHH',
              'hintStyle': {'fontFamily': 'HintMono', 'fontSize': 16, 'color': '#FF000000', 'height': 1.35},
              'isCollapsed': true,
              'contentPadding': [0, 10, 0, 0],
              'border': {'type': 'none'},
              'enabledBorder': {'type': 'none'},
              'focusedBorder': {'type': 'none'},
            },
          },
        },
      },
    })));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'f'))),
    ));
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return d;
    }))!;
    final w = boundary.size.width.toInt(), h = boundary.size.height.toInt();
    var bottom = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (data.getUint8((y * w + x) * 4 + 3) > 128) bottom = y;
      }
    }
    double baseline(TextStyle s) {
      final p = TextPainter(text: TextSpan(text: 'H', style: s), textDirection: TextDirection.ltr)..layout();
      final b = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      p.dispose();
      return b;
    }

    // The H's foot on the content's baseline (10 below the top), not on the
    // hint's own (as if the hint were top-aligned with the line).
    final onContent = 10 + baseline(value);
    final onOwn = 10 + baseline(hint);
    // ignore: avoid_print
    print('foot row $bottom; content baseline $onContent, hint\'s own $onOwn');
    expect((bottom + 1 - onContent).abs(), lessThanOrEqualTo(1.5));
    expect((bottom + 1 - onOwn).abs(), greaterThan(5));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
