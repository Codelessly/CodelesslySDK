import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const String visibleFormula =
    r"${= sortBy(filter(records, r => crateId == 'all' || r.crate == crateId), sortBy)}";

final List<Map<String, Object>> records = [
  {'title': 'Banana', 'crate': 'b'},
  {'title': 'Apple', 'crate': 'a'},
  {'title': 'Cherry', 'crate': 'a'},
];

CodelesslyContext recordsContext({List<VariableData> extra = const []}) {
  final CodelesslyContext context = CodelesslyContext.empty();
  for (final VariableData variable in [
    VariableData(
      id: 'records',
      name: 'records',
      type: VariableType.list,
      value: records,
    ),
    VariableData(id: 'crateId', name: 'crateId', value: 'all'),
    VariableData(id: 'sortBy', name: 'sortBy', value: 'title'),
    VariableData(
      id: 'visible',
      name: 'visible',
      type: VariableType.list,
      formula: visibleFormula,
    ),
    VariableData(
      id: 'count',
      name: 'count',
      type: VariableType.integer,
      formula: r'${= length(visible)}',
    ),
    ...extra,
  ]) {
    context.variables[variable.id] = Observable(variable);
  }
  return context;
}

ScopedValues scopeOf(CodelesslyContext context) =>
    ScopedValues.preview(variables: const {}, codelesslyContext: context);

Object? read(String path, CodelesslyContext context) =>
    PropertyValueDelegate.getVariableValueFromPath<Object>(
      path,
      scopedValues: scopeOf(context),
    );

void main() {
  group('Computed variables', () {
    test('bindings and formulas read a computed variable by name', () {
      final CodelesslyContext context = recordsContext()
        ..bindComputedVariables();
      expect(read(r'${visible[0].title}', context), 'Apple');
      expect(read(r'${= length(visible)}', context), 3);
      expect(read(r'${= visible[2].title}', context), 'Cherry');
      // A computed variable reading another computed one.
      expect(read(r'${count}', context), 3);
      expect(
        PropertyValueDelegate.substituteVariables(
          r'${count} records, first ${visible[0].title}',
          scopedValues: scopeOf(context),
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
        ),
        '3 records, first Apple',
      );
    });

    test('it updates when an input changes and caches otherwise', () {
      final CodelesslyContext context = recordsContext()
        ..bindComputedVariables();
      final Observable<VariableData> visible = context.findVariableByName(
        'visible',
      )!;
      int notified = 0;
      visible.addListener(() => notified++);

      context.updateVariable('crateId', 'a');
      expect(read(r'${= map(visible, r => r.title)}', context), [
        'Apple',
        'Cherry',
      ]);
      expect(read(r'${count}', context), 2);
      expect(notified, 1);

      // An input change that doesn't change the result notifies no one.
      context.updateVariable('sortBy', 'title');
      context.findVariableByName('records')!.value = context
          .findVariableByName('records')!
          .value
          .copyWith(value: [...records]);
      expect(notified, 1);

      context.updateVariable('crateId', 'b');
      expect(read(r'${visible[0].title}', context), 'Banana');
      expect(read(r'${count}', context), 1);
      expect(notified, 2);
    });

    test('computed variables are read-only', () {
      final CodelesslyContext context = recordsContext()
        ..bindComputedVariables();
      expect(context.updateVariable('count', 10), isFalse);
      expect(read(r'${count}', context), 3);
    });

    testWidgets('a Set variable action leaves a computed variable unchanged '
        'and a widget bound to it rebuilds when its input changes', (
      tester,
    ) async {
      final CodelesslyContext context = recordsContext()
        ..bindComputedVariables();
      late BuildContext captured;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: context,
          child: Builder(
            builder: (buildContext) {
              captured = buildContext;
              return ValueListenableBuilder<VariableData>(
                valueListenable: context.findVariableByName('count')!,
                builder: (buildContext, _, _) => Text(
                  PropertyValueDelegate.substituteVariables(
                    r'${count} shown',
                    scopedValues: ScopedValues.of(buildContext),
                    nullSubstitutionMode: NullSubstitutionMode.emptyString,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('3 shown'), findsOneWidget);

      final bool set = FunctionsRepository.setVariableFromAction(
        captured,
        SetVariableAction(
          variable: VariableData(
            id: 'count',
            name: 'count',
            type: VariableType.integer,
          ),
          newValue: '42',
        ),
      );
      expect(set, isFalse);
      await tester.pump();
      expect(find.text('3 shown'), findsOneWidget);

      FunctionsRepository.setVariableFromAction(
        captured,
        SetVariableAction(
          variable: VariableData(id: 'crateId', name: 'crateId'),
          newValue: 'a',
        ),
      );
      await tester.pump();
      expect(find.text('2 shown'), findsOneWidget);
    });

    test('cycles evaluate to empty values instead of looping', () {
      final CodelesslyContext context = recordsContext(
        extra: [
          VariableData(id: 'a', name: 'a', formula: r'${= b + 1}'),
          VariableData(id: 'b', name: 'b', formula: r'${= a + 1}'),
          VariableData(id: 'self', name: 'self', formula: r'${= self + 1}'),
          VariableData(
            id: 'afterCycle',
            name: 'afterCycle',
            formula: r"${= 'a is ' + a}",
          ),
        ],
      )..bindComputedVariables();
      expect(
        ComputedVariables.cyclicNames(context.variableNamesMap()),
        {'a', 'b', 'self'},
      );
      expect(read(r'${a}', context), '');
      expect(read(r'${b}', context), '');
      expect(read(r'${self}', context), '');
      expect(read(r'${afterCycle}', context), 'a is ');
      // The rest still works.
      expect(read(r'${count}', context), 3);
      context.updateVariable('crateId', 'b');
      expect(read(r'${count}', context), 1);
    });

    test('formulas can be a bare expression or a single path', () {
      final CodelesslyContext context = recordsContext(
        extra: [
          VariableData(
            id: 'bare',
            name: 'bare',
            type: VariableType.integer,
            formula: 'length(records) * 2',
          ),
          VariableData(
            id: 'alias',
            name: 'alias',
            type: VariableType.list,
            formula: r'${records}',
          ),
        ],
      )..bindComputedVariables();
      expect(read(r'${bare}', context), 6);
      expect(read(r'${alias[1].title}', context), 'Apple');
      expect(
        ComputedVariables.inputsOf(context.variableNamesMap()['visible']!),
        {'records', 'crateId', 'sortBy'},
      );
    });

    test('a result of another type than declared takes its own type', () {
      final VariableData variable = VariableData(
        id: 'x',
        name: 'x',
        formula: '[1, 2]',
      );
      final VariableData resolved = ComputedVariables.withResult(variable, [
        1,
        2,
      ]);
      expect(resolved.type, VariableType.list);
      expect(resolved.getValue(), [1, 2]);
      expect(resolved.formula, '[1, 2]');
      expect(ComputedVariables.withResult(variable, null).value, '');
    });

    test('resolveAll previews computed variables over default values', () {
      final Map<String, VariableData> resolved = ComputedVariables.resolveAll(
        recordsContext().variableNamesMap(),
      );
      expect(resolved['count']!.getValue(), 3);
      expect((resolved['visible']!.getValue() as List).first, {
        'title': 'Apple',
        'crate': 'a',
      });
    });

    test('the formula survives the published variables JSON', () {
      final SDKLayoutVariables published = SDKLayoutVariables(
        id: 'layout',
        variables: {
          'canvas': {
            'visible': VariableData(
              id: 'visible',
              name: 'visible',
              type: VariableType.list,
              formula: visibleFormula,
            ),
          },
        },
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
      );
      final SDKLayoutVariables decoded = SDKLayoutVariables.fromJson(
        jsonDecode(jsonEncode(published.toJson())),
      );
      expect(decoded.variables['canvas']!['visible']!.formula, visibleFormula);
    });
  });
}
