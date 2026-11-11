// A one-line text field with a fixed height draws its border box at that
// height (a 60 px search field), whatever its padding and font.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

/// The field under a desktop app's theme (compact density).
Future<void> compact(WidgetTester tester) async {
  final view = find.byType(NodeView);
  final widget = tester.widget<NodeView>(view);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(visualDensity: VisualDensity.compact),
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: widget)),
  ));
}

void main() {
  for (final fit in ['fixed', 'fill', 'hugParent']) {
    testWidgets('a $fit-height one-line field is as tall as its box, on a desktop too', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
      final hugParent = fit == 'hugParent';
      final border = {'borderSide': {'color': '#FF34343C', 'width': 2}, 'borderRadius': 14};
      await show(
        tester,
        {
          'col': {
            'type': 'column',
            'children': [hugParent ? 'wrap' : 'field'],
            'layout': {'width': 390, 'height': 200},
          },
          'wrap': {
            'type': 'column',
            'children': ['field'],
            'layout': {'width': {'fill': 100}, 'height': {'hug': 40}, 'padding': [16, 0, 16, 0]},
            'props': {'crossAxisAlignment': 'start'},
          },
          'field': {
            'type': 'textField',
            'layout': {'width': {'fill': 358}, 'height': fit == 'fill' ? {'fill': 60} : 60, if (fit == 'fill') 'flex': 1},
            'props': {
              'style': {'fontFamily': 'Archivo', 'fontSize': 18},
              'decoration': {
                'hintText': 'Search',
                'prefixIcon': {'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'}, 'size': 26, 'color': '#FF9C9CA6'},
                'filled': true,
                'fillColor': '#FF18181C',
                'contentPadding': [18, 0, 18, 0],
                'border': border,
                'enabledBorder': border,
                'focusedBorder': border,
              },
            },
          },
        },
      );
      await compact(tester);
      await tester.pumpAndSettle();
      final decorator = tester.getSize(find.byType(InputDecorator));
      expect(decorator.height, fit == 'fill' ? 200 : 60);
      // The outline is drawn around the whole box: its fill reaches the
      // box's top and bottom rows.
      final image = await tester.runAsync(() => captureImage(tester.element(find.byType(InputDecorator))));
      final bytes = (await tester.runAsync(() => image!.toByteData()))!;
      int alphaAt(int x, int y) => bytes.getUint8((y * image!.width + x) * 4 + 3);
      final x = image!.width ~/ 2;
      final painted = [for (var y = 0; y < image.height; y++) if (alphaAt(x, y) > 0) y];
      expect(painted.first, lessThanOrEqualTo(2), reason: 'rows painted: ${painted.first}..${painted.last} of ${image.height}');
      expect(painted.last, greaterThanOrEqualTo(image.height - 3));
    });
  }
}
