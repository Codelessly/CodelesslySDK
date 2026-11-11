// A date/time input styled like a text field: its value in a pattern, or a
// bound display text, and no dialog when its picker is the design's own.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

Map<String, Json> _screen(Map<String, Object?> props) => {
  'col': {
    'type': 'column',
    'children': ['dt'],
    'layout': {'width': 390, 'height': 200},
  },
  'dt': {
    'type': 'dateTimeInput',
    'layout': {
      'width': {'fill': 358},
      'height': 60,
    },
    'bind': {'props.value': r'${arrival}'},
    'props': {
      'mode': 'dateTime',
      'decoration': {
        'filled': true,
        'fillColor': '#FF18181C',
        'contentPadding': [18, 0, 18, 0],
        'prefixIcon': {
          'icon': {'type': 'MATERIAL_ICON', 'name': 'event', 'style': 'rounded'},
          'size': 24,
        },
      },
      'style': {'fontSize': 18, 'color': '#FFF7F5F0'},
      ...props,
    },
  },
};

void main() {
  testWidgets('shows its value in a pattern and follows the bound value', (tester) async {
    final s = await show(
      tester,
      _screen({'displayFormat': 'EEE, MMM d · h:mm a'}),
      variables: [v('arrival', '2026-11-12T09:05:00')],
    );
    await tester.pumpAndSettle();
    expect(find.text('Thu, Nov 12 · 9:05 AM'), findsOneWidget);
    s.scope.set('arrival', '2026-11-12T13:20:00');
    await tester.pumpAndSettle();
    expect(find.text('Thu, Nov 12 · 1:20 PM'), findsOneWidget);
    expect(tester.getSize(find.byType(InputDecorator)).height, 60);
  });

  testWidgets('a display text wins; with its own picker a tap opens no dialog', (tester) async {
    await show(
      tester,
      _screen({'displayText': 'Now · 1:20 PM', 'picker': 'none'}),
      variables: [v('arrival', '2026-11-12T13:20:00')],
    );
    await tester.pumpAndSettle();
    expect(find.text('Now · 1:20 PM'), findsOneWidget);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });
}
