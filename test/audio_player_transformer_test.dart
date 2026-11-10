import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'support/load_test_fonts.dart';

class FakeAudioPlayback implements AudioPlayback {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  final urls = <String>[];
  final seeks = <Duration>[];
  int plays = 0;
  int pauses = 0;
  int disposals = 0;
  Completer<void>? pendingLoad;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Future<void> setUrl(String url) {
    urls.add(url);
    return pendingLoad?.future ?? Future.value();
  }

  @override
  Future<void> play() async {
    plays++;
    states.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    pauses++;
    states.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  final loops = <bool>[];
  final volumes = <double>[];

  @override
  Future<void> setLoop(bool loop) async => loops.add(loop);

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> dispose() async {
    disposals++;
    await states.close();
    await positions.close();
    await durations.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);
  AudioPlayerNode node(String? url, {String? description}) => AudioPlayerNode(
    id: 'audio',
    name: 'Audio',
    basicBoxLocal: NodeBox(0, 0, 320, 64),
    properties: AudioPlayerProperties(
      url: url,
      description: description,
      autoPlay: true,
    ),
  );

  late List<FakeAudioPlayback> players;
  setUp(() => players = []);
  FakeAudioPlayback createPlayer() {
    final player = FakeAudioPlayback();
    players.add(player);
    return player;
  }

  Future<void> mount(
    WidgetTester tester,
    String? url, {
    bool preview = false,
    String? description,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: Center(
            child: PassiveAudioPlayerWidget(
              node: node(url, description: description),
              isPreview: preview,
              createPlayer: createPlayer,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'registry uses native audio transformer; preview never creates player',
    (tester) async {
      final audio = node('https://example.com/song.mp3');
      final manager = PassiveNodeTransformerManager(
        (id) => audio,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      expect(
        manager.getTransformerByNode(audio),
        isA<PassiveAudioPlayerTransformer>(),
      );
      await mount(tester, audio.properties.url, preview: true);
      expect(players, isEmpty);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('0:00 / --:--'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    },
  );

  testWidgets(
    'invalid URLs rejected by API before loading; missing URL stays offline',
    (tester) async {
      for (final url in [
        'http://example.com/music.mp3',
        'file:///music.mp3',
        'https://localhost/music.wav',
        'https://example.com/music.exe',
      ]) {
        expect(() => node(url), throwsFormatException);
      }
      await mount(tester, null);
      expect(players, isEmpty);
    },
  );

  testWidgets(
    'loading never autoplays, manual play pause seek and background pause',
    (tester) async {
      await mount(
        tester,
        'https://example.com/song.m4a',
        description: 'A song',
      );
      final player = players.single;
      expect(player.urls, ['https://example.com/song.m4a']);
      expect(player.plays, 0);
      expect(find.text('A song'), findsOneWidget);
      expect(find.byTooltip('Play audio'), findsOneWidget);
      await tester.tap(find.byTooltip('Play audio'));
      await tester.pump();
      expect(player.plays, 1);
      await tester.tap(find.byTooltip('Pause audio'));
      await tester.pump();
      expect(player.pauses, 1);
      player.durations.add(const Duration(seconds: 10));
      await tester.pump();
      await tester.drag(find.byType(Slider), const Offset(80, 0));
      await tester.pump();
      expect(player.seeks, isNotEmpty);
      await tester.tap(find.byTooltip('Play audio'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(player.pauses, greaterThan(1));
    },
  );

  testWidgets(
    'source replacement and preview dispose player; stale load cannot restart',
    (tester) async {
      await mount(tester, 'https://example.com/first.mp3');
      final old = players.single;
      await mount(tester, 'https://example.com/second.mp3');
      await tester.pump();
      expect(old.disposals, 1);
      expect(players.last.urls, ['https://example.com/second.mp3']);
      await mount(tester, 'https://example.com/second.mp3', preview: true);
      await tester.pump();
      expect(players.last.disposals, 1);
      expect(players.length, 2);
    },
  );

  testWidgets('load error shows unavailable state without autoplay', (
    tester,
  ) async {
    await mount(tester, 'https://example.com/broken.mp3');
    final player = players.single;
    player.states.addError(StateError('platform error'));
    await tester.pump();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(player.plays, 0);
  });

  testWidgets('poster and loading use real bundled fonts and fixed viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, null);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/audio_poster.png'),
    );
    players.clear();
    await mount(tester, 'https://example.com/loading.mp3');
    // Loading remains pending without a platform or network.
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/audio_loading.png'),
    );
  });

  group('state-driven playback', () {
    AudioPlayerNode ambient({bool background = true}) => AudioPlayerNode(
      id: 'rain',
      name: 'Rain',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      properties: AudioPlayerProperties(
        url: 'https://example.com/rain.mp3',
        loop: true,
        volume: 0.5,
        background: background,
      ),
    );

    Future<void> mountBound(
      WidgetTester tester,
      AudioPlayerNode audio,
      AudioBindings bindings, {
      bool preview = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassiveAudioPlayerWidget(
              node: audio,
              isPreview: preview,
              createPlayer: createPlayer,
              bindings: bindings,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('loop and volume are applied once loaded; bound volume wins', (
      tester,
    ) async {
      final audio = ambient();
      await mountBound(tester, audio, const AudioBindings(volume: 0.2));
      final player = players.single;
      expect(player.loops, [true]);
      expect(player.volumes, [0.2]);
      expect(player.plays, 0, reason: 'nothing plays unless bound to');
      await mountBound(tester, audio, const AudioBindings(volume: 0.8));
      expect(player.volumes, [0.2, 0.8]);
      expect(players, hasLength(1), reason: 'a volume change keeps the player');
    });

    testWidgets('a bound playing value plays and pauses', (tester) async {
      final audio = ambient();
      await mountBound(tester, audio, const AudioBindings(playing: true));
      final player = players.single;
      expect(player.plays, 1);
      await mountBound(tester, audio, const AudioBindings(playing: false));
      expect(player.pauses, 1);
      await mountBound(tester, audio, const AudioBindings(playing: false));
      expect(player.pauses, 1, reason: 'unchanged state does nothing');
    });

    testWidgets('a changed playKey plays from the start', (tester) async {
      final audio = ambient();
      await mountBound(tester, audio, const AudioBindings(playKey: 'inhale'));
      final player = players.single;
      expect(player.plays, 0, reason: 'the first key does not chime');
      await mountBound(tester, audio, const AudioBindings(playKey: 'hold'));
      expect(player.seeks, [Duration.zero]);
      expect(player.plays, 1);
      await mountBound(
        tester,
        audio,
        const AudioBindings(playKey: 'exhale', playing: false),
      );
      expect(player.plays, 1, reason: 'a muted chime stays silent');
    });

    testWidgets('a bound url loads that source', (tester) async {
      await mountBound(
        tester,
        ambient(),
        const AudioBindings(url: 'https://example.com/waves.mp3'),
      );
      expect(players.single.urls, ['https://example.com/waves.mp3']);
    });

    testWidgets(
      'background audio draws nothing at runtime, a marker in design',
      (tester) async {
        await mountBound(tester, ambient(), const AudioBindings());
        expect(find.byType(Slider), findsNothing);
        expect(find.byIcon(Icons.graphic_eq), findsNothing);
        await mountBound(
          tester,
          ambient(),
          const AudioBindings(),
          preview: true,
        );
        expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      },
    );

    test('properties round-trip through JSON', () {
      final json = ambient().toJson();
      final copy = AudioPlayerNode.fromJson(json);
      expect(copy.properties.loop, isTrue);
      expect(copy.properties.volume, 0.5);
      expect(copy.properties.background, isTrue);
    });
  });
}
