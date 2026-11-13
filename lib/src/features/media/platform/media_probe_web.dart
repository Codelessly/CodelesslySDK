import 'dart:js_interop';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;
import '../media_probe_metadata.dart';

/// Only called after explicit picked-file validation. The temporary URL never
/// leaves this preflight and is not accepted by the runtime media URL validator.
Future<Map<String, Object?>> probePickedVideoBytes(Uint8List bytes) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'video/mp4'));
  final url = web.URL.createObjectURL(blob);
  try {
    return await readVideoMetadata(VideoPlayerController.networkUrl(Uri.parse(url)));
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
