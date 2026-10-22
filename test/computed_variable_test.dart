import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart'
    show body, brandRegular, button, canvas, layoutOf, pumpLayouts, text;

final VariableData level = VariableData(
  id: 'level',
  name: 'level',
  value: 0.87,
  type: VariableType.decimal,
);
final VariableData limit = VariableData(
  id: 'limit',
  name: 'limit',
  value: 0.75,
  type: VariableType.decimal,
);
final VariableData over = VariableData(
  id: 'over',
  name: 'over',
  type: VariableType.boolean,
  formula: 'level > limit',
);
final VariableData label = VariableData(
  id: 'label',
  name: 'label',
  formula: "if(over, 'ALERT ' + round(level * 100) + '%', 'OK')",
);
final VariableData alerts = VariableData(
  id: 'alerts',
  name: 'alerts',
  type: VariableType.list,
  formula: "filter([object('id', 'black', 'on', over)], a => a.on)",
);
final VariableData loop = VariableData(
  id: 'loop',
  name: 'loop',
  type: VariableType.integer,
  formula: 'loop + 1',
);

SetVariableAction setLimit(String value) =>
    SetVariableAction(variable: limit, newValue: value);

Future<void> pumpScreen(WidgetTester tester) => pumpLayouts(
  tester,
  [
    layoutOf('layout', [
      canvas('main', 'mainBody'),
      body('mainBody', 'main', ['status', 'count', 'raise', 'lower', 'cycle']),
      text('status', 'mainBody', r'Status ${label}', brandRegular),
      text('count', 'mainBody', r'Alerts ${= length(alerts)}', brandRegular),
      button('raise', 'mainBody', 'Raise', setLimit('0.9')),
      button('lower', 'mainBody', 'Lower', setLimit('0.5')),
      text('cycle', 'mainBody', r'Loop [${loop}]', brandRegular),
    ]),
  ],
  variables: {
    'main': {
      for (final v in [level, limit, over, label, alerts, loop]) v.id: v,
    },
  },
);

void main() {
  testWidgets('computed variables follow the variables their formulas read', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Status ALERT 87%'), findsOneWidget);
    expect(find.text('Alerts 1'), findsOneWidget);

    // Raising the limit clears the alert everywhere, through two levels of
    // computed variables.
    await tester.tap(find.text('Raise'));
    await tester.pumpAndSettle();
    expect(find.text('Status OK'), findsOneWidget);
    expect(find.text('Alerts 0'), findsOneWidget);

    await tester.tap(find.text('Lower'));
    await tester.pumpAndSettle();
    expect(find.text('Status ALERT 87%'), findsOneWidget);
  });

  testWidgets('a formula that reads its own variable stops, not hangs', (
    tester,
  ) async {
    await pumpScreen(tester);
    // The inner read of `loop` is null (0 in arithmetic), so loop + 1 is 1.
    expect(find.text('Loop [1]'), findsOneWidget);
  });

  testWidgets('setting a computed variable is ignored', (tester) async {
    await pumpScreen(tester);
    final BuildContext context = tester.element(find.text('Raise'));
    expect(
      FunctionsRepository.setVariableFromAction(
        context,
        SetVariableAction(variable: over, newValue: 'false'),
      ),
      isFalse,
    );
    await tester.pump();
    expect(find.text('Status ALERT 87%'), findsOneWidget);
  });
}
