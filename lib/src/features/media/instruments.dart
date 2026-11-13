// The media feature's instrument voices: `felt`, `reed` and `pluck`, what a
// play sound action's `waveform` may name beside the plain waves. Data only;
// SoundService registers them with its engine by default, and an app adds
// its own (`SoundService(instruments: [...kSoundInstruments, mine])`).
import 'sound.dart';

/// A felt piano: a triangle with a soft octave through a low-pass, decaying
/// to a quiet sustain.
const SoundInstrument kFeltInstrument = SoundInstrument(
  'felt',
  oscillators: [SoundOscillator('triangle', 1, 1), SoundOscillator('sine', 2, 0.18)],
  cutoffRatio: 8,
  cutoffMax: 3200,
  resonance: 0.4,
  attack: 0.004,
  envelope: [SoundEnvelopeStep(0.55, at: 0.004, tau: 0.25), SoundEnvelopeStep(0.25, at: 1.2, tau: 1.6)],
  release: 0.32,
  harmonics: [SoundOscillator('triangle', 1, .85), SoundOscillator('sine', 2, .15)],
);

/// A reed organ: square and detuned saw through a resonant filter.
const SoundInstrument kReedInstrument = SoundInstrument(
  'reed',
  oscillators: [SoundOscillator('square', 1, 0.55), SoundOscillator('sawtooth', 1.003, 0.3)],
  cutoffRatio: 5,
  cutoffMax: 2200,
  resonance: 1.2,
  attack: 0.012,
  attackLevel: 0.8,
  envelope: [SoundEnvelopeStep(0.6, at: 0.012, tau: 0.15)],
  release: 0.18,
  harmonics: [SoundOscillator('square', 1, .5), SoundOscillator('sine', 1, .3), SoundOscillator('sine', 3, .2)],
);

/// A plucked string: a saw whose filter closes as it dies away.
const SoundInstrument kPluckInstrument = SoundInstrument(
  'pluck',
  oscillators: [SoundOscillator('sawtooth', 1, 0.7), SoundOscillator('triangle', 0.5, 0.35)],
  cutoffRatio: 14,
  cutoffMax: 6000,
  cutoffSweepTo: 2.2,
  cutoffSweepTau: 0.09,
  resonance: 2,
  attack: 0.002,
  attackLevel: 1.1,
  envelope: [SoundEnvelopeStep(0.0001, at: 0.002, tau: 0.55, absolute: true)],
  release: 0.12,
  harmonics: [SoundOscillator('sine', 1, .6), SoundOscillator('sine', 2, .25), SoundOscillator('sine', 3, .15)],
  ringSeconds: 1.6,
  ringTau: .55,
);

/// The instrument voices a [SoundService] has by default.
const List<SoundInstrument> kSoundInstruments = [kFeltInstrument, kReedInstrument, kPluckInstrument];
