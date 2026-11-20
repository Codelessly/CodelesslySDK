// A node cut to a shape of its own (clipPath, clipCuts) draws its border along
// the shape (the clip's border painter). A bound border colour that changes
// takes the fast colour-only repaint: the border along the shape follows it,
// by its pixels, both ways.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final shape in const [
    {'clipPath': 'M0 0 H1 V1 H0 Z'},
    {
      'clipCuts': [
        {'center': 'centerLeft', 'radius': 12},
      ],
    },
  ]) {
    testWidgets('a bound border colour on a node cut to ${shape.keys.single} repaints along the shape', (tester) async {
      final scope = VariableScope([Variable(id: 'on', name: 'on', type: VariableType.boolean, value: true)]);
      final doc = LayoutDocument.fromJson({
        'schema': 3,
        'roots': ['t'],
        'nodes': {
          't': {
            'type': 'box',
            'layout': {'width': 200, 'height': 100},
            'decoration': {
              ...shape,
              'fills': [{'color': '#FF0000FF'}],
              'strokes': [{'color': '#FFFF0000'}],
              'strokeWidth': 4,
            },
            'bind': {'decoration.strokes[0].color': r"${= on ? '#FFFF0000' : '#FF00FF00'}"},
          },
        },
      });
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
      addTearDown(tree.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 't'))),
      ));
      await tester.pumpAndSettle();

      Future<(int, int, int)> topEdge() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final data = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          image.dispose();
          return d;
        }))!;
        final w = boundary.size.width.round();
        int at(ByteData d, int c) => d.getUint8((1 * w + 100) * 4 + c);
        return (at(data, 0), at(data, 1), at(data, 2));
      }

      expect(await topEdge(), (255, 0, 0), reason: 'the border along the shape, red');
      scope.set('on', false);
      await tester.pumpAndSettle();
      expect(await topEdge(), (0, 255, 0), reason: 'the bound colour changed: the border along the shape is green');
      scope.set('on', true);
      await tester.pumpAndSettle();
      expect(await topEdge(), (255, 0, 0), reason: 'and back');
    });
  }
}
