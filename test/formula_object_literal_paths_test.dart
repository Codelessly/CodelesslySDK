import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The formula a crate digger counts plays with: an object literal inside a
/// lambda inside `${= }`.
const String countPlay =
    r'${= map(records, r => r.id == x ? merge(r, {plays: r.plays + 1}) : r)}';

const List<Map<String, Object>> crate = [
  {'id': 'a', 'plays': 1},
  {'id': 'b', 'plays': 4},
];

CodelesslyContext crateContext() => CodelesslyContext.empty()
  ..variables['records'] = Observable(
    VariableData(
      id: 'records',
      name: 'records',
      type: VariableType.list,
      value: jsonEncode(crate),
    ),
  )
  ..variables['x'] = Observable(
    VariableData(id: 'x', name: 'x', type: VariableType.text, value: 'b'),
  )
  ..variables['label'] = Observable(
    VariableData(id: 'label', name: 'label', type: VariableType.text),
  );

Future<BuildContext> pumpContext(
  WidgetTester tester,
  CodelesslyContext codelesslyContext,
) async {
  late BuildContext captured;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

List<Object?> recordsOf(CodelesslyContext c) {
  final Object? value = c.variables['records']!.value.getValue();
  return value is String ? jsonDecode(value) as List : value as List;
}

void main() {
  test('The regexes keep a formula with object literals whole', () {
    expect(exactFormulaRegex.hasMatch(countPlay), isTrue);
    expect(FormulaEvaluator.exactExpression(countPlay), isNotNull);
    expect(formulaRegex.firstMatch('n: $countPlay!')!.group(0), countPlay);
  });

  testWidgets('A set variable action takes an object literal formula', (
    tester,
  ) async {
    final CodelesslyContext c = crateContext();
    final BuildContext context = await pumpContext(tester, c);
    final bool set = FunctionsRepository.setVariableFromAction(
      context,
      SetVariableAction(
        variable: VariableData(
          id: 'records',
          name: 'records',
          type: VariableType.list,
        ),
        newValue: countPlay,
      ),
    );
    expect(set, isTrue);
    expect(recordsOf(c), [
      {'id': 'a', 'plays': 1},
      {'id': 'b', 'plays': 5},
    ]);
  });

  testWidgets('A text variable set to text around such a formula', (
    tester,
  ) async {
    final CodelesslyContext c = crateContext();
    final BuildContext context = await pumpContext(tester, c);
    FunctionsRepository.setVariableFromAction(
      context,
      SetVariableAction(
        variable: VariableData(
          id: 'label',
          name: 'label',
          type: VariableType.text,
        ),
        newValue: r'Plays: ${= merge({n: 2}, {n: 3}).n} of ${x}',
      ),
    );
    expect(c.variables['label']!.value.value, 'Plays: 3 of b');
  });

  testWidgets('A property binding and a text read such a formula', (
    tester,
  ) async {
    final CodelesslyContext c = crateContext();
    final BuildContext context = await pumpContext(tester, c);
    final ScopedValues scopedValues = ScopedValues.of(context);
    final TextNode text = TextNode(
      id: 'count',
      name: 'count',
      basicBoxLocal: NodeBox(0, 0, 100, 20),
      data: '',
      variables: {
        'data': countPlay,
      },
    );
    final List? mapped = PropertyValueDelegate.getPropertyValue<List>(
      text,
      'data',
      scopedValues: scopedValues,
    );
    expect(mapped, [
      {'id': 'a', 'plays': 1},
      {'id': 'b', 'plays': 5},
    ]);
    text.variables['data'] =
        r'${= count(filter('
            r'map(records, r => merge(r, {hot: r.plays > 2})), '
            r'r => r.hot))} hot';
    expect(
      PropertyValueDelegate.substituteVariables(
        text.variables['data']!,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
        scopedValues: scopedValues,
      ),
      '1 hot',
    );
  });

  test('Variable syntax matches keep such a formula whole', () {
    expect(
      [
        for (final m in variableSyntaxIdentifierRegex.allMatches(
          'Played $countPlay times by \${user.name}',
        ))
          m[0],
      ],
      [countPlay, r'${user.name}'],
    );
    expect(countPlay.wrapWithVariableSyntax(), countPlay);
    expect(countPlay.containsUncheckedVariablePath, isTrue);
    // A quoted brace doesn't end it either, and a path still matches alone.
    expect(
      variableSyntaxIdentifierRegex.firstMatch(r"${= '}' + x} ${y}")![0],
      r"${= '}' + x}",
    );
  });

  test('The variables an action or binding reads include its formula', () {
    final RectangleNode node = RectangleNode(
      id: 'row',
      name: 'row',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: SetVariableAction(
            variable: VariableData(
              id: 'records',
              name: 'records',
              type: VariableType.list,
            ),
            newValue: countPlay,
          ),
        ),
      ],
    )..variables['visible'] = r'${= count(filter(crate, c => c.on)) > 0}';
    expect(node.getUsedVariableNames(), {'records', 'x', 'crate'});
  });
}
