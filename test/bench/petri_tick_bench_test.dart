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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../scripting/support/engine_setup.dart';
import 'petri_bundle.dart';
import 'petri_full_bundle.dart';

Map<String, Object?> get _bundle => jsonDecode(petriBundleJson) as Map<String, Object?>;

List<Variable> appVariables() => [
      for (final v in ((_bundle['model'] as Map)['variables'] as Map).values) Variable.fromJson(v)!,
    ];

final List<String> appVarNames = [for (final v in fullAppVariables()) v.name];

List<Variable> fullAppVariables() => [
      for (final v in ((((jsonDecode(petriFullBundleJson) as Map)['model'] as Map)['variables']) as Map).values) Variable.fromJson(v)!,
    ];

List<ScriptDef> scripts() => ScriptDef.listFromJson(((_bundle['layouts'] as Map).values.first as Map)['scripts']);

void main() {
  setUpAll(setUpScriptEngine);

  for (final full in [false, true]) {
  test('script time per tick: advance (lifeStep over 2,304 cells)${full ? ', every app variable' : ''}', () async {
    final scope = VariableScope(full ? fullAppVariables() : appVariables());
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
    expect(scope.read('gen'), (full ? 0 : 0) + 65);
    // ignore: avoid_print
    print('[bench] $scriptEngineName advance${full ? ' (all variables)' : ''}: ${(sw.elapsedMicroseconds / n / 1000).toStringAsFixed(2)} ms per tick');
  });
  }

  test('script overhead: a trivial script, every app variable, and lifeStep alone', () async {
    final scope = VariableScope(fullAppVariables());
    const runner = SandboxScriptRunner();
    final noop = ScriptDef.fromJson({'id': 'noop', 'name': 'noop', 'capabilities': ['variables.read'], 'source': 'return 1;'})!;
    final life = scripts().firstWhere((s) => s.name == 'lifeStep');
    final cells = scope.read('cells');
    Future<double> time(ScriptDef s, Json args, {ScriptHost? host}) async {
      for (var i = 0; i < 5; i++) {
        await runner.run(s, args: args, scripts: scripts(), host: host);
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        await runner.run(s, args: args, scripts: scripts(), host: host);
      }
      return sw.elapsedMicroseconds / 40 / 1000;
    }
    final noopBare = await time(noop, const {});
    final noopVars = await time(noop, const {}, host: _VarsHost(scope));
    final lifeMs = await time(life, {'cells': cells, 'birth': 8, 'survive': 12});
    // ignore: avoid_print
    print('[bench] $scriptEngineName: no-op ${noopBare.toStringAsFixed(2)} ms, no-op reading every variable ${noopVars.toStringAsFixed(2)} ms, lifeStep ${lifeMs.toStringAsFixed(2)} ms');
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

  Future<void> frames(WidgetTester tester, String label, List<int> Function(int i, List<int> current) next, {bool full = false}) async {
    final bundle = PublishBundle.fromJson(full ? jsonDecode(petriFullBundleJson) as Map<String, Object?> : _bundle);
    // Tests can't fetch the screen's Google Fonts: fallback metrics make a
    // few texts taller, and the 900-high screen overflows by a few pixels.
    final reportError = FlutterError.onError;
    FlutterError.onError = (d) {
      if ('${d.exception}'.contains('overflowed')) return;
      reportError?.call(d);
    };
    addTearDown(() => FlutterError.onError = reportError);
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
      if (full) {
        // What the advance script writes besides the cells.
        final pop = cells.where((c) => c != 0 && c != 3).length;
        final history = [...(scope.read('history') as List), pop];
        scope.set('gen', (scope.read('gen') as int) + 1);
        scope.set('pop', pop);
        scope.set('delta', pop - (history.length > 1 ? history[history.length - 2] as int : pop));
        scope.set('history', history.length > 120 ? history.sublist(history.length - 120) : history);
      }
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
    if (full) {
      NodeBox.debugCountPaints = true;
      NodeBox.debugPaintCounts.clear();
      NodeBox.debugCountApplies = true;
      NodeBox.debugApplyCounts.clear();
      for (var i = 0; i < 3; i++) {
        cells = next(i, cells);
        scope.set('cells', cells);
        scope.set('gen', (scope.read('gen') as int) + 1);
        await tester.pump();
      }
      NodeBox.debugCountPaints = false;
      final logs = <String>[];
      final saved = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      debugPrintMarkNeedsPaintStacks = true;
      debugPrintMarkNeedsLayoutStacks = true;
      cells = next(9, cells);
      scope.set('cells', cells);
      scope.set('gen', (scope.read('gen') as int) + 1);
      debugPrintMarkNeedsPaintStacks = false;
      debugPrintMarkNeedsLayoutStacks = false;
      debugPrint = saved;
      final heads = <String, int>{};
      final text = logs.join('\n');
      for (final block in text.split(RegExp(r'markNeeds(Paint|Layout)\(\) called for '))) {
        final lines = block.split('\n');
        final who = lines.first.split(' ').first;
        final frame = lines.firstWhere((l) => l.contains('package:codelessly_sdk') && !l.contains('markNeeds'), orElse: () => '?');
        final k = '$who <- ${frame.replaceAll(RegExp(r'^#\d+\s+'), '').trim()}';
        heads[k] = (heads[k] ?? 0) + 1;
      }
      final hs = heads.entries.toList()..sort((a, b) => b.value - a.value);
      // ignore: avoid_print
      for (final h in hs.take(15)) print('[bench] mark ${h.value} ${h.key}');
      NodeBox.debugCountApplies = false;
      // ignore: avoid_print
      print('[bench] applies in 3 ticks: ${NodeBox.debugApplyCounts}');
      final top = NodeBox.debugPaintCounts.entries.toList()..sort((a, b) => b.value - a.value);
      // ignore: avoid_print
      print('[bench] paints in 3 ticks: ${NodeBox.debugPaintCounts.values.fold(0, (a, b) => a + b)} boxes; top ${top.take(12).map((e) => '${e.key}:${e.value}').join(' ')}');
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

  testWidgets('frame time per tick: the whole Bench screen (desktop)', (tester) async {
    await frames(tester, 'full screen life tick', (i, c) => life(c), full: true);
  });
}

class _VarsHost implements NamedVariablesScriptHost {
  _VarsHost(this.scope);
  final VariableScope scope;
  @override
  Map<String, Object?> variables() => {for (final v in appVarNames) v: scope.read(v)};
  @override
  Map<String, Object?> variablesNamed(Set<String> names) => {for (final v in appVarNames) if (names.contains(v)) v: scope.read(v)};
  @override
  Map<String, Object?> nodeValues() => const {};
  @override
  void setVariable(String name, Object? value) => scope.set(name, value);
  @override
  Future<Object?> call(String name, List<Object?> args) async => null;
}
