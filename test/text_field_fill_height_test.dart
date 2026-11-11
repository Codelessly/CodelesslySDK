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
      expect(tester.getCenter(find.byType(EditableText)).dy, closeTo(tester.getCenter(box.first).dy, 1.5));
      // The text starts where the padding says (18 px in).
      expect(tester.getTopLeft(find.byType(EditableText)).dx - tester.getTopLeft(box.first).dx, closeTo(18, 0.5));
    });

  testWidgets('its prefix icon centres in the whole height', (tester) async {
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
          'style': {'fontSize': 21},
          'decoration': {
            'hintText': 'Search',
            'prefixIcon': {
              'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'},
              'size': 26,
            },
            'prefixIconPadding': [20, 0, 8, 0],
            'contentPadding': [0, 0, 18, 0],
          },
        },
      },
    });
    await compact(tester);
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(InputDecorator));
    // The glyph sits in an Align that hugs it (its padding around).
    final icon = tester.getRect(find
        .descendant(
          of: find.byType(InputDecorator),
          matching: find.byWidgetPredicate((w) => w is Align && w.widthFactor == 1 && w.heightFactor == 1),
        )
        .first);
    expect(icon.center.dy, closeTo(box.center.dy, 1));
  });
}
