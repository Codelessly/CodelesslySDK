import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart'
    show body, brandRegular, canvas, layoutOf, pumpLayouts, text;

final VariableData tick = VariableData(
  id: 'tick',
  name: 'tick',
  value: 0,
  type: VariableType.integer,
);

Reaction every(int millis, ActionModel action) => Reaction(
  trigger: TriggerModel(type: TriggerType.interval, intervalMillis: millis),
  action: action,
);

SetVariableAction addOne() => SetVariableAction(
  variable: tick,
  newValue: '1',
  numberOperation: NumberOperation.add,
);

/// A screen showing `tick`, whose canvas runs [reactions].
SDKPublishLayout screen(List<Reaction> reactions) {
  final CanvasNode main = canvas('main', 'mainBody')
    ..reactions.addAll(reactions);
  final SDKPublishLayout layout = layoutOf('layout', [
    main,
    body('mainBody', 'main', ['count']),
    text('count', 'mainBody', r'Ticks ${tick}', brandRegular),
  ]);
  return layout;
}

Future<void> pumpScreen(WidgetTester tester, List<Reaction> reactions) async {
  final SDKPublishLayout layout = screen(reactions);
  final Codelessly codelessly = await pumpLayouts(
    tester,
    [layout],
    variables: {
      'main': {tick.id: tick},
    },
  );
  expect(codelessly, isNotNull);
}

void main() {
  testWidgets('an interval reaction runs every period while shown', (
    tester,
  ) async {
    await pumpScreen(tester, [every(1000, addOne())]);
    expect(find.text('Ticks 0'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.text('Ticks 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    expect(find.text('Ticks 4'), findsOneWidget);

    // Leaving the screen stops the timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a slow interval chain skips ticks instead of piling up', (
    tester,
  ) async {
    // Each run waits 2.5 s after counting, so with a 1 s period only one run
    // is in flight at a time.
    await pumpScreen(tester, [
      every(1000, addOne()),
      every(1000, DelayAction(milliseconds: 2500)),
    ]);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.text('Ticks 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    expect(find.text('Ticks 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.text('Ticks 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('reactions with different periods run on their own timers', (
    tester,
  ) async {
    await pumpScreen(tester, [
      every(1000, addOne()),
      every(500, addOne()),
    ]);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    // 2 from the 500 ms timer, 1 from the 1 s timer.
    expect(find.text('Ticks 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
