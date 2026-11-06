import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'interaction_states_test.dart' show Harness, cardWithDot, fillPatch;

void main() {
  for (final int transitionMs in [0, 150]) {
    testWidgets('a button hovered for a while still takes the tap '
        '(pressed scales it, transition $transitionMs ms)', (tester) async {
      final (:card, :dot) = cardWithDot();
      card.interactionStates = {
        InteractionState.hovered: {'card': fillPatch('#FF0000')},
        InteractionState.pressed: {
          'card': {'drawScale': 0.97},
        },
      };
      card.transitionMs = transitionMs;
      final harness = Harness();
      await harness.pump(tester, [card, dot]);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(500, 500));
      await mouse.moveTo(const Offset(150, 50));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await mouse.down(const Offset(150, 50));
      await tester.pump(const Duration(milliseconds: 120));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(harness.taps, ['tap']);
    });
  }
}
