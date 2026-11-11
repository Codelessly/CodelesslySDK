// A switch that is off can't be toggled; a controlled one shows only its
// bound value, its reactions deciding.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

Map<String, Json> _screen(Map<String, Object?> props, {List<Json> actions = const []}) => {
  'col': {
    'type': 'column',
    'children': ['sw'],
    'layout': {'width': 300, 'height': 100},
  },
  'sw': {
    'type': 'switch',
    'layout': {'width': 60, 'height': 40},
    'bind': {'props.value': r'${on}'},
    'props': props,
    'actions': [if (actions.isNotEmpty) reaction('changed', actions)],
  },
};

void main() {
  testWidgets('a disabled switch ignores taps', (tester) async {
    final s = await show(
      tester,
      _screen(
        {'enabled': false},
        actions: [
          {'type': 'setVariable', 'variable': 'on', 'value': r'${result}'},
        ],
      ),
      variables: [v('on', false, VariableType.boolean)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(s['on'], false);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });

  testWidgets('a controlled switch only shows what its reactions set', (tester) async {
    final s = await show(
      tester,
      _screen(
        {'controlled': true},
        actions: [
          {'type': 'setVariable', 'variable': 'taps', 'op': 'add', 'value': '1'},
        ],
      ),
      variables: [v('on', false, VariableType.boolean), v('taps', 0, VariableType.integer)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(s['taps'], 1);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
    s.scope.set('on', true);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
  });
}
