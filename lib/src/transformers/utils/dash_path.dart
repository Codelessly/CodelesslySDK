import 'dart:ui';

/// Converts a [path] to a dashed [Path] with a given [length] and [gap].
/// The [distance] parameter can be used to offset the dash pattern.
Path dashPath(final Path path, double length,
    [double? gap, double? distance = 0]) {
  gap ??= length;
  PathMetrics pathMetrics = path.computeMetrics();
  Path dest = Path();
  for (var metric in pathMetrics) {
    bool draw = true;
    while (distance! < metric.length) {
      if (draw) {
        dest.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += length;
      } else {
        distance += gap;
      }
      draw = !draw;
    }
  }
  return dest;
}
