// A styled dateTimeInput with a fixed height paints its fill and border over
// the whole height, its value centred in it, as a text field does (the
// decorator alone keeps a 48 px box).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

void main() {
  testWidgets('a 60 px styled dateTimeInput is 60 px tall, its value centred', (tester) async {
    final border = {
      'borderSide': {'color': '#FF34343C', 'width': 2},
      'borderRadius': 14,
    };
    await show(tester, {
      'col': {
        'type': 'column',
        'children': ['when'],
        'layout': {'width': 390, 'height': 200},
      },
      'when': {
        'type': 'dateTimeInput',
        'layout': {'width': {'fill': 358}, 'height': 60},
        'props': {
          'mode': 'dateTime',
          'value': '2026-11-12T13:20:00.000Z',
          'picker': 'none',
          'displayText': 'Now · 1:20 PM',
          'style': {'fontSize': 18},
          'decoration': {
            'filled': true,
            'fillColor': '#FF18181C',
            'contentPadding': [18, 0, 18, 0],
            'border': border,
            'enabledBorder': border,
          },
        },
      },
    });
    await tester.pumpAndSettle();
    final box = find.ancestor(
      of: find.byType(InputDecorator),
      matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration),
    );
    expect(tester.getSize(box.first).height, 60);
    final text = find.text('Now · 1:20 PM');
    expect(tester.getCenter(text).dy, closeTo(tester.getCenter(box.first).dy, 1.5));
  });
}
