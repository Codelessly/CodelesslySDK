import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// A row/column that hugs its cross axis and stretches its children
// (RenderHugCross) relays out when a stretched child's content changes:
// incremental relayout gives what a fresh render gives.

Map<String, Map<String, Object?>> _nodes({required bool tall, double b = 30}) => {
      'r': {
        'type': 'row',
        'children': ['c', 'side'],
        'layout': {'width': 300, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'stretch'},
      },
      // Fills the row's main axis and is stretched across it: tight both
      // ways in the stretch pass.
      'c': {
        'type': 'column',
        'children': [if (tall) 'a', 'b'],
        'layout': {'width': {'fill': 100}, 'height': {'hug': 0}},
      },
      'a': {'type': 'box', 'layout': {'width': 40, 'height': 100}},
      'b': {'type': 'box', 'layout': {'width': 40, 'height': b}},
      'side': {'type': 'box', 'layout': {'width': 50, 'height': {'fill': 10}}},
    };

LayoutDocument _doc({required bool tall, double b = 30}) =>
    LayoutDocument.fromJson({'roots': ['r'], 'nodes': _nodes(tall: tall, b: b)});

Future<Map<String, Rect>> _rects(WidgetTester tester, NodeTree tree) async {
  final view = tester.renderObject(find.byType(NodeView));
  return {for (final id in ['r', 'c', 'b', 'side']) id: tree.boxOf(id)!.rectIn(view)!};
}

Future<NodeTree> _show(WidgetTester tester, DocumentSource source) async {
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 'r')),
  ));
  return tree;
}

// A row that hugs its height and stretches its children: children that fill
// the height take the row's height, which its other children (or, when every
// child fills, the children's own content) set, as Flutter's
// `IntrinsicHeight(child: Row(crossAxisAlignment: stretch, ...))` does. The
// same across for a column that hugs its width.

Future<Map<String, Rect>> _rectsOf(WidgetTester tester, Map<String, Map<String, Object?>> nodes, {String root = 'r'}) async {
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

Map<String, Map<String, Object?>> _card(String type, {Object height = const {'fill': 100}, List<String> extra = const []}) => {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': 400},
        'children': ['card'],
      },
      'card': {
        'type': type,
        'props': {'crossAxisAlignment': 'stretch'},
        'layout': type == 'row'
            ? {'width': {'fill': 100}, 'height': {'hug': 40}}
            : {'width': {'hug': 40}, 'height': {'fill': 100}},
        'children': ['bar', 'body'],
      },
      'bar': {
        'type': 'box',
        'layout': type == 'row' ? {'width': 5, 'height': height} : {'width': height, 'height': 5},
      },
      'body': {
        'type': 'column',
        'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'padding': [12, 11, 12, 11]},
        'children': ['title', ...extra],
      },
      'title': {'type': 'text', 'props': {'text': 'Close'}, 'layout': {'width': 100, 'height': 20}},
      'note': {
        'type': 'text',
        'props': {'text': 'Couldn’t fill', 'maxLines': 3},
        'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'margin': [0, 8, 0, 0]},
        'bind': {'visible': r'${= missing != null}'},
      },
    };

void main() {
  group('a hugging row whose children stretch', () {
    for (final (from, to) in [(true, false), (false, true)]) {
      testWidgets('grows and shrinks with a stretched child that ${from ? 'shrinks' : 'grows'}', (tester) async {
        final fresh = await _rects(tester, await _show(tester, DocumentSource(_doc(tall: to))));

        final source = DocumentSource(_doc(tall: from));
        final tree = await _show(tester, source);
        source.document = _doc(tall: to);
        await tester.pump();
        expect(await _rects(tester, tree), fresh);
        expect(fresh['r']!.height, to ? 130 : 30);
      });
    }

    testWidgets('follows a bound text when only its words change', (tester) async {
      final vars = ValuesScope({'tip': 'One line.'});
      addTearDown(vars.dispose);
      final doc = LayoutDocument.fromJson({
        'roots': ['r'],
        'nodes': {
          'r': {
            'type': 'row',
            'children': ['bar', 'c'],
            'layout': {'width': 200, 'height': {'hug': 0}},
            'props': {'crossAxisAlignment': 'stretch'},
          },
          'bar': {'type': 'box', 'layout': {'width': 4, 'height': {'fill': 10}}},
          'c': {
            'type': 'column',
            'children': ['t'],
            'layout': {'width': {'fill': 100}, 'height': {'hug': 0}},
          },
          't': {
            'type': 'text',
            'layout': {'width': {'fill': 100}, 'height': {'hug': 12}},
            'props': {'style': {'fontSize': 14}},
            'bind': {'props.text': r'${tip}'},
          },
        },
      });
      final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: vars));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 'r')),
      ));
      final view = tester.renderObject(find.byType(NodeView));
      final before = tree.boxOf('r')!.rectIn(view)!.height;
      vars.set('tip', 'Many words now, enough to wrap onto several lines in a narrow column of text.');
      await tester.pump();
      await tester.pump();
      final row = tree.boxOf('r')!.rectIn(view)!;
      final text = tree.boxOf('t')!.rectIn(view)!;
      expect(text.height, greaterThan(before), reason: 'the text wraps');
      expect(row.height, greaterThanOrEqualTo(text.height), reason: 'the row holds it');
    });
  });

  group('fill children of a hugging parent', () {
    testWidgets('fill-height children of a hugging row are as tall as its tallest other child', (tester) async {
      final r = await _rectsOf(tester, {
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

    testWidgets('a hugging row of only fill-height children is as tall as their content', (tester) async {
      final r = await _rectsOf(tester, {
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

    testWidgets('items across a list that hugs: a column that fills a height nobody gives is as tall as its content', (tester) async {
      // What the notation writes for `each` in a Row: {"fill": 0} with no room to fill.
      final r = await _rectsOf(tester, {
        'r': {'type': 'row', 'children': ['list'], 'layout': {'width': 300, 'height': {'hug': 0}}},
        'list': {
          'type': 'listView',
          'children': ['item'],
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'scrollDirection': 'horizontal', 'scrollable': false, 'itemCount': 3, 'spacing': 8},
        },
        'item': {
          'type': 'column',
          'children': ['a', 'b'],
          'layout': {'width': {'hug': 0}, 'height': {'fill': 0}},
        },
        'a': {'type': 'box', 'layout': {'width': 30, 'height': 20}},
        'b': {'type': 'box', 'layout': {'width': 30, 'height': 25}},
      });
      // Also when the page does give the row room (here the screen's 600): the list hugs.
      expect(r['r']!.height, 45);
      expect(r['list']!.height, 45);
      expect(r['item']!.height, 45);
    });

    testWidgets('a label that grows, then a value that may be squeezed: the value keeps its size at the end of the row', (tester) async {
      // What the notation writes for `Text "Lint" grow` followed by `Text "12 s"`.
      final r = await _rectsOf(tester, {
        'r': {'type': 'row', 'children': ['label', 'value'], 'layout': {'width': 300, 'height': {'hug': 0}}},
        'label': {
          'type': 'text',
          'props': {'text': 'Lint', 'style': {'fontSize': 13, 'color': '#FF000000'}},
          'layout': {'flex': 1, 'squeezable': true, 'width': {'fill': 0}, 'height': {'hug': 0}},
        },
        'value': {
          'type': 'text',
          'props': {'text': '12 s', 'style': {'fontSize': 13, 'color': '#FF000000'}},
          'layout': {'squeezable': true, 'width': {'hug': 0}, 'height': {'hug': 0}},
        },
      });
      expect(r['value']!.right, 300);
      expect(r['value']!.width, lessThan(60));
      expect(r['label']!.width, 300 - r['value']!.width);
    });

    testWidgets('fill-width children of a hugging column are as wide as its widest other child', (tester) async {
      final r = await _rectsOf(tester, {
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

    testWidgets('a bar that fills a hugging row stretches to its siblings, not to its design size', (tester) async {
      final screen = await harness.show(tester, _card('row', extra: ['note']), variables: [harness.v('missing', null)]);
      expect(screen.tree.boxOf('note')!.collapsed, isTrue);
      expect(screen.tree.boxOf('card')!.size.height, 42);
      expect(screen.tree.boxOf('bar')!.size.height, 42);
    });

    testWidgets('a fixed bar sets the thickness of a hugging row whose children stretch', (tester) async {
      final screen = await harness.show(tester, _card('row', height: 100));
      expect(screen.tree.boxOf('card')!.size.height, 100);
    });
  });
}
