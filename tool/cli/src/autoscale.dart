// How many workers the render server runs when it is left to follow its load (`serve --workers auto`, the default).
//
// The design is the autoscaler of the owner's OverlookV2 (packages/dsg/lib/src/autoscale.dart: `AutoscalePolicy`,
// `Autoscaler`, used by DsgEngine for `concurrency: "auto"`), copied here because the SDK's tool cannot depend on
// that repository. The shape is kept: a policy of constants, a state entry, and a controller whose methods take
// the entry and `now` and return the change they made (or null), so every decision is a pure function a test
// can drive with a clock of its own; growth in steps that widen (… 4 → 8 → 12 → 20 → 32 → 48 → 72 …); a cut to
// half at most when the level is refused; the refused level remembered as a ceiling that expires; a least time
// between a change and the next raise; evidence that the level holds before it is raised.
//
// What differs is the domain. There the limit is a provider's rate limit, known only by its refusals, which
// arrive up to a minute after a raise: a raise waits a minute and a ceiling stands twenty. Here the limit is this
// machine (its cores and memory), a worker is up 1.3 s after it is asked for, and every signal is local and
// immediate:
//
//   Overlook                                 here
//   initial 4                                1: one client rendering one page at a time is nearly all use, and
//                                            pays for one engine (about 350 MB), not for a pool
//   grow 4 → 8 → 12 → 20 → 32 → 48           1 → 4, then the same steps; never past what waits (a raise adds
//                                            no more workers than there is work waiting for one: one request
//                                            waiting behind another adds one worker, not three)
//   saturated: running at the limit, items   saturated: no worker idle and work waiting (requests in the queue,
//   ready                                    captures of a shared request nobody took), for `sustain` (150 ms)
//   minRaiseGap 60 s                         1 s after a refusal; a raise itself waits for the workers of the
//                                            one before to be up (`starting`), not for a clock
//   successes ≥ half the limit, or           a measured rate at this level (work done per second while
//   healthyFor 3 min                         saturated, over at least `measureFor` 400 ms and two units a
//                                            worker), or healthyFor 5 s when renders are too long to count
//   refusal: provider 429/529                refusal: a worker did not start; or the last raise did not raise
//                                            the work done per second by `minGain` (a fifth) of what its
//                                            workers would add (past the cores more workers render no more)
//   (none)                                   held, not cut: free memory would fall under the reserve
//   cut 0.5, burst 30 s                      cut 0.5 (a raise that did not help goes back to the level before
//                                            it), burst 2 s (the start failures of one raise are one refusal)
//   ceilingFor 20 min                        2 min: what stops helping is the machine's other load, which
//                                            changes in minutes
//   (the limit only grows or is cut)         workers idle for `retireAfter` (60 s) are ended, down to `min`
//
// Below `judgeFrom` (4) a raise is not judged by its rate: Overlook starts at 4 without evidence too, and the
// step to 4 is the one a request of several captures waits for.
import 'dart:math' as math;

/// How the pool grows, is cut and shrinks.
class AutoscalePolicy {
  const AutoscalePolicy({
    this.initial = 1,
    this.min = 1,
    this.max,
    this.cut = 0.5,
    this.sustain = const Duration(milliseconds: 150),
    this.measureFor = const Duration(milliseconds: 400),
    this.minRaiseGap = const Duration(seconds: 1),
    this.healthyFor = const Duration(seconds: 5),
    this.burst = const Duration(seconds: 2),
    this.ceilingFor = const Duration(minutes: 2),
    this.retireAfter = const Duration(seconds: 60),
    this.minGain = 0.2,
    this.judgeFrom = 4,
    this.workerMb = 400,
    this.reserveMb = 1024,
    this.memoryHold = const Duration(seconds: 10),
  });

  /// The workers the server starts with.
  final int initial;

  /// Never below this.
  final int min;

  /// Never above this; null: no fixed bound (what waits, the rate and the memory bound it).
  final int? max;

  /// A refusal never takes the limit below this share of the level it hit.
  final double cut;

  /// Work must have waited this long, with no worker idle, before the first raise.
  final Duration sustain;

  /// The least stretch a rate is measured over.
  final Duration measureFor;

  /// The least time between a refusal (or a cut) and the next raise.
  final Duration minRaiseGap;

  /// Saturated this long with too little finished to measure a rate (long renders): raised, or kept, unjudged.
  final Duration healthyFor;

  /// Refusals this close to the first of them are one: one cut.
  final Duration burst;

  /// How long the level a refusal hit stays a ceiling.
  final Duration ceilingFor;

  /// A worker beyond [min] that has been idle this long is ended.
  final Duration retireAfter;

  /// The share of the gain a raise's workers would give at best (twice the workers, twice the work) that it
  /// must give to be kept.
  final double minGain;

  /// From this many workers on, a raise needs a measured rate first and is judged by the rate after it.
  final int judgeFrom;

  /// What a worker is taken to hold when a raise is weighed against the free memory, and the free memory a raise
  /// must leave.
  final int workerMb, reserveMb;

  /// How long a raise held for memory is not tried again.
  final Duration memoryHold;

  /// The next level after [limit] holds: 4 from below it (Overlook's first level; [Autoscaler.tick] never adds
  /// more workers than there is work waiting, so one request that waits adds one), then +4 up to 12, then +50 %
  /// rounded to a multiple of 4 (4 → 8 → 12 → 20 → 32 → 48 → 72 …).
  int grow(int limit) {
    if (limit < 4) return 4;
    final step = ((limit / 2 / 4).round() * 4).clamp(4, 1 << 30);
    return limit + step;
  }

  int clamp(int n) {
    var v = n < min ? min : n;
    if (max != null && v > max!) v = max!;
    return v;
  }

  AutoscalePolicy copyWith({int? initial, int? min, int? max, Duration? retireAfter, int? reserveMb, int? workerMb}) => AutoscalePolicy(
        initial: initial ?? this.initial,
        min: min ?? this.min,
        max: max ?? this.max,
        cut: cut,
        sustain: sustain,
        measureFor: measureFor,
        minRaiseGap: minRaiseGap,
        healthyFor: healthyFor,
        burst: burst,
        ceilingFor: ceilingFor,
        retireAfter: retireAfter ?? this.retireAfter,
        minGain: minGain,
        judgeFrom: judgeFrom,
        workerMb: workerMb ?? this.workerMb,
        reserveMb: reserveMb ?? this.reserveMb,
        memoryHold: memoryHold,
      );
}

/// A change the autoscaler made (the server logs it and starts or ends workers to match), or a raise it held
/// ([from] == [to]: said in the status, nothing to do).
typedef AutoscaleChange = ({int from, int to, String reason});

/// What the autoscaler knows: one entry for the server's life.
class AutoscaleState {
  AutoscaleState(this.limit, this.changedAt);

  /// The workers the server should have now.
  int limit;

  /// The highest level that held (it was measured, or raised from, with no refusal).
  int? learned;

  /// The level a refusal hit; growth stays below it until [ceilingUntil], then probes past it.
  int? ceiling;
  DateTime? ceilingUntil;

  /// The last change of [limit].
  DateTime changedAt;

  int refusals = 0;
  DateTime? lastRefusalAt, burstAt;
  String? lastRefusal;

  /// Since when no worker has been idle with work waiting (null: not saturated), when that was last seen, and
  /// the work finished in that stretch.
  DateTime? saturatedSince, lastSaturatedAt;
  int units = 0;

  /// The raise still to judge: the level it left and the rate measured there (null: none was).
  int? raisedFrom;
  double? rateBefore;

  /// The rate last measured, and the level it was measured at.
  double? rate;
  int? rateAt;

  DateTime? memoryHeldUntil;

  /// The last decision, for `serve --status`.
  DateTime? decidedAt;
  int? decidedFrom, decidedTo;
  String? decision;

  Map<String, Object?> toJson(DateTime now) => {
        'limit': limit,
        'learned': learned,
        'ceiling': ceiling != null && ceilingUntil != null && now.isBefore(ceilingUntil!) ? ceiling : null,
        'ceilingUntil': ceiling != null && ceilingUntil != null && now.isBefore(ceilingUntil!) ? ceilingUntil!.toIso8601String() : null,
        'refusals': refusals,
        'lastRefusal': lastRefusal,
        'rate': rate == null ? null : double.parse(rate!.toStringAsFixed(2)),
        'rateAt': rateAt,
        'lastDecision': decision == null ? null : {'at': decidedAt!.toIso8601String(), 'from': decidedFrom, 'to': decidedTo, 'reason': decision},
      };
}

/// The controller over the server's [AutoscaleState].
class Autoscaler {
  const Autoscaler(this.policy);
  final AutoscalePolicy policy;

  AutoscaleState start(DateTime now) => AutoscaleState(policy.clamp(policy.initial), now);

  AutoscaleChange _decided(AutoscaleState s, DateTime now, int from, int to, String reason) {
    s
      ..decidedAt = now
      ..decidedFrom = from
      ..decidedTo = to
      ..decision = reason;
    return (from: from, to: to, reason: reason);
  }

  /// [n] units of work were finished (captures, or requests that capture nothing).
  void progress(AutoscaleState s, int n) => s.units += n;

  /// The workers of the last raise are up: the rate at the new level is measured from here.
  void landed(AutoscaleState s, DateTime now) {
    s
      ..saturatedSince = null
      ..units = 0;
  }

  /// The level was refused while [running] workers still run: a worker did not start (`start_failure`), or the
  /// last raise did not raise the rate (`no_gain`, [running] the level before it). The limit drops to what runs,
  /// never below [AutoscalePolicy.cut] of the level it hit, which becomes the ceiling growth stays under for
  /// [AutoscalePolicy.ceilingFor]. Refusals within [AutoscalePolicy.burst] of the first are one burst: one cut,
  /// then only lowered to what still runs.
  AutoscaleChange? refused(AutoscaleState s, DateTime now, {required int running, required String kind, String? why}) {
    final from = s.limit;
    final inBurst = s.burstAt != null && now.difference(s.burstAt!) < policy.burst;
    if (!inBurst) s.burstAt = now;
    s
      ..refusals += 1
      ..lastRefusalAt = now
      ..raisedFrom = null
      ..rateBefore = null
      ..saturatedSince = null
      ..units = 0;
    final what = switch (kind) {
      'start_failure' => 'a worker did not start',
      'no_gain' => 'more workers rendered no more',
      _ => kind,
    };
    s.lastRefusal = '$what at $from${why == null || why.isEmpty ? '' : ' ($why)'}';
    // The level a burst hit is its ceiling (kept for the whole burst).
    if (!inBurst || s.ceiling == null) {
      s
        ..ceiling = from
        ..ceilingUntil = now.add(policy.ceilingFor);
    }
    final floor = policy.clamp((s.ceiling! * policy.cut).floor());
    var to = running < from ? running : (inBurst ? from : from - 1);
    if (to < floor) to = floor;
    to = policy.clamp(to);
    s.learned = to;
    if (to == from) return null;
    s
      ..limit = to
      ..changedAt = now;
    return _decided(s, now, from, to, '${s.lastRefusal}: back to $to, and no higher than ${s.ceiling! - 1} for ${_span(policy.ceilingFor)}');
  }

  /// Workers idle for [AutoscalePolicy.retireAfter] were ended: the limit follows them down to [to].
  AutoscaleChange? retired(AutoscaleState s, DateTime now, {required int to}) {
    final from = s.limit;
    to = policy.clamp(to);
    if (to >= from) return null;
    s
      ..limit = to
      ..changedAt = now
      ..raisedFrom = null
      ..rateBefore = null
      ..saturatedSince = null
      ..units = 0;
    return _decided(s, now, from, to, '${from - to} worker${from - to == 1 ? '' : 's'} idle for ${_span(policy.retireAfter)}');
  }

  /// Called on every look at the pool: [idle] workers have nothing to do, [starting] are not up yet, [demand] is
  /// the work waiting for a worker (requests queued, captures nobody took), [freeMb] the machine's free memory
  /// (null: not told). Judges the last raise once its rate is measured (cutting it when it did not help), then
  /// raises the limit when the pool is saturated and the rate at this level is known.
  AutoscaleChange? tick(AutoscaleState s, DateTime now, {required int idle, required int starting, required int demand, int? freeMb}) {
    if (demand <= 0 || idle > 0) {
      // A queue that empties for a moment between two requests of the same clients is the same stretch.
      if (s.lastSaturatedAt == null || now.difference(s.lastSaturatedAt!) > policy.sustain) {
        s
          ..saturatedSince = null
          ..units = 0;
        // (A raise the load left before it could be measured is kept: nothing says it did not help.)
        if (s.raisedFrom != null && starting == 0) {
          s
            ..raisedFrom = null
            ..rateBefore = null;
        }
      }
      return null;
    }
    s.lastSaturatedAt = now;
    if (starting > 0) return null;
    final since = s.saturatedSince ??= now;
    final window = now.difference(since);
    final from = s.limit;
    final measured = window >= policy.measureFor && s.units >= 2 * from;
    final rate = measured || (window >= policy.healthyFor && s.units > 0) ? s.units * 1e6 / window.inMicroseconds : null;
    if (rate != null) {
      s
        ..rate = rate
        ..rateAt = from;
    }
    // The last raise, judged by the rate after it.
    if (s.raisedFrom != null) {
      if (rate == null && window < policy.healthyFor) return null;
      final before = s.rateBefore, was = s.raisedFrom!;
      if (rate != null && before != null && was < from) {
        final needed = before * (1 + policy.minGain * (from / was - 1));
        if (rate < needed) {
          return refused(s, now, running: was, kind: 'no_gain',
              why: '${rate.toStringAsFixed(1)} a second at $from workers against ${before.toStringAsFixed(1)} at $was');
        }
      }
      s
        ..raisedFrom = null
        ..rateBefore = null;
    }
    if (s.learned == null || from > s.learned!) s.learned = from;
    if (window < policy.sustain) return null;
    // From judgeFrom on, a raise waits for the rate it will be judged against.
    if (from >= policy.judgeFrom && rate == null && window < policy.healthyFor) return null;
    if (s.lastRefusalAt != null && now.difference(s.lastRefusalAt!) < policy.minRaiseGap) return null;
    if (s.memoryHeldUntil != null && now.isBefore(s.memoryHeldUntil!)) return null;
    // No more workers than there is work waiting for one.
    var to = policy.clamp(math.min(policy.grow(from), from + demand));
    String? probe;
    final ceiling = s.ceiling;
    if (ceiling != null && to >= ceiling) {
      if (s.ceilingUntil != null && !now.isBefore(s.ceilingUntil!)) {
        probe = '${_span(policy.ceilingFor)} since $ceiling was too many: trying past it';
        s
          ..ceiling = null
          ..ceilingUntil = null;
      } else {
        // Under a live ceiling, half the gap to it: a level between what held and what was refused is found in a
        // few steps.
        final half = (ceiling - from) ~/ 2;
        to = from + (half < 1 ? 1 : half);
        if (to >= ceiling) to = ceiling - 1;
      }
    }
    if (to <= from) return null;
    if (freeMb != null) {
      final fits = (freeMb - policy.reserveMb) ~/ policy.workerMb;
      if (fits < to - from) {
        if (fits < 1) {
          s.memoryHeldUntil = now.add(policy.memoryHold);
          return _decided(s, now, from, from,
              'held at $from: $freeMb MB of memory are free, and another worker (about ${policy.workerMb} MB) would leave less than the ${policy.reserveMb} MB kept free');
        }
        to = from + fits;
      }
    }
    s
      ..raisedFrom = from
      ..rateBefore = rate
      ..limit = to
      ..changedAt = now
      ..saturatedSince = null
      ..units = 0;
    final why = '$demand waiting with all $from busy${rate == null ? '' : ' (${rate.toStringAsFixed(1)} a second)'}';
    return _decided(s, now, from, to, probe == null ? why : '$probe; $why');
  }

  static String _span(Duration d) => d.inSeconds >= 120 && d.inSeconds % 60 == 0 ? '${d.inMinutes} min' : '${d.inSeconds} s';
}
