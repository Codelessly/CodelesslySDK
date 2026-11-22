// A pane that hugs its height in a row that stretches its children is as
// tall as the row, and so are its fill and its hairline.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

void main() {
  testWidgets('a hugging pane stretched by its row paints its fill at the row\'s height', (tester) async {
    for (final bound in [false, true]) {
      final s = await harness.show(tester, {
        'col': {
          'type': 'column',
          'layout': {'width': 600, 'height': 400},
          'children': ['row'],
        },
        'row': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'flex': 1},
          'props': {'crossAxisAlignment': 'stretch'},
          'children': ['pane', 'rest'],
        },
        'pane': {
          'type': 'column',
          'layout': {'squeezable': true, 'width': bound ? 0 : 200, 'height': {'hug': 0}},
          'props': {'crossAxisAlignment': 'start'},
          'decoration': {
            'fills': [
              {'color': '#FFF8FAFC'},
            ],
            'strokes': [
              {'color': '#FFE2E8F0'},
            ],
            'strokeSides': 'right',
          },
          if (bound) 'bind': {'layout.width': r'${paneA}'},
          'children': ['inner'],
        },
        'inner': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': 60},
        },
        'rest': {
          'type': 'column',
          'layout': {'flex': 1, 'width': {'fill': 0}, 'height': {'hug': 0}},
        },
      }, variables: bound ? [harness.v('paneA', 200, VariableType.decimal)] : const []);
      await tester.pump();
      final box = s.tree.boxOf('pane')!;
      expect(box.size, const Size(200, 400), reason: 'bound: $bound');
      // Every box of the pane down to the one that holds its children is
      // the pane's height: the one that paints its fill is among them.
      final heights = <String>[];
      RenderObject? o = box;
      while (o is RenderBox && o != s.tree.boxOf('inner')) {
        heights.add('${o.runtimeType} ${o.size.height}');
        RenderObject? next;
        o.visitChildren((c) => next ??= c);
        o = next;
      }
      expect(heights.where((h) => !h.endsWith(' 400.0')), isEmpty, reason: 'bound: $bound: $heights');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
