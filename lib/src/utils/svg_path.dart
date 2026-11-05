import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';

import '../transformers/utils/dash_path.dart';
import 'extensions.dart';

/// Parses SVG path data ([RectangleNode.path]) into a [Path]: the M, L, H,
/// V, C, S, Q, T, A and Z commands, absolute (upper case) and relative
/// (lower case), with numbers separated by spaces, commas or signs. Returns
/// null when [data] is empty or not valid path data.
Path? parseSvgPath(String? data) {
  if (data == null || data.trim().isEmpty) return null;
  try {
    return _SvgPathParser(data).parse();
  } on FormatException {
    return null;
  }
}

class _SvgPathParser {
  _SvgPathParser(this.data);

  final String data;
  int _i = 0;

  static final RegExp _number = RegExp(
    r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
  );

  void _skipSeparators() {
    while (_i < data.length) {
      final String c = data[_i];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        _i++;
      } else {
        break;
      }
    }
  }

  bool get _atNumber {
    _skipSeparators();
    if (_i >= data.length) return false;
    return _number.matchAsPrefix(data, _i) != null;
  }

  double _readNumber() {
    _skipSeparators();
    final Match? match = _number.matchAsPrefix(data, _i);
    if (match == null) {
      throw FormatException('Expected a number', data, _i);
    }
    _i = match.end;
    return double.parse(match.group(0)!);
  }

  /// An arc flag: a single 0 or 1, which may be written without a separator.
  bool _readFlag() {
    _skipSeparators();
    if (_i >= data.length) throw FormatException('Expected a flag', data, _i);
    final String c = data[_i++];
    if (c == '0') return false;
    if (c == '1') return true;
    throw FormatException('Expected a flag', data, _i - 1);
  }

  Path parse() {
    final Path path = Path();
    Offset current = Offset.zero;
    Offset start = Offset.zero;
    // The last control point, for S and T.
    Offset? lastCubic;
    Offset? lastQuad;
    String? command;
    while (true) {
      _skipSeparators();
      if (_i >= data.length) break;
      final String c = data[_i];
      if (RegExp(r'[MmLlHhVvCcSsQqTtAaZz]').hasMatch(c)) {
        command = c;
        _i++;
      } else if (command == null ||
          command == 'Z' ||
          command == 'z' ||
          !_atNumber) {
        throw FormatException('Unexpected character', data, _i);
      } else if (command == 'M') {
        // Coordinates after a moveto are linetos.
        command = 'L';
      } else if (command == 'm') {
        command = 'l';
      }
      final bool relative = command.toLowerCase() == command;
      Offset point(double x, double y) =>
          relative ? current + Offset(x, y) : Offset(x, y);
      switch (command.toUpperCase()) {
        case 'Z':
          path.close();
          current = start;
          lastCubic = lastQuad = null;
          continue;
        case 'M':
          current = point(_readNumber(), _readNumber());
          start = current;
          path.moveTo(current.dx, current.dy);
          lastCubic = lastQuad = null;
        case 'L':
          current = point(_readNumber(), _readNumber());
          path.lineTo(current.dx, current.dy);
          lastCubic = lastQuad = null;
        case 'H':
          final double x = _readNumber();
          current = Offset(relative ? current.dx + x : x, current.dy);
          path.lineTo(current.dx, current.dy);
          lastCubic = lastQuad = null;
        case 'V':
          final double y = _readNumber();
          current = Offset(current.dx, relative ? current.dy + y : y);
          path.lineTo(current.dx, current.dy);
          lastCubic = lastQuad = null;
        case 'C':
          final Offset c1 = point(_readNumber(), _readNumber());
          final Offset c2 = point(_readNumber(), _readNumber());
          final Offset end = point(_readNumber(), _readNumber());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastCubic = c2;
          lastQuad = null;
          current = end;
        case 'S':
          final Offset c1 = lastCubic == null
              ? current
              : current * 2 - lastCubic;
          final Offset c2 = point(_readNumber(), _readNumber());
          final Offset end = point(_readNumber(), _readNumber());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastCubic = c2;
          lastQuad = null;
          current = end;
        case 'Q':
          final Offset control = point(_readNumber(), _readNumber());
          final Offset end = point(_readNumber(), _readNumber());
          path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
          lastQuad = control;
          lastCubic = null;
          current = end;
        case 'T':
          final Offset control = lastQuad == null
              ? current
              : current * 2 - lastQuad;
          final Offset end = point(_readNumber(), _readNumber());
          path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
          lastQuad = control;
          lastCubic = null;
          current = end;
        case 'A':
          final double rx = _readNumber().abs();
          final double ry = _readNumber().abs();
          final double rotation = _readNumber();
          final bool largeArc = _readFlag();
          final bool sweep = _readFlag();
          final Offset end = point(_readNumber(), _readNumber());
          if (rx == 0 || ry == 0) {
            path.lineTo(end.dx, end.dy);
          } else {
            path.arcToPoint(
              end,
              radius: Radius.elliptical(rx, ry),
              rotation: rotation,
              largeArc: largeArc,
              clockwise: sweep,
            );
          }
          lastCubic = lastQuad = null;
          current = end;
      }
    }
    return path;
  }
}

/// Strokes [path] with [color] (or [gradient]), [strokeWidth], [strokeCap]
/// and [strokeJoin], dashed by [dashPattern] when it has one.
///
/// A [gradient] is laid out over the painted box, as a box's gradient
/// paint is, so an angular gradient centred in the box runs around an arc.
class SvgPathStrokePainter extends CustomPainter {
  /// Creates a [SvgPathStrokePainter].
  const SvgPathStrokePainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
    this.gradient,
    this.strokeCap = StrokeCapEnum.none,
    this.strokeJoin = StrokeJoinEnum.miter,
    this.strokeMiterLimit = 4,
    this.dashPattern = const [],
  });

  /// The path, in the painted box's coordinates.
  final Path path;

  /// The stroke colour, used when there is no [gradient].
  final Color color;

  /// The gradient the stroke is painted with, over the painted box, or null
  /// for a solid [color].
  final Gradient? gradient;

  /// The stroke width, centered on [path].
  final double strokeWidth;

  /// The ends of the open segments.
  final StrokeCapEnum strokeCap;

  /// The corners.
  final StrokeJoinEnum strokeJoin;

  /// The miter limit for [StrokeJoinEnum.miter] corners.
  final double strokeMiterLimit;

  /// Dash and gap lengths, or empty for a solid stroke.
  final List<double> dashPattern;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap.flutterStrokeCap
      ..strokeJoin = strokeJoin.flutterStrokeJoin
      ..strokeMiterLimit = strokeMiterLimit
      ..isAntiAlias = true;
    if (gradient case final Gradient gradient) {
      paint.shader = gradient.createShader(Offset.zero & size);
    }
    final List<double> dashes = dashPattern.where((d) => d > 0).toList();
    canvas.drawPath(
      dashes.isEmpty
          ? path
          : dashPath(path, dashes.first, dashes.length > 1 ? dashes[1] : null),
      paint,
    );
  }

  @override
  bool shouldRepaint(SvgPathStrokePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.gradient != gradient ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.strokeCap != strokeCap ||
      oldDelegate.strokeJoin != strokeJoin ||
      oldDelegate.strokeMiterLimit != strokeMiterLimit ||
      !_listEquals(oldDelegate.dashPattern, dashPattern);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Clips its child to an SVG [path].
class SvgPathClipper extends CustomClipper<Path> {
  /// Creates a [SvgPathClipper].
  const SvgPathClipper(this.data);

  /// The SVG path data.
  final String data;

  @override
  Path getClip(Size size) => parseSvgPath(data) ?? Path();

  @override
  bool shouldReclip(SvgPathClipper oldClipper) => oldClipper.data != data;
}
