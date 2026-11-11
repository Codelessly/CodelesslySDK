// Sounds: short synthesised voices for play sound actions, and the clock
// clock triggers tick on. Web Audio in browsers; PCM through just_audio on
// native platforms. Apps may supply their own [SoundEngine].
import 'platform/sound_engine_stub.dart' if (dart.library.io) 'platform/sound_engine_native.dart' if (dart.library.js_interop) 'platform/sound_engine_web.dart';

/// The voices a play sound action plays.
enum SoundVoice {
  /// A wood block: a pitched knock.
  wood,

  /// A clean sine beep.
  beep,

  /// A two-tone cowbell.
  bell,

  /// A rim shot: a noise burst with a knock.
  rim,

  /// A closed hi-hat: bright noise.
  hat,

  /// A bubbly pop: a tile picked up or placed.
  pop,

  /// A falling, wobbly boing: a wrong answer.
  boing,

  /// A bright two-note chime: a right answer.
  chime,

  /// A short rising fanfare: a level finished.
  fanfare,

  /// A soft tap: a button press.
  tap,

  /// A light pluck: an item picked.
  pick;

  /// [name] as a voice, loosely matched (`Cowbell`, `hi-hat`), else wood.
  static SoundVoice named(String name) {
    final n = name.trim().toLowerCase();
    for (final v in values) {
      if (v.name == n) return v;
    }
    return switch (n) {
      'cowbell' => bell,
      'hihat' || 'hi-hat' => hat,
      'woodblock' || 'wood block' => wood,
      _ => wood,
    };
  }
}

/// A platform's sound output and the clock sounds are scheduled on.
abstract interface class SoundEngine {
  /// Whether sounds can be heard.
  bool get available;

  /// Seconds on the clock sounds are scheduled on.
  double get now;

  /// Starts (or resumes) audio; browsers allow it only after a user gesture.
  void resume();

  /// Plays [voice] at [time] on [now]'s clock (now when null or past), at
  /// [volume] (0–2) and [pitch] (a ratio).
  void play(SoundVoice voice, {double? time, double volume = 1, double pitch = 1});
}

/// Optional engine capability: independently owned, sustained sine voices.
/// Kept separate so existing custom SoundEngine implementations remain valid.
abstract interface class SustainedSoundEngine {
  void startNote(String id, {double frequency = 440, double volume = 1});
  void stopNote(String id);
  void stopAllNotes();
}

/// The app's sounds, on an [engine] (the platform's by default).
class SoundService {
  SoundService({SoundEngine? engine}) : engine = engine ?? createSoundEngine();

  final SoundEngine engine;

  /// Seconds on the sound clock.
  double get now => engine.now;

  bool get available => engine.available;

  /// Starts/replaces a sustained voice. Returns false on unsupported engines.
  bool startNote(String id, {double frequency = 440, double volume = 1}) {
    final output = engine;
    if (output is! SustainedSoundEngine || id.isEmpty || !frequency.isFinite || !volume.isFinite) return false;
    output.resume();
    (output as SustainedSoundEngine).startNote(id, frequency: frequency.clamp(8, 24000).toDouble(), volume: volume.clamp(0, 2).toDouble());
    return true;
  }

  void stopNote(String id) {
    final output = engine;
    if (output is SustainedSoundEngine) (output as SustainedSoundEngine).stopNote(id);
  }

  void stopAllNotes() {
    final output = engine;
    if (output is SustainedSoundEngine) (output as SustainedSoundEngine).stopAllNotes();
  }

  /// Plays [voice]; volume is clamped to 0–2 and pitch to 0.25–4.
  void play(SoundVoice voice, {double? time, double volume = 1, double pitch = 1}) {
    engine.resume();
    engine.play(voice, time: time, volume: volume.clamp(0, 2).toDouble(), pitch: pitch.clamp(0.25, 4).toDouble());
  }
}

/// A silent engine on a stopwatch clock: off the web, and in tests.
class SilentSoundEngine implements SoundEngine, SustainedSoundEngine {
  final Map<String, (double, double)> notes = {};
  @override
  void startNote(String id, {double frequency = 440, double volume = 1}) => notes[id] = (frequency, volume);
  @override
  void stopNote(String id) => notes.remove(id);
  @override
  void stopAllNotes() => notes.clear();
  final Stopwatch _clock = Stopwatch()..start();

  /// Sounds played (voice, time, volume, pitch), for tests.
  final List<(SoundVoice, double, double, double)> played = [];

  @override
  bool get available => false;

  @override
  double get now => _clock.elapsedMicroseconds / 1e6;

  @override
  void resume() {}

  @override
  void play(SoundVoice voice, {double? time, double volume = 1, double pitch = 1}) =>
      played.add((voice, time ?? now, volume, pitch));
}

/// A clock that runs on a stopwatch while audio is held back and on the
/// audio clock once audio runs, continuous across each switch: starting
/// audio late would otherwise set the time back by the seconds the page ran
/// on the stopwatch.
class SoundClock {
  double _audioBase = 0;
  double _wallBase = 0;
  bool _onAudio = false;

  /// The time, given the stopwatch's [wall] time, whether audio is
  /// [running], and the audio clock's [audio] time (seconds).
  double now({required double wall, required bool running, required double audio}) {
    if (running != _onAudio) {
      final current = _onAudio ? audio + _audioBase : wall - _wallBase;
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
