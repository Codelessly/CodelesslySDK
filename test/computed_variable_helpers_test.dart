import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const String visibleFormula =
    r"${= sortBy(filter(records, r => crateId == 'all' || r.crate == crateId), sortBy)}";

final List<Map<String, Object>> records = [
  {'title': 'Banana', 'crate': 'b'},
  {'title': 'Apple', 'crate': 'a'},
  {'title': 'Cherry', 'crate': 'a'},
];

CodelesslyContext recordsContext() {
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
      value: visibleFormula,
    ),
    VariableData(
      id: 'count',
      name: 'count',
      type: VariableType.integer,
      value: r'${= length(visible)}',
    ),
  ]) {
    context.variables[variable.id] = Observable(variable);
  }
  return context;
}

Object? read(String path, CodelesslyContext context) =>
    PropertyValueDelegate.getVariableValueFromPath<Object>(
      path,
      scopedValues: ScopedValues.preview(
        variables: const {},
        codelesslyContext: context,
      ),
    );

void main() {
  testWidgets('Set variable leaves a computed variable its formula', (
    tester,
  ) async {
    final CodelesslyContext context = recordsContext();
    late BuildContext captured;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: Builder(
          builder: (buildContext) {
            captured = buildContext;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read(r'${count}', context), 3);
    expect(context.updateVariable('count', 10), isFalse);

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
    expect(context.findVariableByName('count')!.value.isComputed, isTrue);

    FunctionsRepository.setVariableFromAction(
      captured,
      SetVariableAction(
        variable: VariableData(id: 'crateId', name: 'crateId'),
        newValue: 'a',
      ),
    );
    expect(read(r'${count}', context), 2);
  });

  test('helpers read the formula from the value', () {
    final Map<String, VariableData> byName = recordsContext()
        .variableNamesMap();
    expect(ComputedVariables.inputsOf(byName['visible']!), {
      'records',
      'crateId',
      'sortBy',
    });
    expect(ComputedVariables.inputsOf(byName['records']!), isEmpty);
    expect(ComputedVariables.errorOf(r'${= length(}'), isNotNull);
    expect(ComputedVariables.errorOf(visibleFormula), isNull);
    expect(
      ComputedVariables.cyclicNames({
        'a': VariableData(id: 'a', name: 'a', value: r'${= b + 1}'),
        'b': VariableData(id: 'b', name: 'b', value: r'${= a + 1}'),
        'c': VariableData(id: 'c', name: 'c', value: '1'),
      }),
      {'a', 'b'},
    );
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

  test(
    'separate expression resolves dependencies without changing wire inputs',
    () {
      final VariableData seed = VariableData(
        id: 'seed',
        name: 'seed',
        type: VariableType.integer,
        value: '2',
      );
      final VariableData first = VariableData(
        id: 'first',
        name: 'first',
        type: VariableType.integer,
        value: '99',
        formula: 'seed + 1',
      );
      final VariableData second = VariableData(
        id: 'second',
        name: 'second',
        type: VariableType.integer,
        formula: 'first + 1',
      );
      final VariableData legacy = VariableData(
        id: 'legacy',
        name: 'legacy',
        type: VariableType.integer,
        value: r'${= second + 1}',
      );
      final Map<String, VariableData> original = {
        'legacy': legacy,
        'second': second,
        'first': first,
        'seed': seed,
      };
      expect(ComputedVariables.formulaOf(first), 'seed + 1');
      expect(ComputedVariables.formulaOf(legacy), r'${= second + 1}');
      final VariableData both = VariableData(
        id: 'both',
        name: 'both',
        type: VariableType.integer,
        value: r'${= 100}',
        formula: 'seed + 1',
      );
      expect(ComputedVariables.formulaOf(both), 'seed + 1');
      expect(
        ComputedVariables.resolveAll({
          'seed': seed,
          'both': both,
        })['both']!.getValue(),
        3,
      );
      expect(both.value, r'${= 100}');
      expect(both.formula, 'seed + 1');
      expect(ComputedVariables.inputsOf(first), {'seed'});
      expect(ComputedVariables.inputsOf(second), {'first'});
      expect(ComputedVariables.cyclicNames(original), isEmpty);

      final Map<String, VariableData> resolved = ComputedVariables.resolveAll(
        original,
      );
      expect(resolved['first']!.getValue(), 3);
      expect(resolved['second']!.getValue(), 4);
      expect(resolved['legacy']!.getValue(), 5);
      expect(resolved['first']!.formula, isEmpty);
      expect(resolved['legacy']!.value, '5');
      expect(original['first'], same(first));
      expect(first.value, '99');
      expect(first.formula, 'seed + 1');
      expect(second.value, isEmpty);
      expect(second.formula, 'first + 1');
      expect(legacy.value, r'${= second + 1}');
    },
  );

  test(
    'separate and legacy expressions form cycles and clear preview values',
    () {
      final VariableData a = VariableData(
        id: 'a',
        name: 'a',
        type: VariableType.integer,
        value: '7',
        formula: 'b + 1',
      );
      final VariableData b = VariableData(
        id: 'b',
        name: 'b',
        type: VariableType.integer,
        value: r'${= a + 1}',
      );
      final Map<String, VariableData> variables = {'a': a, 'b': b};
      expect(ComputedVariables.cyclicNames(variables), {'a', 'b'});
      final resolved = ComputedVariables.resolveAll(variables);
      expect(resolved['a']!.value, isEmpty);
      expect(resolved['b']!.value, isEmpty);
      expect(resolved['a']!.getValue(), isNull);
      expect(a.value, '7');
      expect(a.formula, 'b + 1');
      expect(b.value, r'${= a + 1}');
    },
  );

  test(
    'both formula wire forms round-trip and resolve after deserialization',
    () {
      final separate = VariableData.fromJson({
        'id': 'separate',
        'name': 'separate',
        'type': 'integer',
        'value': '',
        'formula': 'base + 1',
      });
      final legacy = VariableData.fromJson({
        'id': 'legacy',
        'name': 'legacy',
        'type': 'integer',
        'formula': r'${= separate + 1}',
      });
      expect(separate.value, isEmpty);
      expect(separate.formula, 'base + 1');
      expect(separate.toJson()['formula'], 'base + 1');
      expect(separate.toJson()['value'], isNull);
      expect(legacy.formula, isEmpty);
      expect(legacy.value, r'${= separate + 1}');
      expect(legacy.toJson()['value'], r'${= separate + 1}');
      expect(legacy.toJson()['formula'], isNull);
      final copied = separate.copyWith(value: '8');
      expect(copied.value, '8');
      expect(copied.formula, 'base + 1');
      final decoded = <String, VariableData>{
        'base': VariableData(
          id: 'base',
          name: 'base',
          type: VariableType.integer,
          value: 2,
        ),
        'separate': VariableData.fromJson(
          jsonDecode(jsonEncode(separate.toJson())),
        ),
        'legacy': VariableData.fromJson(
          jsonDecode(jsonEncode(legacy.toJson())),
        ),
      };
      expect(ComputedVariables.resolveAll(decoded)['legacy']!.getValue(), 4);
      expect(decoded['separate']!.formula, 'base + 1');
      expect(decoded['legacy']!.value, r'${= separate + 1}');
    },
  );

  test('the formula survives the published variables JSON', () {
    final SDKLayoutVariables published = SDKLayoutVariables(
      id: 'layout',
      variables: {
        'canvas': {
          'visible': VariableData(
            id: 'visible',
            name: 'visible',
            type: VariableType.list,
            value: visibleFormula,
          ),
          'separate': VariableData(
            id: 'separate',
            name: 'separate',
            type: VariableType.list,
            formula: ComputedVariables.expressionOf(visibleFormula)!,
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
    final VariableData visible = decoded.variables['canvas']!['visible']!;
    expect(visible.value, visibleFormula);
    expect(visible.isComputed, isTrue);
    final VariableData separate = decoded.variables['canvas']!['separate']!;
    expect(separate.value, isEmpty);
    expect(separate.formula, ComputedVariables.expressionOf(visibleFormula));
    expect(separate.isComputed, isTrue);
    final Map<String, VariableData> resolved = ComputedVariables.resolveAll({
      ...recordsContext().variableNamesMap(),
      'separate': separate,
    });
    expect((resolved['separate']!.getValue() as List).first, {
      'title': 'Apple',
      'crate': 'a',
    });
    expect(separate.formula, ComputedVariables.expressionOf(visibleFormula));
    expect(separate.value, isEmpty);
  });
}
