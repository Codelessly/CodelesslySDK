import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

  testWidgets('combined date and time preview uses real fonts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final node = DateTimeInputNode(
      id: 'dt-golden',
      name: 'Date and time',
      basicBoxLocal: NodeBox(0, 0, 320, 48),
      mode: 'dateTime',
      value: '2024-02-29T09:05:00Z',
      properties: DateTimeInputProperties(label: 'Appointment'),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: Center(
            child: PassiveDateTimeInputWidget(node: node, isPreview: true),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/date_time_input_preview.png'),
    );
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
  testWidgets('dateTime writes one ISO value to a bound variable', (
    tester,
  ) async {
    final value = Observable(
      VariableData(
        id: 'appointment',
        name: 'appointment',
        value: '2024-02-29T09:05:00Z',
      ),
    );
    final payload = CodelesslyContext.empty()
      ..variables['appointment'] = value;
    final node = DateTimeInputNode(
      id: 'dt-bound',
      name: 'Appointment',
      basicBoxLocal: NodeBox(0, 0, 320, 48),
      mode: 'dateTime',
      value: '2024-02-29T09:05:00Z',
      properties: DateTimeInputProperties(label: 'Appointment'),
      variables: {'value': r'${appointment}'},
    );
    final manager = PassiveNodeTransformerManager(
      (id) => node,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: payload,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'dateTime'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Appointment: 2024-02-29T09:05:00Z'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(value.value.value, '2024-02-29T09:05:00Z');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(value.value.value, '2024-02-29T09:05:00.000Z');
    value.value = value.value.copyWith(value: '2024-03-01T14:30:00Z');
    await tester.pump();
    expect(find.text('Appointment: 2024-03-01T14:30:00Z'), findsOneWidget);
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
