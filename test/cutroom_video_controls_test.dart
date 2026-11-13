import 'dart:async';
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/features/media/players.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideo extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final played = <int>[], paused = <int>[], disposed = <int>[];
  final seeks = <Duration>[], volumes = <double>[], loops = <bool>[];
  int next = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    events[++next] = StreamController.broadcast(sync: true);
    return next;
  }

  void ready(int id) => events[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(320, 180),
    ),
  );
  @override
  Stream<VideoEvent> videoEventsFor(int id) => events[id]!.stream;
  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
    await events[id]?.close();
  }

  @override
  Future<void> play(int id) async => played.add(id);
  @override
  Future<void> pause(int id) async => paused.add(id);
  @override
  Future<void> seekTo(int id, Duration value) async => seeks.add(value);
  @override
  Future<void> setVolume(int id, double value) async => volumes.add(value);
  @override
  Future<void> setLooping(int id, bool value) async => loops.add(value);
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late VideoPlayerPlatform old;
  late FakeVideo platform;
  setUp(() {
    old = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform = FakeVideo();
  });
  tearDown(() => VideoPlayerPlatform.instance = old);
  Future<void> show(WidgetTester tester, Map<String, Object?> props, {bool preview = false}) async {
    final node = api.Node.fromJson({
      'type': 'video',
      'props': {'url': 'https://example.com/movie.mp4', ...props},
    })!;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaVideo(node: node, preview: preview),
      ),
    );
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  testWidgets('bound source time, playing, volume and loop control a loaded video', (tester) async {
    await show(tester, {'playing': true, 'positionSeconds': 2.375, 'volume': .4, 'loop': true});
    platform.ready(1);
    await flush(tester);
    expect(platform.played, contains(1));
    expect(platform.seeks.last, const Duration(milliseconds: 2375));
    expect(platform.volumes.last, .4);
    expect(platform.loops.last, true);
    await show(tester, {'playing': false, 'positionSeconds': 100.0, 'volume': .2, 'loop': false});
    await flush(tester);
    expect(platform.paused, contains(1));
    expect(platform.seeks.last, const Duration(seconds: 10));
    expect(platform.volumes.last, .2);
    expect(platform.loops.last, false);
    final seeks = platform.seeks.length;
    await show(tester, {'playing': false, 'positionSeconds': 100.0, 'volume': .2, 'loop': false});
    await flush(tester);
    expect(platform.seeks.length, seeks, reason: 'unrelated rebuilds do not rescrub');
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
  });
  testWidgets('omitted controls preserve manual playback and design previews never load', (tester) async {
    await show(tester, {'autoPlay': true});
    platform.ready(1);
    await flush(tester);
    expect(platform.played, isEmpty);
    expect(platform.seeks, isEmpty);
    await show(tester, {'playing': true, 'positionSeconds': 2.0}, preview: true);
    await flush(tester);
    await tester.pump(const Duration(seconds: 1));
    await flush(tester);
    expect(platform.next, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
