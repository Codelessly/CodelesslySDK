import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a centered filling tablet variant stays inside its resized mobile-design wrapper',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(834, 1112);
      addTearDown(tester.view.reset);
      final tree = NodeTree(
        DocumentSource(
          LayoutDocument.fromJson({
            'roots': ['canvas'],
            'nodes': {
              'canvas': {
                'type': 'canvas',
                'layout': {'width': 834, 'height': 1112},
                'slots': {'body': 'body'},
              },
              'body': {
                'type': 'stack',
                'children': ['responsive'],
                'layout': {
                  'width': {'fill': 390},
                  'height': {'fill': 844},
                },
              },
              'responsive': {
                'type': 'variance',
                'layout': {
                  'width': {'fill': 390},
                  'height': {'fill': 844},
                  'x': {'start': 0, 'end': 0},
                  'y': {'start': 0, 'end': 0},
                },
                'props': {
                  'current': 'm',
                  'variants': [
                    {
                      'id': 'm',
                      'breakpoint': 'mobile',
                      'children': ['mobile'],
                    },
                    {
                      'id': 't',
                      'breakpoint': 'tablet',
                      'children': ['tablet'],
                    },
                  ],
                },
              },
              'mobile': {
                'type': 'box',
                'layout': {
                  'width': {'fill': 390},
                  'height': {'fill': 844},
                  'x': {'align': 0},
                  'y': {'align': 0},
                },
              },
              'tablet': {
                'type': 'stack',
                'children': ['retry'],
                'layout': {
                  'width': {'fill': 834},
                  'height': {'fill': 1112},
                  'x': {'align': 0},
                  'y': {'align': 0},
                  'padding': [72, 26, 72, 26],
                },
              },
              'retry': {
                'type': 'box',
                'layout': {'width': 80, 'height': 40},
              },
            },
          }),
        ),
      )..responsive = ResponsiveWidth(Breakpoints.defaults, 834);
      addTearDown(tree.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'canvas'),
        ),
      );
      final view = tester.renderObject(find.byType(NodeView));
      expect(
        tree.boxOf('responsive')!.rectIn(view),
        const Rect.fromLTWH(0, 0, 834, 1112),
      );
      expect(
        tree.boxOf('tablet')!.rectIn(view),
        const Rect.fromLTWH(0, 0, 834, 1112),
      );
      expect(
        tree.boxOf('retry')!.rectIn(view),
        const Rect.fromLTWH(72, 26, 80, 40),
      );
    },
  );

  testWidgets(
    'fixed centered decorations keep their intentional design overhang',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final tree = NodeTree(
        DocumentSource(
          LayoutDocument.fromJson({
            'roots': ['frame'],
            'nodes': {
              'frame': {
                'type': 'stack',
                'children': ['decoration'],
                'layout': {'width': 390, 'height': 844},
              },
              'decoration': {
                'type': 'box',
                'layout': {
                  'width': 834,
                  'height': 1112,
                  'x': {'align': 0},
                  'y': {'align': 0},
                },
              },
            },
          }),
        ),
      );
      addTearDown(tree.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'frame'),
        ),
      );
      final view = tester.renderObject(find.byType(NodeView));
      expect(
        tree.boxOf('decoration')!.rectIn(view),
        const Rect.fromLTWH(-222, -134, 834, 1112),
      );
    },
  );
}
