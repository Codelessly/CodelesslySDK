import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  test('one digit runs only its matching reaction', () async {
    final s = scope();
    final n = node([key('1', 1), key('6', 6), key('9', 9)]);
    await fire(n, s, '6');
    expect(s.read('count'), 6);
    await fire(n, s, '4');
    expect(s.read('count'), 6);
  });
  test(
    'modifiers select the matching shortcut without running bare keys',
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
  test('each matching reaction keeps its own when predicate', () async {
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
  test(
    'keyUp is filtered too, and an empty combo remains a wildcard',
    () async {
      final s = scope();
      final n = node([
        key('a', 1, type: 'keyUp'),
        key('b', 10, type: 'keyUp'),
        key('', 100, type: 'keyUp'),
        key('a', 1000),
      ]);
      await fire(n, s, 'A', type: 'keyUp');
      expect(s.read('count'), 101);
    },
  );
  test('shift needed to type punctuation remains compatible', () async {
    final s = scope();
    await fire(node([key('Mod+?', 7)]), s, '?', meta: true, shift: true);
    expect(s.read('count'), 7);
  });
}
