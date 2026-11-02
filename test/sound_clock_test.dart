import 'package:codelessly_sdk/src/audio/sound_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the sound clock carries on when audio starts late', () {
    final SoundClock clock = SoundClock();
    // 15 s on the stopwatch while the browser holds audio back.
    expect(clock.now(wall: 15, running: false, audio: 0), 15);
    // The first tap starts audio, whose clock starts near zero: the time
    // carries on instead of going back to zero.
    expect(clock.now(wall: 15, running: true, audio: 0), 15);
    expect(clock.now(wall: 16, running: true, audio: 1), 16);
    // A sound for 16.5 on this clock plays at 1.5 on the audio clock.
    expect(clock.toAudio(16.5), 1.5);
  });

  test('it carries on when audio stops again', () {
    final SoundClock clock = SoundClock();
    expect(clock.now(wall: 2, running: true, audio: 0.5), 2);
    expect(clock.now(wall: 3, running: true, audio: 1.5), 3);
    // Audio suspended: the stopwatch takes over from the same time.
    expect(clock.now(wall: 3, running: false, audio: 1.5), 3);
    expect(clock.now(wall: 4, running: false, audio: 1.5), 4);
  });
}
