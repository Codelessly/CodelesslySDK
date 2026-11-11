// Runs a publish bundle as an app and times it: frames (build and raster,
// from the engine's frame timings), script runs, and how many generations a
// clock-driven screen gets through. Built for the Petri stress test (a
// clock running a script that rewrites 2,304 bound cells per tick).
//
//   flutter build web --release && (serve build/web)
//   open /?seconds=10&speed=30   →  the console prints "[bench-result] {...}"
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Times every script run.
class TimingRunner implements ScriptRunner {
  TimingRunner(this.inner);
  final ScriptRunner inner;
  final List<double> runsMs = [];

  @override
  Future<ScriptRunResult> run(ScriptDef script,
      {Json args = const {}, List<ScriptDef> scripts = const [], ScriptHost? host}) async {
    final sw = Stopwatch()..start();
    final r = await inner.run(script, args: args, scripts: scripts, host: host);
    runsMs.add(sw.elapsedMicroseconds / 1000);
    return r;
  }
}

double _pct(List<double> xs, double p) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  return s[((s.length - 1) * p).round()];
}

Map<String, Object?> _stats(List<double> xs) => {
      'n': xs.length,
      'median': double.parse(_pct(xs, 0.5).toStringAsFixed(2)),
      'p90': double.parse(_pct(xs, 0.9).toStringAsFixed(2)),
      'max': double.parse(_pct(xs, 1).toStringAsFixed(2)),
    };

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final seconds = int.tryParse(q['seconds'] ?? '') ?? 10;
  final speed = int.tryParse(q['speed'] ?? '') ?? 30;
  final bundle = decodeBundle(utf8.encode(await rootBundle.loadString('assets/${q['bundle'] ?? 'petri_bundle'}.json')));
  final runner = TimingRunner(const SandboxScriptRunner());
  final codelessly = Codelessly(
    config: CodelesslyConfig(services: Services(scripts: runner)),
    loader: MemoryPublishLoader(bundle),
  );
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: CodelesslyWidget(codelessly: codelessly)));

  final build = <double>[], raster = <double>[], total = <double>[];
  var recording = false;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    if (!recording) return;
    for (final t in timings) {
      build.add(t.buildDuration.inMicroseconds / 1000);
      raster.add(t.rasterDuration.inMicroseconds / 1000);
      total.add(t.totalSpan.inMicroseconds / 1000);
    }
  });
  // Frame-to-frame intervals as the app sees them.
  final intervals = <double>[];
  Duration? last;
  void onFrame(Duration ts) {
    if (recording && last != null) intervals.add((ts - last!).inMicroseconds / 1000);
    last = ts;
    if (recording) SchedulerBinding.instance.scheduleFrameCallback(onFrame);
  }

  await Future<void>.delayed(const Duration(seconds: 3));
  final vars = codelessly.appVariables;
  vars.set('speed', speed);
  final gen0 = vars.read('gen') as int? ?? 0;
  runner.runsMs.clear();
  recording = true;
  SchedulerBinding.instance.scheduleFrameCallback(onFrame);
  vars.set('running', true);
  final sw = Stopwatch()..start();
  await Future<void>.delayed(Duration(seconds: seconds));
  vars.set('running', false);
  recording = false;
  final gens = (vars.read('gen') as int? ?? 0) - gen0;
  final result = {
    'speed': speed,
    'seconds': sw.elapsedMilliseconds / 1000,
    'generations': gens,
    'gensPerSecond': double.parse((gens / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(2)),
    'scriptMs': _stats(runner.runsMs),
    'frameBuildMs': _stats(build),
    'frameRasterMs': _stats(raster),
    'frameIntervalMs': _stats(intervals),
  };
  // ignore: avoid_print
  print('[bench-result] ${jsonEncode(result)}');
}
