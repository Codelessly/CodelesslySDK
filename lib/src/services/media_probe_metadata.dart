import 'package:video_player/video_player.dart';

/// Shared decoder lifecycle for public URLs and explicitly picked local bytes.
Future<Map<String, Object?>> readVideoMetadata(VideoPlayerController controller) async {
  try {
    await controller.initialize().timeout(const Duration(seconds: 20));
    final value = controller.value;
    final duration = value.duration.inMicroseconds / Duration.microsecondsPerSecond;
    final width = value.size.width, height = value.size.height;
    if (!duration.isFinite || duration < .1 || duration > 600) {
      throw StateError('Choose a video between 0.1 seconds and 10 minutes');
    }
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw StateError('The source video has invalid dimensions');
    }
    return {'durationSeconds': duration, 'width': width, 'height': height};
  } finally {
    await controller.dispose();
  }
}
