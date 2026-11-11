// Petri v2's stress test, measured: a clock tick runs the `advance` script
// (a Life generation over 2,304 cells, written back through vars.set), and
// the grid of 2,304 bound cells rebuilds. Prints ms per tick for the
// script (QuickJS on the VM, the Web Worker in Chrome) and for the frame.
//
//   flutter test test/bench/petri_tick_bench_test.dart
//   flutter test --platform chrome test/bench/petri_tick_bench_test.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripting/support/engine_setup.dart';
import 'petri_bundle.dart';

Map<String, Object?> get _bundle => jsonDecode(petriBundleJson) as Map<String, Object?>;

List<Variable> appVariables() => [
      for (final v in ((_bundle['model'] as Map)['variables'] as Map).values) Variable.fromJson(v)!,
    ];

List<ScriptDef> scripts() => ScriptDef.listFromJson(((_bundle['layouts'] as Map).values.first as Map)['scripts']);

void main() {
  setUpAll(setUpScriptEngine);

  test('script time per tick: advance (lifeStep over 2,304 cells)', () async {
    final scope = VariableScope(appVariables());
    final errors = <Object>[];
    final context = RuntimeActionContext(
      scope: scope,
      services: Services(),
      scripts: scripts(),
      onError: (e, s, a) => errors.add(e is ActionFailed ? e.error : e),
    );
    final node = Node.fromJson({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': [{'type': 'runScript', 'script': 'advance'}]},
      ],
    }, id: 'n')!;
    Future<void> tick() => const CodelesslyActions().run(node, 'click', context);
    for (var i = 0; i < 5; i++) {
      await tick(); // warm up
    }
    const n = 60;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      await tick();
    }
    sw.stop();
    expect(errors, isEmpty);
    expect(scope.read('gen'), 65);
    // ignore: avoid_print
    print('[bench] $scriptEngineName advance: ${(sw.elapsedMicroseconds / n / 1000).toStringAsFixed(2)} ms per tick');
  });

  /// One Conway generation on the 48×48 torus (the script's rule, in Dart).
  List<int> life(List<int> c) => [
        for (var i = 0; i < 2304; i++)
          () {
            final x = i % 48, y = i ~/ 48;
            var n = 0;
            for (var dy = -1; dy <= 1; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                if ((dx != 0 || dy != 0) && c[((y + dy + 48) % 48) * 48 + (x + dx + 48) % 48] == 1) n++;
              }
            }
            return (c[i] == 1 ? (n == 2 || n == 3) : n == 3) ? 1 : 0;
          }(),
      ];

  Future<void> frames(WidgetTester tester, String label, List<int> Function(int i, List<int> current) next) async {
    final bundle = PublishBundle.fromJson(_bundle);
    final codelessly = Codelessly.fromBundle(bundle);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
    await tester.pumpAndSettle();
    final scope = codelessly.appVariables;
    var cells = (scope.read('cells') as List).cast<int>();
    const n = int.fromEnvironment('BENCH_N', defaultValue: 30);
    final times = <int>[];
    final phases = [0, 0, 0, 0];
    for (var i = 0; i < n; i++) {
      cells = next(i, cells);
      final binding = tester.binding;
      final sw = Stopwatch()..start();
      scope.set('cells', cells);
      final t0 = sw.elapsedMicroseconds;
      binding.buildOwner!.buildScope(binding.rootElement!);
      final t1 = sw.elapsedMicroseconds;
      binding.rootPipelineOwner.flushLayout();
      final t2 = sw.elapsedMicroseconds;
      binding.rootPipelineOwner.flushCompositingBits();
      binding.rootPipelineOwner.flushPaint();
      final t3 = sw.elapsedMicroseconds;
      phases[0] += t0;
      phases[1] += t1 - t0;
      phases[2] += t2 - t1;
      phases[3] += t3 - t2;
      times.add(t3);
      await tester.pump();
    }
    times.sort();
    String ms(int us) => (us / n / 1000).toStringAsFixed(2);
    // ignore: avoid_print
    print('[bench] $label: frame median ${(times[n ~/ 2] / 1000).toStringAsFixed(2)} ms, max ${(times.last / 1000).toStringAsFixed(2)} ms '
        '(set ${ms(phases[0])} build ${ms(phases[1])} layout ${ms(phases[2])} paint ${ms(phases[3])})');
  }

  testWidgets('frame time per tick: Life generations over 2,304 bound cells', (tester) async {
    await frames(tester, 'life tick', (i, c) => life(c));
  });

  testWidgets('frame time per tick: the whole board changes (seed, clear)', (tester) async {
    final rng = math.Random(1);
    await frames(tester, 'whole board', (i, c) => [for (var k = 0; k < 2304; k++) rng.nextDouble() < 0.3 ? 1 : 0]);
  });
}
