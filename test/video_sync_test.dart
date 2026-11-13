// A video whose position is bound to a running clock (a timeline's
// playhead): WebM sources load, seeks coalesce while scrubbing, a playing
// video only corrects drift, and reportIntervalMs makes the video a clock.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/features/media/players.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class SlowSeekVideo extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final seeks = <Duration>[], played = <int>[];
  Completer<void>? gate;
  Duration position = Duration.zero;
  int next = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    events[++next] = StreamController.broadcast(sync: true);
    return next;
  }

  void ready(int id) => events[id]!.add(VideoEvent(
      eventType: VideoEventType.initialized, duration: const Duration(seconds: 8), size: const Size(360, 640)));
  @override
  Stream<VideoEvent> videoEventsFor(int id) => events[id]!.stream;
  @override
  Future<void> dispose(int id) async => events[id]?.close();
  @override
  Future<void> play(int id) async => played.add(id);
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> seekTo(int id, Duration value) async {
    seeks.add(value);
    position = value;
    await gate?.future;
  }

  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<Duration> getPosition(int id) async => position;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late VideoPlayerPlatform old;
  late SlowSeekVideo platform;
  setUp(() {
    old = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform = SlowSeekVideo();
  });
  tearDown(() => VideoPlayerPlatform.instance = old);

  Future<void> show(WidgetTester tester, Map<String, Object?> props, {ValueChanged<Map<String, Object?>>? onStatus}) async {
    final node = api.Node.fromJson({
      'type': 'video',
      'props': {'url': 'https://cdn.example.com/clips/pier.webm?alt=media', 'showControls': false, ...props},
    })!;
    await tester.pumpWidget(MaterialApp(home: MediaVideo(node: node, preview: false, onStatus: onStatus)));
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  test('WebM, MOV and M4V sources are accepted, with query strings', () {
    expect(isRemoteMediaUrl('https://cdn.example.com/a.webm?alt=media&token=1', videoExtensions), true);
    expect(isRemoteMediaUrl('https://cdn.example.com/a.mov', videoExtensions), true);
    expect(isRemoteMediaUrl('https://cdn.example.com/a.gif', videoExtensions), false);
    expect(isRemoteMediaUrl('https://cdn.example.com/a.ogg', audioExtensions), true);
  });

  testWidgets('a fast scrub coalesces: only the newest position seeks next', (tester) async {
    await show(tester, {'playing': false, 'positionSeconds': 1.0});
    platform.ready(1);
    platform.gate = Completer();
    await flush(tester);
    expect(platform.seeks, [const Duration(seconds: 1)]);
    // Ten scrub positions while the first seek is still running.
    for (var i = 1; i <= 10; i++) {
      await show(tester, {'playing': false, 'positionSeconds': 1.0 + i / 10});
    }
    expect(platform.seeks.length, 1, reason: 'nothing queues behind a running seek');
    platform.gate!.complete();
    platform.gate = null;
    await flush(tester);
    expect(platform.seeks, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('playing, a bound position only corrects drift past syncTolerance', (tester) async {
    await show(tester, {'playing': true, 'positionSeconds': 0.0, 'syncTolerance': .3});
    platform.ready(1);
    await flush(tester);
    final start = platform.seeks.length;
    // The clock advances with the video: no seeks.
    for (var t = .04; t < 1; t += .04) {
      platform.position = Duration(microseconds: (t * 1e6).round());
      await tester.pump(const Duration(milliseconds: 500)); // controller polls the position
      await show(tester, {'playing': true, 'positionSeconds': t, 'syncTolerance': .3});
    }
    expect(platform.seeks.length, start);
    // A jump (a seek while playing) is far from the video: it seeks.
    await show(tester, {'playing': true, 'positionSeconds': 5.0, 'syncTolerance': .3});
    await flush(tester);
    expect(platform.seeks.last, const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reportIntervalMs reports the position while playing', (tester) async {
    final reports = <Map<String, Object?>>[];
    await show(tester, {'playing': true, 'reportIntervalMs': 100}, onStatus: reports.add);
    platform.ready(1);
    await flush(tester);
    platform.position = const Duration(milliseconds: 1500);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 150));
    final playing = reports.where((r) => r['playing'] == true).toList();
    expect(playing, isNotEmpty);
    expect(playing.last['positionSeconds'], 1.5);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cover fit fills the box, and the poster shows while loading', (tester) async {
    await show(tester, {'fit': 'cover', 'poster': 'https://cdn.example.com/pier.jpg'});
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    platform.ready(1);
    await flush(tester);
    expect(tester.widget<FittedBox>(find.byType(FittedBox)).fit, BoxFit.cover);
    await tester.pumpWidget(const SizedBox());
  });
}
