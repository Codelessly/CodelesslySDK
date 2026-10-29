import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  computedValueTests();

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

Observable<VariableData> variable(
  String name,
  Object? value,
  VariableType type,
) => Observable(VariableData(id: name, name: name, value: value, type: type));

void computedValueTests() {
  late Observable<VariableData> events;
  late CodelesslyContext context;

  setUp(() {
    events = variable('events', [
      {'m': 'PR-102', 'min': 14},
      {'m': 'PR-102', 'min': 23},
      {'m': 'WC-302', 'min': 26},
    ], VariableType.list);
    context = CodelesslyContext.empty()
      ..variables['events'] = events
      ..variables['planned'] = variable('planned', 342, VariableType.integer)
      ..variables['downtime'] = Observable(
        VariableData(
          id: 'downtime',
          name: 'downtime',
          type: VariableType.integer,
          formula: "sum(filter(events, e => e.m == 'PR-102'), 'min')",
        ),
      )
      ..variables['availability'] = Observable(
        VariableData(
          id: 'availability',
          name: 'availability',
          type: VariableType.decimal,
          formula: '(planned - downtime) / planned',
        ),
      )
      ..variables['loopA'] = Observable(
        VariableData(
          id: 'loopA',
          name: 'loopA',
          type: VariableType.integer,
          formula: 'loopB + 1',
        ),
      )
      ..variables['loopB'] = Observable(
        VariableData(
          id: 'loopB',
          name: 'loopB',
          type: VariableType.integer,
          formula: 'loopA + 1',
        ),
      );
  });

  ScopedValues scope() => ScopedValues.preview(
    variables: context.variableNamesMap(),
    codelesslyContext: context,
  );

  test('a computed variable reads as its formula, typed', () {
    expect(
      PropertyValueDelegate.getVariableValueFromPath<int>(
        r'${downtime}',
        scopedValues: scope(),
      ),
      37,
    );
    expect(context.getVariableValue<int>('downtime'), 37);
    // Computed variables can read other computed variables.
    expect(
      PropertyValueDelegate.getVariableValueFromPath<double>(
        r'${availability}',
        scopedValues: scope(),
      ),
      closeTo(305 / 342, 1e-9),
    );
    // And formulas can read them.
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${= fixed(availability * 100, 1)}',
        scopedValues: scope(),
      ),
      '89.2',
    );
  });

  test('a computed choice variable reads as the text its formula gives', () {
    context.variables['worst'] = variable(
      'worst',
      r"${= if(downtime > 30, 'down', 'running')}",
      VariableType.choice,
    );
    expect(context.getVariableValue<String>('worst'), 'down');
  });

  test('it follows changes to what it reads', () {
    // Read once so the results are cached.
    expect(
      context.getVariableValue<double>('availability'),
      closeTo(305 / 342, 1e-9),
    );
    events.value = events.value.copyWith(
      value: [
        {'m': 'PR-102', 'min': 50},
      ],
    );
    expect(context.getVariableValue<int>('downtime'), 50);
    // Including computed variables that read it through another.
    expect(
      context.getVariableValue<double>('availability'),
      closeTo(292 / 342, 1e-9),
    );
  });

  test('a cycle stops instead of overflowing', () {
    // loopA reads loopB, which reads loopA again: that inner read is null,
    // which arithmetic counts as 0, so loopB is 1 and loopA 2.
    expect(context.getVariableValue<int>('loopA'), 2);
  });

  testWidgets('bindings to it listen to the variables its formula reads', (
    tester,
  ) async {
    late BuildContext buildContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              buildContext = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final manager = PassiveNodeTransformerManager(
      (id) => throw StateError(id),
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final listenables = <Listenable>[];
    manager.addVariableListenables(
      context,
      'availability',
      listenables,
      buildContext,
    );
    expect(
      listenables,
      containsAll([
        context.variables['availability'],
        context.variables['planned'],
        context.variables['downtime'],
        events,
      ]),
    );
    // A cycle is walked once.
    final cycle = <Listenable>[];
    manager.addVariableListenables(context, 'loopA', cycle, buildContext);
    expect(cycle.length, 2);
  });

  testWidgets('setting a computed variable leaves its formula alone', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: ActionChainHost(
            child: Builder(
              builder: (c) {
                captured = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    final bool changed = FunctionsRepository.setVariableFromAction(
      captured,
      SetVariableAction(
        variable: VariableData(id: 'downtime', name: 'downtime'),
        newValue: '5',
      ),
    );
    expect(changed, isFalse);
    expect(context.getVariableValue<int>('downtime'), 37);
  });
}
