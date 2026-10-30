import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:web/web.dart' as web;

import 'sound.dart';

SoundEngine createSoundEngine() {
  try {
    return _WebSoundEngine(web.AudioContext());
  } catch (_) {
    return SilentSoundEngine();
  }
}

/// Short synthesised voices, each under 80 ms, through a gentle compressor.
class _WebSoundEngine implements SoundEngine {
  _WebSoundEngine(this._ctx) {
    _out = _ctx.createDynamicsCompressor()
      ..threshold.value = -6
      ..ratio.value = 4;
    _out.connect(_ctx.destination);
  }

  final web.AudioContext _ctx;
  late final web.DynamicsCompressorNode _out;
  web.AudioBuffer? _noiseBuffer;

  web.AudioBuffer get _noise => _noiseBuffer ??= () {
    final double rate = _ctx.sampleRate;
    final web.AudioBuffer buffer = _ctx.createBuffer(1, rate.toInt(), rate);
    final Float32List data = Float32List(rate.toInt());
    final math.Random rng = math.Random(15);
    for (int i = 0; i < data.length; i++) {
      data[i] = rng.nextDouble() * 2 - 1;
    }
    buffer.copyToChannel(data.toJS, 0);
    return buffer;
  }();

  @override
  bool get available => true;

  @override
  double get now => _ctx.currentTime;

  @override
  void resume() {
    if (_ctx.state != 'running') _ctx.resume();
  }

  web.GainNode _envelope(double t, double gain, double decay) {
    final web.GainNode g = _ctx.createGain();
    g.gain
      ..setValueAtTime(0.0001, t)
      ..exponentialRampToValueAtTime(math.max(gain, 0.0002), t + 0.001)
      ..exponentialRampToValueAtTime(0.0001, t + decay);
    g.connect(_out);
    return g;
  }

  void _tone(double t, String type, double freq, double gain, double decay) {
    final web.OscillatorNode osc = _ctx.createOscillator()
      ..type = type
      ..frequency.setValueAtTime(freq, t);
    osc.connect(_envelope(t, gain, decay));
    osc
      ..start(t)
      ..stop(t + decay + 0.02);
  }

  void _burst(double t, double gain, double decay, double cutoff) {
    final web.AudioBufferSourceNode src = _ctx.createBufferSource()
      ..buffer = _noise;
    final web.BiquadFilterNode hp = _ctx.createBiquadFilter()
      ..type = 'highpass'
      ..frequency.setValueAtTime(cutoff, t);
    src.connect(hp);
    hp.connect(_envelope(t, gain, decay));
    src
      ..start(t, 0, decay + 0.02)
      ..stop(t + decay + 0.02);
  }

  @override
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  }) {
    if (volume <= 0.0005) return;
    final double t = math.max(time ?? 0, _ctx.currentTime);
    final double f = pitch;
    switch (voice) {
      case SoundVoice.wood:
        _tone(t, 'sine', 1200 * f, volume, 0.045);
        _tone(t, 'triangle', 2400 * f, volume * 0.25, 0.02);
      case SoundVoice.beep:
        _tone(t, 'sine', 880 * f, volume * 0.8, 0.06);
      case SoundVoice.bell:
        _tone(t, 'square', 545 * f, volume * 0.35, 0.08);
        _tone(t, 'square', 815 * f, volume * 0.35, 0.08);
      case SoundVoice.rim:
        _burst(t, volume * 0.6, 0.03, 2000 * f);
        _tone(t, 'triangle', 1700 * f, volume * 0.5, 0.025);
      case SoundVoice.hat:
        _burst(t, volume * 0.7, 0.04, 7000 * f);
    }
  }
}
