// An input island follows its bindings when a variable changes after the
// first build, on a running screen and on a design canvas alike (the
// editor's design capture sets preview values, then captures).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

void main() {
  for (final interactive in [true, false]) {
    testWidgets('a radio and a slider follow a changed variable (interactive: $interactive)', (tester) async {
      final s = await show(
        tester,
        {
          'col': {'type': 'column', 'children': ['r', 's'], 'layout': {'width': 300, 'height': 100}},
          'r': {
            'type': 'radio',
            'layout': {'width': 18, 'height': 18},
            'props': {'value': 'Team'},
            'bind': {'props.groupValue': r'${plan}'},
          },
          's': {
            'type': 'slider',
            'layout': {'width': 300, 'height': 28},
            'props': {'value': 0, 'min': 0, 'max': 50},
            'bind': {'props.value': r'${size}'},
          },
        },
        variables: [v('plan', ''), v('size', 0.0, VariableType.decimal)],
        interactive: interactive,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, '');
      s.scope.set('plan', 'Team');
      s.scope.set('size', 12.0);
      await tester.pumpAndSettle();
      expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, 'Team');
      expect(tester.widget<Slider>(find.byType(Slider)).value, 12.0);
    });
  }

  for (final restarts in [true, false])
  testWidgets('a board that rests its islands restarts them on a new value (restarts: $restarts)', (tester) async {
    final s = await show(
      tester,
      {
        'col': {'type': 'column', 'children': ['s'], 'layout': {'width': 300, 'height': 100}},
        's': {
          'type': 'slider',
          'layout': {'width': 300, 'height': 28},
          'props': {'value': 0, 'min': 0, 'max': 50},
          'bind': {'props.value': r'${size}'},
        },
      },
      variables: [v('size', 0.0, VariableType.decimal)],
      interactive: false,
    );
    s.tree.islands.environment = IslandEnvironment(
      wrap: (child) => TickerMode(enabled: false, child: child),
      restartsWhenRebuilt: restarts,
    );
    await tester.pumpAndSettle();
    final before = tester.state(find.byType(Slider));
    s.scope.set('size', 12.0);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 12.0);
    // Restarted, the slider's state (and its thumb animation) is new, at 12.
    expect(identical(tester.state(find.byType(Slider)), before), !restarts);
  });

  testWidgets('a compact radio scales its ring to its box', (tester) async {
    for (final compact in [false, true]) {
      await show(tester, {
        'col': {'type': 'column', 'children': ['r'], 'layout': {'width': 100, 'height': 100}},
        'r': {'type': 'radio', 'layout': {'width': 18, 'height': 18}, 'props': {'value': 'a', 'compact': compact}},
      });
      await tester.pumpAndSettle();
      final scales = tester
          .widgetList<Transform>(find.ancestor(of: find.byType(Radio<String>), matching: find.byType(Transform)))
          .map((t) => double.parse(t.transform.storage[0].toStringAsFixed(4)));
      expect(scales, contains(compact ? 1.0 : 0.5625));
      if (compact) expect(scales, isNot(contains(0.5625)));
    }
  });
}
