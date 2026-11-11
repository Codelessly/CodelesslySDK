import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> write(VariableScope scope, String formula, {ActionCancellation? cancellation}) => const CodelesslyActions().run(
  Node.fromJson({
    'type': 'box',
    'actions': [
      {
        'trigger': {'type': 'click'},
        'actions': [
          {'type': 'setVariable', 'variable': 'rows', 'value': formula},
        ],
      },
    ],
  }, id: 'tap')!,
  'click',
  RuntimeActionContext(scope: scope),
  cancellation: cancellation,
);
void main() {
  test('a cancelled pending worker cannot overwrite the destination', () async {
    final result = Completer<Object?>();
    final scripts = ScriptsScope(scripts: const [ScriptDef(id: 'next', name: 'next')],
      runner: FunctionScriptRunner({'next': (_, _) => result.future}));
    final vars = VariableScope(const [Variable(name: 'rows', type: VariableType.list, value: [1])], parent: scripts);
    scripts.reader = vars;
    final cancellation = ActionCancellation();
    final running = write(vars, r'${= script.next()}', cancellation: cancellation);
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    result.complete([2]);
    await running;
    expect(vars.read('rows'), [1]);
    vars.dispose();
    scripts.dispose();
  });
  test('script-backed writes keep the old list until the asynchronous result arrives', () async {
    final result = Completer<Object?>();
    final scripts = ScriptsScope(
      scripts: const [ScriptDef(id: 'next', name: 'next')],
      runner: FunctionScriptRunner({'next': (_, _) => result.future}),
    );
    final vars = VariableScope(const [
      Variable(name: 'rows', type: VariableType.list, value: [1]),
    ], parent: scripts);
    scripts.reader = vars;
    final running = write(vars, r'${= script.next()}');
    await Future<void>.delayed(Duration.zero);
    expect(vars.read('rows'), [1]);
    result.complete([1, 2]);
    await running;
    expect(vars.read('rows'), [1, 2]);
    scripts.dispose();
    vars.dispose();
  });
  test('a failed asynchronous script leaves existing data intact', () async {
    final scripts = ScriptsScope(
      scripts: const [ScriptDef(id: 'bad', name: 'bad')],
      runner: FunctionScriptRunner({'bad': (_, _) async => throw StateError('failed')}),
    );
    final vars = VariableScope(const [
      Variable(name: 'rows', type: VariableType.list, value: [1]),
    ], parent: scripts);
    scripts.reader = vars;
    await write(vars, r'${= script.bad()}');
    expect(vars.read('rows'), [1]);
    scripts.dispose();
    vars.dispose();
  });
  test('nested asynchronous formulas settle before the write', () async {
    final scripts = ScriptsScope(
      scripts: const [
        ScriptDef(id: 'inner', name: 'inner'),
        ScriptDef(
          id: 'outer',
          name: 'outer',
          params: [ScriptParam(name: 'n')],
        ),
      ],
      runner: FunctionScriptRunner({
        'inner': (_, _) async => 2,
        'outer': (a, _) async => [a['n']],
      }),
    );
    final vars = VariableScope(const [
      Variable(name: 'rows', type: VariableType.list, value: [1]),
    ], parent: scripts);
    scripts.reader = vars;
    await write(vars, r'${= script.outer(script.inner())}');
    expect(vars.read('rows'), [2]);
    scripts.dispose();
    vars.dispose();
  });
}
