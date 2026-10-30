import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';

import '../audio/sound.dart';

/// Runs a [TriggerType.clock] reaction: a steady tick for rhythm.
///
/// Ticks are counted on the sound clock ([Sound.now]) from where the clock
/// started, each one [TriggerModel.every] milliseconds after the last (read
/// again at each tick, so a tempo change applies from the next one). Timers
/// only poll; nothing accumulates their jitter, so the ticks don't drift.
/// Each tick's actions run up to [TriggerModel.lookaheadMs] early with its
/// exact time, so a Play Sound can be scheduled to land on it.
class BeatClock {
  /// Creates a clock for [trigger]. [evaluate] substitutes variables and
  /// formulas in a field; [onTick] runs the reaction for one tick.
  BeatClock({
    required this.trigger,
    required this.evaluate,
    required this.onTick,
    double Function()? now,
  }) : _now = now ?? (() => Sound.now);

  /// The clock's settings.
  final TriggerModel trigger;

  /// The text of a field with its variables and formulas filled in.
  final String Function(String text) evaluate;

  /// Runs the reaction for tick number [tick] due at [at] seconds on the
  /// sound clock, [waitMs] from now.
  final void Function(int tick, double at, double waitMs) onTick;

  final double Function() _now;
  Timer? _timer;
  double? _next;
  int _tick = 0;

  /// How often the clock looks for due ticks.
  static const Duration pollInterval = Duration(milliseconds: 10);

  /// Whether the clock is counting ticks now.
  bool get running => _next != null;

  static final Map<String, BeatClock> _shared = {};
  final List<void Function(int tick, double at, double waitMs)> _listeners =
      [];

  /// The clock of [trigger] shared by every screen with the same settings:
  /// a screen shown in place of another (a tab) picks up the running clock
  /// instead of starting its own count again. The newest listener runs each
  /// tick; [release] removes it, and the clock stops with the last one.
  static BeatClock acquire({
    required TriggerModel trigger,
    required String Function(String text) evaluate,
    required void Function(int tick, double at, double waitMs) onTick,
  }) {
    final String key =
        '${trigger.every}|${trigger.runWhen}|${trigger.lookaheadMs}';
    final BeatClock clock = _shared[key] ??= BeatClock._keyed(
      key,
      trigger,
    );
    clock
      .._evaluate = evaluate
      .._listeners.add(onTick);
    if (clock._timer == null) clock.start();
    return clock;
  }

  BeatClock._keyed(this._key, this.trigger)
    : _now = (() => Sound.now),
      evaluate = _noEvaluate,
      onTick = _noTick;

  static String _noEvaluate(String text) => '';
  static void _noTick(int tick, double at, double waitMs) {}

  String? _key;
  String Function(String text)? _evaluate;

  /// Removes [onTick] from a shared clock; the last one stops it.
  void release(void Function(int tick, double at, double waitMs) onTick) {
    _listeners.remove(onTick);
    if (_listeners.isNotEmpty) return;
    stop();
    _shared.remove(_key);
  }

  String _eval(String text) => (_evaluate ?? evaluate)(text);

  void _fire(int tick, double at, double waitMs) {
    if (_key == null) {
      onTick(tick, at, waitMs);
    } else if (_listeners.isNotEmpty) {
      _listeners.last(tick, at, waitMs);
    }
  }

  /// Starts polling.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => poll());
    poll();
  }

  /// Stops polling and resets the count.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _next = null;
    _tick = 0;
  }

  bool _shouldRun() {
    final String? when = trigger.runWhen;
    if (when == null || when.trim().isEmpty) return true;
    final String v = _eval(when).trim().toLowerCase();
    return v == 'true' || (double.tryParse(v) ?? 0) != 0;
  }

  /// Milliseconds to the next tick, at least 10.
  double _intervalMs() {
    final String? every = trigger.every;
    final double? ms = every == null || every.trim().isEmpty
        ? trigger.intervalMs?.toDouble()
        : double.tryParse(_eval(every).trim());
    if (ms == null || !ms.isFinite) return 1000;
    return math.max(10, ms);
  }

  /// Runs every tick due within the lookahead. Called by the poll timer;
  /// public for tests.
  void poll() {
    if (!_shouldRun()) {
      _next = null;
      _tick = 0;
      return;
    }
    final double now = _now();
    final double lookahead = trigger.lookaheadMs / 1000;
    // A clock that has just started, or fell far behind (a hidden tab),
    // starts again a moment from now instead of firing a burst.
    if (_next == null || _next! < now - 0.25) _next = now + 0.05;
    int fired = 0;
    while (_next! <= now + lookahead && fired < 32) {
      final double at = _next!;
      _fire(_tick, at, math.max(0, (at - now) * 1000));
      _tick++;
      fired++;
      _next = at + _intervalMs() / 1000;
    }
  }
}
