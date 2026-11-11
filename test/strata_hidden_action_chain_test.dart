import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

Future<support.Screen> setup(WidgetTester tester) => support.show(
  tester,
  {
    'col': {
      'type': 'stack',
      'layout': {'width': 200, 'height': 400},
      'children': ['panel'],
    },
    'panel': {
      'type': 'column',
      'layout': {'width': 200, 'height': 400},
      'bind': {'visible': r'${shown}'},
      'children': ['button'],
    },
    'button': {
      'type': 'box',
      'layout': {'width': 100, 'height': 40},
      'actions': [
        support.reaction('click', [
          {'type': 'setVariable', 'variable': 'shown', 'value': 'false'},
          {'type': 'delay', 'ms': 100},
          {'type': 'setVariable', 'variable': 'done', 'value': 'true'},
        ]),
      ],
    },
  },
  variables: [support.v('shown', true, VariableType.boolean), support.v('done', false, VariableType.boolean)],
);
void main() {
  testWidgets('a reaction finishes after hiding its own tab', (tester) async {
    final s = await setup(tester);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(s['shown'], false);
    expect(s.tree.boxOf('button')!.attached, false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(s['done'], true);
  });
  testWidgets('disposing the screen still cancels a retained reaction', (tester) async {
    final s = await setup(tester);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    s.reactions.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(s['done'], false);
  });
}
