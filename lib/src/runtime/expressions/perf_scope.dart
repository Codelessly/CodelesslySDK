// `perf`: the app's own frame timings, for a screen that shows them (a
// diagnostics line, a benchmark readout).
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../contracts.dart';
import 'scopes.dart';

/// Declares `perf`: `{frameMs, buildMs, rasterMs, fps}` over the frames the
/// engine reported last (an average of their build + raster time, and how
/// many frames a second were drawn). All 0 until the first report.
///
/// It listens to frame timings only while a binding or reaction watches
/// `perf`, so a screen that doesn't read it pays nothing. A new value is set
/// only when it moved by more than [threshold] (relative), so the frame that
/// redraws a `perf` readout doesn't keep the screen redrawing on its own.
class PerfScope extends NamedScope {
  PerfScope({super.parent, this.threshold = 0.05});

  static const Map<String, Object?> idle = {'frameMs': 0.0, 'buildMs': 0.0, 'rasterMs': 0.0, 'fps': 0.0};

  final double threshold;
  Map<String, Object?> _value = idle;
  bool _listening = false;
  bool _disposed = false;

  @override
  bool declares(String name) => name == 'perf';

  @override
  Object? valueOf(String name, ValueScope reader) => name == 'perf' ? _value : null;

  @override
  Listenable watch(String name) {
    if (name == 'perf' && !_listening && !_disposed) {
      _listening = true;
      SchedulerBinding.instance.addTimingsCallback(_timings);
    }
    return super.watch(name);
  }

  /// Folds a batch of frame timings into `perf`.
  void report(List<FrameTiming> timings) {
    if (timings.isEmpty || _disposed) return;
    var build = 0.0, raster = 0.0;
    for (final t in timings) {
      build += t.buildDuration.inMicroseconds / 1000;
      raster += t.rasterDuration.inMicroseconds / 1000;
    }
    final n = timings.length;
    final first = timings.first.timestampInMicroseconds(FramePhase.vsyncStart);
    final last = timings.last.timestampInMicroseconds(FramePhase.vsyncStart);
    final seconds = (last - first) / 1e6;
    final fps = n > 1 && seconds > 0 ? (n - 1) / seconds : 0.0;
    final next = {'frameMs': (build + raster) / n, 'buildMs': build / n, 'rasterMs': raster / n, 'fps': fps};
    if (!_moved(next)) return;
    _value = Map.unmodifiable(next);
    changed(const ['perf']);
  }

  bool _moved(Map<String, Object?> next) {
    if (identical(_value, idle)) return true;
    for (final k in const ['frameMs', 'fps']) {
      final a = (_value[k] as num).toDouble(), b = (next[k] as num).toDouble();
      if ((a - b).abs() > threshold * (a.abs() > 1 ? a.abs() : 1)) return true;
    }
    return false;
  }

  void _timings(List<FrameTiming> timings) => report(timings);

  @override
  void dispose() {
    _disposed = true;
    if (_listening) SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }
}
