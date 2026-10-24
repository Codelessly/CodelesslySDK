import 'dart:math' as math;
import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';

import '../../utils/formula.dart';

/// The x and y bounds of a line chart's plot, in data units. Date x values
/// are epoch milliseconds of their wall-clock time (see
/// [LineChartGeometry.parseX]).
class ChartDomain {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  const ChartDomain(this.xMin, this.xMax, this.yMin, this.yMax);

  double get xSpan => xMax - xMin;

  double get ySpan => yMax - yMin;

  @override
  bool operator ==(Object other) =>
      other is ChartDomain &&
      other.xMin == xMin &&
      other.xMax == xMax &&
      other.yMin == yMin &&
      other.yMax == yMax;

  @override
  int get hashCode => Object.hash(xMin, xMax, yMin, yMax);

  @override
  String toString() => 'ChartDomain(x: $xMin..$xMax, y: $yMin..$yMax)';
}

/// Maps data values of a [domain] to pixels of a [plot] rectangle.
class ChartScale {
  final ChartDomain domain;
  final Rect plot;

  const ChartScale(this.domain, this.plot);

  /// The pixel x of data value [x].
  double px(double x) =>
      plot.left + (x - domain.xMin) / domain.xSpan * plot.width;

  /// The pixel y of data value [y].
  double py(double y) =>
      plot.bottom - (y - domain.yMin) / domain.ySpan * plot.height;

  /// The pixel position of data point [point].
  Offset toPixel(Offset point) => Offset(px(point.dx), py(point.dy));

  /// The data x at pixel x [px], clamped to the domain.
  double xAt(double px) {
    if (plot.width <= 0) return domain.xMin;
    final double x = domain.xMin + (px - plot.left) / plot.width * domain.xSpan;
    return x.clamp(domain.xMin, domain.xMax).toDouble();
  }
}

/// One cubic Bézier segment of a curve, from the previous segment's end.
typedef CubicSegment = ({Offset c1, Offset c2, Offset end});

/// Pure functions behind the line chart: reading data, the domain,
/// interpolation, the Catmull-Rom curve and readout text.
abstract final class LineChartGeometry {
  /// Reads a number from a num or a numeric string.
  static double? parseNum(Object? value) => switch (value) {
    num() when value.isFinite => value.toDouble(),
    String() => double.tryParse(value.trim()),
    _ => null,
  };

  /// Reads a date from a DateTime or an ISO string such as
  /// `2026-10-22 00:30` or `2026-10-22T00:30:00`, as its wall-clock time in
  /// a UTC DateTime: no timezone conversion happens, so the hour read is the
  /// hour written.
  static DateTime? parseDate(Object? value) {
    final DateTime? date = switch (value) {
      DateTime() => value,
      String() when double.tryParse(value.trim()) == null => DateTime.tryParse(
        value.trim(),
      ),
      _ => null,
    };
    if (date == null) return null;
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
    );
  }

  /// Whether [value] is a date rather than a number.
  static bool isDate(Object? value) => parseDate(value) != null;

  /// Reads an x value: a number, or a date as epoch milliseconds of its
  /// wall-clock time.
  static double? parseX(Object? value) =>
      parseNum(value) ?? parseDate(value)?.millisecondsSinceEpoch.toDouble();

  /// The wall-clock date of a date axis x value.
  static DateTime dateOf(double x) =>
      DateTime.fromMillisecondsSinceEpoch(x.round(), isUtc: true);

  /// Reads the points of [data], a list of maps, with x from [xField] and y
  /// from [yField], sorted by x. Items without a valid x or y are skipped.
  static List<Offset> points(List? data, String xField, String yField) {
    final List<Offset> points = [
      for (final Object? item in data ?? const [])
        if (item is Map)
          if ((parseX(item[xField]), parseNum(item[yField])) case (
            final double x,
            final double y,
          ))
            Offset(x, y),
    ];
    points.sort((a, b) => a.dx.compareTo(b.dx));
    return points;
  }

  /// Whether the x values of [data] are dates, judged by its first item
  /// with an x value.
  static bool hasDateX(List? data, String xField) {
    for (final Object? item in data ?? const []) {
      if (item is Map && item[xField] != null) return isDate(item[xField]);
    }
    return false;
  }

  /// The domain of [points]: each bound is its override when given, else
  /// the data's extent. An empty span is widened so the scale stays finite.
  static ChartDomain domain(
    List<Offset> points, {
    double? xMin,
    double? xMax,
    double? yMin,
    double? yMax,
  }) {
    double extent(Iterable<double> values, double Function(double, double) f) =>
        values.isEmpty ? 0 : values.reduce(f);
    final Iterable<double> xs = points.map((p) => p.dx);
    final Iterable<double> ys = points.map((p) => p.dy);
    double x0 = xMin ?? extent(xs, math.min);
    double x1 = xMax ?? extent(xs, math.max);
    double y0 = yMin ?? extent(ys, math.min);
    double y1 = yMax ?? extent(ys, math.max);
    if (x1 <= x0) (x0, x1) = (x0 - 0.5, x0 + 0.5);
    if (y1 <= y0) (y0, y1) = (y0 - 0.5, y0 + 0.5);
    return ChartDomain(x0, x1, y0, y1);
  }

  /// The plot rectangle of a chart of [size] with the given insets.
  static Rect plotRect(
    Size size, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) => Rect.fromLTRB(
    left,
    top,
    math.max(left, size.width - right),
    math.max(top, size.height - bottom),
  );

  /// The y of [points] (sorted by x) at [x], interpolated linearly between
  /// neighbours and held at the first and last values outside them. Null
  /// when there are no points.
  static double? interpolate(List<Offset> points, double x) {
    if (points.isEmpty) return null;
    if (x <= points.first.dx) return points.first.dy;
    if (x >= points.last.dx) return points.last.dy;
    int lo = 0, hi = points.length - 1;
    while (hi - lo > 1) {
      final int mid = (lo + hi) >> 1;
      if (points[mid].dx <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final Offset a = points[lo], b = points[hi];
    if (b.dx == a.dx) return b.dy;
    return a.dy + (b.dy - a.dy) * (x - a.dx) / (b.dx - a.dx);
  }

  /// The control points of the Catmull-Rom segment from [p1] to [p2], with
  /// [p0] before and [p3] after: `p1 + (p2 - p0) / 6` and
  /// `p2 - (p3 - p1) / 6`.
  static (Offset, Offset) catmullRomControls(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
  ) => (p1 + (p2 - p0) / 6, p2 - (p3 - p1) / 6);

  /// The cubic segments of a Catmull-Rom spline through [points], starting
  /// at the first point. The neighbours of the end points are the end
  /// points themselves.
  static List<CubicSegment> catmullRom(List<Offset> points) {
    Offset at(int i) => points[i.clamp(0, points.length - 1)];
    return [
      for (int i = 0; i < points.length - 1; i++)
        if (catmullRomControls(at(i - 1), at(i), at(i + 1), at(i + 2)) case (
          final Offset c1,
          final Offset c2,
        ))
          (c1: c1, c2: c2, end: at(i + 1)),
    ];
  }

  /// The curve through pixel [points]: a Catmull-Rom spline when [smooth],
  /// else a polyline.
  static Path curvePath(List<Offset> points, {required bool smooth}) {
    final Path path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (smooth) {
      for (final CubicSegment s in catmullRom(points)) {
        path.cubicTo(s.c1.dx, s.c1.dy, s.c2.dx, s.c2.dy, s.end.dx, s.end.dy);
      }
    } else {
      for (final Offset p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  /// The area under [curve] (through pixel [points]) down to [bottom].
  static Path areaPath(Path curve, List<Offset> points, double bottom) =>
      Path.from(curve)
        ..lineTo(points.last.dx, bottom)
        ..lineTo(points.first.dx, bottom)
        ..close();

  /// [x] as text: a date formatted with the date [pattern] (as the
  /// `formatDate` formula function does) on a date axis, else the number
  /// without trailing zeros.
  static String formatX(double x, {required bool isDate, String? pattern}) {
    if (isDate) {
      return FormulaEvaluator.formatDate(
            dateOf(x),
            pattern == null || pattern.isEmpty ? 'h:mm a' : pattern,
          ) ??
          '';
    }
    return FormulaEvaluator.stringify(
      x == x.roundToDouble() ? x.round() : double.parse(x.toStringAsFixed(4)),
    );
  }

  /// [y] times [scale] with [decimals] decimals, followed by [suffix].
  static String formatY(
    double y, {
    double scale = 1,
    int decimals = 1,
    String suffix = '',
  }) => '${(y * scale).toStringAsFixed(decimals.clamp(0, 20))}$suffix';

  /// Whether the curve rises at [x]: compares the value at [x] with the one
  /// [lookahead] further, or [lookahead] before when that is past the data.
  static bool rising(List<Offset> points, double x, double lookahead) {
    final double here = interpolate(points, x) ?? 0;
    if (points.isNotEmpty && x + lookahead > points.last.dx) {
      return here > (interpolate(points, x - lookahead) ?? here);
    }
    return (interpolate(points, x + lookahead) ?? here) > here;
  }

  /// How far ahead [rising] looks for a readout's trend: 10 minutes on a
  /// date axis, else 1 % of the domain.
  static double trendLookahead(ChartDomain domain, {required bool isDate}) =>
      isDate
      ? const Duration(minutes: 10).inMilliseconds.toDouble()
      : domain.xSpan / 100;

  /// The two lines of the scrub readout at [x]: the formatted x, and the
  /// interpolated y with an optional trend arrow.
  static (String, String) readout(
    List<Offset> points,
    double x, {
    required ChartDomain domain,
    required bool isDate,
    String? xFormat,
    double yScale = 1,
    int yDecimals = 1,
    String ySuffix = '',
    bool trend = false,
  }) {
    final double y = interpolate(points, x) ?? 0;
    final String arrow = !trend
        ? ''
        : rising(points, x, trendLookahead(domain, isDate: isDate))
        ? ' ↑'
        : ' ↓';
    return (
      formatX(x, isDate: isDate, pattern: xFormat),
      '${formatY(y, scale: yScale, decimals: yDecimals, suffix: ySuffix)}'
          '$arrow',
    );
  }

  /// Where the readout card of [size] goes for the cursor at pixel [point]:
  /// 12 px right of it, or left when it would pass the plot's right edge,
  /// and above the point, clamped to the plot.
  static Rect readoutRect(Offset point, Size size, Rect plot) {
    double left = point.dx + 12;
    if (left + size.width > plot.right) left = point.dx - 12 - size.width;
    final double top = (point.dy - size.height - 12)
        .clamp(plot.top, math.max(plot.top, plot.bottom - size.height))
        .toDouble();
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  /// Reads a color: a hex string (`#RRGGBB` or `#AARRGGBB`), a [ColorRGBA]
  /// or a [Color], with its alpha multiplied by [opacity] when given.
  static Color? parseColor(Object? value, [Object? opacity]) {
    final Color? color = switch (value) {
      Color() => value,
      ColorRGB() => Color.from(
        alpha: value is ColorRGBA ? value.a : 1,
        red: value.r,
        green: value.g,
        blue: value.b,
      ),
      String() => switch (ColorRGBA.fromHex(value.trim())) {
        final ColorRGBA c => Color.from(
          alpha: c.a,
          red: c.r,
          green: c.g,
          blue: c.b,
        ),
        null => null,
      },
      _ => null,
    };
    final double? alpha = parseNum(opacity);
    if (color == null || alpha == null) return color;
    return color.withValues(alpha: color.a * alpha.clamp(0, 1));
  }

  /// Reads a dash pattern `[on, off]`, falling back to [fallback].
  static (double, double) parseDash(Object? value, (double, double) fallback) {
    if (value is List && value.length >= 2) {
      final double? on = parseNum(value[0]), off = parseNum(value[1]);
      if (on != null && off != null && on > 0 && off >= 0) return (on, off);
    }
    return fallback;
  }
}
