import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/beat_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Beat Clock: steady ticks on the sound clock, a lookahead so sounds
/// can be scheduled on time, a tempo read again at each tick, and a run
/// condition that restarts the count.
void main() {
  late double now;
  late List<(int, double, double)> ticks;
  late Map<String, String> vars;

  BeatClock clock({
    String every = r'${= 60000 / bpm}',
    String? runWhen = r'${playing}',
    int lookaheadMs = 100,
  }) => BeatClock(
    trigger: TriggerModel(
      type: TriggerType.clock,
      every: every,
      runWhen: runWhen,
      lookaheadMs: lookaheadMs,
    ),
    // A tiny stand-in for variable substitution.
    evaluate: (String text) => switch (text) {
      r'${= 60000 / bpm}' => '${60000 / double.parse(vars['bpm']!)}',
      r'${playing}' => vars['playing']!,
      _ => text,
    },
    onTick: (int tick, double at, double wait) => ticks.add((tick, at, wait)),
    now: () => now,
  );

  setUp(() {
    now = 10;
    ticks = [];
    vars = {'bpm': '120', 'playing': 'true'};
  });

  test('ticks at exact times, ahead of when they are due', () {
    final BeatClock c = clock();
    // Poll irregularly, like a jittery timer.
    for (final double t in [
      10.0,
      10.013,
      10.031,
      10.29,
      10.47,
      10.52,
      11.06,
      11.5,
    ]) {
      now = t;
      c.poll();
    }
    final List<double> times = [for (final (_, at, _) in ticks) at];
    expect(times.first, closeTo(10.05, 1e-9));
    for (int i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], closeTo(0.5, 1e-9), reason: 'tick $i');
    }
    expect([
      for (final (n, _, _) in ticks) n,
    ], List.generate(ticks.length, (i) => i));
    // Every tick ran before it was due, by up to the lookahead.
    for (final (_, at, wait) in ticks) {
      expect(wait, inInclusiveRange(0, 100));
      expect(at, greaterThanOrEqualTo(10.05));
    }
    expect(ticks.last.$2, closeTo(11.55, 1e-9));
  });

  test('a tempo change applies from the next tick', () {
    final BeatClock c = clock();
    now = 10;
    c.poll(); // tick 0 at 10.05; next at 10.55
    vars['bpm'] = '240';
    now = 10.5;
    c.poll(); // tick 1 at 10.55; next at 10.55 + 0.25
    now = 10.75;
    c.poll();
    expect(
      [for (final (_, at, _) in ticks) at],
      [closeTo(10.05, 1e-9), closeTo(10.55, 1e-9), closeTo(10.80, 1e-9)],
    );
  });

  test('stops while its condition is false and starts again from tick 0', () {
    final BeatClock c = clock();
    now = 10;
    c.poll();
    now = 10.5;
    c.poll();
    expect(ticks.length, 2);
    vars['playing'] = 'false';
    now = 11;
    c.poll();
    expect(c.running, isFalse);
    expect(ticks.length, 2);
    vars['playing'] = 'true';
    now = 20;
    c.poll();
    expect(ticks.last.$1, 0);
    expect(ticks.last.$2, closeTo(20.05, 1e-9));
  });

  test('after falling far behind it restarts instead of bursting', () {
    final BeatClock c = clock();
    now = 10;
    c.poll();
    now = 30; // the tab was hidden for 20 s
    c.poll();
    expect(ticks.length, 2);
    expect(ticks.last.$2, closeTo(30.05, 1e-9));
  });

  test('a fixed interval works without a formula', () {
    final BeatClock c = BeatClock(
      trigger: TriggerModel(
        type: TriggerType.clock,
        every: '250',
        lookaheadMs: 0,
      ),
      evaluate: (String t) => t,
      onTick: (int tick, double at, double wait) => ticks.add((tick, at, wait)),
      now: () => now,
    );
    for (double t = 10; t <= 11.001; t += 0.01) {
      now = t;
      c.poll();
    }
    expect(
      [for (final (_, at, _) in ticks) at],
      [for (int i = 0; i < 4; i++) closeTo(10.05 + 0.25 * i, 1e-6)],
    );
  });

  test('play sound plays the named voice at its time and volume', () {
    final SilentSoundEngine engine = SilentSoundEngine();
    Sound.engine = engine;
    Sound.play(
      Sound.voiceNamed('Cowbell'),
      time: 12.5,
      volume: 0.6,
      pitch: 1.5,
    );
    Sound.play(Sound.voiceNamed('nonsense'), volume: 5);
    expect(engine.played[0].$1, SoundVoice.bell);
    expect(engine.played[0].$2, 12.5);
    expect(engine.played[0].$3, 0.6);
    expect(engine.played[0].$4, 1.5);
    expect(engine.played[1].$1, SoundVoice.wood);
    expect(engine.played[1].$3, 2); // clamped
  });

  test('play sound lists the variables it reads', () {
    final action = PlaySoundAction(
      sound: r'${voice}',
      volume: r'${= accentGain * master}',
      at: r'${result.at}',
    );
    expect(
      action.getUsedVariableNames(),
      containsAll(['voice', 'accentGain', 'master']),
    );
  });
}
