import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/services/media_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../lists/support.dart' as lists;

class Exporter implements MediaExportEngine {
  @override
  bool get available => true;
  @override
  Future<Map<String, Object?>> export(MediaExportRequest request, {required void Function(double) onProgress}) async {
    onProgress(.5);
    return {'bytes': 123, 'downloaded': true};
  }

  @override
  void cancel() {}
}

Map<String, Object?> project([String url = 'https://example.com/clip.mp4']) => {
  'clips': [
    {'url': url, 'start': 1, 'end': 3},
  ],
  'captions': [
    {'text': 'Morning', 'start': 0, 'end': 1, 'x': .5, 'y': .7},
  ],
  'volume': .5,
};

class Encoder implements MediaExportEngine {
  @override
  bool get available => true;
  final done = Completer<Map<String, Object?>>();
  bool cancelled = false;
  @override
  Future<Map<String, Object?>> export(MediaExportRequest request, {required void Function(double) onProgress}) {
    onProgress(.5);
    return done.future;
  }

  @override
  void cancel() {
    cancelled = true;
    if (!done.isCompleted) done.completeError(const MediaExportCancelled());
  }
}

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
  group('exporting a video', () {
    testWidgets('an export reports its progress and its result to the actions that started it', (tester) async {
      final services = Services(mediaExport: MediaExportService(engine: Exporter()));
      final screen = await lists.show(
        tester,
        {
          'col': {
            'type': 'box',
            'layout': {'width': 200, 'height': 100},
            'decoration': {
              'fills': [
                {'color': '#FF203638'},
              ],
            },
            'actions': [
              lists.reaction('click', [
                {
                  'type': 'callFunction',
                  'name': 'media.export',
                  'params': {
                    'project': {
                      'clips': [
                        {'url': 'https://example.com/clip.mp4', 'start': 0, 'end': 2},
                      ],
                      'captions': [],
                    },
                    'progressVariable': 'progress',
                  },
                },
                {'type': 'setVariable', 'variable': 'output', 'value': r'${result}'},
              ]),
            ],
          },
        },
        variables: [lists.v('progress', 0, VariableType.decimal), lists.v('output', {}, VariableType.map)],
        services: services,
      );
      await tester.tapAt(screen.center('col'));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(screen['progress'], .5);
      expect((screen['output'] as Map)['ok'], true);
      expect((screen['output'] as Map)['bytes'], 123);
      await tester.pumpWidget(const SizedBox());
    });

    test('an export request with bad sources, timing, captions or dimensions is refused', () {
      expect(MediaExportRequest.fromJson(project()).duration, 2);
      for (final url in [
        'http://example.com/a.mp4',
        'https://localhost/a.mp4',
        'https://127.0.0.1/a.mp4',
        'file:///a.mp4',
        'https://example.com/a.mov',
      ]) {
        expect(() => MediaExportRequest.fromJson(project(url)), throwsArgumentError);
      }
      expect(() => MediaExportRequest.fromJson(project(), width: 4000), throwsArgumentError);
      final bad = project();
      (bad['clips'] as List).first['end'] = 0;
      expect(() => MediaExportRequest.fromJson(bad), throwsArgumentError);
      final caption = project();
      (caption['captions'] as List).first['x'] = double.nan;
      expect(() => MediaExportRequest.fromJson(caption), throwsArgumentError);
    });
    test('an export reports progress and refuses a second run while one is going', () async {
      final encoder = Encoder();
      final active = MediaExportService(engine: encoder);
      final values = <double>[];
      final result = active.export(MediaExportRequest.fromJson(project()), onProgress: values.add);
      expect(active.running, true);
      expect(values, [.5]);
      await expectLater(active.export(MediaExportRequest.fromJson(project())), throwsStateError);
      encoder.done.complete({'bytes': 123, 'downloaded': true});
      expect((await result)['bytes'], 123);
      expect(active.running, false);
      active.dispose();
    });
  });

  group('importing media', () {
    for (final name in ['media.probe', 'media.import']) {
      testWidgets('$name with no source or backend fails with an error the app can handle', (tester) async {
        final screen = await lists.show(
          tester,
          {
            'col': {
              'type': 'box',
              'layout': {'width': 200, 'height': 100},
              'actions': [
                lists.reaction('click', [
                  {
                    'type': 'callFunction',
                    'name': name,
                    'params': {'url': 'http://localhost/private.mp4'},
                  },
                  {'type': 'setVariable', 'variable': 'output', 'value': r'${result}'},
                ]),
              ],
            },
          },
          variables: [lists.v('output', {}, VariableType.map)],
          services: Services(),
        );
        await tester.tapAt(screen.center('col'));
        for (var i = 0; i < 8; i++) {
          await tester.pump();
        }
        final output = screen['output'] as Map;
        expect(output['ok'], false);
        expect(output['error'], isNotEmpty);
        expect(output['error'], contains(name == 'media.probe' ? 'public HTTPS MP4' : 'cloud file storage'));
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('importing media', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late VideoPlayerPlatform old;
    late ProbeVideoPlatform platform;
    const url = 'https://media.example.test/film.mp4';
    setUp(() {
      old = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = platform = ProbeVideoPlatform();
    });
    tearDown(() => VideoPlayerPlatform.instance = old);
    test('a public video\'s duration and size are read', () async {
      expect(await probeMedia(url), {'durationSeconds': 2.375, 'width': 640.0, 'height': 360.0, 'url': url});
      expect(platform.created.single.uri, url);
      expect(platform.played, isEmpty);
      expect(platform.disposed, [1]);
    });
    test('a blocked URL is refused before anything loads', () async {
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
  });
}
