import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  testWidgets('a hug text can change while its tab is collapsed', (tester) async {
    final s = await support.show(
      tester,
      {
        'col': {
          'type': 'stack',
          'layout': {'width': 200, 'height': 400},
          'children': ['tab'],
        },
        'tab': {
          'type': 'column',
          'layout': {'width': 200, 'height': 400},
          'bind': {'visible': r'${shown}'},
          'children': ['inner'],
        },
        'inner': {
          'type': 'column',
          'layout': {
            'width': {'fill': 200},
            'height': {'hug': 100},
          },
          'children': ['label'],
        },
        'label': {
          'type': 'text',
          'layout': {
            'width': {'fill': 200},
            'height': {'hug': 100},
          },
          'props': {'text': r'${title}'},
          'actions': [
            support.reaction(
              'timer',
              [
                {'type': 'setVariable', 'variable': 'ticks', 'op': 'add', 'value': '1'},
              ],
              extra: {'intervalMs': 50},
            ),
          ],
        },
      },
      variables: [
        support.v('shown', true, VariableType.boolean),
        support.v('title', 'Specimen'),
        support.v('ticks', 0, VariableType.integer),
      ],
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(s['ticks'], greaterThan(0));
    setVariableIn(s.scope, 'shown', false);
    await tester.pump();
    final hiddenTicks = s['ticks'];
    setVariableIn(s.scope, 'title', 'A much longer specimen title that wraps across lines');
    await tester.pump();
    expect(tester.takeException(), isNull);
    setVariableIn(s.scope, 'title', 'Another specimen while the tab remains hidden');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect(s['ticks'], hiddenTicks, reason: 'hidden tab timers pause');
    setVariableIn(s.scope, 'shown', true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(s['ticks'] as int, greaterThan(hiddenTicks as int));
    expect(s.tree.boxOf('label')!.attached, isTrue);
    expect(tester.takeException(), isNull);
  });
}
