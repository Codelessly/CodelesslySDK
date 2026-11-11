import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  test('transition weights match preview endpoints and midpoint', () {
    expect(mediaTransitionAt('Dissolve', 0, 2, hasPrevious: true).previous, 1);
    expect(mediaTransitionAt('Dissolve', .2, 2, hasPrevious: true).previous, .5);
    expect(mediaTransitionAt('Dissolve', .4, 2, hasPrevious: true).previous, 0);
    expect(mediaTransitionAt('Dissolve', 0, 2, hasPrevious: false).previous, 0);
    expect(mediaTransitionAt('Dip to black', 1.8, 2, hasPrevious: true).black, closeTo(.5, 1e-9));
    expect(mediaTransitionAt('Dip to black', 2, 2, hasPrevious: true).black, closeTo(1, 1e-9));
  });

  test('export request validates sources, timing, captions and dimensions', () {
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
  test('export service reports progress and guards concurrent runs', () async {
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
  test('cancellation releases the active export state', () async {
    final encoder = Encoder();
    final active = MediaExportService(engine: encoder);
    final result = active.export(MediaExportRequest.fromJson(project()));
    final expectation = expectLater(result, throwsA(isA<MediaExportCancelled>()));
    active.cancel();
    await expectation;
    expect(active.running, false);
    expect(encoder.cancelled, true);
    active.dispose();
  });
}
