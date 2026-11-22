// A text of one line that does not end in an ellipsis is not narrowed
// below its line while what is beside it can wrap: a row with no room took
// its share from a badge's label ("★ 4." of "★ 4.8") as from the heading
// beside it.
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

Map<String, Object?> _text(String text, {int? maxLines, String? overflow}) => {
      'type': 'text',
      'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
      'props': {'text': text, 'style': {'fontSize': 10}, 'maxLines': ?maxLines, 'overflow': ?overflow},
    };

void main() {
  testWidgets('the heading beside it wraps, the one line keeps its width', (tester) async {
    for (final (maxLines, kept) in [(1, true), (null, false)]) {
      final s = await harness.show(tester, {
        'col': {
          'type': 'row',
          'layout': {'width': 170, 'height': {'hug': 0}},
          'props': {'spacing': 8, 'crossAxisAlignment': 'start'},
          'children': ['name', 'mark'],
        },
        'name': _text('Umi Omakase Box'),
        'mark': _text('aa bb cc', maxLines: maxLines),
      });
      await tester.pump();
      tester.takeException();
      final mark = s.tree.boxOf('mark')!, name = s.tree.boxOf('name')!;
      // In the test font a letter is 10 wide: "aa bb cc" is 80, the heading 150.
      if (kept) {
        expect(mark.size.width, 80, reason: 'the one line is whole');
        expect(name.size.width, closeTo(82, 0.5));
      } else {
        // A text that may wrap gives way with the heading, as before.
        expect(mark.size.width, lessThan(80));
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
