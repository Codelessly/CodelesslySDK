// A progress bar with exactFill and clipFill draws as Flutter code that
// clips a track to its rounded shape and fills an exact fraction of it.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _pixels(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: ColoredBox(color: Colors.white, child: child)))));
  late List<int> out;
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List().toList();
  });
  return out;
}

void main() {
  testWidgets('exactFill + clipFill draws as a clipped track with an exact fraction', (tester) async {
    const w = 233.0, h = 12.0;
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['n'],
      'nodes': {
        'n': {
          'type': 'progressBar',
          'layout': {'width': w, 'height': h},
          'props': {
            'value': 126, 'max': 190, 'color': '#FFFFD400', 'backgroundColor': '#FF2E2E36',
            'borderRadius': 99, 'exactFill': true, 'clipFill': true,
          },
        },
      },
    })));
    final node = await _pixels(tester, NodeView(tree: tree, rootId: 'n'));
    tree.dispose();
    final reference = await _pixels(
      tester,
      SizedBox(
        width: w,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: h,
            color: const Color(0xFF2E2E36),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: 126 / 190, child: Container(color: const Color(0xFFFFD400))),
          ),
        ),
      ),
    );
    expect(node, reference);
  });
}
