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
  });
}
