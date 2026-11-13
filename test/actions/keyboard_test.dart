import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/actions/key_matching.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;

// A screen's key shortcuts don't take keys that type into a focused text
// field.

void main() {
  {
    Node node(List<Map<String, Object?>> reactions) =>
        Node.fromJson({'type': 'box', 'actions': reactions}, id: 'keys')!;
    Map<String, Object?> key(
      String value,
      int amount, {
      String type = 'keyDown',
      String when = '',
    }) => {
      'trigger': {'type': type, 'key': value, if (when.isNotEmpty) 'when': when},
      'actions': [
        {
          'type': 'setVariable',
          'variable': 'count',
          'op': 'add',
          'value': '$amount',
        },
      ],
    };
    VariableScope scope() => VariableScope(const [
      Variable(name: 'count', type: VariableType.integer, value: 0),
      Variable(name: 'enabled', type: VariableType.boolean, value: false),
    ]);
    Future<void> fire(
      Node n,
      VariableScope s,
      String label, {
      bool meta = false,
      bool shift = false,
      bool alt = false,
      String type = 'keyDown',
    }) => const CodelesslyActions().run(
      n,
      type,
      RuntimeActionContext(scope: s, services: Services()),
      event: {
        'result': {'key': label, 'meta': meta, 'shift': shift, 'alt': alt},
      },
    );
    test('a shortcut matches the character a key types, so ? is Shift + /', () async {
      final s = scope();
      final n = node([key('?', 1), key('/', 10)]);
      await const CodelesslyActions().run(n, 'keyDown', RuntimeActionContext(scope: s, services: Services()),
          event: {
            'result': {'key': '/', 'character': '?', 'shift': true, 'meta': false, 'alt': false},
          });
      expect(s.read('count'), 1);
      expect(runtimeKeyEventMatches(KeyCombo.tryParse('u'), 'U', character: 'U', shift: true), isTrue);
      expect(runtimeKeyEventMatches(KeyCombo.tryParse('?'), '/', character: '?', meta: true), isFalse);
      expect(typesText('a'), isTrue);
      expect(typesText('\r'), isFalse);
      expect(typesText(null), isFalse);
    });

    test('a held key repeats only into reactions that ask for repeats', () async {
      final s = scope();
      final n = node([
        key('Arrow Right', 1),
        {...key('Arrow Right', 10), 'trigger': {'type': 'keyDown', 'key': 'Arrow Right', 'repeat': true}},
      ]);
      // The first press runs both.
      await const CodelesslyActions().run(n, 'keyDown', RuntimeActionContext(scope: s, services: Services()),
          event: {'result': {'key': 'Arrow Right', 'repeat': false}});
      expect(s.read('count'), 11);
      // A repeat runs only the one that asked for repeats.
      await const CodelesslyActions().run(n, 'keyDown', RuntimeActionContext(scope: s, services: Services()),
          event: {'result': {'key': 'Arrow Right', 'repeat': true}});
      expect(s.read('count'), 21);
      expect(Trigger.fromJson({'type': 'keyDown', 'repeat': true})!.toJson(), {'type': 'keyDown', 'repeat': true});
      expect(Trigger.fromJson({'type': 'keyDown'})!.repeat, isFalse);
    });

    test(
      'a shortcut with modifiers runs without running the bare key\'s',
      () async {
        final s = scope();
        final n = node([key('z', 1), key('Mod+z', 10), key('Mod+Shift+z', 100)]);
        await fire(n, s, 'Z', meta: true);
        expect(s.read('count'), 10);
        await fire(n, s, 'Z', meta: true, shift: true);
        expect(s.read('count'), 110);
        await fire(n, s, 'Z', alt: true);
        expect(s.read('count'), 110);
      },
    );
    test('each reaction to a key keeps its own condition', () async {
      final s = scope();
      final n = node([
        key('h', 1, when: r'${= enabled}'),
        key('h', 10, when: r'${= !enabled}'),
        key('h', 100, when: r'${= result.key == "H"}'),
      ]);
      await fire(n, s, 'H');
      expect(s.read('count'), 110);
      s.set('enabled', true);
      await fire(n, s, 'H');
      expect(s.read('count'), 211);
    });
  }

  group('while typing', () {
    testWidgets('a letter shortcut waits while a text field has focus, and Escape still runs', (tester) async {
      final s = await lists.show(
        tester,
        {
          'col': {
            'type': 'column',
            'children': ['field'],
            'layout': {'width': 300, 'height': 200},
            'actions': [
              lists.reaction('keyDown', [
                {'type': 'setVariable', 'variable': 'hits', 'op': 'add', 'value': '1'},
              ], extra: {'key': 'c'}),
              lists.reaction('keyDown', [
                {'type': 'setVariable', 'variable': 'escapes', 'op': 'add', 'value': '1'},
              ], extra: {'key': 'Escape'}),
            ],
          },
          'field': {'type': 'textField', 'layout': {'width': 300, 'height': 48}},
        },
        variables: [lists.v('hits', 0, VariableType.integer), lists.v('escapes', 0, VariableType.integer)],
      );
      await tester.pumpAndSettle();
      // No focus: the shortcut runs.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(s['hits'], 1);
      // Typing into the field: the letter is the field's.
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(s['hits'], 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(s['escapes'], 1);
    });
  });
}
