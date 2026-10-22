import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

/// A screen whose interval reaction runs [action] every [intervalMs].
List<BaseNode> tickingScreen(ActionModel action, {int intervalMs = 1000}) => [
  canvas('main', 'mainBody')
    ..reactions = [
      Reaction(
        action: action,
        trigger: TriggerModel(
          type: TriggerType.interval,
          intervalMs: intervalMs,
        ),
      ),
    ],
  body('mainBody', 'main', []),
];

void main() {
  testWidgets('an interval reaction runs on every tick while the screen '
      'shows and stops when it leaves', (tester) async {
    int ticks = 0;
    await pumpLayouts(
      tester,
      [
        layoutOf(
          'layout',
          tickingScreen(CallFunctionAction(name: 'tick'), intervalMs: 500),
        ),
      ],
      functions: {'tick': (context, reference, params) => ticks++},
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(ticks, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(ticks, 1);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(ticks, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(ticks, 3);
  });

  testWidgets('a tick is skipped while the previous run is still awaited', (
    tester,
  ) async {
    int ticks = 0;
    await pumpLayouts(
      tester,
      [
        layoutOf(
          'layout',
          tickingScreen(CallFunctionAction(name: 'slow'), intervalMs: 100),
        ),
      ],
      functions: {
        'slow': (context, reference, params) {
          ticks++;
          return Future<void>.delayed(const Duration(milliseconds: 350));
        },
      },
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, 1);
    // Ticks at 200, 300 and 400 ms find the first run still awaited.
    await tester.pump(const Duration(milliseconds: 300));
    expect(ticks, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
