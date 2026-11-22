// How the render server decides the number of its workers when it follows its load (tool/cli/src/autoscale.dart):
// every decision is a function of the state, the clock and what the pool says, so these run on a clock of their
// own, with no server. test/tool/render_parallel_test.dart tests the server doing what is decided here.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/autoscale.dart';

void main() {
  const policy = AutoscalePolicy();
  const scaler = Autoscaler(policy);
  var now = DateTime.utc(2026, 1, 1, 12);
  setUp(() => now = DateTime.utc(2026, 1, 1, 12));
  void pass(Duration d) => now = now.add(d);
  void ms(int n) => pass(Duration(milliseconds: n));

  /// The pool saturated for [millis] in which [units] of work finish, looked at every 50 ms: the first change.
  AutoscaleChange? saturated(AutoscaleState s, int millis, {int units = 0, int demand = 100, int? freeMb}) {
    final steps = millis ~/ 50;
    for (var i = 0; i <= steps; i++) {
      final change = scaler.tick(s, now, idle: 0, starting: 0, demand: demand, freeMb: freeMb);
      if (change != null) return change;
      if (i == steps) break;
      ms(50);
      if (units > 0) scaler.progress(s, (units * (i + 1)) ~/ steps - (units * i) ~/ steps);
    }
    return null;
  }

  test('the steps: 4 from below it, then 8, 12, 20, 32, 48, 72', () {
    final levels = [1];
    while (levels.last < 72) {
      levels.add(policy.grow(levels.last));
    }
    expect(levels, [1, 4, 8, 12, 20, 32, 48, 72]);
    expect(policy.grow(2), 4);
    expect(policy.grow(3), 4);
  });

  test('one worker to start with, and one for as long as nothing waits', () {
    final s = scaler.start(now);
    expect(s.limit, 1);
    for (var i = 0; i < 200; i++) {
      // A lone client: its request is being rendered, nothing waits; or the worker is idle.
      expect(scaler.tick(s, now, idle: i.isEven ? 0 : 1, starting: 0, demand: 0), isNull);
      ms(100);
    }
    expect(s.limit, 1);
    expect(s.decision, isNull);
  });

  test('a request that waits adds a worker once it has waited a moment; never more workers than wait', () {
    final s = scaler.start(now);
    expect(scaler.tick(s, now, idle: 0, starting: 0, demand: 1), isNull, reason: 'Not at the first look.');
    ms(100);
    expect(scaler.tick(s, now, idle: 0, starting: 0, demand: 1), isNull);
    ms(60);
    final change = scaler.tick(s, now, idle: 0, starting: 0, demand: 1)!;
    expect((change.from, change.to), (1, 2), reason: 'One waits: one more worker, not three.');
    expect(change.reason, contains('1 waiting with all 1 busy'));
    expect(s.limit, 2);

    final many = scaler.start(now);
    final first = saturated(many, 200, demand: 15)!;
    expect((first.from, first.to), (1, 4));
  });

  test('nothing is added while a worker is idle, or while the workers of the last raise are starting', () {
    final s = scaler.start(now);
    for (var i = 0; i < 40; i++) {
      expect(scaler.tick(s, now, idle: 1, starting: 0, demand: 5), isNull);
      ms(50);
    }
    final t = scaler.start(now);
    expect(saturated(t, 200, demand: 15)!.to, 4);
    for (var i = 0; i < 100; i++) {
      expect(scaler.tick(t, now, idle: 0, starting: 3, demand: 15), isNull);
      ms(50);
    }
    expect(t.limit, 4);
  });

  test('a queue that empties for a moment between two requests is the same stretch; one that stays empty is not', () {
    final s = scaler.start(now);
    scaler.tick(s, now, idle: 0, starting: 0, demand: 2);
    ms(100);
    // Empty for 50 ms: the clients' next requests are on their way.
    expect(scaler.tick(s, now, idle: 0, starting: 0, demand: 0), isNull);
    ms(50);
    expect(scaler.tick(s, now, idle: 0, starting: 0, demand: 2)?.to, 3);

    final t = scaler.start(now);
    scaler.tick(t, now, idle: 0, starting: 0, demand: 2);
    ms(100);
    scaler.tick(t, now, idle: 1, starting: 0, demand: 0);
    ms(400);
    scaler.tick(t, now, idle: 1, starting: 0, demand: 0);
    expect(scaler.tick(t, now, idle: 0, starting: 0, demand: 2), isNull, reason: 'A new stretch starts from nothing.');
  });

  test('from four workers on a raise waits for the rate at this level, and is kept when the rate rose', () {
    final s = scaler.start(now);
    expect(saturated(s, 200)!.to, 4);
    scaler.landed(s, now);
    // 4 workers, 10 units a second.
    expect(saturated(s, 300, units: 3), isNull, reason: 'No rate is measured in 300 ms.');
    final up = saturated(s, 1000, units: 10)!;
    expect((up.from, up.to), (4, 8));
    expect(up.reason, contains('a second'));
    scaler.landed(s, now);
    // 8 workers render 18 a second: kept, and raised again.
    final next = saturated(s, 2000, units: 36)!;
    expect((next.from, next.to), (8, 12));
    expect(s.learned, 8);
    expect(s.ceiling, isNull);
  });

  test('a raise that did not raise the work done per second is taken back, and its level is a ceiling that expires', () {
    final s = scaler.start(now);
    saturated(s, 200);
    scaler.landed(s, now);
    expect(saturated(s, 2000, units: 20)!.to, 8); // 10 a second at 4.
    scaler.landed(s, now);
    // 8 workers render 10.5 a second: a twentieth more, where twice the workers would give twice at best.
    final cut = saturated(s, 4000, units: 42)!;
    expect((cut.from, cut.to), (8, 4));
    expect(cut.reason, contains('more workers rendered no more at 8'));
    expect(s.ceiling, 8);
    expect(s.refusals, 1);
    expect(s.toJson(now)['ceiling'], 8);

    // Under the ceiling: half the gap, then one below it, then no further.
    scaler.landed(s, now);
    pass(policy.minRaiseGap);
    final half = saturated(s, 3000, units: 30)!;
    expect((half.from, half.to), (4, 6));
    scaler.landed(s, now);
    final near = saturated(s, 3000, units: 39)!; // 13 a second at 6: kept.
    expect((near.from, near.to), (6, 7));
    scaler.landed(s, now);
    expect(saturated(s, 20000, units: 300), isNull, reason: '8 was too many: 7 is where it stays.');
    expect(s.limit, 7);

    // Two minutes after the refusal the ceiling is no more: it tries past it.
    pass(policy.ceilingFor);
    expect(s.toJson(now)['ceiling'], isNull);
    final probe = saturated(s, 3000, units: 45)!;
    expect(probe.from, 7);
    expect(probe.to, greaterThanOrEqualTo(8));
    expect(probe.reason, contains('trying past it'));
  });

  test('a queue of a thousand grows the pool for as long as growing helps, and no further', () {
    // A machine whose 16 cores render one unit a second each; workers past 16 add nothing.
    final s = scaler.start(now);
    final changes = <String>[];
    var done = 0.0, top = 0;
    for (var step = 0; step < 2400; step++) {
      done += (s.limit < 16 ? s.limit : 16) * 0.05;
      scaler.progress(s, done.floor());
      done -= done.floor();
      final change = scaler.tick(s, now, idle: 0, starting: 0, demand: 1000);
      if (change != null) {
        changes.add('${change.from}>${change.to}');
        scaler.landed(s, now);
      }
      if (s.limit > top) top = s.limit;
      ms(50);
    }
    // 20 workers render a third more than 12 did: kept. 32 render no more than 20: taken back, and so is each
    // try between them.
    expect(changes.take(6), ['1>4', '4>8', '8>12', '12>20', '20>32', '32>20'], reason: '$changes');
    expect(top, 32, reason: 'It never tried more than the step past what helped.');
    expect(s.limit, 20, reason: '$changes');
    expect(s.ceiling, inInclusiveRange(21, 32));
    expect(s.refusals, greaterThanOrEqualTo(1));
  });

  test('renders too long to count: raised without a rate after healthyFor, and not judged', () {
    final s = scaler.start(now);
    saturated(s, 200);
    scaler.landed(s, now);
    expect(saturated(s, 4900), isNull);
    final up = saturated(s, 200)!;
    expect((up.from, up.to), (4, 8));
    scaler.landed(s, now);
    final again = saturated(s, 6000)!;
    expect((again.from, again.to), (8, 12), reason: 'No rate before, none after: nothing says it did not help.');
  });

  test('a worker that does not start cuts the pool to what runs; the failures of one raise are one cut', () {
    final s = scaler.start(now);
    saturated(s, 200);
    scaler.landed(s, now);
    expect(saturated(s, 1000, units: 10)!.to, 8);
    // Of the four new workers none starts: four failures within a second.
    final cut = scaler.refused(s, now, running: 4, kind: 'start_failure', why: 'w4 could not be started')!;
    expect((cut.from, cut.to), (8, 4));
    expect(cut.reason, contains('a worker did not start at 8'));
    for (var i = 0; i < 3; i++) {
      ms(100);
      expect(scaler.refused(s, now, running: 4, kind: 'start_failure'), isNull);
    }
    expect(s.limit, 4);
    expect(s.ceiling, 8);
    expect(s.refusals, 4);
    // No raise for a moment after a refusal, then only under the ceiling.
    expect(saturated(s, 900, units: 9), isNull);
    final next = saturated(s, 2000, units: 20)!;
    expect((next.from, next.to), (4, 6));
  });

  test('a refusal never takes more than half: the workers still up may be fewer for a moment', () {
    final s = scaler.start(now)..limit = 12;
    final cut = scaler.refused(s, now, running: 2, kind: 'start_failure')!;
    expect(cut.to, 6);
  });

  test('free memory that would fall under the reserve holds a raise, or makes it smaller', () {
    final s = scaler.start(now);
    // 1024 MB kept free, 400 MB a worker: 1300 MB free holds no other worker.
    final held = saturated(s, 200, demand: 15, freeMb: 1300)!;
    expect((held.from, held.to), (1, 1));
    expect(held.reason, contains('1300 MB of memory are free'));
    expect(s.limit, 1);
    expect(saturated(s, 5000, demand: 15, freeMb: 90000), isNull, reason: 'Not asked again at once.');
    pass(policy.memoryHold);
    // Room for two.
    final some = saturated(s, 200, demand: 15, freeMb: 1900)!;
    expect((some.from, some.to), (1, 3));
  });

  test('the bounds, when given', () {
    final bounded = Autoscaler(policy.copyWith(initial: 2, min: 2, max: 5));
    final s = bounded.start(now);
    expect(s.limit, 2);
    ms(200);
    bounded.tick(s, now, idle: 0, starting: 0, demand: 50);
    ms(200);
    expect(bounded.tick(s, now, idle: 0, starting: 0, demand: 50)!.to, 4);
    bounded.landed(s, now);
    for (var i = 0; i < 40; i++) {
      bounded.progress(s, 1);
      ms(50);
      final change = bounded.tick(s, now, idle: 0, starting: 0, demand: 50);
      if (change != null) {
        expect(change.to, 5);
        break;
      }
    }
    expect(s.limit, 5);
    expect(bounded.retired(s, now, to: 1)!.to, 2, reason: 'Never under the least.');
  });

  test('workers that were idle are ended: the limit follows them down, and what was learned stays', () {
    final s = scaler.start(now);
    saturated(s, 200);
    scaler.landed(s, now);
    saturated(s, 1000, units: 10);
    scaler.landed(s, now);
    saturated(s, 2000, units: 36);
    expect(s.limit, 12);
    pass(policy.retireAfter);
    final down = scaler.retired(s, now, to: 1)!;
    expect((down.from, down.to), (12, 1));
    expect(down.reason, '11 workers idle for 60 s');
    expect(s.learned, 8);
    expect(scaler.retired(s, now, to: 1), isNull);
    // And it grows again when work waits again.
    expect(saturated(s, 200, demand: 15)!.to, 4);
  });

  test('what serve --status says of it', () {
    final s = scaler.start(now);
    expect(s.toJson(now), containsPair('limit', 1));
    expect(s.toJson(now)['lastDecision'], isNull);
    saturated(s, 200, demand: 15);
    final said = s.toJson(now);
    expect(said['limit'], 4);
    expect(said['lastDecision'], containsPair('from', 1));
    expect(said['lastDecision'], containsPair('to', 4));
    expect((said['lastDecision'] as Map)['reason'], contains('waiting'));
  });
}
