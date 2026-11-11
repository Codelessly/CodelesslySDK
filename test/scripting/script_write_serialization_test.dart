import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

const writer = ScriptDef(
  id: 'write',
  name: 'write',
  source: '',
  capabilities: [
    ScriptCapability.variablesRead,
    ScriptCapability.variablesWrite,
  ],
);

VariableScope scope([ValueScope? parent]) => VariableScope(const [
  Variable(name: 'count', type: VariableType.integer, value: 0),
], parent: parent);
Node button(String script) => Node.fromJson({
  'type': 'box',
  'actions': [
    {
      'trigger': {'type': 'click'},
      'actions': [
        {'type': 'runScript', 'script': script},
      ],
    },
  ],
}, id: script)!;
Future<void> click(
  RuntimeActionContext context,
  String script, {
  ActionCancellation? cancellation,
}) => const CodelesslyActions().run(
  button(script),
  'click',
  context,
  cancellation: cancellation,
);

void main() {
  test(
    'overlapping writers read the latest committed snapshot across child scopes',
    () async {
      final app = scope();
      final entered = Completer<void>(), release = Completer<void>();
      final snapshots = <int>[];
      final runner = FunctionScriptRunner({
        'write': (_, host) async {
          final before = host!.variables()['count'] as int;
          snapshots.add(before);
          if (snapshots.length == 1) {
            entered.complete();
            await release.future;
          }
          host.setVariable('count', before + 1);
          return before + 1;
        },
      });
      RuntimeActionContext context() => RuntimeActionContext(
        scope: VariableScope(const [], parent: app),
        services: Services(scripts: runner),
        scripts: const [writer],
      );
      final first = click(context(), 'write');
      await entered.future;
      final second = click(context(), 'write');
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait([first, second]);
      expect(snapshots, [0, 1]);
      expect(app.read('count'), 2);
    },
  );

  test('independent app scopes run concurrently', () async {
    final firstEntered = Completer<void>(),
        secondEntered = Completer<void>(),
        release = Completer<void>();
    var calls = 0;
    final runner = FunctionScriptRunner({
      'write': (_, host) async {
        if (++calls == 1) {
          firstEntered.complete();
          await release.future;
        } else {
          secondEntered.complete();
        }
        host!.setVariable('count', 1);
        return 1;
      },
    });
    RuntimeActionContext context() => RuntimeActionContext(
      scope: scope(),
      services: Services(scripts: runner),
      scripts: const [writer],
    );
    final first = click(context(), 'write');
    await firstEntered.future;
    final second = click(context(), 'write');
    await secondEntered.future.timeout(const Duration(seconds: 2));
    release.complete();
    await Future.wait([first, second]);
  });

  test('read-only scripts remain concurrent with a waiting writer', () async {
    const reader = ScriptDef(
      id: 'read',
      name: 'read',
      source: '',
      capabilities: [ScriptCapability.variablesRead],
    );
    final entered = Completer<void>(), release = Completer<void>();
    final runner = FunctionScriptRunner({
      'write': (_, host) async {
        entered.complete();
        await release.future;
        host!.setVariable('count', 1);
        return 1;
      },
      'read': (_, host) => host!.variables()['count'],
    });
    final app = scope();
    final context = RuntimeActionContext(
      scope: app,
      services: Services(scripts: runner),
      scripts: const [writer, reader],
    );
    final pending = click(context, 'write');
    await entered.future;
    await click(context, 'read').timeout(const Duration(seconds: 2));
    expect(app.read('count'), 0);
    release.complete();
    await pending;
    expect(app.read('count'), 1);
  });

  test(
    'canceled queued writes do not execute or stall the next write',
    () async {
      final app = scope(),
          entered = Completer<void>(),
          release = Completer<void>();
      var calls = 0;
      final runner = FunctionScriptRunner({
        'write': (_, host) async {
          calls++;
          if (calls == 1) {
            entered.complete();
            await release.future;
          }
          final n = host!.variables()['count'] as int;
          host.setVariable('count', n + 1);
          return n + 1;
        },
      });
      final context = RuntimeActionContext(
        scope: app,
        services: Services(scripts: runner),
        scripts: const [writer],
      );
      final first = click(context, 'write');
      await entered.future;
      final cancellation = ActionCancellation();
      final canceled = click(context, 'write', cancellation: cancellation);
      cancellation.cancel();
      final third = click(context, 'write');
      release.complete();
      await Future.wait([first, canceled, third]);
      expect(calls, 2);
      expect(app.read('count'), 2);
    },
  );

  test('nested host actions can run a writer without queue deadlock', () async {
    const outer = ScriptDef(
      id: 'outer',
      name: 'outer',
      source: '',
      capabilities: [ScriptCapability.variablesWrite, ScriptCapability.actions],
    );
    final runner = FunctionScriptRunner({
      'outer': (_, host) async {
        await host!.call('runAction', [
          {
            'type': 'forEach',
            'items': r'${= [1]}',
            'actions': [
              {'type': 'runScript', 'script': 'write'},
            ],
          },
        ]);
        return true;
      },
      'write': (_, host) {
        host!.setVariable('count', 1);
        return 1;
      },
    });
    final app = scope();
    final context = RuntimeActionContext(
      scope: app,
      services: Services(scripts: runner),
      scripts: const [outer, writer],
    );
    await click(context, 'outer').timeout(const Duration(seconds: 2));
    expect(app.read('count'), 1);
  });
}
