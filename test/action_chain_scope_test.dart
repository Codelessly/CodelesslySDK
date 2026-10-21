import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction click(ActionModel action) => Reaction(
  action: action,
  trigger: TriggerModel(type: TriggerType.click),
);

/// A fake cloud write: records `${item.id}` and waits for the test.
Reaction write(String name) =>
    click(CallFunctionAction(name: name, params: {'id': r'${item.id}'}));

/// Pumps a list of [tasks] whose rows run [reactions] on tap, like a
/// ListView of cloud documents: rows are keyed by index, so after the data
/// changes a row's element shows another document, and the rows past the
/// end unmount. The [ActionChainHost] stands in for the CodelesslyWidget's.
/// With [embedRows], each row has its own host too, like a row built from an
/// embedded layout.
Future<void> pumpTasks(
  WidgetTester tester, {
  required CodelesslyContext codelesslyContext,
  required ValueNotifier<List<Map<String, Object?>>> tasks,
  required List<Reaction> reactions,
  bool embedRows = false,
}) async {
  Widget row(Widget child) => embedRows ? ActionChainHost(child: child) : child;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: ActionChainHost(
          child: Scaffold(
            body: ValueListenableBuilder<List<Map<String, Object?>>>(
              valueListenable: tasks,
              builder: (context, items, _) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => IndexedItemProvider(
                  key: ValueKey(index),
                  item: IndexedItem(index, items[index]),
                  child: row(
                    Builder(
                      builder: (context) => GestureDetector(
                        key: ValueKey('row $index'),
                        onTap: () => FunctionsRepository.triggerAction(
                          context,
                          TriggerType.click,
                          reactions: reactions,
                        ),
                        child: SizedBox(
                          height: 48,
                          child: Text('${items[index]['title']}'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Observable<VariableData> textVariable(String name) =>
    Observable(VariableData(id: name, name: name, value: ''));

void main() {
  final a = {'id': 'a', 'title': 'Buy milk'};
  final b = {'id': 'b', 'title': 'Walk dog'};
  final c = {'id': 'c', 'title': 'Pay rent'};

  testWidgets('a chain reads the tapped item after the list changes under it', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b, c]);
    final written = <String>[];
    final removed = <String>[];
    final saved = Completer<void>();
    final lastId = textVariable('lastId');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['lastId'] = lastId
      ..functions = {
        'complete': (context, reference, params) async {
          written.add(params['id']);
          await saved.future;
        },
        'remove': (context, reference, params) => removed.add(params['id']),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        write('complete'),
        click(
          ShowToastAction(
            message: r'Completed “${item.title}”',
            duration: 1000,
          ),
        ),
        click(
          SetVariableAction(
            variable: VariableData(id: 'lastId', name: 'lastId'),
            newValue: r'${item.id} at ${index}',
          ),
        ),
        write('remove'),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('row 0')));
    await tester.pump();
    expect(written, ['a']);

    // The stream sends the list without the done task before the write's
    // future completes: row 0 now shows "Walk dog".
    tasks.value = [b, c];
    await tester.pump();
    expect(find.text('Walk dog'), findsOneWidget);
    expect(find.text('Buy milk'), findsNothing);

    saved.complete();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Completed “Buy milk”'), findsOneWidget);
    expect(find.text('Completed “Walk dog”'), findsNothing);
    expect(lastId.value.value, 'a at 0');
    expect(removed, ['a']);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chain finishes after its row unmounts', (tester) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final calls = <String>[];
    final removed = Completer<void>();
    final status = textVariable('status');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['status'] = status
      ..functions = {
        'removeDocument': (context, reference, params) async {
          calls.add('remove ${params['id']}');
          await removed.future;
        },
        'reload': (context, reference, params) => calls.add('reload'),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        write('removeDocument'),
        click(
          SetVariableAction(
            variable: VariableData(id: 'status', name: 'status'),
            newValue: r'Deleted ${item.title}',
          ),
        ),
        click(ShowToastAction(message: 'Task deleted', duration: 1000)),
        click(CallFunctionAction(name: 'reload')),
      ],
    );

    final Element row = tester.element(find.byKey(const ValueKey('row 1')));
    await tester.tap(find.byKey(const ValueKey('row 1')));
    await tester.pump();
    expect(calls, ['remove b']);

    // The stream drops the removed task, taking its row out of the list,
    // before the write's future completes.
    tasks.value = [a];
    await tester.pump();
    expect(row.mounted, isFalse);
    expect(find.byKey(const ValueKey('row 1')), findsNothing);

    removed.complete();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));
    expect(status.value.value, 'Deleted Walk dog');
    expect(find.text('Task deleted'), findsOneWidget);
    expect(calls, ['remove b', 'reload']);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chain whose screen is gone reports the actions it skips', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a]);
    final calls = <String>[];
    final saved = Completer<void>();
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'save': (context, reference, params) async {
          calls.add('save');
          await saved.future;
        },
        'next': (context, reference, params) => calls.add('next'),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        write('save'),
        click(CallFunctionAction(name: 'next')),
      ],
    );
    ErrorLogger.instance.clear();

    await tester.tap(find.byKey(const ValueKey('row 0')));
    await tester.pump();
    // The whole screen, host included, is replaced mid chain.
    await tester.pumpWidget(const SizedBox());
    saved.complete();
    await tester.pump();

    expect(calls, ['save']);
    expect(
      ErrorLogger.instance.errors.map((error) => error.type),
      contains('action_chain_detached'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a for-each inside a chain keeps the tapped item', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final seen = <String>[];
    final saved = Completer<void>();
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['tags'] = Observable(
        VariableData(
          id: 'tags',
          name: 'tags',
          type: VariableType.list,
          value: ['x', 'y'],
        ),
      )
      ..functions = {
        'save': (context, reference, params) async {
          await saved.future;
        },
        'tag': (context, reference, params) => seen.add(params['v']),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [
        write('save'),
        click(
          ForEachAction(
            items: 'tags',
            actions: [
              CallFunctionAction(
                name: 'tag',
                params: {'v': r'${item.id}:${result.item}'},
              ),
            ],
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('row 0')));
    await tester.pump();
    tasks.value = [b];
    await tester.pump();
    saved.complete();
    await tester.pump();
    expect(seen, ['a:x', 'a:y']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chain from an embedded layout row finishes on the outer one', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final calls = <String>[];
    final removed = Completer<void>();
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'removeDocument': (context, reference, params) async {
          calls.add('remove ${params['id']}');
          await removed.future;
        },
        'reload': (context, reference, params) => calls.add('reload'),
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      embedRows: true,
      reactions: [
        write('removeDocument'),
        click(ShowToastAction(message: r'Deleted ${item.title}')),
        click(CallFunctionAction(name: 'reload')),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('row 1')));
    await tester.pump();
    // The row and the host of its embedded layout leave together.
    tasks.value = [a];
    await tester.pump();
    removed.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deleted Walk dog'), findsOneWidget);
    expect(calls, ['remove b', 'reload']);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chain in a dialog finishes on its opener after it closes', (
    tester,
  ) async {
    final saved = Completer<void>();
    final calls = <String>[];
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'close': (context, reference, params) {
          Navigator.of(context).pop();
        },
        'save': (context, reference, params) => saved.future,
        'next': (context, reference, params) => calls.add('next'),
      };
    late BuildContext pageContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: ActionChainHost(
            child: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold();
              },
            ),
          ),
        ),
      ),
    );
    // What showDialogAction does: the dialog's layout links to its opener.
    final openerHosts = ActionChainOpener.hostsFor(pageContext);
    showDialog<void>(
      context: pageContext,
      builder: (context) => ActionChainOpener(
        openerHosts: openerHosts,
        child: ActionChainHost(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => FunctionsRepository.triggerAction(
                context,
                TriggerType.click,
                reactions: [
                  click(CallFunctionAction(name: 'close')),
                  click(CallFunctionAction(name: 'save')),
                  click(ShowToastAction(message: 'Saved')),
                  click(CallFunctionAction(name: 'next')),
                ],
              ),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);

    saved.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);
    expect(calls, ['next']);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deferred callback runs on the chain after its row unmounts', (
    tester,
  ) async {
    final tasks = ValueNotifier<List<Map<String, Object?>>>([a, b]);
    final undone = textVariable('undone');
    VoidCallback? undo;
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['undone'] = undone
      ..functions = {
        // Registers a callback to run later, like a toast's Undo button.
        'register': (context, reference, params) {
          undo = ActionChain.defer(
            context,
            (context) => FunctionsRepository.runActions(context, [
              SetVariableAction(
                variable: VariableData(id: 'undone', name: 'undone'),
                newValue: r'${item.id} at ${index}',
              ),
            ]),
            label: 'Undo',
          );
        },
      };
    await pumpTasks(
      tester,
      codelesslyContext: codelesslyContext,
      tasks: tasks,
      reactions: [click(CallFunctionAction(name: 'register'))],
    );

    await tester.tap(find.byKey(const ValueKey('row 1')));
    await tester.pump();
    tasks.value = [a];
    await tester.pump();
    expect(find.byKey(const ValueKey('row 1')), findsNothing);

    undo!();
    await tester.pump();
    expect(undone.value.value, 'b at 1');

    // With the whole screen gone, it reports instead of running.
    undone.value = undone.value.copyWith(value: '');
    ErrorLogger.instance.clear();
    await tester.pumpWidget(const SizedBox());
    undo!();
    await tester.pump();
    expect(undone.value.value, '');
    expect(
      ErrorLogger.instance.errors.map((error) => error.type),
      contains('action_chain_detached'),
    );
    expect(tester.takeException(), isNull);
  });
}
