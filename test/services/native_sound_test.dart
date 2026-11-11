import 'dart:async';
import 'dart:typed_data';
import 'package:codelessly_sdk/src/services/platform/sound_engine_native.dart';
import 'package:flutter_test/flutter_test.dart';

class Player implements NativeTonePlayer {
  final loaded = Completer<void>();
  bool played = false, disposed = false;
  @override
  Future<void> load(Uint8List bytes, {required bool loop}) => loaded.future;
  @override
  void play() => played = true;
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('PCM has valid RIFF length, mono sample rate and bounded samples', () {
    final bytes = toneWave(440, 2);
    final data = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(4, Endian.little), bytes.length - 8);
    expect(data.getUint32(24, Endian.little), 48000);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(40, Endian.little), bytes.length - 44);
    for (var i = 44; i < bytes.length; i += 2) {
      expect(data.getInt16(i, Endian.little).abs(), lessThanOrEqualTo(6554));
    }
  });
  test(
    'release during load prevents playback; same-pitch voices release independently',
    () async {
      final players = <Player>[];
      final engine = NativeSoundEngine(
        createPlayer: () {
          final p = Player();
          players.add(p);
          return p;
        },
      );
      engine.startNote('a', frequency: 261.6);
      engine.startNote('b', frequency: 261.6);
      engine.stopNote('a');
      players[0].loaded.complete();
      players[1].loaded.complete();
      await Future<void>.delayed(Duration.zero);
      expect(players[0].disposed, isTrue);
      expect(players[0].played, isFalse);
      expect(players[1].played, isTrue);
      expect(players[1].disposed, isFalse);
      engine.stopAllNotes();
      expect(players[1].disposed, isTrue);
    },
  );
  test('retrigger replaces only its own pending player', () async {
    final players = <Player>[];
    final engine = NativeSoundEngine(
      createPlayer: () {
        final p = Player();
        players.add(p);
        return p;
      },
    );
    engine.startNote('a');
    engine.startNote('a');
    players[0].loaded.complete();
    players[1].loaded.complete();
    await Future<void>.delayed(Duration.zero);
    expect(players[0].played, isFalse);
    expect(players[1].played, isTrue);
    engine.stopAllNotes();
  });
}
