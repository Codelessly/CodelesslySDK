import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'action_chain_scope_test.dart' show click, pumpTasks, textVariable;

void main() {
  final a = {'id': 'a', 'title': 'Buy milk'};
  final b = {'id': 'b', 'title': 'Walk dog'};

  for (final bool embedRows in [false, true]) {
    testWidgets('Undo runs with the original item after its row unmounts'
        '${embedRows ? ' from an embedded layout' : ''}', (tester) async {
      final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
      final restored = <String>[];
      final undone = textVariable('undone');
      final codelesslyContext = CodelesslyContext.empty()
        ..variables['undone'] = undone
        ..functions = {
          // Checking a task off drops it from the stream.
          'complete': (context, reference, params) => tasks.value = [
            for (final task in tasks.value)
              if (task['id'] != params['id']) task,
          ],
          'restore': (context, reference, params) => restored.add(params['id']),
        };
      await pumpTasks(
        tester,
        codelesslyContext: codelesslyContext,
        tasks: tasks,
        embedRows: embedRows,
        reactions: [
          click(
            CallFunctionAction(name: 'complete', params: {'id': r'${item.id}'}),
          ),
          click(
            ShowToastAction(
              message: r'Completed “${item.title}”',
              actionLabel: 'Undo',
              duration: 4000,
              actions: [
                SetVariableAction(
                  variable: VariableData(id: 'undone', name: 'undone'),
                  newValue: r'${item.title} at ${index}',
                ),
                CallFunctionAction(
                  name: 'restore',
                  params: {'id': r'${item.id}'},
                ),
              ],
            ),
          ),
        ],
      );

      final Element row = tester.element(find.byKey(const ValueKey('row 1')));
      await tester.tap(find.byKey(const ValueKey('row 1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(row.mounted, isFalse);
      expect(find.text('Completed “Walk dog”'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      expect(undone.value.value, 'Walk dog at 1');
      expect(restored, ['b']);

      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Undo after the screen is gone reports the skipped actions', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a]);
    final restored = <String>[];
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'restore': (context, reference, params) => restored.add(params['id']),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        click(
          ShowToastAction(
            message: 'Done',
            actionLabel: 'Undo',
            duration: 4000,
            actions: [
              CallFunctionAction(
                name: 'restore',
                params: {'id': r'${item.id}'},
              ),
            ],
          ),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('row 0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final Element undo = tester.element(find.text('Undo'));
    final VoidCallback onPressed = tester
        .widget<TextButton>(
          find.ancestor(
            of: find.text('Undo'),
            matching: find.byType(TextButton),
          ),
        )
        .onPressed!;
    expect(undo.mounted, isTrue);
    ErrorLogger.instance.clear();

    // The screen goes, then the button is pressed (e.g. mid fade-out).
    await tester.pumpWidget(const SizedBox());
    onPressed();
    await tester.pump();

    expect(restored, isEmpty);
    expect(
      ErrorLogger.instance.errors.map((error) => error.type),
      contains('action_chain_detached'),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
