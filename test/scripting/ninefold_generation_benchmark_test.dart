// A script near its CPU limit: Ninefold v2 generates an Expert sheet (up to
// 150 random grids, each dug to a unique solution and graded by a
// human-style solver). Runs on the platform's engine (QuickJS on the VM,
// the Web Worker in Chrome: `flutter test --platform chrome`) and prints
// the CPU time per seed, so the script's timeoutMs can be tuned per engine.
@Tags(['benchmark'])
library;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/ninefold_engine.dart';
import 'support/engine_setup.dart';

void main() {
  setUpAll(setUpScriptEngine);

  const engine = ScriptDef(id: 'engine', name: 'engine', source: ninefoldEngine, timeoutMs: 30000);
  const generate = ScriptDef(
    id: 'gen',
    name: 'gen',
    params: [ScriptParam(name: 'seed'), ScriptParam(name: 'level')],
    timeoutMs: 30000,
    source: '''
      const N = await script.engine();
      const g = N.generate(seed, level, 150);
      return {ok: g.ok, attempts: g.attempts, unique: g.ok ? N.countSolutions(g.puzzle, 2).count === 1 : null};
    ''',
  );

  test('generation per level stays within the scripts timeout', () async {
    const runner = SandboxScriptRunner();
    final report = <String>[];
    for (final (level, seeds) in [(1, [1001, 2001]), (2, [1002, 2002]), (3, [1003, 2003]), (4, [1004, 2004, 3004, 4004])]) {
      for (final seed in seeds) {
        final r = await runner.run(generate, args: {'seed': seed, 'level': level}, scripts: const [engine, generate]);
        expect(r.ok, isTrue, reason: '${r.error}');
        final v = r.value! as Map;
        expect(v['unique'], anyOf(isTrue, isNull));
        report.add('level $level seed $seed: ${v['attempts']} grids, ${r.cpuMs.toStringAsFixed(0)} ms CPU');
        expect(r.cpuMs, lessThan(30000));
      }
    }
    // ignore: avoid_print
    print('[$scriptEngineName]\n${report.join('\n')}');
  });
}
