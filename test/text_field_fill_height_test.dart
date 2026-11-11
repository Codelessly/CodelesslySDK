// A fixed-height one-line field with nothing tall in it (no prefix icon)
// still draws its border box at its full height, not a 48 px one.
import 'package:codelessly_sdk/codelessly_sdk.dart';
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
          'layout': {'width': {'fill': 358}, 'height': 68},
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
          final decorator = tester.getSize(find.byType(InputDecorator));
          expect(decorator.height, 68);
          // The outline is drawn around the whole box: its fill reaches the
          // box's top and bottom rows.
          final image = await tester.runAsync(() => captureImage(tester.element(find.byType(InputDecorator))));
          final bytes = (await tester.runAsync(() => image!.toByteData()))!;
          int alphaAt(int x, int y) => bytes.getUint8((y * image!.width + x) * 4 + 3);
          final x = image!.width ~/ 2;
          final painted = [
            for (var y = 0; y < image.height; y++)
              if (alphaAt(x, y) > 0) y,
          ];
          expect(
            painted.first,
            lessThanOrEqualTo(2),
            reason: 'rows painted: ${painted.first}..${painted.last} of ${image.height}',
          );
          expect(painted.last, greaterThanOrEqualTo(image.height - 3));
    });
}
