import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/actions/runner.dart' show ActionsStopped;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stopped chain (a cancelled purchase) reaches actionError with its code, logging no error', () async {
    final scope = VariableScope(const [Variable(name: 'after', type: VariableType.text, value: '')]);
    final events = <Json>[];
    final errors = <Object>[];
    final context = RuntimeActionContext(
      scope: scope,
      functions: {'buy': (_, _) => throw const ActionsStopped('purchase-cancelled', 'Purchase cancelled')},
      onError: (error, _, _) => errors.add(error),
      onActionErrorEvent: events.add,
    );
    await const CodelesslyActions().run(
      Node.fromJson({
        'type': 'box',
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'callFunction', 'name': 'buy'},
              {'type': 'setVariable', 'variable': 'after', 'value': 'ran'},
            ],
          },
        ],
      }, id: 'buy')!,
      'click',
      context,
    );
    expect(scope.read('after'), '', reason: 'the chain stops');
    expect(errors, isEmpty, reason: 'a person cancelling is not an error');
    expect((events.single['error'] as Map)['code'], 'purchase-cancelled');
    scope.dispose();
  });
}
