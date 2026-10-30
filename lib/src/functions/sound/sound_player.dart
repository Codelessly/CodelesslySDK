import 'package:codelessly_api/codelessly_api.dart';

import 'sound_player_stub.dart'
    if (dart.library.js_interop) 'sound_player_web.dart'
    as platform;

/// Speech and short sounds for [SpeakAction] and [PlaySoundAction].
///
/// On the web, speech uses the browser's Web Speech API and presets are
/// synthesized with Web Audio. Elsewhere speech and presets are silent (no
/// text-to-speech engine ships with the SDK), and sound files play through
/// just_audio.
abstract final class SoundPlayer {
  /// Says [text] aloud, stopping whatever was being said.
  static Future<void> speak(
    String text, {
    double rate = 1,
    double pitch = 1,
    String language = 'en-US',
  }) => platform.speak(text, rate: rate, pitch: pitch, language: language);

  /// Plays [preset] at [volume] (0 to 1).
  static Future<void> playPreset(SoundPreset preset, {double volume = 1}) =>
      platform.playTones(tonesOf(preset), volume: volume);

  /// The notes of [preset]: frequency (Hz), start and length (seconds),
  /// wave and loudness.
  static List<Tone> tonesOf(SoundPreset preset) => switch (preset) {
    SoundPreset.pop => const [Tone(660, 0, 0.12), Tone(990, 0.06, 0.16)],
    SoundPreset.boing => const [
      Tone(220, 0, 0.18, wave: 'triangle', volume: 0.22),
      Tone(165, 0.1, 0.22, wave: 'triangle', volume: 0.22),
    ],
    SoundPreset.chime => const [
      Tone(784, 0, 0.18),
      Tone(988, 0.1, 0.18),
      Tone(1319, 0.2, 0.32),
    ],
    SoundPreset.fanfare => const [
      Tone(523, 0, 0.16, wave: 'triangle'),
      Tone(659, 0.14, 0.16, wave: 'triangle'),
      Tone(784, 0.28, 0.16, wave: 'triangle'),
      Tone(1047, 0.42, 0.5, wave: 'triangle'),
      Tone(784, 0.56, 0.16, wave: 'triangle'),
      Tone(1047, 0.7, 0.6, wave: 'triangle'),
    ],
    SoundPreset.tap => const [Tone(880, 0, 0.05, volume: 0.08)],
    SoundPreset.pick => const [Tone(520, 0, 0.07, volume: 0.1)],
  };
}

/// One note of a synthesized sound.
class Tone {
  /// Creates a [Tone].
  const Tone(
    this.hz,
    this.start,
    this.length, {
    this.wave = 'sine',
    this.volume = 0.18,
  });

  /// Frequency in hertz.
  final double hz;

  /// When it starts, in seconds from the sound's start.
  final double start;

  /// How long it rings, in seconds.
  final double length;

  /// Oscillator wave: `sine`, `triangle`, `square` or `sawtooth`.
  final String wave;

  /// Peak loudness, 0 to 1.
  final double volume;
}
