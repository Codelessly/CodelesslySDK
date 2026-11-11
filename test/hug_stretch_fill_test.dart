// A row that hugs its height and stretches its children: children that fill
// the height take the row's height, which its other children (or, when every
// child fills, the children's own content) set, as Flutter's
// `IntrinsicHeight(child: Row(crossAxisAlignment: stretch, ...))` does. The
// same across for a column that hugs its width.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, Rect>> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, {String root = 'r'}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: root)),
  ));
  expect(tester.takeException(), isNull);
  final view = tester.renderObject(find.byType(NodeView));
  return {for (final id in nodes.keys) id: tree.boxOf(id)!.rectIn(view)!};
}

Map<String, Object?> _fill(String axis, double design, [Map<String, Object?> extra = const {}]) => {
      'type': 'box',
      'layout': {
        if (axis == 'height') ...{'width': 40, 'height': {'fill': design}} else ...{'height': 40, 'width': {'fill': design}},
      },
      'decoration': {'fills': [{'id': 'p', 'color': '#FF000000'}]},
      ...extra,
    };

Map<String, Object?> _text(String text, {required bool row}) => {
      'type': 'text',
      'layout': row ? {'width': 60, 'height': {'fill': 0}} : {'height': 30, 'width': {'fill': 0}},
      'props': {'text': text, 'style': {'fontSize': 10}},
    };

void main() {
  testWidgets('fill-height children of a hugging stretch row take the tallest other child', (tester) async {
    final r = await _show(tester, {
      'r': {
        'type': 'row',
        'children': ['a', 'b', 'tall'],
        'layout': {'width': 300, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      'a': _fill('height', 0),
      'b': _fill('height', 0),
      'tall': {'type': 'box', 'layout': {'width': 40, 'height': 70}},
    });
    expect(r['r']!.height, 70);
    expect(r['a']!.height, 70);
    expect(r['b']!.height, 70);
  });

  testWidgets('a hugging stretch row of only fill-height children takes their content height', (tester) async {
    final r = await _show(tester, {
      'r': {
        'type': 'row',
        'children': ['t1', 't2', 'line'],
        'layout': {'width': 300, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      't1': _text('One', row: true),
      't2': _text('One two three four five six seven eight', row: true),
      'line': _fill('height', 0),
    });
    // Like IntrinsicHeight: as tall as the tallest content.
    expect(r['t2']!.height, greaterThan(20));
    expect(r['r']!.height, r['t2']!.height);
    expect(r['t1']!.height, r['r']!.height);
    expect(r['line']!.height, r['r']!.height);
  });

  testWidgets('a fill-height column in a hugging stretch row takes its content height', (tester) async {
    final r = await _show(tester, {
      'r': {
        'type': 'row',
        'children': ['c', 'line'],
        'layout': {'width': 300, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      'c': {
        'type': 'column',
        'children': ['x', 'y'],
        'layout': {'width': 100, 'height': {'fill': 0}},
      },
      'x': {'type': 'box', 'layout': {'width': 40, 'height': 30}},
      'y': {'type': 'box', 'layout': {'width': 40, 'height': 25}},
      'line': _fill('height', 0),
    });
    expect(r['r']!.height, 55);
    expect(r['c']!.height, 55);
    expect(r['line']!.height, 55);
  });

  testWidgets('a hugging stretch row of only fill-height children follows their content', (tester) async {
    Map<String, Map<String, Object?>> nodes(double y) => {
          'r': {
            'type': 'row',
            'children': ['c', 'line'],
            'layout': {'width': 300, 'height': {'hug': 0}},
            'props': {'crossAxisAlignment': 'stretch'},
          },
          'c': {
            'type': 'column',
            'children': ['x', 'y'],
            'layout': {'width': 100, 'height': {'fill': 0}},
          },
          'x': {'type': 'box', 'layout': {'width': 40, 'height': 30}},
          'y': {'type': 'box', 'layout': {'width': 40, 'height': y}},
          'line': _fill('height', 0),
        };
    final source = DocumentSource(LayoutDocument.fromJson({'roots': ['r'], 'nodes': nodes(25)}));
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r')),
    ));
    final view = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('r')!.rectIn(view)!.height, 55);
    for (final y in [60.0, 5.0]) {
      source.document = LayoutDocument.fromJson({'roots': ['r'], 'nodes': nodes(y)});
      await tester.pump();
      expect(tree.boxOf('r')!.rectIn(view)!.height, 30 + y);
      expect(tree.boxOf('line')!.rectIn(view)!.height, 30 + y);
    }
  });

  testWidgets('fill-width children of a hugging stretch column take the widest other child', (tester) async {
    final r = await _show(tester, {
      'r': {
        'type': 'column',
        'children': ['a', 'wide'],
        'layout': {'height': 300, 'width': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      'a': _fill('width', 0),
      'wide': {'type': 'box', 'layout': {'width': 90, 'height': 40}},
    });
    expect(r['r']!.width, 90);
    expect(r['a']!.width, 90);
  });

  testWidgets('a hugging stretch column of only fill-width children takes their content width', (tester) async {
    final r = await _show(tester, {
      'r': {
        'type': 'column',
        'children': ['t', 'line'],
        'layout': {'height': 300, 'width': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      't': {
        'type': 'text',
        'layout': {'height': 30, 'width': {'fill': 0}},
        'props': {'text': 'Hello world', 'style': {'fontSize': 10}},
      },
      'line': _fill('width', 0),
    });
    expect(r['r']!.width, greaterThan(30));
    expect(r['t']!.width, r['r']!.width);
    expect(r['line']!.width, r['r']!.width);
  });
}
