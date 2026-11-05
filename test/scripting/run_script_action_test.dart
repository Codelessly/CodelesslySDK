// "Run script" actions and `script.name()` in formulas, in a running
// widget tree. Runs on the VM (QuickJS) and in Chrome (Web Worker).
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/engine_setup.dart';

Observable<VariableData> variable(
  String name,
  VariableType type,
  Object? value,
) => Observable(VariableData(id: name, name: name, type: type, value: value));

/// Pumps a screen whose [CodelesslyContext] has [variables] and [scripts].
Future<(BuildContext, CodelesslyContext)> pumpScreen(
  WidgetTester tester, {
  Map<String, Observable<VariableData>> variables = const {},
  List<ScriptModel> scripts = const [],
}) async {
  final CodelesslyContext codelessly = CodelesslyContext.empty();
  codelessly.variables.addAll(variables);
  for (final ScriptModel s in scripts) {
    codelessly.scripts[s.name] = s;
  }
  late BuildContext captured;
  await tester.pumpWidget(
    Provider<Codelessly>.value(
      value: Codelessly(),
      child: ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return (captured, codelessly);
}

const ScriptModel addTip = ScriptModel(
  id: 'tip',
  name: 'addTip',
  params: [
    ScriptParam(name: 'bill'),
    ScriptParam(name: 'pct', defaultValue: 18),
  ],
  capabilities: [
    ScriptCapability.variablesRead,
    ScriptCapability.variablesWrite,
  ],
  source: '''
    const total = Math.round(bill * (1 + pct / 100) * 100) / 100;
    vars.set("total", total);
    vars.set("history", [...vars.get("history"), total]);
    return {total, people: vars.get("people")};
  ''',
);

void main() {
  setUpAll(setUpScriptEngine);

  testWidgets(
    'A Run script action passes typed arguments, writes variables and leaves its result',
    (tester) async {
      final (context, codelessly) = await pumpScreen(
        tester,
        variables: {
          'people': variable('people', VariableType.integer, 4),
          'total': variable('total', VariableType.decimal, 0.0),
          'history': variable('history', VariableType.list, []),
          'stored': variable('stored', VariableType.map, null),
        },
        scripts: [addTip],
      );
      Object? result;
      await tester.runAsync(
        () => ActionChain.run(() async {
          await FunctionsRepository.performAction(
            context,
            RunScriptAction(
              scriptId: 'tip',
              arguments: {'bill': r'${people}0'},
              resultVariable: 'stored',
            ),
          );
          result = ActionChain.current?.result;
        }),
      );
      // `${people}0` is the text "40", which reads as the number 40.
      expect(result, {'total': 47.2, 'people': 4});
      expect(codelessly.variables['total']!.value.getValue(), 47.2);
      expect(codelessly.variables['history']!.value.getValue(), [47.2]);
      expect(codelessly.variables['stored']!.value.getValue(), {
        'total': 47.2,
        'people': 4,
      });
    },
  );

  testWidgets(
    'A failing script runs its onError actions with the error as the result',
    (tester) async {
      final (context, codelessly) = await pumpScreen(
        tester,
        variables: {'message': variable('message', VariableType.text, '')},
        scripts: [
          const ScriptModel(
            id: 'bad',
            name: 'bad',
            source: 'function f() {\n  throw new TypeError("nope");\n}\nf();',
          ),
        ],
      );
      bool? continued;
      Object? result;
      await tester.runAsync(
        () => ActionChain.run(() async {
          continued = await FunctionsRepository.performAction(
            context,
            RunScriptAction(
              scriptId: 'bad',
              onError: [
                SetVariableAction(
                  variable: VariableData(
                    id: 'message',
                    name: 'message',
                    type: VariableType.text,
                  ),
                  newValue:
                      r'${result.error.type} at line ${result.error.line}',
                ),
              ],
            ),
          ) as bool;
          result = ActionChain.current?.result;
        }),
      );
      expect(continued, isTrue);
      expect(
        codelessly.variables['message']!.value.getValue(),
        'TypeError at line 2',
      );
      expect((result! as Map)['error'], containsPair('message', 'nope'));
    },
  );

  testWidgets('A failing script without onError actions stops the chain', (
    tester,
  ) async {
    final (context, _) = await pumpScreen(
      tester,
      scripts: [
        const ScriptModel(
          id: 'loop',
          name: 'loop',
          source: 'while (true) {}',
          timeoutMs: 100,
        ),
      ],
    );
    Object? error;
    await tester.runAsync(() async {
      try {
        await FunctionsRepository.performAction(
          context,
          RunScriptAction(scriptId: 'loop'),
        );
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<ScriptFailedException>());
    expect((error! as ScriptFailedException).error['type'], 'LimitError');
  });

  testWidgets('A script that is missing fails cleanly', (tester) async {
    final (context, _) = await pumpScreen(tester);
    Object? error;
    await tester.runAsync(() async {
      try {
        await FunctionsRepository.performAction(
          context,
          RunScriptAction(scriptId: 'ghost'),
        );
      } catch (e) {
        error = e;
      }
    });
    expect(error.toString(), contains('There is no script "ghost"'));
  });

  testWidgets(
    'Script arguments keep the type of a single variable or formula',
    (tester) async {
      final (context, _) = await pumpScreen(
        tester,
        variables: {
          'items': variable('items', VariableType.list, [1, 2]),
          'name': variable('name', VariableType.text, 'Ada'),
        },
      );
      final ScopedValues scope = ScopedValues.of(context);
      expect(FunctionsRepository.scriptArgument(r'${items}', scope), [1, 2]);
      expect(
        FunctionsRepository.scriptArgument(r'${= sum(items) * 2}', scope),
        6,
      );
      expect(
        FunctionsRepository.scriptArgument(r'Hi ${name}', scope),
        'Hi Ada',
      );
      expect(FunctionsRepository.scriptArgument('30', scope), 30);
      expect(FunctionsRepository.scriptArgument('true', scope), true);
      expect(FunctionsRepository.scriptArgument('[1, "a"]', scope), [1, 'a']);
      expect(
        FunctionsRepository.scriptArgument('plain text', scope),
        'plain text',
      );
    },
  );

  testWidgets('Formulas call scripts with script.name(args), read-only', (
    tester,
  ) async {
    final (context, codelessly) = await pumpScreen(
      tester,
      variables: {
        'bill': variable('bill', VariableType.decimal, 50.0),
        'total': variable('total', VariableType.decimal, 0.0),
      },
      scripts: [
        addTip,
        const ScriptModel(
          id: 'pay',
          name: 'payment',
          params: [
            ScriptParam(name: 'p'),
            ScriptParam(name: 'rate'),
            ScriptParam(name: 'years'),
          ],
          source: 'const r = rate / 1200, n = years * 12;\nreturn Math.round(p * r / (1 - Math.pow(1 + r, -n)) * 100) / 100;',
        ),
      ],
    );
    final ScopedValues scope = ScopedValues.of(context);
    Object? payment;
    Object? tip;
    await tester.runAsync(() async {
      for (int i = 0; i < 40; i++) {
        payment = PropertyValueDelegate.getVariableValueFromPath<Object>(
          r'${= script.payment(350000, 6.5, 30)}',
          scopedValues: scope,
        );
        tip = PropertyValueDelegate.getVariableValueFromPath<Object>(
          r'${= script.addTip(bill)}',
          scopedValues: scope,
        );
        // On the web the first evaluation starts the run in the worker.
        if (payment != null && tip != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(payment, 2212.24);
    // A formula's script can't change variables: vars.set fails, so the
    // result is null and the variable is untouched.
    expect(tip, isNull);
    expect(codelessly.variables['total']!.value.getValue(), 0.0);
    expect(FormulaEvaluator.callsScript('1 + script.payment(a, b, c)'), isTrue);
    // Widgets bound to a computed variable that calls a script rebuild with
    // its result too (on the web it arrives late).
    final Map<String, VariableData> byName = {
      'split': VariableData(
        id: 'split',
        name: 'split',
        type: VariableType.map,
        formula: 'script.splitBill(bill, 18)',
      ),
      'perPerson': VariableData(
        id: 'pp',
        name: 'perPerson',
        type: VariableType.decimal,
        formula: 'split.perPerson',
      ),
    };
    expect(
      PropertyValueDelegate.computedDependencies(
        'perPerson',
        byName,
      ).callsScript,
      isTrue,
    );
    expect(
      FormulaEvaluator.referencedPaths('script.payment(amount, rate, 30)'),
      {'amount', 'rate'},
    );
  });

  test(
    'Script models round-trip through JSON and drop unknown capabilities',
    () {
      final ScriptModel model = ScriptModel.fromJson({
        ...addTip.toJson(),
        'capabilities': ['variables.read', 'teleport', 'clock'],
        'pageId': 'page1',
      });
      expect(model.capabilities, [
        ScriptCapability.variablesRead,
        ScriptCapability.clock,
      ]);
      expect(model.pageId, 'page1');
      expect(ScriptModel.fromJson(model.toJson()), model);
      expect(addTip.toJson().containsKey('timeoutMs'), isFalse);
      final RunScriptAction action = RunScriptAction(
        scriptId: 'tip',
        arguments: {'bill': '40'},
        onError: [ShowToastAction(message: 'x')],
      );
      expect(ActionModel.fromJson(action.toJson()), action);
      expect(const ScriptModel(id: 'a', name: 'vars').validate(), isNotEmpty);
      expect(
        const ScriptModel(
          id: 'a',
          name: 'ok',
          params: [
            ScriptParam(name: 'x'),
            ScriptParam(name: 'x'),
          ],
        ).validate(),
        isNotEmpty,
      );
    },
  );

  test('A script runs its stored test cases with sample variables', () async {
    const ScriptModel model = ScriptModel(
      id: 'v',
      name: 'validate',
      params: [ScriptParam(name: 'form')],
      capabilities: [ScriptCapability.variablesRead],
      source: """
        const errors = {};
        if (!/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$/.test(form.email)) errors.email = 'Invalid email';
        if (form.age < vars.get('minAge')) errors.age = 'Too young';
        if (form.age > 150) throw new RangeError('age');
        return {valid: Object.keys(errors).length === 0, errors};
      """,
      tests: [
        ScriptTest(
          name: 'ok',
          args: {
            'form': {'email': 'a@b.co', 'age': 30},
          },
          vars: {'minAge': 13},
          expect: {'errors': {}, 'valid': true},
        ),
        ScriptTest(
          name: 'bad',
          args: {
            'form': {'email': 'nope', 'age': 9},
          },
          vars: {'minAge': 13},
          expect: {
            'valid': false,
            'errors': {'email': 'Invalid email', 'age': 'Too young'},
          },
        ),
        ScriptTest(
          name: 'throws',
          args: {
            'form': {'email': 'a@b.co', 'age': 200},
          },
          vars: {'minAge': 13},
          expectError: 'RangeError',
        ),
        ScriptTest(
          name: 'wrong on purpose',
          args: {
            'form': {'email': 'a@b.co', 'age': 30},
          },
          vars: {'minAge': 13},
          expect: {'valid': false},
        ),
      ],
    );
    final List<ScriptTestResult> results = await model.runTests();
    expect([for (final r in results) r.passed], [true, true, true, false]);
    expect(results.last.reason, contains('Expected'));
    expect(ScriptModel.fromJson(model.toJson()).tests, model.tests);
  });

  test('The catalog describes every host API with its capability', () {
    final Map<String, Object?> json = ScriptCatalog.toJson();
    final List api = json['api']! as List;
    expect(
      api.map((e) => (e as Map)['signature']),
      containsAll([
        'vars.get(name)',
        'app.callApi(name, inputs?)',
        'fmt.currency(n, code?, digits?)',
      ]),
    );
    for (final ScriptCapability c in ScriptCapability.values) {
      expect(
        (json['capabilities']! as Map).containsKey(c.id),
        isTrue,
        reason: c.id,
      );
    }
    expect(
      ScriptCatalog.entries
          .firstWhere((e) => e.signature == 'vars.set(name, value)')
          .parameters,
      ['name', 'value'],
    );
  });
}
