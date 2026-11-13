// A child capped across a stretching row/column (constraints.maxWidth under
// crossAxisAlignment: stretch) keeps its cap, at the start unless its
// layout.align places it: CSS `max-width` over `align-items: stretch`
// (Flutter's tight stretch would ignore the cap). Rects as CSS gives them for
// a 900 px wide `display: flex; flex-direction: column; align-items:
// stretch` with a `max-width: 530px` child.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lists/support.dart';

void main() {
  for (final (label, width, align, left) in [
    ('fill, at the start', {'fill': 900}, null, 0.0),
    ('hug-free fixed size stays capped', 800, null, 0.0),
    ('centered by its align', {'fill': 900}, [0, 0], 185.0),
    ('at the end by its align', {'fill': 900}, [1, 0], 370.0),
  ]) {
    testWidgets('a capped child of a stretching column: $label', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await show(tester, {
        'col': {'type': 'column', 'children': ['intro', 'full'], 'layout': {'width': 900, 'height': {'hug': 100}}, 'props': {'crossAxisAlignment': 'stretch'}},
        'intro': {
          'type': 'box',
          'layout': {'width': width, 'height': 40, 'constraints': {'maxWidth': 530}, 'align': ?align},
        },
        'full': {'type': 'box', 'layout': {'width': {'fill': 900}, 'height': 10}},
      });
      await tester.pumpAndSettle();
      final intro = s.tree.boxOf('intro')!;
      final content = intro.contentBox ?? intro;
      final x = content.localToGlobal(Offset.zero).dx - s.tree.boxOf('col')!.localToGlobal(Offset.zero).dx;
      expect((x, content.size.width), (left, 530.0));
      expect(s.tree.boxOf('full')!.size.width, 900, reason: 'an uncapped child still stretches');
    });
  }
}
