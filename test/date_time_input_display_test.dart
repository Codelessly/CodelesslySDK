// A date/time input reads its value by a pattern, in its own style, and bare
// shows only the value (or hint) and its icon inside the node's box.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show;

Future<void> _field(WidgetTester tester, Map<String, Object?> props) => show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34, 'padding': [10, 0, 10, 0]},
        'decoration': {'strokes': [{'color': '#FFB8C2CE'}], 'radius': 4},
        'props': props,
      },
    });

void main() {
  testWidgets('a pattern formats the date and the time', (tester) async {
    await _field(tester, {'mode': 'date', 'value': '2026-12-01', 'format': 'MMM d, y', 'bare': true});
    await tester.pumpAndSettle();
    expect(find.text('Dec 1, 2026'), findsOneWidget);
    expect(find.byType(InputDecorator), findsNothing);
    await _field(tester, {'mode': 'time', 'value': '10:30', 'format': 'h:mm a', 'bare': true});
    await tester.pumpAndSettle();
    expect(find.text('10:30 AM'), findsOneWidget);
  });

  testWidgets('empty and bare, it shows its hint in the hint style', (tester) async {
    await _field(tester, {
      'mode': 'date', 'value': '', 'bare': true, 'hint': 'Pick a date',
      'hintStyle': {'fontSize': 13, 'color': '#FF6B7A8D'},
    });
    await tester.pumpAndSettle();
    final t = tester.widget<Text>(find.text('Pick a date'));
    expect(t.style?.fontSize, 13);
    expect(t.style?.color, const Color(0xFF6B7A8D));
  });

  testWidgets('without a pattern it keeps Material\'s field', (tester) async {
    await _field(tester, {'mode': 'date', 'value': '2026-12-01'});
    await tester.pumpAndSettle();
    expect(find.byType(InputDecorator), findsOneWidget);
  });
}
