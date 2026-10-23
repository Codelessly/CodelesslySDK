import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Observable<VariableData> variable(
  String name,
  Object? value,
  VariableType type,
) => Observable(VariableData(id: name, name: name, value: value, type: type));

void main() {
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
      ..variables['downtime'] = variable(
        'downtime',
        r"${= sum(filter(events, e => e.m == 'PR-102'), 'min')}",
        VariableType.integer,
      )
      ..variables['availability'] = variable(
        'availability',
        r'${= (planned - downtime) / planned}',
        VariableType.decimal,
      )
      ..variables['loopA'] = variable(
        'loopA',
        r'${= loopB + 1}',
        VariableType.integer,
      )
      ..variables['loopB'] = variable(
        'loopB',
        r'${= loopA + 1}',
        VariableType.integer,
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

  test('bindings to it listen to the variables its formula reads', () {
    final Set<Listenable> listenables =
        PassiveNodeTransformerManager.variableListenables(
          context,
          'availability',
        ).toSet();
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
    expect(
      PassiveNodeTransformerManager.variableListenables(
        context,
        'loopA',
      ).length,
      2,
    );
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
