
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;

LayoutDocument _doc(Map<String, Object?> nodes) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    });

/// The center of node [id] on screen.
Offset _center(WidgetTester tester, NodeTree tree, String id) =>
    tester.getTopLeft(find.byType(NodeView)) + tree.boxOf(id)!.rectIn(tester.renderObject(find.byType(NodeView)))!.center;

// A date/time input styled like a text field: its value in a pattern, or a
// bound display text, and no dialog when its picker is the design's own.
//
// A date/time input reads its value by a pattern, in its own style, and bare
// shows only the value (or hint) and its icon inside the node's box.

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
  testWidgets('shows its value in its pattern and follows a bound value', (tester) async {
    final s = await lists.show(
      tester,
      _screen({'displayFormat': 'EEE, MMM d · h:mm a'}),
      variables: [lists.v('arrival', '2026-11-12T09:05:00')],
    );
    await tester.pumpAndSettle();
    expect(find.text('Thu, Nov 12 · 9:05 AM'), findsOneWidget);
    s.scope.set('arrival', '2026-11-12T13:20:00');
    await tester.pumpAndSettle();
    expect(find.text('Thu, Nov 12 · 1:20 PM'), findsOneWidget);
    expect(tester.getSize(find.byType(InputDecorator)).height, 60);
  });

  testWidgets('shows its display text instead, and with its own picker a tap opens no dialog', (tester) async {
    await lists.show(
      tester,
      _screen({'displayText': 'Now · 1:20 PM', 'picker': 'none'}),
      variables: [lists.v('arrival', '2026-11-12T13:20:00')],
    );
    await tester.pumpAndSettle();
    expect(find.text('Now · 1:20 PM'), findsOneWidget);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });
}

Future<void> _field(WidgetTester tester, Map<String, Object?> props) => lists.show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34, 'padding': [10, 0, 10, 0]},
        'decoration': {'strokes': [{'color': '#FFB8C2CE'}], 'radius': 4},
        'props': props,
      },
    });

void _master() {
  testWidgets('with its own picker a tap runs the node\'s click reactions', (tester) async {
    final s = await lists.show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 300, 'height': 100}},
      'd': {
        'type': 'dateTimeInput',
        'layout': {'width': 300, 'height': 34},
        'props': {'mode': 'date', 'value': '2026-12-01', 'format': 'MMM d, y', 'bare': true, 'picker': 'none'},
        'actions': [lists.reaction('click', [{'type': 'setVariable', 'variable': 'opened', 'value': true}])],
      },
    }, variables: [lists.v('opened', false, VariableType.boolean)]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dec 1, 2026'));
    await tester.pumpAndSettle();
    expect(s['opened'], isTrue);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('without a pattern it is Material\'s own field', (tester) async {
    await _field(tester, {'mode': 'date', 'value': '2026-12-01'});
    await tester.pumpAndSettle();
    expect(find.byType(InputDecorator), findsOneWidget);
  });
}

void main() {
  testWidgets('a decorated date picker is a formatted field, and its dialog takes the picker theme', (tester) async {
    const theme = {
      'backgroundColor': '#FFFFFFFF',
      'accentColor': '#FF2F4F46',
      'textColor': '#FF23262B',
      'mutedColor': '#FF8C8F94',
      'radius': 14,
      'dayRadius': 8,
      'fontFamily': 'Arial',
    };
    final field = {
      'border': {'type': 'outline', 'borderRadius': 10, 'borderSide': {'color': '#FFD3CDC0'}},
      'prefixIcon': {'icon': {'type': 'MATERIAL_ICON', 'name': 'calendar_today', 'style': 'outlined'}, 'size': 17},
      'filled': true,
      'fillColor': '#FFFFFFFF',
    };
    final tree = NodeTree(DocumentSource(_doc({
      'date': {
        'type': 'datePicker',
        'layout': {'width': 260, 'height': 42},
        'props': {
          'value': '2026-11-30',
          'format': 'EEE d MMM yyyy',
          'helpText': 'FIRST DAY OFF',
          'decoration': field,
          'pickerTheme': theme,
        },
      },
      'time': {
        'type': 'timePicker',
        'layout': {'width': 160, 'height': 42, 'y': {'start': 80}},
        'props': {'value': '13:00', 'format': 'HH:mm', 'alwaysUse24HourFormat': true, 'decoration': field, 'pickerTheme': theme},
      },
    })));
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    // A field, not a button, showing the formatted value.
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(InputDecorator), findsNWidgets(2));
    expect(find.text('Mon 30 Nov 2026'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);

    await tester.tapAt(_center(tester, tree, 'date'));
    await tester.pumpAndSettle();
    final dialog = tester.element(find.byType(DatePickerDialog));
    final t = Theme.of(dialog);
    expect(t.colorScheme.primary, const Color(0xFF2F4F46));
    expect(t.colorScheme.surfaceContainerHigh, const Color(0xFFFFFFFF));
    expect(t.datePickerTheme.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
    expect(find.text('FIRST DAY OFF'), findsOneWidget);
    Navigator.of(dialog).pop(DateTime(2026, 12, 4));
    await tester.pumpAndSettle();
    expect(find.text('Fri 4 Dec 2026'), findsOneWidget);

    await tester.tapAt(_center(tester, tree, 'time'));
    await tester.pumpAndSettle();
    final timeDialog = tester.element(find.byType(TimePickerDialog));
    expect(MediaQuery.of(timeDialog).alwaysUse24HourFormat, isTrue);
    expect(Theme.of(timeDialog).timePickerTheme.dialHandColor, const Color(0xFF2F4F46));
    Navigator.of(timeDialog).pop(const TimeOfDay(hour: 14, minute: 30));
    await tester.pumpAndSettle();
    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('an empty date picker shows its hint', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'time': {
        'type': 'timePicker',
        'layout': {'width': 160, 'height': 42},
        'props': {
          'value': '',
          'decoration': {'hintText': '—', 'border': {'type': 'outline'}},
        },
      },
    })));
    await tester.pumpWidget(MaterialApp(home: Material(child: Center(child: NodeView(tree: tree, rootId: 's', interactive: true)))));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsWidgets);
    expect(find.text('00:00'), findsNothing);
  });

  group('how the value is shown', () {
    _ours();
    _master();
  });
}
