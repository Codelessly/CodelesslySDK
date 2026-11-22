// A row that stretches its children and fills the height, where nothing
// bounds the height: an app's frame (a row that fills the window, its panes
// stretched) drawn alone, in a view as tall as its content. Stretching to no
// bound gave its children an infinite height ("BoxConstraints forces an
// infinite height", then "RenderBox was not laid out" from the boxes above).
// It is as tall as its tallest child, the others stretched to that, as a row
// that hugs its height is; a column that stretches across no bound likewise.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [nodes] under a canvas as tall as its content, in a view that scrolls
/// both ways: no bound on either axis.
Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, {Object width = 560}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'schema': 3,
    'roots': ['screen'],
    'nodes': {
      'screen': {
        'type': 'canvas',
        'layout': {'width': width, 'height': {'hug': 0}},
        'slots': {'body': 'col'},
      },
      ...nodes,
    },
  })));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: NodeView(tree: tree, rootId: 'screen'))),
    ),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Object?> _box(Object width, Object height) => {
      'type': 'box',
      'layout': {'width': width, 'height': height},
      'decoration': {
        'fills': [
          {'color': '#FFEEEEEE'},
        ],
      },
    };

void main() {
  testWidgets('a stretching row that fills the height of a column as tall as its content: as tall as its tallest child', (tester) async {
    final (tree, view) = await _show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'children': ['frame'],
      },
      'frame': {
        'type': 'row',
        'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
        'children': ['side', 'main'],
      },
      'side': _box(100, {'fill': 0}),
      'main': {
        'type': 'column',
        'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'flex': 1},
        'children': ['body'],
      },
      'body': _box(100, 80),
    });
    expect(tester.takeException(), isNull);
    expect(tree.boxOf('frame')!.rectIn(view)!.size, const Size(560, 80));
    expect(tree.boxOf('side')!.rectIn(view)!.height, 80);
    expect(tree.boxOf('main')!.rectIn(view)!.size, const Size(460, 80));
  });

  testWidgets('a stretching column that fills the width of a row as wide as its content: as wide as its widest child', (tester) async {
    final (tree, view) = await _show(tester, width: {'hug': 0}, {
      'col': {
        'type': 'row',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'children': ['inner'],
      },
      'inner': {
        'type': 'column',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
        'children': ['wide', 'narrow'],
      },
      'wide': _box(120, 40),
      'narrow': _box({'fill': 0}, 40),
    });
    expect(tester.takeException(), isNull);
    expect(tree.boxOf('inner')!.rectIn(view)!.width, 120);
    expect(tree.boxOf('narrow')!.rectIn(view)!.width, 120);
  });
}
