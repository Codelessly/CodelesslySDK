// The x viewport: which rows are in view, as state.
//
// Rows sit at whole positions (row i is centered on i and half a row wide
// each side). The viewport is two numbers: the pixels from one row to the
// next, and the rows of room between the last row and the right edge
// (negative once the view is dragged back into history). Held against the
// last row, older rows put before the data move nothing, and a view at the
// end follows new rows without being told.
import 'dart:math' as math;

class GraphViewport {
  const GraphViewport({required this.barSpacing, required this.rightOffset});

  final double barSpacing;
  final double rightOffset;

  /// The position at the plot's right edge.
  double to(int count) => count - 1 + rightOffset + 0.5;

  /// The position at the plot's left edge.
  double from(int count, double width) => to(count) - width / barSpacing;

  /// The last row is in view: new rows are followed.
  bool get atEnd => rightOffset >= 0;

  /// The first and last rows at least partly in view; `(0, -1)` for none.
  (int, int) visible(int count, double width) {
    if (count == 0 || width <= 0) return (0, -1);
    final first = math.max(0, (from(count, width) - 0.5).floor() + 1);
    final last = math.min(count - 1, (to(count) + 0.5).ceil() - 1);
    return (first, last);
  }

  /// Dragged by [dx] pixels (to the right shows older rows).
  GraphViewport pan(double dx) => GraphViewport(barSpacing: barSpacing, rightOffset: rightOffset - dx / barSpacing);

  /// Zoomed by [factor] with the position under [px] (from the plot's left)
  /// staying under it.
  GraphViewport zoomAt(double px, double factor, double width, {double min = 0.5, double max = 80}) {
    final next = (barSpacing * factor).clamp(min, max);
    final right = width - px;
    return GraphViewport(barSpacing: next, rightOffset: rightOffset - right / barSpacing + right / next);
  }

  /// Kept so that at least [keep] rows stay in view on either side.
  GraphViewport clamp(int count, double width, {int keep = 2}) {
    if (count == 0 || width <= 0) return this;
    final k = math.min(keep, count);
    final most = width / barSpacing - k, least = (k - count).toDouble();
    return GraphViewport(barSpacing: barSpacing, rightOffset: most < least ? least : rightOffset.clamp(least, most));
  }

  /// After [appended] new rows: a view at the end follows them, any other
  /// stays on the rows it shows.
  GraphViewport afterAppend(int appended, {required bool follow}) =>
      appended <= 0 || (follow && atEnd) ? this : GraphViewport(barSpacing: barSpacing, rightOffset: rightOffset - appended);

  /// The view that shows the last [rows] rows across [width].
  static GraphViewport showLast(int rows, double width, {double rightOffset = 0}) =>
      GraphViewport(barSpacing: width / math.max(1, rows + rightOffset), rightOffset: rightOffset);

  @override
  bool operator ==(Object other) =>
      other is GraphViewport && other.barSpacing == barSpacing && other.rightOffset == rightOffset;

  @override
  int get hashCode => Object.hash(barSpacing, rightOffset);

  @override
  String toString() => 'GraphViewport(barSpacing: $barSpacing, rightOffset: $rightOffset)';
}
