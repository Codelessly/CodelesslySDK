import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import '../widgets/media_players.dart' show isRemoteMediaUrl;
import 'media_probe_metadata.dart';
import 'platform/media_probe_stub.dart' if (dart.library.js_interop) 'platform/media_probe_web.dart' as platform;

/// Reads public remote metadata without starting playback. The runtime player's
/// existing HTTPS MP4 boundary stays unchanged.
Future<Map<String, Object?>> probeMedia(String url) async {
  if (!isRemoteMediaUrl(url, const ['.mp4'])) {
    throw ArgumentError('Choose a public HTTPS MP4 video source');
  }
  final metadata = await readVideoMetadata(VideoPlayerController.networkUrl(Uri.parse(url)));
  return {...metadata, 'url': url};
}

/// Validates explicitly picked file bytes before a host may upload them. No
/// local URL is returned or admitted to the public runtime media URL boundary.
Future<Map<String, Object?>> probePickedVideo(String name, Uint8List bytes, {String? contentType}) async {
  if (!name.toLowerCase().endsWith('.mp4') ||
      (contentType != null && contentType.isNotEmpty && contentType != 'video/mp4')) {
    throw ArgumentError('Choose an MP4 video');
  }
  if (bytes.isEmpty || bytes.length > 512 * 1024 * 1024) {
    throw ArgumentError('Choose a nonempty video smaller than 512 MB');
  }
  return platform.probePickedVideoBytes(bytes);
}
