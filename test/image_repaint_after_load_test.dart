// On the web the first draw of a just-decoded image can't use its mipmaps
// (a big icon drawn small comes out aliased); an image client paints once
// more after the frame that first shows the image.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/image_fill.dart' show ImageClient;
import 'package:codelessly_sdk/src/render/paint/node_paint.dart' show RenderNodePaint;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  tearDown(() => ImageClient.repaintAfterLoad = false);

  for (final repaint in [true, false]) {
    testWidgets('repaintAfterLoad $repaint: ${repaint ? 'one more paint after the image shows' : 'none'}', (tester) async {
      ImageClient.repaintAfterLoad = repaint;
      final bytes = File('../references/lantern_v2/assets/img/lens.png').readAsBytesSync();
      final uri = 'data:image/png;base64,${base64Encode(bytes)}';
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['b'],
        'nodes': {
          'b': {
            'type': 'box',
            'layout': {'width': 32, 'height': 32},
            'decoration': {
              'fills': [
                {'type': 'image', 'image': {'url': uri, 'fit': 'contain'}},
              ],
            },
          },
        },
      })));
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'b'))));
      RenderNodePaint? painter;
      void find(RenderObject o) {
        if (o is RenderNodePaint) painter ??= o;
        o.visitChildren(find);
      }

      find(tree.boxOf('b')!);
      expect(painter, isNotNull);
      // Wait for the image to decode, then the frame that shows it.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      expect(painter!.debugNeedsPaint, repaint, reason: 'after the frame that shows it, another paint is asked for only on the web');
      await tester.pump();
      expect(painter!.debugNeedsPaint, isFalse);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    });
  }
}
