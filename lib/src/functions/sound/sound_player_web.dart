import 'package:web/web.dart' as web;

import 'sound_player.dart';

web.AudioContext? _context;

/// Speaks with the browser's speech synthesis.
Future<void> speak(
  String text, {
  required double rate,
  required double pitch,
  required String language,
}) async {
  if (text.trim().isEmpty) return;
  try {
    final web.SpeechSynthesis synth = web.window.speechSynthesis;
    synth.cancel();
    synth.speak(
      web.SpeechSynthesisUtterance(text)
        ..rate = rate.clamp(0.1, 4)
        ..pitch = pitch.clamp(0, 2)
        ..lang = language,
    );
  } catch (_) {
    // A browser without speech synthesis stays quiet.
  }
}

/// Synthesizes [tones] with Web Audio oscillators.
Future<void> playTones(List<Tone> tones, {required double volume}) async {
  try {
    final web.AudioContext ctx = _context ??= web.AudioContext();
    final double now = ctx.currentTime;
    for (final Tone tone in tones) {
      final web.OscillatorNode osc = ctx.createOscillator()
        ..type = tone.wave
        ..frequency.value = tone.hz;
      final web.GainNode gain = ctx.createGain();
      final double peak = (tone.volume * volume).clamp(0.0001, 1);
      gain.gain
        ..setValueAtTime(0.0001, now + tone.start)
        ..exponentialRampToValueAtTime(peak, now + tone.start + 0.02)
        ..exponentialRampToValueAtTime(0.0001, now + tone.start + tone.length);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + tone.start);
      osc.stop(now + tone.start + tone.length + 0.05);
    }
  } catch (_) {
    // No Web Audio: silent.
  }
}
