import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  final sources = <String>[];
  final disposed = <int>[];
  final played = <int>[];
  final paused = <int>[];
  final loops = <bool>[];
  final events = <int, StreamController<VideoEvent>>{};
  int nextId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource source) async {
    sources.add(source.uri!);
    final id = nextId++;
    events[id] = StreamController<VideoEvent>.broadcast(sync: true);
    return id;
  }

  void initialize(int id) => events[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 1),
      size: const Size(320, 180),
    ),
  );

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await events[playerId]!.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      loops.add(looping);
  @override
  Future<void> play(int playerId) async => played.add(playerId);
  @override
  Future<void> pause(int playerId) async => paused.add(playerId);
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform previous;
  late FakeVideoPlatform fake;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    fake = FakeVideoPlatform();
    VideoPlayerPlatform.instance = fake;
  });
  tearDown(() => VideoPlayerPlatform.instance = previous);

  VideoNode node(String? url) => VideoNode(
    id: 'video',
    name: 'Video',
    basicBoxLocal: NodeBox(0, 0, 320, 180),
    properties: VideoProperties(url: url, autoPlay: true, showControls: true),
  );

  Future<void> mount(
    WidgetTester tester,
    String? url, {
    bool preview = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: PassiveVideoWidget(node: node(url), isPreview: preview),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'only public HTTPS MP4 URLs reach the platform; preview never loads',
    (tester) async {
      for (final url in [
        'http://example.com/movie.mp4',
        'file:///movie.mp4',
        'https://localhost/movie.mp4',
        'https://127.0.0.1/movie.mp4',
        'https://192.168.1.2/movie.mp4',
        'https://example.com/movie.mov',
      ]) {
        expect(() => node(url), throwsFormatException, reason: url);
        expect(fake.sources, isEmpty, reason: url);
      }
      await mount(tester, 'https://example.com/movie.mp4', preview: true);
      expect(fake.sources, isEmpty);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    },
  );

  testWidgets('initialize, manual play/pause, loop default and lifecycle', (
    tester,
  ) async {
    const first = 'https://example.com/first.mp4';
    await mount(tester, first);
    expect(fake.sources, [first]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fake.played, isEmpty, reason: 'autoPlay content must not autoplay');
    fake.initialize(1);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Play video'), findsOneWidget);
    expect(fake.loops, [false]);
    await tester.tap(find.byTooltip('Play video'));
    await tester.pump();
    expect(fake.played, isNotEmpty);
    expect(fake.played, everyElement(1));
    // The platform reports playback state, rather than the fake assuming it.
    fake.events[1]!.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Pause video'));
    await tester.pump();
    expect(fake.paused, isNotEmpty);
    expect(fake.paused, everyElement(1));
    await mount(tester, 'https://example.com/second.mp4');
    expect(fake.sources, [first, 'https://example.com/second.mp4']);
    fake.initialize(2);
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(fake.disposed, contains(1));
    await mount(tester, null);
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(fake.disposed, contains(2));
  });

  testWidgets('poster golden uses bundled Material font and fixed viewport', (
    tester,
  ) async {
    final fonts = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await fonts.load();
    await tester.binding.setSurfaceSize(const Size(400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, null);
    expect(fake.sources, isEmpty);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/video_poster.png'),
    );
    await mount(tester, 'https://example.com/loading.mp4');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/video_loading.png'),
    );
  });
}
