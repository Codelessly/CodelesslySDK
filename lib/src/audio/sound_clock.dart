/// A clock that runs on a stopwatch while the browser holds audio back and on
/// the audio clock once audio runs, and stays continuous across each switch:
/// starting audio late would otherwise set the time back by the seconds the
/// page ran on the stopwatch, and the clocks and delays timed on it with it.
class SoundClock {
  double _audioBase = 0;
  double _wallBase = 0;
  bool _onAudio = false;

  /// The time now, given the stopwatch's [wall] time, whether audio is
  /// [running], and the audio clock's [audio] time (seconds).
  double now({
    required double wall,
    required bool running,
    required double audio,
  }) {
    if (running != _onAudio) {
      final double current = _onAudio ? audio + _audioBase : wall - _wallBase;
      if (running) {
        _audioBase = current - audio;
      } else {
        _wallBase = wall - current;
      }
      _onAudio = running;
    }
    return running ? audio + _audioBase : wall - _wallBase;
  }

  /// [time] on this clock as audio clock time, to schedule a sound at.
  double toAudio(double time) => time - _audioBase;
}
