// A date/time input styled like a text field: its value in a pattern, or a
// bound display text, and no dialog when its picker is the design's own.
//
// A date/time input reads its value by a pattern, in its own style, and bare
// shows only the value (or hint) and its icon inside the node's box.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

void main() {
  _ours();
  _master();
}

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

void _ours() {
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

Future<void> _field(WidgetTester tester, Map<String, Object?> props) => show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34, 'padding': [10, 0, 10, 0]},
        'decoration': {'strokes': [{'color': '#FFB8C2CE'}], 'radius': 4},
        'props': props,
      },
    });

void _master() {
  testWidgets('its own picker: a tap runs the node\'s click reactions', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34},
        'props': {'mode': 'date', 'value': '2026-12-01', 'format': 'MMM d, y', 'bare': true, 'picker': 'none'},
        'actions': [reaction('click', [{'type': 'setVariable', 'variable': 'opened', 'value': true}])],
      },
    }, variables: [v('opened', false, VariableType.boolean)]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dec 1, 2026'));
    await tester.pumpAndSettle();
    expect(s['opened'], isTrue);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('a pattern formats the date and the time', (tester) async {
    await _field(tester, {'mode': 'date', 'value': '2026-12-01', 'format': 'MMM d, y', 'bare': true});
    await tester.pumpAndSettle();
    expect(find.text('Dec 1, 2026'), findsOneWidget);
    expect(find.byType(InputDecorator), findsNothing);
    // The value sits in the middle of the 34 px box.
    final box = tester.getRect(find.byType(NodeView).first);
    final text = tester.getRect(find.text('Dec 1, 2026'));
    expect(text.center.dy - box.top, closeTo(17, 1.5));
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
