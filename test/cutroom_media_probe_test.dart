import 'dart:async';
import 'package:codelessly_sdk/src/services/media_probe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class ProbeVideoPlatform extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final created = <DataSource>[], disposed = <int>[], played = <int>[];
  Duration duration = const Duration(milliseconds: 2375);
  Size size = const Size(640, 360);
  bool fail = false, stall = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    created.add(source);
    final id = created.length;
    events[id] = StreamController<VideoEvent>(sync: true);
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) {
    if (!stall) {
      scheduleMicrotask(() {
        if (fail) {
          events[id]!.addError(PlatformException(code: 'decode', message: 'Cannot decode video'));
        } else {
          events[id]!.add(VideoEvent(eventType: VideoEventType.initialized, duration: duration, size: size));
        }
      });
    }
    return events[id]!.stream;
  }

  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
    await events[id]!.close();
  }

  @override
  Future<void> play(int id) async => played.add(id);
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform old;
  late ProbeVideoPlatform platform;
  const url = 'https://media.example.test/film.mp4';
  setUp(() {
    old = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform = ProbeVideoPlatform();
  });
  tearDown(() => VideoPlayerPlatform.instance = old);
  test('public MP4 metadata is returned and its paused controller is disposed', () async {
    expect(await probeMedia(url), {'durationSeconds': 2.375, 'width': 640.0, 'height': 360.0, 'url': url});
    expect(platform.created.single.uri, url);
    expect(platform.played, isEmpty);
    expect(platform.disposed, [1]);
  });
  test('blocked URLs never create a controller', () async {
    for (final blocked in [
      'http://media.example.test/a.mp4',
      'https://localhost/a.mp4',
      'https://192.168.1.1/a.mp4',
      'blob:https://example.test/a',
      'https://example.test/a.webm',
    ]) {
      await expectLater(probeMedia(blocked), throwsArgumentError);
    }
    expect(platform.created, isEmpty);
    expect(platform.disposed, isEmpty);
  });
  test('decode errors dispose the controller', () async {
    platform.fail = true;
    await expectLater(probeMedia(url), throwsA(isA<PlatformException>()));
    expect(platform.disposed, [1]);
    expect(platform.played, isEmpty);
  });
  test('unsupported duration and dimensions dispose every source', () async {
    platform.duration = const Duration(seconds: 601);
    await expectLater(probeMedia(url), throwsStateError);
    platform.duration = const Duration(milliseconds: 50);
    await expectLater(probeMedia(url), throwsStateError);
    platform.duration = const Duration(seconds: 2);
    platform.size = const Size(double.infinity, 360);
    await expectLater(probeMedia(url), throwsStateError);
    platform.size = const Size(640, 0);
    await expectLater(probeMedia(url), throwsStateError);
    expect(platform.disposed, [1, 2, 3, 4]);
  });
  test('metadata timeout releases a never-initialized controller', () async {
    platform.stall = true;
    await expectLater(probeMedia(url), throwsA(isA<TimeoutException>()));
    expect(platform.disposed, [1]);
  });
  test('picked preflight validates before native unsupported result without a controller', () async {
    await expectLater(probePickedVideo('film.webm', Uint8List(1)), throwsArgumentError);
    await expectLater(probePickedVideo('film.mp4', Uint8List(1), contentType: 'application/pdf'), throwsArgumentError);
    await expectLater(probePickedVideo('film.mp4', Uint8List(0)), throwsArgumentError);
    await expectLater(probePickedVideo('film.mp4', Uint8List.fromList([0, 1, 2])), throwsUnsupportedError);
    expect(platform.created, isEmpty);
  });
}
