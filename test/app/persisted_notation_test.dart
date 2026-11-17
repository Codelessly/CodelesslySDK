import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';
import '../support/screen.dart' as screen;

void main() {
  testWidgets(
    'saved variable survives pointer and keyboard changes with a named control',
    (tester) async {
      final storage = MemoryLocalStorage();
      const saved = Variable(
        id: 'saved',
        name: 'saved',
        type: VariableType.boolean,
        value: false,
        persist: true,
      );
      final ui = await screen.show(
        tester,
        {
          'col': {
            'type': 'column',
            'layout': {'width': 240, 'height': 100},
            'children': ['save'],
          },
          'save': {
            'type': 'filledButton',
            'props': {'label': 'Save job'},
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {
                    'type': 'setVariable',
                    'variable': 'saved',
                    'value': r'${= !saved}',
                  },
                ],
              },
            ],
          },
        },
        variables: [saved],
      );
      final attached = PersistedVariable.attach(ui.scope, saved, storage);
      addTearDown(attached.dispose);

      await tester.tapAt(ui.center('save'));
      await tester.pump();
      expect(ui['saved'], true);
      expect(storage.get(persistedVariableKey(saved)), true);

      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedId, 'save');
      expect(keys.ringShown, true);
      expect(keys.semantics!.label, 'Save job');
      expect(keys.semantics!.isButton, true);
      await keys.enter();
      expect(ui['saved'], false);
      await keys.space();
      expect(ui['saved'], true);

      final reloaded = VariableScope([saved]);
      final second = PersistedVariable.attach(reloaded, saved, storage);
      expect(reloaded.read('saved'), true);
      second.dispose();
      reloaded.dispose();
    },
  );

  test(
    'obsolete stored shape resets to the declared default and removes the old entry',
    () async {
      const variable = Variable(
        id: 'search',
        name: 'search',
        type: VariableType.map,
        value: {'keyword': '', 'pay': 20},
        persist: true,
      );
      final key = persistedVariableKey(variable);
      final storage = MemoryLocalStorage({
        key: {'keyword': 'kiln', 'pay': 'twenty'},
      });
      final scope = VariableScope([variable]);
      final attached = PersistedVariable.attach(scope, variable, storage);
      expect(scope.read('search'), {'keyword': '', 'pay': 20});
      expect(storage.containsKey(key), false);
      attached.dispose();
      scope.dispose();
    },
  );
}
