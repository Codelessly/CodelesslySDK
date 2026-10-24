import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A set variable action whose new value is '' survives saving, and running
/// it (whatever the variable's type) doesn't stop the actions after it.
void main() {
  group('canvas load actions', loadActionTests);

  test("newValue '' round-trips", () {
    final SetVariableAction action = SetVariableAction(
      variable: VariableData(id: 'q', name: 'q', type: VariableType.text),
      newValue: '',
    );
    final Map json = action.toJson();
    final ActionModel restored = ActionModel.fromJson(json);
    expect(restored, isA<SetVariableAction>());
    expect((restored as SetVariableAction).newValue, '');
    // An action saved without the key reads it as ''.
    expect(
      (ActionModel.fromJson(
        {...json}..remove('newValue'),
      ) as SetVariableAction).newValue,
      '',
    );
    expect(
      Reaction.fromJson(
        Reaction(
          action: action,
          trigger: TriggerModel(type: TriggerType.click),
        ).toJson(),
      ).action,
      action,
    );
  });

  for (final VariableType type in VariableType.values) {
    testWidgets("setting a $type variable to '' lets the next action run", (
      tester,
    ) async {
      final List<String> calls = [];
      final VariableData variable = VariableData(
        id: 'v',
        name: 'v',
        type: type,
        value: switch (type) {
          VariableType.integer => '3',
          VariableType.decimal => '1.5',
          VariableType.boolean => 'true',
          VariableType.color => '#FF0000',
          VariableType.list => '[1, 2]',
          VariableType.map => '{"a": 1}',
          _ => 'x',
        },
      );
      final Observable<VariableData> notifier = Observable(variable);
      late BuildContext context;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty()
            ..variables['v'] = notifier
            ..functions = {
              'after': (context, reference, params) => calls.add('after'),
            },
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final ListOperation op in [
        ListOperation.replace,
        if (type == VariableType.list) ...[
          ListOperation.add,
          ListOperation.update,
          ListOperation.remove,
        ],
      ]) {
        calls.clear();
        await FunctionsRepository.triggerAction(
          context,
          TriggerType.click,
          reactions: [
            Reaction(
              action: SetVariableAction(
                variable: variable,
                newValue: '',
                listOperation: op,
              ),
              trigger: TriggerModel(type: TriggerType.click),
            ),
            Reaction(
              action: CallFunctionAction(name: 'after'),
              trigger: TriggerModel(type: TriggerType.click),
            ),
          ],
        );
        await tester.pump();
        expect(calls, ['after'], reason: '$type $op');
        expect(tester.takeException(), isNull);
      }
      // Nested action lists (a conditional's branch) run on too.
      calls.clear();
      await FunctionsRepository.runActions(context, [
        SetVariableAction(variable: variable, newValue: ''),
        CallFunctionAction(name: 'after'),
      ]);
      expect(calls, ['after']);
    });
  }
}

/// A canvas's load actions: one that throws is reported and the rest run.
void loadActionTests() {
  testWidgets('a failing load action does not stop the rest', (tester) async {
    final List<String> calls = [];
    final Observable<VariableData> query = Observable(
      VariableData(id: 'q', name: 'q', type: VariableType.text, value: 'x'),
    );
    final CanvasNode canvas = CanvasNode(
      id: 'canvas',
      name: 'canvas',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: const [],
      properties: CanvasProperties(bodyId: 'body'),
      reactions: [
        for (final ActionModel action in [
          CallFunctionAction(name: 'boom'),
          SetVariableAction(variable: query.value, newValue: ''),
          CallFunctionAction(name: 'after'),
        ])
          Reaction(
            action: action,
            trigger: TriggerModel(type: TriggerType.load),
          ),
      ],
    )..parentID = kRootNode;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..variables['q'] = query
          ..functions = {
            'boom': (context, reference, params) => throw StateError('boom'),
            'after': (context, reference, params) => calls.add('after'),
          },
        child: MaterialApp(
          home: PassiveCanvasWidget(
            node: canvas,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
            builder: (context) => const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(query.value.value, '');
    expect(calls, ['after']);
  });
}
