import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A Stack that hugs its content: a child placed outside its edge on purpose
// hangs out (a bubble's tail, a reaction pill), and a child that fills it
// is as big as its content (a fill under a hug is circular: it was 0).

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'schema': 3, 'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

const _text = {'fontSize': 16.0, 'color': '#FF000000'};

void main() {
  group('a negative place in a Stack', () {
    testWidgets('holds in a Stack that hugs: x=-5 and {"end": -12} hang out of it', (tester) async {
      final (tree, view) = await _show(tester, {
        's': {
          'type': 'stack',
          'children': ['bubble', 'tail', 'pill'],
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'clipBehavior': 'none'},
        },
        'bubble': {'type': 'box', 'layout': {'width': 120, 'height': 80}},
        'tail': {'type': 'box', 'layout': {'width': 18, 'height': 16, 'x': -5, 'y': {'end': -7}}},
        'pill': {'type': 'box', 'layout': {'width': 40, 'height': 24, 'x': {'end': 8}, 'y': {'end': -12}}},
      }, 's');
      expect(tree.boxOf('s')!.rectIn(view)!, const Rect.fromLTWH(0, 0, 120, 80));
      expect(tree.boxOf('tail')!.rectIn(view)!, const Rect.fromLTWH(-5, 80 + 7 - 16, 18, 16));
      expect(tree.boxOf('pill')!.rectIn(view)!, const Rect.fromLTWH(120 - 8 - 40, 80 + 12 - 24, 40, 24));
    });

    testWidgets('holds in a Stack of a fixed size, as before', (tester) async {
      final (tree, view) = await _show(tester, {
        's': {'type': 'stack', 'children': ['a', 'b'], 'layout': {'width': 200, 'height': 100}},
        'a': {'type': 'box', 'layout': {'width': 20, 'height': 20, 'x': -10, 'y': -10}},
        'b': {'type': 'box', 'layout': {'width': 30, 'height': 24, 'x': {'end': -15}, 'y': {'end': -12}}},
      }, 's');
      expect(tree.boxOf('a')!.rectIn(view)!, const Rect.fromLTWH(-10, -10, 20, 20));
      expect(tree.boxOf('b')!.rectIn(view)!, const Rect.fromLTWH(185, 88, 30, 24));
    });

    testWidgets('a child placed further in than a hugging Stack is big is still kept inside it', (tester) async {
      final (tree, view) = await _show(tester, {
        's': {'type': 'stack', 'children': ['big', 'far'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}},
        'big': {'type': 'box', 'layout': {'width': 100, 'height': 50}},
        'far': {'type': 'box', 'layout': {'width': 20, 'height': 20, 'x': 300, 'y': 300}},
      }, 's');
      expect(tree.boxOf('far')!.rectIn(view)!, const Rect.fromLTWH(80, 30, 20, 20));
    });
  });

  group('a fill under a Stack that hugs', () {
    testWidgets('in a Row: the Stack and the Column in it are as wide as the text (it was 0)', (tester) async {
      final (tree, view) = await _show(tester, {
        'row': {'type': 'row', 'children': ['s'], 'layout': {'width': 390, 'height': {'hug': 0}}},
        's': {'type': 'stack', 'children': ['bubble', 'tail'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}},
        'bubble': {
          'type': 'column',
          'children': ['t'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'padding': 10},
        },
        't': {'type': 'text', 'layout': {'width': {'fill': 0}, 'height': {'hug': 0}}, 'props': {'text': 'Hi there', 'style': _text}},
        'tail': {'type': 'box', 'layout': {'width': 18, 'height': 16, 'x': -5, 'y': {'end': -7}}},
      }, 'row');
      final t = tree.boxOf('t')!.rectIn(view)!;
      final bubble = tree.boxOf('bubble')!.rectIn(view)!;
      // One line, as wide as the words, the bubble its padding around them.
      expect(t.height, lessThan(30));
      expect(t.width, greaterThan(40));
      expect(bubble.width, closeTo(t.width + 20, 0.5));
      expect(tree.boxOf('s')!.rectIn(view)!.width, closeTo(bubble.width, 0.5));
    });

    testWidgets('a long text wraps at the room the Row has, not one word a line', (tester) async {
      final (tree, view) = await _show(tester, {
        'row': {'type': 'row', 'children': ['s'], 'layout': {'width': 200, 'height': {'hug': 0}}},
        's': {'type': 'stack', 'children': ['bubble'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'squeezable': true}},
        'bubble': {'type': 'column', 'children': ['t'], 'layout': {'width': {'fill': 0}, 'height': {'hug': 0}}},
        't': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': 'A message long enough to need more than one line here', 'style': _text},
        },
      }, 'row');
      final t = tree.boxOf('t')!.rectIn(view)!;
      expect(t.width, lessThanOrEqualTo(200));
      expect(t.width, greaterThan(150));
      expect(t.height, lessThan(100));
    });

    testWidgets('a fill with a design number keeps it, and a fill beside a sized child takes its size', (tester) async {
      final (tree, view) = await _show(tester, {
        's': {'type': 'stack', 'children': ['img', 'scrim'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}},
        'img': {'type': 'box', 'layout': {'width': 160, 'height': 90}},
        'scrim': {'type': 'box', 'layout': {'width': {'fill': 0}, 'height': {'fill': 0}}},
      }, 's');
      expect(tree.boxOf('scrim')!.rectIn(view)!, const Rect.fromLTWH(0, 0, 160, 90));
    });
  });

  group('a flex child\'s minWidth', () {
    Map<String, Object?> rule() => {
          'type': 'box',
          'layout': {
            'width': {'fill': 0},
            'height': 1,
            'flex': 1,
            'constraints': {'minWidth': 48},
          },
        };

    testWidgets('is kept beside a long text that gives way (a dashed rule each side of a status line)', (tester) async {
      final (tree, view) = await _show(tester, {
        'row': {'type': 'row', 'children': ['l', 't', 'r'], 'layout': {'width': 390, 'height': {'hug': 0}, 'padding': [16, 8, 16, 8]}, 'props': {'spacing': 16}},
        'l': rule(),
        't': {
          'type': 'text',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'squeezable': true},
          'props': {'text': 'This channel was closed because your trial ended. Restart therapy to continue.', 'style': _text},
        },
        'r': rule(),
      }, 'row');
      expect(tree.boxOf('l')!.rectIn(view)!.width, closeTo(48, 0.5));
      expect(tree.boxOf('r')!.rectIn(view)!.width, closeTo(48, 0.5));
      expect(tree.boxOf('t')!.rectIn(view)!.width, closeTo(390 - 32 - 32 - 96, 0.5));
    });

    testWidgets('changes nothing where there is room: the rules share what the text leaves', (tester) async {
      final (tree, view) = await _show(tester, {
        'row': {'type': 'row', 'children': ['l', 't', 'r'], 'layout': {'width': 390, 'height': {'hug': 0}}},
        'l': rule(),
        't': {'type': 'text', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'squeezable': true}, 'props': {'text': 'Short', 'style': _text}},
        'r': rule(),
      }, 'row');
      final t = tree.boxOf('t')!.rectIn(view)!.width;
      expect(tree.boxOf('l')!.rectIn(view)!.width, closeTo((390 - t) / 2, 0.5));
    });
  });
}
