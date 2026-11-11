// A slider whose value and range are all bound: the value lands within the
// bound range (not clamped to the default 0–10 first).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

void main() {
  for (final interactive in [true, false]) {
    testWidgets('a bound value 12 in a bound 2–50 range (interactive: $interactive)', (tester) async {
      await show(
        tester,
        {
          'col': {'type': 'column', 'children': ['s'], 'layout': {'width': 300, 'height': 100}},
          's': {
            'type': 'slider',
            'layout': {'width': 300, 'height': 28},
            'props': {'value': 0, 'min': 0, 'max': 10},
            'bind': {
              'props.value': r'${f.numValue}',
              'props.min': r'${f.min}',
              'props.max': r'${f.max}',
              'props.divisions': r'${= round(f.max - f.min)}',
            },
          },
        },
        variables: [v('f', {'numValue': 12.0, 'min': 2.0, 'max': 50.0}, VariableType.map)],
        interactive: interactive,
      );
      await tester.pumpAndSettle();
      final s = tester.widget<Slider>(find.byType(Slider));
      expect((s.min, s.max, s.value), (2.0, 50.0, 12.0));
    });
  }
}
