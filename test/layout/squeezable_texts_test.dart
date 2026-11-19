// Texts that may be squeezed (`layout.squeezable`), side by side in a row
// that squeezes its children: each keeps its own width while they fit, and
// they give way in proportion when they do not (CSS's flex-shrink).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' show Directionality, Size, TextDirection;
import 'package:flutter_test/flutter_test.dart';

import '../controls/support.dart';

Map<String, Object?> _text(String text, double size) => {
      'type': 'text',
      'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'squeezable': true},
      'props': {'text': text, 'style': {'fontSize': size}},
    };

Map<String, Object?> _doc(Map<String, Map<String, Object?>> texts, {String align = 'spaceBetween'}) => {
      'schema': 3,
      'id': 'doc',
      'roots': ['col'],
      'nodes': {
        'col': {
          'type': 'column',
          'layout': {'width': 358, 'height': 200},
          'props': {'crossAxisAlignment': 'start'},
          'children': ['row'],
        },
        'row': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'spacing': 8, 'mainAxisAlignment': align, 'crossAxisAlignment': 'center'},
          'children': texts.keys.toList(),
        },
        ...texts,
      },
    };

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> doc) async {
  tester.view.physicalSize = const Size(358, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (tree, _) = runningTree(doc);
  addTearDown(tree.dispose);
  await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: NodeView(tree: tree, rootId: 'col')));
  await tester.pump();
  return tree;
}

void main() {
  testWidgets('two texts that fit keep their own widths (not half the row each)', (tester) async {
    final tree = await _show(tester, _doc({'title': _text('Kitchens near you', 14), 'count': _text('6 kitchens', 10)}));
    final title = tree.boxOf('title')!, count = tree.boxOf('count')!;
    // On one line: its own width, more than half the row.
    expect(title.size.width, 17 * 14);
    expect(title.size.height, lessThan(20));
    expect(title.size.width + count.size.width, lessThanOrEqualTo(358 - 8));
  });

  testWidgets('two texts that do not fit both give way, the longer more', (tester) async {
    final tree = await _show(
      tester,
      _doc({
        'long': _text('A much longer title of a card that needs to give way to the other', 13),
        'short': _text('Short label at the end of it', 13),
      }, align: 'start'),
    );
    final long = tree.boxOf('long')!, short = tree.boxOf('short')!;
    expect(long.size.width + 8 + short.size.width, lessThanOrEqualTo(358.5));
    expect(long.size.width, greaterThan(short.size.width));
  });
}
