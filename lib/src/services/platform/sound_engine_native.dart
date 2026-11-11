// just_audio exposes in-memory PCM through its experimental stream source API.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart' as audio;
import '../sound.dart';

/// Adapter lets the note lifecycle be tested without a platform plugin.
abstract interface class NativeTonePlayer {
  Future<void> load(Uint8List wav, {required bool loop});
  void play();
  Future<void> dispose();
}

class _AudioTonePlayer implements NativeTonePlayer {
  final audio.AudioPlayer player = audio.AudioPlayer();
  @override
  Future<void> load(Uint8List wav, {required bool loop}) async {
    await player.setAudioSource(_WaveSource(wav));
    await player.setLoopMode(loop ? audio.LoopMode.one : audio.LoopMode.off);
  }

  @override
  void play() {
    unawaited(player.play().catchError((Object _) {}));
  }

  @override
  Future<void> dispose() => player.dispose();
}

class _WaveSource extends audio.StreamAudioSource {
  _WaveSource(this.bytes);
  final Uint8List bytes;
  @override
  Future<audio.StreamAudioResponse> request([int? start, int? end]) async {
    final a = (start ?? 0).clamp(0, bytes.length),
        b = (end ?? bytes.length).clamp(
          (start ?? 0).clamp(0, bytes.length),
          bytes.length,
        );
    return audio.StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: b - a,
      offset: a,
      stream: Stream.value(bytes.sublist(a, b)),
      contentType: 'audio/wav',
    );
  }
}

/// PCM16 mono WAV. An integer number of periods makes a seamless loop.
Uint8List toneWave(double frequency, double volume, {bool sustained = true}) {
  const rate = 48000;
  final hz = frequency.clamp(8, 24000).toDouble();
  final cycles = math.max(1, (hz / 4).round());
  final samples = sustained ? (cycles * rate / hz).round() : rate ~/ 12;
  final radiansPerSample = sustained
      ? 2 * math.pi * cycles / samples
      : 2 * math.pi * hz / rate;
  final bytes = Uint8List(44 + samples * 2), data = ByteData.sublistView(bytes);
  void text(int at, String s) {
    bytes.setRange(at, at + s.length, s.codeUnits);
  }

  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final envelope = sustained ? 1.0 : math.exp(-i / (rate * .015));
    data.setInt16(
      44 + i * 2,
      (math.sin(radiansPerSample * i) *
              volume.clamp(0, 2) *
              .1 *
              32767 *
              envelope)
          .round(),
      Endian.little,
    );
  }
  return bytes;
}

class NativeSoundEngine
    implements SoundEngine, SustainedSoundEngine, DisposableSoundEngine {
  NativeSoundEngine({NativeTonePlayer Function()? createPlayer})
    : _create = createPlayer ?? _AudioTonePlayer.new;
  final NativeTonePlayer Function() _create;
  final Map<String, NativeTonePlayer> _voices = {};
  final Stopwatch _clock = Stopwatch()..start();
  bool _available = true;
  bool _disposed = false;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stopAllNotes();
  }

  int _serial = 0;
  @override
  bool get available => !_disposed && _available;
  @override
  double get now => _clock.elapsedMicroseconds / 1e6;
  @override
  void resume() {}
  @override
  void startNote(String id, {double frequency = 440, double volume = 1}) {
    stopNote(id);
    _start(id, frequency, volume, true);
  }

  void _start(String id, double frequency, double volume, bool loop) {
    if (_disposed) return;
    NativeTonePlayer output;
    try {
      output = _create();
    } catch (_) {
      _available = false;
      return;
    }
    _voices[id] = output;
    unawaited(() async {
      try {
        await output.load(
          toneWave(frequency, volume, sustained: loop),
          loop: loop,
        );
        if (!identical(_voices[id], output)) return;
        _available = true;
        output.play();
        if (!loop) {
          Timer(const Duration(milliseconds: 150), () {
            if (identical(_voices[id], output)) stopNote(id);
          });
        }
      } catch (_) {
        if (identical(_voices[id], output)) {
          _available = false;
          stopNote(id);
        }
      }
    }());
  }

  @override
  void stopNote(String id) {
    final output = _voices.remove(id);
    if (output != null) unawaited(output.dispose().catchError((Object _) {}));
  }

  @override
  void stopAllNotes() {
    for (final id in _voices.keys.toList()) {
      stopNote(id);
    }
  }

  @override
  void play(
    SoundVoice voice, {
    double? time,
    double volume = 1,
    double pitch = 1,
  }) {
    final id = 'one-shot-${_serial++}';
    final delay = (time ?? now) - now;
    void start() => _start(id, 440 * pitch, volume, false);
    if (delay > 0) {
      Timer(Duration(microseconds: (delay * 1e6).round()), start);
    } else {
      start();
    }
  }
}

SoundEngine createSoundEngine() => NativeSoundEngine();
