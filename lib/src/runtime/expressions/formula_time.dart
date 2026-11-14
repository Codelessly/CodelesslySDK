// The time formulas read, and how often a formula's value changes with it:
// pure Dart (no Flutter), so the formula parser and evaluator run where
// Flutter does not (a recorder's checks, a server). The clocks that rebuild
// widgets (FormulaClock, FrameClock) are in formula_clock.dart.

/// How often a formula's value can change as time passes, finest first:
/// what a widget showing it must be rebuilt on (`FormulaClock.of`).
///
/// * [frame]: `nowMs()`, a millisecond clock (every frame);
/// * [second]: `now()`, a time of day or a countdown (every second);
/// * [minute]: `today()`, `timeAgo(date)`, `isToday(date)`, `isPast(date)`,
///   `isFuture(date)`: values that change at most once a minute, or that
///   may show a minute late (every minute).
enum ClockTick {
  frame,
  second,
  minute;

  /// The finer of this and [other] (either may be null).
  ClockTick finer(ClockTick? other) => other == null || index <= other.index ? this : other;
}

/// The instant formulas read as now.
abstract final class FormulaTime {
  /// Optional instant pinned by an editor or preview for deterministic dates.
  static DateTime? pinned;

  /// The pinned instant, or the device clock for live formulas.
  static DateTime now() => pinned ?? DateTime.now();
}
