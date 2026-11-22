// A timer that counts to its end (a short interval, a condition, and a
// reaction that writes a name the condition reads) is said while it runs
// ([ScreenTimers.anyCounting]): what takes a picture of a screen lets it
// arrive. A carousel that turns while it is not paused, a countdown of
// seconds and a clock are not such timers.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

Map<String, Json> _page(int everyMs, String when, String variable, String value) => {
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 100},
        'actions': [
          {
            'trigger': {'type': 'timer', 'intervalMs': everyMs, 'when': when},
            'actions': [
              {'type': 'setVariable', 'variable': variable, 'value': value},
            ],
          },
        ],
      },
    };

void main() {
  testWidgets('a count-up is counting until its condition ends it', (tester) async {
    final s = await harness.show(tester, _page(40, r'${= tick<50}', 'tick', r'${= tick+1}'),
        variables: [harness.v('tick', 0, VariableType.integer)]);
    await tester.pump();
    expect(ScreenTimers.anyCounting, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(s['tick'], inInclusiveRange(8, 11));
    expect(ScreenTimers.anyCounting, isTrue);
    // Let it arrive, as a picture's taker does.
    for (var i = 0; i < 100 && ScreenTimers.anyCounting; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(s['tick'], 50);
    expect(ScreenTimers.anyCounting, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(ScreenTimers.anyCounting, isFalse);
  });

  testWidgets('a carousel, a countdown of seconds and a clock are not', (tester) async {
    // It turns while it is not paused: its condition reads nothing it writes.
    await harness.show(tester, _page(200, r'${= !paused}', 'slide', r'${= slide+1}'),
        variables: [harness.v('paused', false, VariableType.boolean), harness.v('slide', 0, VariableType.integer)]);
    await tester.pump();
    expect(ScreenTimers.anyCounting, isFalse);
    await tester.pumpWidget(const SizedBox());
    // A second at a time.
    await harness.show(tester, _page(1000, r'${= left>0}', 'left', r'${= left-1}'), variables: [harness.v('left', 90, VariableType.integer)]);
    await tester.pump();
    expect(ScreenTimers.anyCounting, isFalse);
    await tester.pumpWidget(const SizedBox());
    // No condition at all.
    await harness.show(tester, _page(100, '', 'n', r'${= n+1}'), variables: [harness.v('n', 0, VariableType.integer)]);
    await tester.pump();
    expect(ScreenTimers.anyCounting, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
