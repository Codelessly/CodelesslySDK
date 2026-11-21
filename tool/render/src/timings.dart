// Where a render run's time goes, phase by phase: what `--timings` (or CODELESSLY_TIMINGS=1) prints, so a
// command that got slower shows which part did.
//
// A phase is a name and the milliseconds spent in it, summed over the run (every screen at every size adds to
// `show`, `capture`, `png` and so on). The phases are told in the order they first ran.

/// The phases of one run. [RenderTimings.current] is the run being timed (the render command runs one at a time).
class RenderTimings {
  RenderTimings();

  /// The run being timed.
  static RenderTimings current = RenderTimings();

  final Map<String, int> _micros = {};
  final Map<String, int> _counts = {};
  final Stopwatch _total = Stopwatch()..start();

  /// Adds the time [body] takes to [phase].
  Future<T> time<T>(String phase, Future<T> Function() body) async {
    final clock = Stopwatch()..start();
    try {
      return await body();
    } finally {
      add(phase, clock.elapsedMicroseconds);
    }
  }

  /// Adds the time [body] takes to [phase] (a body that does not wait).
  T timeSync<T>(String phase, T Function() body) {
    final clock = Stopwatch()..start();
    try {
      return body();
    } finally {
      add(phase, clock.elapsedMicroseconds);
    }
  }

  final Stopwatch _lap = Stopwatch()..start();

  /// Adds the time since the last lap (or the start) to [phase]: for steps that follow one another.
  void lap(String phase) {
    add(phase, _lap.elapsedMicroseconds);
    _lap.reset();
  }

  void add(String phase, int micros) {
    _micros[phase] = (_micros[phase] ?? 0) + micros;
    _counts[phase] = (_counts[phase] ?? 0) + 1;
  }

  /// `load 12 ms, fonts 3 ms, show 410 ms (18), ... ; total 2031 ms`: each phase, with how many times it ran
  /// when more than once, then the whole run.
  String get line {
    final parts = [
      for (final e in _micros.entries) '${e.key} ${(e.value / 1000).round()} ms${_counts[e.key]! > 1 ? ' (${_counts[e.key]})' : ''}',
    ];
    return '${parts.join(', ')}${parts.isEmpty ? '' : '; '}total ${(_total.elapsedMicroseconds / 1000).round()} ms';
  }
}
