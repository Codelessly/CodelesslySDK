// Sounds: short synthesised voices for play sound actions, and the clock
// clock triggers tick on. Web Audio in browsers; PCM through just_audio on
// native platforms. Apps may supply their own [SoundEngine].
//
// Part of the media feature. The contract here knows plain waveforms only;
// an instrument voice is data ([SoundInstrument]) registered by name with
// the service, which hands it to the engine (instruments.dart has the
// first-party ones).
import 'dart:async';
import 'dart:math' as math;

import 'instruments.dart' show kSoundInstruments;
import 'platform/sound_engine_stub.dart'
    if (dart.library.io) 'platform/sound_engine_native.dart'
    if (dart.library.js_interop) 'platform/sound_engine_web.dart';

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
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  });
}

/// Optional engine capability: independently owned, sustained sine voices.
/// Kept separate so existing custom SoundEngine implementations remain valid.
abstract interface class SustainedSoundEngine {
  void startNote(String id, {double frequency = 440, double volume = 1});
  void stopNote(String id);
  void stopAllNotes();
}

/// The plain waves a sustained voice can have. `playSound` also takes the
/// name of a registered instrument ([SoundService.instruments]).
const List<String> kSoundWaveforms = ['sine', 'triangle', 'square', 'sawtooth'];

/// One oscillator of an instrument: a [wave] (`sine`, `triangle`, `square`,
/// `sawtooth`) at [ratio] times the note's frequency, at [level].
class SoundOscillator {
  const SoundOscillator(this.wave, this.ratio, this.level);
  final String wave;
  final double ratio, level;
}

/// A step of an instrument's envelope after its attack: from [at] seconds
/// the gain approaches [level] times the peak ([absolute]: [level] itself)
/// with time constant [tau].
class SoundEnvelopeStep {
  const SoundEnvelopeStep(this.level, {required this.at, required this.tau, this.absolute = false});
  final double level, at, tau;
  final bool absolute;
}

/// An instrument voice, by [name]: what a sustained voice started with
/// `waveform: <name>` sounds like. Data, so the engines hold no instrument
/// of their own: a filtered oscillator graph where the engine has one (Web
/// Audio), and the harmonics of a PCM tone where it hasn't.
class SoundInstrument {
  const SoundInstrument(
    this.name, {
    required this.oscillators,
    required this.cutoffRatio,
    required this.cutoffMax,
    this.cutoffSweepTo,
    this.cutoffSweepTau = 0,
    this.resonance = 1,
    this.attack = 0.005,
    this.attackLevel = 1,
    this.envelope = const [],
    this.release = 0.06,
    required this.harmonics,
    this.ringSeconds,
    this.ringTau = 0,
  });

  final String name;

  /// The oscillators through the low-pass filter.
  final List<SoundOscillator> oscillators;

  /// The filter's cutoff: [cutoffRatio] times the note's frequency, at most
  /// [cutoffMax] hertz; then closing towards [cutoffSweepTo] times the
  /// frequency with time constant [cutoffSweepTau], when set.
  final double cutoffRatio, cutoffMax;
  final double? cutoffSweepTo;
  final double cutoffSweepTau;

  /// The filter's Q.
  final double resonance;

  /// The gain rises to [attackLevel] times the peak in [attack] seconds,
  /// then follows [envelope]; a stopped voice fades over [release] seconds.
  final double attack, attackLevel;
  final List<SoundEnvelopeStep> envelope;
  final double release;

  /// The PCM voice: each oscillator's wave at its ratio (a harmonic number)
  /// and level, summed.
  final List<SoundOscillator> harmonics;

  /// A PCM voice that dies away by itself rings for [ringSeconds] (decaying
  /// with [ringTau]) instead of looping; null: sustained.
  final double? ringSeconds;
  final double ringTau;
}

/// An engine that plays instrument voices: told each instrument the service
/// has, it plays one when a voice starts with its name as the waveform.
abstract interface class InstrumentSoundEngine {
  void addInstrument(SoundInstrument instrument);
}

/// Hertz of MIDI note [note] (69 = A 440).
double midiToHz(num note) => 440.0 * math.pow(2, (note - 69) / 12);

/// Optional timbre support; older custom sustained engines remain compatible.
abstract interface class WaveformSoundEngine {
  void startNoteWithWaveform(String id,{double frequency=440,double volume=1,String waveform='sine'});
}

/// Optional cleanup for engines owning contexts, players or listeners.
abstract interface class DisposableSoundEngine {
  FutureOr<void> dispose();
}

/// The app's sounds, on an [engine] (the platform's by default).
class SoundService {
  SoundService({SoundEngine? engine, List<SoundInstrument> instruments = kSoundInstruments})
      : engine = engine ?? createSoundEngine(),
        instruments = {for (final i in instruments) i.name: i} {
    final output = this.engine;
    if (output is InstrumentSoundEngine) this.instruments.values.forEach((output as InstrumentSoundEngine).addInstrument);
  }

  final SoundEngine engine;

  /// The instrument voices by name (the media feature's by default): a
  /// sustained voice's `waveform` may name one. [addInstrument] adds more.
  final Map<String, SoundInstrument> instruments;

  /// Registers [instrument] (replacing one of its name).
  void addInstrument(SoundInstrument instrument) {
    instruments[instrument.name] = instrument;
    final output = engine;
    if (output is InstrumentSoundEngine) (output as InstrumentSoundEngine).addInstrument(instrument);
  }
  bool _disposed = false;
  Future<void>? _closing;
  Future<void> dispose() {
    if (_closing case final pending?) return pending;
    _disposed = true;
    stopAllNotes();
    final output = engine;
    return _closing = Future<void>.sync(() {
      if (output is DisposableSoundEngine) return (output as DisposableSoundEngine).dispose();
    });
  }

  /// Seconds on the sound clock.
  double get now => engine.now;

  bool get available => !_disposed && engine.available;

  /// Starts/replaces a sustained voice. Returns false on unsupported engines.
  bool startNote(String id, {double frequency = 440, double volume = 1}) => _startNote(id,frequency,volume,'sine');

  /// Requests a timbre when supported; legacy engines retain their original voice.
  bool startNoteWithWaveform(String id,{double frequency=440,double volume=1,String waveform='sine'}) {
    if (waveform == 'sine' || engine is! WaveformSoundEngine) return startNote(id, frequency: frequency, volume: volume);
    return _startNote(id, frequency, volume, waveform);
  }
  bool _startNote(String id,double frequency,double volume,String waveform) {
    final output = engine;
    if (_disposed ||
        output is! SustainedSoundEngine ||
        id.isEmpty ||
        !frequency.isFinite ||
        !volume.isFinite) {
      return false;
    }
    output.resume();
    final hz=frequency.clamp(8,24000).toDouble(),gain=volume.clamp(0,2).toDouble();
    if(output is WaveformSoundEngine){
      (output as WaveformSoundEngine).startNoteWithWaveform(id, frequency: hz, volume: gain, waveform: kSoundWaveforms.contains(waveform) || instruments.containsKey(waveform) ? waveform : 'sine');
    }else{
      (output as SustainedSoundEngine).startNote(id,frequency:hz,volume:gain);
    }
    return true;
  }

  void stopNote(String id) {
    final output = engine;
    if (output is SustainedSoundEngine) {
      (output as SustainedSoundEngine).stopNote(id);
    }
  }

  void stopAllNotes() {
    final output = engine;
    if (output is SustainedSoundEngine) {
      (output as SustainedSoundEngine).stopAllNotes();
    }
  }

  /// Plays [voice]; volume is clamped to 0–2 and pitch to 0.25–4.
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  }) {
    if (_disposed) return;
    engine.resume();
    engine.play(
      voice,
      time: time,
      volume: volume.clamp(0, 2).toDouble(),
      pitch: pitch.clamp(0.25, 4).toDouble(),
    );
  }
}

/// A silent engine on a stopwatch clock: off the web, and in tests.
class SilentSoundEngine implements SoundEngine, SustainedSoundEngine, WaveformSoundEngine {
  final Map<String, (double, double)> notes = {};

  /// The waveform each sounding voice was started with, for tests.
  final Map<String, String> waveforms = {};
  @override
  void startNote(String id, {double frequency = 440, double volume = 1}) {
    notes[id] = (frequency, volume);
    waveforms[id] = 'sine';
  }

  @override
  void startNoteWithWaveform(String id, {double frequency = 440, double volume = 1, String waveform = 'sine'}) {
    notes[id] = (frequency, volume);
    waveforms[id] = waveform;
  }

  @override
  void stopNote(String id) {
    notes.remove(id);
    waveforms.remove(id);
  }
  @override
  void stopAllNotes() {
    notes.clear();
    waveforms.clear();
  }

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
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  }) => played.add((voice, time ?? now, volume, pitch));
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
  double now({
    required double wall,
    required bool running,
    required double audio,
  }) {
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
