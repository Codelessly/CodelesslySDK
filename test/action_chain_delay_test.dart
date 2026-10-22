import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'action_chain_scope_test.dart' show click, pumpTasks, textVariable;

void main() {
  final a = {'id': 'a', 'title': 'Buy milk'};
  final b = {'id': 'b', 'title': 'Walk dog'};
  final c = {'id': 'c', 'title': 'Pay rent'};

  testWidgets('a delay keeps the tapped item while the list changes', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final removed = <String>[];
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'remove': (context, reference, params) => removed.add(params['id']),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        click(DelayAction(milliseconds: 500)),
        click(
          CallFunctionAction(name: 'remove', params: {'id': r'${item.id}'}),
        ),
        click(ShowToastAction(message: r'Removed ${item.title}')),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('row 0')));
    await tester.pump(const Duration(milliseconds: 100));
    // A new task streams in at the top while the delay runs.
    tasks.value = [c, a, b];
    await tester.pump();
    expect(find.text('Pay rent'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(removed, ['a']);
    expect(find.text('Removed Buy milk'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a delay after the row unmounts still runs the rest', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final status = textVariable('status');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['status'] = status
      ..functions = {
        // The stream drops the removed task right away.
        'removeDocument': (context, reference, params) => tasks.value = [a],
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        click(
          CallFunctionAction(
            name: 'removeDocument',
            params: {'id': r'${item.id}'},
          ),
        ),
        click(DelayAction(milliseconds: 300)),
        click(
          SetVariableAction(
            variable: VariableData(id: 'status', name: 'status'),
            newValue: r'Deleted ${item.title}',
          ),
        ),
        click(ShowToastAction(message: 'Task deleted')),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('row 1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('row 1')), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(status.value.value, 'Deleted Walk dog');
    expect(find.text('Task deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm removes the tapped task after the list changes', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final removed = <String>[];
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'removeDocument': (context, reference, params) {
          removed.add(params['id']);
          tasks.value = [
            for (final task in tasks.value)
              if (task['id'] != params['id']) task,
          ];
        },
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        click(
          ConfirmAction(
            title: r'Delete ${item.title}?',
            confirmLabel: 'Delete',
            actions: [
              CallFunctionAction(
                name: 'removeDocument',
                params: {'id': r'${item.id}'},
              ),
              ShowToastAction(message: r'Deleted ${item.title}'),
            ],
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('row 0')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Buy milk?'), findsOneWidget);
    // Another task streams in at the top while the dialog is open.
    tasks.value = [c, a, b];
    await tester.pump();

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(removed, ['a']);
    expect(find.text('Deleted Buy milk'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
