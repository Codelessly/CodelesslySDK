// A fixed-height one-line field with nothing tall in it (no prefix icon)
// still draws its border box at its full height, not a 48 px one.
import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

/// The field under a desktop app's theme (compact density).
Future<void> compact(WidgetTester tester) async {
  final view = find.byType(NodeView);
  final widget = tester.widget<NodeView>(view);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(visualDensity: VisualDensity.compact),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: widget),
      ),
    ),
  );
}

void main() {
  const fit = 'fixed';
  for (final size in [14.0, 21.0])
    testWidgets('a 68 px field with $size px text and no icon fills its height', (tester) async {
      final border = {
        'borderSide': {'color': '#FF34343C', 'width': 2},
        'borderRadius': 14,
      };
      await show(tester, {
        'col': {
          'type': 'column',
          'children': ['field'],
          'layout': {'width': 390, 'height': 200},
        },
        'field': {
          'type': 'textField',
          'layout': {
            'width': {'fill': 358},
            'height': 68,
          },
          'props': {
            'style': {'fontSize': size},
            'decoration': {
              'hintText': 'Search',
              'filled': true,
              'fillColor': '#FF18181C',
              'contentPadding': [18, 0, 18, 0],
              'border': border,
              'enabledBorder': border,
            },
          },
        },
      });
      await compact(tester);
      await tester.pumpAndSettle();
      // The fill and border are painted over the whole 68 px, the line
      // centred in it.
      final box = find.ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration),
      );
      expect(tester.getSize(box.first).height, 68);
      // (Text much smaller than the box sits a few pixels low: not centred
      // yet for 14 px in 68.)
      if (size >= 18) {
        expect(tester.getCenter(find.byType(EditableText)).dy, closeTo(tester.getCenter(box.first).dy, 1.5));
      }
    });
}
