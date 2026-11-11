import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _doc({
  double width = 1440,
  double height = 900,
  double x = -525,
  double y = -28,
}) => LayoutDocument.fromJson({
  'roots': ['canvas'],
  'nodes': {
    'canvas': {
      'type': 'canvas',
      'slots': {'body': 'body'},
      'layout': {
        'width': width,
        'height': height,
        'x': {'start': x},
        'y': {'start': y},
      },
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
        'current': 'desktop',
        'variants': [
          {
            'id': 'desktop',
            'children': ['content'],
          },
        ],
      },
    },
    'content': {
      'type': 'column',
      'children': ['title'],
      'layout': {
        'width': {'fill': width},
        'height': {'fill': height},
        'padding': 36,
        'x': {'align': 0},
        'y': {'align': 0},
      },
      'props': {'crossAxisAlignment': 'start'},
    },
    'title': {
      'type': 'text',
      'layout': {'width': 200, 'height': 30},
      'props': {'text': 'Tally'},
    },
  },
});

Future<(DocumentSource, NodeTree, RenderObject)> _show(
  WidgetTester tester,
  LayoutDocument doc, {
  bool interactive = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 1200);
  addTearDown(tester.view.reset);
  final source = DocumentSource(doc);
  final tree = NodeTree(source);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(
          tree: tree,
          rootId: doc.roots.first,
          interactive: interactive,
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return (source, tree, tester.renderObject(find.byType(NodeView)));
}

void main() {
  testWidgets(
    'scrollable aligned fill desktop keeps its padding origin and viewport with tall content',
    (tester) async {
      final original = _doc();
      final content = original.nodes['content']!;
      final doc = original.copyWith(
        nodes: {
          ...original.nodes,
          'content': content.copyWith(
            props: content.props.set(ScrollProps.scrollable, true),
            children: ['title', 'tall'],
          ),
          'tall': Node.fromJson({
            'id': 'tall',
            'type': 'box',
            'layout': {'width': 200, 'height': 2000},
          })!,
        },
      );
      final (_, tree, view) = await _show(tester, doc);
      expect(
        tree.boxOf('content')!.rectIn(view),
        const Rect.fromLTWH(0, 0, 1440, 900),
      );
      expect(tree.boxOf('title')!.rectIn(view)!.topLeft, const Offset(36, 36));
      expect(tree.boxOf('tall')!.rectIn(view)!.topLeft, const Offset(36, 66));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop aligned fill content uses its runtime viewport, not a mobile fallback overhang',
    (tester) async {
      final (_, tree, view) = await _show(tester, _doc());
      expect(
        tree.boxOf('canvas')!.rectIn(view),
        const Rect.fromLTWH(0, 0, 1440, 900),
        reason: 'board placement does not apply to a runtime root',
      );
      expect(
        tree.boxOf('content')!.rectIn(view),
        const Rect.fromLTWH(0, 0, 1440, 900),
      );
      expect(tree.boxOf('title')!.rectIn(view)!.topLeft, const Offset(36, 36));
    },
  );
  testWidgets(
    'resizing a centered board canvas from mobile to desktop keeps content at the screen origin',
    (tester) async {
      final (source, tree, view) = await _show(
        tester,
        _doc(width: 390, height: 844, x: 0, y: 0),
      );
      expect(tree.boxOf('title')!.rectIn(view)!.topLeft, const Offset(36, 36));
      source.document = _doc();
      await tester.pump();
      expect(tree.boxOf('title')!.rectIn(view)!.topLeft, const Offset(36, 36));
      expect(tree.boxOf('content')!.rectIn(view)!.size, const Size(1440, 900));
      source.document = _doc(width: 834, height: 1112, x: -222, y: -134);
      await tester.pump();
      expect(tree.boxOf('title')!.rectIn(view)!.topLeft, const Offset(36, 36));
      expect(tree.boxOf('content')!.rectIn(view)!.size, const Size(834, 1112));
    },
  );
  testWidgets(
    'aligned fill children respect max constraints without using their fallback as intentional overflow',
    (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['root'],
        'nodes': {
          'root': {
            'type': 'stack',
            'children': ['child'],
            'layout': {'width': 500, 'height': 300},
          },
          'child': {
            'type': 'box',
            'layout': {
              'width': {'fill': 1440},
              'height': {'fill': 900},
              'x': {'align': 0},
              'y': {'align': 0},
              'constraints': {'maxWidth': 700, 'maxHeight': 400},
            },
          },
        },
      });
      final (_, tree, view) = await _show(tester, doc);
      expect(
        tree.boxOf('child')!.rectIn(view),
        const Rect.fromLTWH(0, 0, 500, 300),
      );
    },
  );
  testWidgets(
    'fixed oversized freeform children keep deliberate centered overhang',
    (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['root'],
        'nodes': {
          'root': {
            'type': 'stack',
            'children': ['fixed', 'offset'],
            'layout': {'width': 390, 'height': 300},
          },
          'fixed': {
            'type': 'box',
            'layout': {
              'width': 585,
              'height': 400,
              'x': {'align': 0},
              'y': {'align': 0},
            },
          },
          'offset': {
            'type': 'box',
            'layout': {
              'width': 20,
              'height': 30,
              'x': {'start': 37},
              'y': {'start': 51},
            },
          },
        },
      });
      final (_, tree, view) = await _show(tester, doc);
      expect(
        tree.boxOf('fixed')!.rectIn(view),
        const Rect.fromLTWH(-97.5, -50, 585, 400),
      );
      expect(
        tree.boxOf('offset')!.rectIn(view),
        const Rect.fromLTWH(37, 51, 20, 30),
      );
    },
  );
}
