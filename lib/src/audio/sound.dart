import 'package:codelessly_api/codelessly_api.dart';

import 'sound_engine_stub.dart'
    if (dart.library.js_interop) 'sound_engine_web.dart';

/// Plays [PlaySoundAction]s and keeps the clock `clock` triggers tick on.
///
/// On the web sounds are synthesised with the Web Audio API and scheduled
/// on `AudioContext.currentTime`, so a click lined up ahead of time lands
/// exactly on its beat whatever the frame rate or timer jitter. Elsewhere
/// the clock is a stopwatch and sounds are silent.
abstract class SoundEngine {
  /// Whether sounds can be heard.
  bool get available;

  /// Seconds on the clock sounds are scheduled on.
  double get now;

  /// Starts (or resumes) audio; browsers allow it only after a user gesture,
  /// so this is called on every play.
  void resume();

  /// Plays [voice] at [time] seconds on [now]'s clock (now if in the past),
  /// at [volume] (0–2) and [pitch] (a ratio).
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  });
}

/// The app's sound.
abstract final class Sound {
  /// The platform's engine. Tests replace it.
  static SoundEngine engine = createSoundEngine();

  /// Seconds on the sound clock.
  static double get now => engine.now;

  /// Plays [voice]; see [SoundEngine.play].
  static void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  }) {
    engine.resume();
    engine.play(
      voice,
      time: time,
      volume: volume.clamp(0, 2).toDouble(),
      pitch: pitch.clamp(0.25, 4).toDouble(),
    );
  }

  /// [name] as a voice: a [SoundVoice] name, loosely matched, else wood.
  static SoundVoice voiceNamed(String name) {
    final String n = name.trim().toLowerCase();
    for (final SoundVoice v in SoundVoice.values) {
      if (v.name == n || v.prettify.toLowerCase() == n) return v;
    }
    return switch (n) {
      'cowbell' => SoundVoice.bell,
      'hihat' || 'hi-hat' => SoundVoice.hat,
      'woodblock' || 'wood block' => SoundVoice.wood,
      _ => SoundVoice.wood,
    };
  }
}

/// A silent engine on a stopwatch clock.
class SilentSoundEngine implements SoundEngine {
  final Stopwatch _clock = Stopwatch()..start();

  /// Sounds played so far (voice, time, volume, pitch), for tests.
  final List<(SoundVoice, double, double, double)> played = [];

  @override
  bool get available => false;

  @override
  double get now => _clock.elapsedMicroseconds / 1e6;

  @override
  void resume() {}

  @override
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  }) => played.add((voice, time ?? now, volume, pitch));
}
