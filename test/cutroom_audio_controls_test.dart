import 'dart:async';
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/widgets/media_players.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class FakeAudioPlatform extends JustAudioPlatform {
  FakeAudio? player;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => player = FakeAudio(request.id);
  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    await player?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }
}

class FakeAudio extends AudioPlayerPlatform {
  FakeAudio(super.id);
  final events = StreamController<PlaybackEventMessage>.broadcast();
  final seeks = <Duration?>[], volumes = <double>[];
  int plays = 0, pauses = 0;
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => const Stream.empty();
  @override
  Future<LoadResponse> load(LoadRequest r) async {
    events.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: const Duration(seconds: 10),
        duration: const Duration(seconds: 10),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
    return LoadResponse(duration: const Duration(seconds: 10));
  }

  @override
  Future<PlayResponse> play(PlayRequest r) async {
    plays++;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest r) async {
    pauses++;
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest r) async {
    seeks.add(r.position);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest r) async {
    volumes.add(r.volume);
    return SetVolumeResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest r) async => SetLoopModeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest r) async {
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest r) async => SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest r) async => SetSkipSilenceResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest r) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(SetShuffleOrderRequest r) async => SetShuffleOrderResponse();
  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse> setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest r,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(SetAndroidAudioAttributesRequest r) async =>
      SetAndroidAudioAttributesResponse();
  @override
  Future<DisposeResponse> dispose(DisposeRequest r) async {
    await events.close();
    return DisposeResponse();
  }
}

void main() {
  late JustAudioPlatform old;
  late FakeAudioPlatform platform;
  setUp(() {
    old = JustAudioPlatform.instance;
    JustAudioPlatform.instance = platform = FakeAudioPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (_) async => null,
    );
  });
  tearDown(() {
    JustAudioPlatform.instance = old;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      null,
    );
  });
  final statuses = <Map<String, Object?>>[];
  Future<void> show(WidgetTester tester, Map<String, Object?> props) async {
    final node = api.Node.fromJson({
      'type': 'audioPlayer',
      'props': {'url': 'https://example.com/music.wav', ...props},
    })!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MediaAudioPlayer(node: node, preview: false, onStatus: statuses.add)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    }
  }

  testWidgets('controlled audio seeks, plays and pauses with source-time clamping', (tester) async {
    await show(tester, {'playing': true, 'positionSeconds': 2.375, 'volume': .4});
    final audio = platform.player!;
    expect(audio.plays, greaterThan(0));
    expect(audio.seeks, contains(const Duration(milliseconds: 2375)));
    expect(audio.volumes.last, .4);
    await show(tester, {'playing': false, 'positionSeconds': 100.0, 'volume': .2});
    expect(audio.pauses, greaterThan(0));
    expect(audio.seeks.last, const Duration(seconds: 10));
    expect(audio.volumes.last, .2);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
  });

  testWidgets('the changed status reports ready, playing and the end of the track', (tester) async {
    statuses.clear();
    await show(tester, {'playing': true});
    expect(statuses.first['ready'], true);
    expect(statuses.any((s) => s['playing'] == true), true);
    platform.player!.events.add(PlaybackEventMessage(
      processingState: ProcessingStateMessage.completed,
      updateTime: DateTime.now(),
      updatePosition: const Duration(seconds: 10),
      bufferedPosition: const Duration(seconds: 10),
      duration: const Duration(seconds: 10),
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    }
    expect(statuses.last['completed'], true);
    expect(statuses.last['playing'], false);
    await tester.pumpWidget(const SizedBox());
  });
}
