// A text field with a fixed height fills it on every platform: on desktop
// and the web Flutter's default density is compact, which took 8px off a
// dense decorator's box (a 34px field drew a 26-29px box).
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a 34px dense field draws a 34px box', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['c'],
      'nodes': {
        'c': {'type': 'column', 'children': ['f'], 'layout': {'width': 300, 'height': {'hug': 40}, 'padding': 10}},
        'f': {
          'type': 'textField',
          'layout': {'width': {'fill': 100}, 'height': 34},
          'props': {
            'initialValue': 'a = 0.5', 'maxLines': 1,
            'decoration': {
              'isDense': true, 'filled': true, 'fillColor': '#FFFFFFFF', 'contentPadding': [8, 8, 8, 8],
              'enabledBorder': {'type': 'outline', 'borderRadius': 0, 'borderSide': {'color': '#FF000000', 'width': 1}},
            },
          },
        },
      },
    });
    final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: VariableScope(const [])));
    addTearDown(tree.dispose);
    expect(ThemeData().visualDensity, VisualDensity.compact);
    await tester.pumpWidget(MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
        child: RepaintBoundary(key: const Key('shot'), child: NodeView(tree: tree, rootId: 'c'))))));
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    final rows = <int>[];
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      for (var y = 0; y < image.height; y++) {
        final i = (y * image.width + 200) * 4;
        if (bytes[i] < 40 && bytes[i + 3] > 200) rows.add(y);
      }
    });
    // The outline's top and bottom: 34 rows apart, from 10 (the padding).
    expect(rows, [10, 43]);
  });
}
