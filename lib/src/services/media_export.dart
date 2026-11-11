// A host media export service; scripts keep their normal no-DOM sandbox.
import '../widgets/media_players.dart' show isRemoteMediaUrl;
import 'platform/media_export_stub.dart' if (dart.library.js_interop) 'platform/media_export_web.dart';

class MediaExportRequest {
  MediaExportRequest._(this.project, this.fileName, this.width, this.height);
  final Map<String, Object?> project;
  final String fileName;
  final int width, height;
  double get duration => (project['clips'] as List).fold(
    0.0,
    (n, c) => n + ((c as Map)['end'] as num).toDouble() - (c['start'] as num).toDouble(),
  );
  factory MediaExportRequest.fromJson(
    Map<String, Object?> project, {
    String fileName = 'video.webm',
    int width = 640,
    int height = 360,
  }) {
    if (width < 16 || height < 16 || width > 1920 || height > 1080) {
      throw ArgumentError('Export size must be between 16×16 and 1920×1080');
    }
    final clips = project['clips'];
    if (clips is! List || clips.isEmpty || clips.length > 100) {
      throw ArgumentError('Choose between 1 and 100 video clips');
    }
    double total = 0;
    for (final c in clips) {
      if (c is! Map || c['url'] is! String || !isRemoteMediaUrl(c['url'] as String, const ['.mp4'])) {
        throw ArgumentError('Every clip needs a public HTTPS MP4 source');
      }
      final start = c['start'], end = c['end'];
      if (start is! num || end is! num || !start.isFinite || !end.isFinite || start < 0 || end - start < .01) {
        throw ArgumentError('Every clip needs a valid source time range');
      }
      total += end - start;
    }
    if (total > 600) {
      throw ArgumentError('Export supports videos up to ten minutes');
    }
    final music = project['musicUrl'];
    if (music != null &&
        music != '' &&
        (music is! String || !isRemoteMediaUrl(music, const ['.mp3', '.wav', '.m4a']))) {
      throw ArgumentError('Music needs a public HTTPS audio source');
    }
    final volume = project['volume'];
    if (volume != null && (volume is! num || !volume.isFinite || volume < 0 || volume > 1)) {
      throw ArgumentError('Music volume must be between zero and one');
    }
    final captions = project['captions'];
    if (captions != null && captions is! List) {
      throw ArgumentError('Captions must be a list');
    }
    for (final c in (captions as List? ?? const [])) {
      if (c is! Map || c['text'] is! String || c['start'] is! num || c['end'] is! num) {
        throw ArgumentError('Every caption needs text and timing');
      }
      for (final key in ['start', 'end', 'x', 'y', 'scale', 'rotation']) {
        final value = c[key];
        if (value != null && (value is! num || !value.isFinite)) {
          throw ArgumentError('Caption $key must be finite');
        }
      }
      if ((c['start'] as num) < 0 || (c['end'] as num) <= (c['start'] as num) || (c['end'] as num) > total) {
        throw ArgumentError('Caption timing must be inside the export');
      }
    }
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_. -]'), '_');
    return MediaExportRequest._(project, safe.endsWith('.webm') ? safe : '$safe.webm', width, height);
  }
}

abstract interface class MediaExportEngine {
  bool get available;
  Future<Map<String, Object?>> export(MediaExportRequest request, {required void Function(double) onProgress});
  void cancel();
}

class MediaExportCancelled implements Exception {
  const MediaExportCancelled();
  @override
  String toString() => 'Export cancelled';
}

/// One export at a time per app. Native hosts can supply an encoder; the
/// browser default records a WebM and downloads it without a cloud upload.
class MediaExportService {
  MediaExportService({MediaExportEngine? engine}) : engine = engine ?? createMediaExportEngine();
  final MediaExportEngine engine;
  bool _running = false;
  int _generation = 0;
  int get generation => _generation;
  bool get running => _running;
  bool get available => engine.available;
  Future<Map<String, Object?>> export(MediaExportRequest request, {void Function(double)? onProgress}) async {
    if (_running) throw StateError('An export is already running');
    if (!available) {
      throw UnsupportedError('Video export is unavailable on this platform');
    }
    _running = true;
    _generation++;
    try {
      return await engine.export(request, onProgress: (v) => onProgress?.call(v.clamp(0.0, 1.0)));
    } finally {
      _running = false;
    }
  }

  void cancel() => engine.cancel();
  void dispose() => cancel();
}

/// Duration-preserving incoming dissolve and outgoing dip weights. The held
/// previous source frame excludes captions, which are composited afterward.
({double previous, double black}) mediaTransitionAt(
  String kind,
  double position,
  double duration, {
  required bool hasPrevious,
}) => (
  previous: kind == 'Dissolve' && hasPrevious ? (1 - position / .4).clamp(0.0, 1.0) : 0,
  black: kind == 'Dip to black' ? ((position - duration + .4) / .4).clamp(0.0, 1.0) : 0,
);
