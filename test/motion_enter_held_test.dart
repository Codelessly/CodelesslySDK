// An entrance held until its page settles (`motion.enterHeld`, bound), and
// replayed when `motion.replayKey` changes.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart' as support;

void main() {
  test('enterHeld round-trips', () {
    final m = api.Motion.fromJson({'enter': true, 'enterFrom': {'translateY': 40}, 'enterHeld': true})!;
    expect(m.enterHeld, isTrue);
    expect(m.toJson()['enterHeld'], true);
    expect(api.Motion.fromJson({'enter': true})!.enterHeld, isFalse);
  });

  testWidgets('a held entrance waits at its start, plays when released, and does not hold again', (tester) async {
    final screen = await support.show(
      tester,
      {
        'col': {'type': 'stack', 'children': ['m'], 'layout': {'width': 400, 'height': 300}},
        'm': {
          'type': 'box',
          'layout': {'width': 40, 'height': 20, 'x': {'start': 0}, 'y': {'start': 100}},
          'motion': {
            'enter': true,
            'enterFrom': {'translateX': -100, 'opacity': 0},
            'duration': 1000,
            'curve': 'linear',
          },
          'bind': {'motion.enterHeld': r'${= !settled}', 'motion.replayKey': r'${visit}'},
        },
      },
      variables: [support.v('settled', false, api.VariableType.boolean), support.v('visit', 'a')],
    );
    final view = tester.renderObject(find.byType(NodeView));
    double left() => screen.tree.boxOf('m')!.rectIn(view)!.left;
    await tester.pump(const Duration(milliseconds: 1500));
    expect(left(), -100, reason: 'held at the start');
    screen.scope.set('settled', true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(left(), closeTo(-50, 2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(left(), 0);
    // Holding again doesn't send it back.
    screen.scope.set('settled', false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(left(), 0);
    // A new replay key plays the entrance again.
    screen.scope.set('settled', true);
    await tester.pump();
    screen.scope.set('visit', 'b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(left(), closeTo(-75, 2));
    await tester.pumpAndSettle();
    expect(left(), 0);
  });
}
