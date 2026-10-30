import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/load_test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('dateTime preview shows label and never opens dialogs', (
    tester,
  ) async {
    final node = DateTimeInputNode(
      id: 'dt',
      name: 'Date time',
      basicBoxLocal: NodeBox(0, 0, 320, 48),
      mode: 'dateTime',
      value: '2024-02-29T09:05:00Z',
      properties: DateTimeInputProperties(label: 'Appointment'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassiveDateTimeInputWidget(node: node, isPreview: true),
        ),
      ),
    );
    expect(find.text('Appointment: 2024-02-29T09:05:00Z'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
  });

  testWidgets('dateTime date bounds, cancellation and chained time', (
    tester,
  ) async {
    final node = DateTimeInputNode(
      id: 'dt',
      name: 'Date time',
      basicBoxLocal: NodeBox(0, 0, 320, 48),
      mode: 'dateTime',
      value: '2024-02-29T09:05:00Z',
      properties: DateTimeInputProperties(
        firstDate: '2024-02-29',
        lastDate: '2024-03-01',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PassiveDateTimeInputWidget(node: node)),
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    final dialog = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(dialog.firstDate, DateTime(2024, 2, 29));
    expect(dialog.lastDate, DateTime(2024, 3, 1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2024-02-29T09:05:00Z'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2024-02-29T09:05:00Z'), findsOneWidget);
  });
  testWidgets(
    'date picker preview is deterministic and does not open a dialog',
    (tester) async {
      final node = DatePickerNode(
        id: 'date',
        name: 'Date',
        basicBoxLocal: NodeBox(0, 0, 320, 48),
        value: '2024-02-29',
        properties: DatePickerProperties(
          firstDate: '2024-02-01',
          lastDate: '2024-03-31',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassiveDatePickerWidget(node: node, isPreview: true),
          ),
        ),
      );
      expect(find.text('2024-02-29'), findsOneWidget);
      await tester.tap(find.text('2024-02-29'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    },
  );

  testWidgets(
    'date picker respects inclusive bounds and formats selected date',
    (tester) async {
      final node = DatePickerNode(
        id: 'date',
        name: 'Date',
        basicBoxLocal: NodeBox(0, 0, 320, 48),
        value: '2024-02-29',
        properties: DatePickerProperties(
          firstDate: '2024-02-29',
          lastDate: '2024-03-01',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PassiveDatePickerWidget(node: node)),
        ),
      );
      await tester.tap(find.text('2024-02-29'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(2024, 2, 29));
      expect(dialog.lastDate, DateTime(2024, 3, 1));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('2024-02-29'), findsOneWidget);
    },
  );

  testWidgets('time picker preview is deterministic and runtime opens dialog', (
    tester,
  ) async {
    final node = TimePickerNode(
      id: 'time',
      name: 'Time',
      basicBoxLocal: NodeBox(0, 0, 320, 48),
      value: '09:05',
      properties: TimePickerProperties(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassiveTimePickerWidget(node: node, isPreview: true),
        ),
      ),
    );
    expect(find.text('09:05'), findsOneWidget);
    await tester.tap(find.text('09:05'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PassiveTimePickerWidget(node: node)),
      ),
    );
    await tester.tap(find.text('09:05'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
