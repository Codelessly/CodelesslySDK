// Dashed paths, in place of upstream's `path_drawing` dependency (the SDK
// takes no package for it).
import 'dart:ui';

/// Where a dash pattern starts along a path: an absolute length, or a share
/// of the path's length.
class DashOffset {
  const DashOffset.absolute(double value)
      : _value = value,
        _percent = false;

  DashOffset.percentage(double value)
      : _value = value.clamp(0.0, 1.0),
        _percent = true;

  final double _value;
  final bool _percent;

  double _of(double length) => _percent ? length * _value : _value;

  @override
  bool operator ==(Object other) =>
      other is DashOffset && other._value == _value && other._percent == _percent;

  @override
  int get hashCode => Object.hash(_value, _percent);
}

/// A list read round and round.
class CircularIntervalList<T> {
  CircularIntervalList(this._values);

  final List<T> _values;
  int _i = 0;

  T get next {
    if (_i >= _values.length) _i = 0;
    return _values[_i++];
  }
}

/// [source] cut into dashes: [dashArray] gives a drawn length, then a gap,
/// and so on.
Path dashPath(
  Path source, {
  required CircularIntervalList<double> dashArray,
  DashOffset? dashOffset,
}) {
  final dest = Path();
  for (final metric in source.computeMetrics()) {
    var distance = (dashOffset ?? const DashOffset.absolute(0))._of(metric.length);
    var draw = true;
    while (distance < metric.length) {
      final len = dashArray.next;
      if (len <= 0) {
        draw = !draw;
        continue;
      }
      if (draw) dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
      distance += len;
      draw = !draw;
    }
  }
  return dest;
}
