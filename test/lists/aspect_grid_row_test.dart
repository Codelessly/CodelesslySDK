// A box keeping its aspect ratio (a card's picture) sizes a grid row whose
// rows are as long as their longest item, as it does in a column.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  testWidgets('an aspect-ratio box in a shrink-wrapped grid row keeps its ratio', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['grid'], 'layout': {'width': 800, 'height': {'hug': 600}}},
      'grid': {
        'type': 'gridView', 'children': ['item'],
        'layout': {'width': {'fill': 300}, 'height': {'hug': 400}},
        'props': {'shrinkWrapRows': true, 'crossAxisCount': 4, 'physics': 'never', 'crossAxisSpacing': 18, 'mainAxisSpacing': 22},
        'bind': {'data': r'${= range(1, 6)}'},
      },
      'item': {'type': 'column', 'children': ['card', 'line'], 'layout': {'width': {'fill': 200}, 'height': {'hug': 200}}, 'props': {'crossAxisAlignment': 'stretch'}},
      'card': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'hug': 100}, 'aspectRatio': 1.6}, 'decoration': {'fills': [{'color': '#FF202125'}]}},
      'line': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': 13}},
    }, variables: []);
    await tester.pumpAndSettle();
    final card = s.tree.boxOf('card')!.size;
    expect(card.height, closeTo(card.width / 1.6, 0.5));
    expect(card.width, greaterThan(150));
    final standalone = await show(tester, {
      'col': {'type': 'column', 'children': ['card'], 'layout': {'width': 400, 'height': {'hug': 600}}, 'props': {'crossAxisAlignment': 'stretch'}},
      'card': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'hug': 100}, 'aspectRatio': 1.6}},
    }, variables: []);
    await tester.pumpAndSettle();
    expect(standalone.tree.boxOf('card')!.size, const Size(400, 250));
  });
}
