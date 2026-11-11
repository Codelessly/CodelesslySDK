import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:web/web.dart' as web;
import '../media_export.dart';

MediaExportEngine createMediaExportEngine() => _WebMediaExport();

class _WebMediaExport implements MediaExportEngine {
  bool _cancelled = false;
  Completer<void>? _cancelSignal;
  @override
  bool get available => web.window.has('MediaRecorder') && web.window.has('AudioContext');
  @override
  void cancel() {
    _cancelled = true;
    final signal = _cancelSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  Future<T> _wait<T>(Future<T> operation) {
    final signal = _cancelSignal;
    if (signal == null) return operation;
    return Future.any<T>([operation, signal.future.then<T>((_) => throw const MediaExportCancelled())]);
  }

  Future<void> _loaded(web.HTMLMediaElement media) async {
    final done = Completer<void>();
    void loaded(web.Event _) {
      if (!done.isCompleted) done.complete();
    }

    void error(web.Event _) {
      if (!done.isCompleted) {
        done.completeError(StateError('Source media could not be loaded. Check the URL and CORS access.'));
      }
    }

    media.onloadedmetadata = loaded.toJS;
    media.onerror = error.toJS;
    media.load();
    try {
      await _wait(done.future.timeout(const Duration(seconds: 20)));
    } finally {
      media.onloadedmetadata = null;
      media.onerror = null;
    }
  }

  Future<void> _seek(web.HTMLVideoElement video, double seconds) async {
    if (seconds == 0) return;
    final done = Completer<void>();
    video.onseeked = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    video.currentTime = seconds;
    try {
      await _wait(done.future.timeout(const Duration(seconds: 10)));
    } finally {
      video.onseeked = null;
    }
  }

  @override
  Future<Map<String, Object?>> export(MediaExportRequest request, {required void Function(double) onProgress}) async {
    _cancelled = false;
    _cancelSignal = Completer<void>();
    final canvas = web.HTMLCanvasElement()
      ..width = request.width
      ..height = request.height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    final previous = web.HTMLCanvasElement()
      ..width = request.width
      ..height = request.height;
    final previousContext = previous.getContext('2d') as web.CanvasRenderingContext2D;
    final audio = web.AudioContext(), stream = canvas.captureStream(25);
    final sound = web.HTMLAudioElement()
      ..crossOrigin = 'anonymous'
      ..loop = true;
    web.HTMLVideoElement? video;
    final prepared = <web.HTMLVideoElement>[];
    Object? encoderFailure;
    web.MediaRecorder? recorder;
    Completer<void>? stopped;
    final chunks = <web.Blob>[];
    try {
      final project = request.project, music = project['musicUrl'] as String? ?? '';
      // Decode source metadata and initial seeks before starting the recording,
      // so loading pauses between clips do not lengthen the exported timeline.
      for (final raw in project['clips'] as List) {
        final clip = raw as Map;
        final source = web.HTMLVideoElement()
          ..crossOrigin = 'anonymous'
          ..preload = 'auto'
          ..muted = true
          ..playsInline = true
          ..src = clip['url'] as String;
        prepared.add(source);
        await _loaded(source);
        final end = (clip['end'] as num).toDouble();
        if (end > source.duration + .05) throw ArgumentError('A clip extends beyond its source video');
        await _seek(source, (clip['start'] as num).toDouble());
      }
      if (music.isNotEmpty) {
        sound.src = music;
        await _loaded(sound);
        final source = audio.createMediaElementSource(sound),
            gain = audio.createGain(),
            dest = audio.createMediaStreamDestination();
        gain.gain.value = (project['volume'] as num? ?? 1).toDouble();
        source.connect(gain);
        gain.connect(dest);
        for (final track in dest.stream.getAudioTracks().toDart) {
          stream.addTrack(track);
        }
        await audio.resume().toDart;
        await _wait(sound.play().toDart);
      }
      final mime = [
        'video/webm;codecs=vp9,opus',
        'video/webm;codecs=vp8,opus',
        'video/webm',
      ].where((type) => web.MediaRecorder.isTypeSupported(type)).firstOrNull;
      if (mime == null) throw UnsupportedError('This browser has no WebM encoder');
      recorder = web.MediaRecorder(stream, web.MediaRecorderOptions(mimeType: mime, videoBitsPerSecond: 1800000));
      stopped = Completer<void>();
      recorder.ondataavailable = ((web.BlobEvent e) {
        if (e.data.size > 0) chunks.add(e.data);
      }).toJS;
      recorder.onstop = ((web.Event _) {
        if (!stopped!.isCompleted) stopped.complete();
      }).toJS;
      recorder.onerror = ((web.Event _) {
        encoderFailure = StateError('The video encoder failed');
        if (!stopped!.isCompleted) stopped.complete();
      }).toJS;
      recorder.start(100);
      double elapsed = 0;
      bool hasPrevious = false;
      var sourceIndex = 0;
      for (final raw in project['clips'] as List) {
        if (_cancelled) throw const MediaExportCancelled();
        final clip = raw as Map;
        video = prepared[sourceIndex++];
        final start = (clip['start'] as num).toDouble(), end = (clip['end'] as num).toDouble(), duration = end - start;
        if (end > video.duration + .05) throw ArgumentError('A clip extends beyond its source video');
        await _wait(video.play().toDart);
        final clock = Stopwatch()..start();
        while (clock.elapsedMicroseconds / 1e6 < duration) {
          if (_cancelled) throw const MediaExportCancelled();
          if (encoderFailure != null) throw encoderFailure!;
          final local = math.min(duration, clock.elapsedMicroseconds / 1e6), at = elapsed + local;
          context.fillStyle = '#141518'.toJS;
          context.fillRect(0, 0, request.width, request.height);
          context.drawImage(video, 0, 0, request.width, request.height);
          final transition = clip['transition'];
          if (transition == 'Dissolve' && hasPrevious && local < .4) {
            context.globalAlpha = 1 - local / .4;
            context.drawImage(previous, 0, 0);
            context.globalAlpha = 1;
          }
          if (transition == 'Dip to black') {
            context.fillStyle = 'rgba(0,0,0,${math.max(0, (local - (duration - .4)) / .4)})'.toJS;
            context.fillRect(0, 0, request.width, request.height);
          }
          for (final rawCaption in project['captions'] as List? ?? const []) {
            final c = rawCaption as Map;
            if (at < (c['start'] as num) || at >= (c['end'] as num)) continue;
            context.save();
            context.translate((c['x'] as num? ?? .5) * request.width, (c['y'] as num? ?? .7) * request.height);
            context.rotate((c['rotation'] as num? ?? 0) * math.pi / 180);
            final scale = (c['scale'] as num? ?? 1).toDouble().clamp(.5, 3.0);
            context.scale(scale, scale);
            context.textAlign = 'center';
            context.font = 'bold ${30 * request.width / 640}px sans-serif';
            context.lineWidth = 4;
            context.strokeStyle = '#141518'.toJS;
            context.strokeText(c['text'] as String, 0, 0);
            context.fillStyle = (c['style'] == 'Neon' ? '#d5ff62' : 'white').toJS;
            context.fillText(c['text'] as String, 0, 0);
            context.restore();
          }
          onProgress(at / request.duration);
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        video.pause();
        previousContext.drawImage(canvas, 0, 0);
        hasPrevious = true;
        elapsed += duration;
      }
      if (encoderFailure != null) throw encoderFailure!;
      recorder.stop();
      await stopped.future;
      final blob = web.Blob(chunks.toJS, web.BlobPropertyBag(type: mime));
      final url = web.URL.createObjectURL(blob);
      final link = web.HTMLAnchorElement()
        ..href = url
        ..download = request.fileName;
      link.click();
      Timer(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
      onProgress(1);
      return {
        'fileName': request.fileName,
        'mimeType': mime,
        'bytes': blob.size,
        'durationSeconds': request.duration,
        'downloaded': true,
      };
    } finally {
      video?.pause();
      sound.pause();
      for (final source in prepared) {
        source.pause();
        source.removeAttribute('src');
        source.load();
      }
      sound.removeAttribute('src');
      sound.load();
      _cancelSignal = null;
      if (recorder != null && recorder.state != 'inactive') {
        recorder.stop();
        await stopped?.future;
      }
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      await audio.close().toDart;
    }
  }
}
