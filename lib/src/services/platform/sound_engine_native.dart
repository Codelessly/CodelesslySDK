// Native voices use owned local files, avoiding a localhost HTTP proxy.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart' as audio;
import '../sound.dart';

/// Adapter lets the note lifecycle be tested without a platform plugin.
abstract interface class NativeTonePlayer {
  Future<void> load(Uint8List wav, {required bool loop});
  void play();
  Future<void> dispose();
}

/// One temporary WAV, cancelled and removed when its voice is released.
class NativeToneFile {
  NativeToneFile({Future<Directory> Function()? directory}):_directory=directory??getTemporaryDirectory;
  final Future<Directory> Function() _directory;
  File? _file;
  bool _disposed=false;
  Future<File?> write(Uint8List wav)async{
    final directory=await _directory();
    if(_disposed)return null;
    final file=_file=File('${directory.path}/codelessly-tone-${identityHashCode(this)}.wav');
    await file.writeAsBytes(wav);
    if(_disposed){await _remove();return null;}
    return file;
  }
  Future<void> _remove()async{
    final file=_file;
    if(file==null)return;
    try{await file.delete();}on FileSystemException{if(await file.exists())rethrow;}
  }
  Future<void> dispose()async{_disposed=true;await _remove();}
}
class _AudioTonePlayer implements NativeTonePlayer {
  final audio.AudioPlayer player = audio.AudioPlayer();
  final NativeToneFile file=NativeToneFile();
  bool _disposed=false;
  @override
  Future<void> load(Uint8List wav, {required bool loop}) async {
    final source=await file.write(wav);
    if(source==null||_disposed)return;
    await player.setFilePath(source.path);
    if(!_disposed)await player.setLoopMode(loop ? audio.LoopMode.one : audio.LoopMode.off);
  }
  @override
  void play() {if(!_disposed)unawaited(player.play().catchError((Object _) {}));}
  @override
  Future<void> dispose()async{
    if(_disposed)return;_disposed=true;
    try{await player.dispose();}finally{await file.dispose();}
  }
}

/// One sample of [waveform] at [phase] radians, about −1..1. Instrument
/// voices are their wave's harmonics (no filters on this path).
double _wave(String waveform, double phase) {
  final cycle = (phase / (2 * math.pi)) % 1;
  double tri(double c) => 4 * (c - .5).abs() - 1;
  return switch (waveform) {
    'triangle' => tri(cycle),
    'square' => cycle < .5 ? .7 : -.7,
    'sawtooth' => (2 * cycle - 1) * .7,
    'felt' => .85 * tri(cycle) + .15 * math.sin(2 * phase),
    'reed' => .5 * (cycle < .5 ? 1 : -1) + .3 * math.sin(phase) + .2 * math.sin(3 * phase),
    'pluck' => .6 * math.sin(phase) + .25 * math.sin(2 * phase) + .15 * math.sin(3 * phase),
    _ => math.sin(phase),
  };
}

/// PCM16 mono WAV. An integer number of periods makes a seamless loop.
Uint8List toneWave(double frequency, double volume, {bool sustained = true, String waveform = 'sine'}) {
  const rate = 48000;
  final hz = frequency.clamp(8, 24000).toDouble();
  final cycles = math.max(1, (hz / 4).round());
  // A pluck dies away by itself: 1.6 s, not looped.
  final pluck = waveform == 'pluck';
  if (pluck) sustained = false;
  final samples = sustained ? (cycles * rate / hz).round() : (pluck ? rate * 8 ~/ 5 : rate ~/ 12);
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
    final envelope = sustained ? 1.0 : math.exp(-i / (rate * (pluck ? .55 : .015)));
    data.setInt16(
      44 + i * 2,
      (_wave(waveform, radiansPerSample * i) *
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
    implements SoundEngine, SustainedSoundEngine, DisposableSoundEngine, WaveformSoundEngine {
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

  @override
  void startNoteWithWaveform(String id,{double frequency=440,double volume=1,String waveform='sine'}){
    stopNote(id);_start(id,frequency,volume,true,waveform:waveform);
  }
  void _start(String id, double frequency, double volume, bool loop,{String waveform='sine'}) {
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
          toneWave(frequency, volume, sustained: loop,waveform:waveform),
          loop: loop && waveform != 'pluck',
        );
        if (!identical(_voices[id], output)) return;
        _available = true;
        output.play();
        if (!loop && waveform != 'pluck') {
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
