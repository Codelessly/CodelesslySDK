import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Core row/column layout beyond what parity samples: wrapping rows, and
// what a squeezing row can take from its children.

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Future<(NodeTree, RenderObject)> show(WidgetTester tester, LayoutDocument doc, {bool interactive = false}) async {
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  group('pinned children', () {
    testWidgets('a child pinned to both edges spans between them, even when set to fill', (tester) async {
      final (tree, view) = await _show(tester, {
        's': {'type': 'stack', 'children': ['card', 'plain'], 'layout': {'width': 390, 'height': 300}},
        // Positioned(left: 12, right: 12): fill doesn't override the pins.
        'card': {'type': 'box', 'layout': {'width': {'fill': 390}, 'height': 50, 'x': {'start': 12, 'end': 12}, 'y': {'start': 12}}},
        'plain': {'type': 'box', 'layout': {'width': {'fill': 390}, 'height': 50, 'y': {'start': 100}}},
      }, 's');
      expect(tree.boxOf('card')!.rectIn(view)!, const Rect.fromLTWH(12, 12, 366, 50));
      expect(tree.boxOf('plain')!.rectIn(view)!, const Rect.fromLTWH(0, 100, 390, 50));
    });
  });

  group('a fitted stack', () {
    testWidgets('scales its content from its design size into its box', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['board'], 'layout': {'width': 400, 'height': 300}},
          'board': {
            'type': 'stack',
            'children': ['room'],
            'props': {'fit': 'contain'},
            'layout': {'width': {'fill': 480}, 'height': {'fill': 640}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}},
          },
          'room': {'type': 'box', 'layout': {'width': 96, 'height': 64, 'x': {'start': 240}, 'y': {'start': 320}}},
        },
      });
      final (tree, view) = await show(tester, doc);
      // 400 × 300 box, 480 × 640 board: scale 300 / 640, centered across.
      const k = 300 / 640;
      final left = (400 - 480 * k) / 2;
      final rect = tree.boxOf('room')!.rectIn(view)!;
      expect(rect.left, closeTo(left + 240 * k, 0.01));
      expect(rect.top, closeTo(320 * k, 0.01));
      expect(rect.width, closeTo(96 * k, 0.01));
      expect(api.StackProps.spec.props, contains(api.StackProps.fit));
    });
  });
}
