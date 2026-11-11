// ScriptsScope.idle waits until formulas' script calls have answered, for
// screenshots of what bound formulas show.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle completes when every running script call has answered', () async {
    var calls = 0;
    final scope = ScriptsScope(
      scripts: [
        ScriptDef.fromJson({'id': 'slow', 'name': 'slow', 'params': [{'name': 'x'}], 'source': 'return x;'})!,
      ],
      runner: FunctionScriptRunner({
        'slow': (args, _) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return (args['x'] as num) * 2;
        },
      }),
    );
    addTearDown(scope.dispose);
    expect(scope.busy, isFalse);
    expect(scope.callScript('slow', [21]), isNull, reason: 'the first read waits for the worker');
    expect(scope.busy, isTrue);
    await scope.idle();
    expect(scope.busy, isFalse);
    expect(scope.callScript('slow', [21]), 42);
    expect(calls, 1);
  });

  test('idle gives up after its timeout', () async {
    final scope = ScriptsScope(
      scripts: [ScriptDef.fromJson({'id': 'never', 'name': 'never', 'source': 'return 1;'})!],
      runner: FunctionScriptRunner({'never': (args, _) => Future<Object?>.delayed(const Duration(seconds: 5), () => 1)}),
    );
    scope.callScript('never', const []);
    final watch = Stopwatch()..start();
    await scope.idle(timeout: const Duration(milliseconds: 50));
    expect(watch.elapsedMilliseconds, lessThan(1000));
    expect(scope.busy, isTrue);
  });
}
