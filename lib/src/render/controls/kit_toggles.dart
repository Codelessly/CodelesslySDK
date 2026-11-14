// What the toggles, the slider and the segmented button need beyond the
// kit (render/controls/kit.dart): a value eased on the tree's ticker, the
// look of a check mark, and a few conversions from the model. No widget.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, readInt, readString;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../convert.dart';
import '../paint/icon_names.dart';
import 'tokens.dart';

/// The SSUI colors the toggles, slider and segmented button draw with
/// beyond [ControlTokens]' own (the document's theme over SSUI's).
extension ToggleTokens on ControlTokens {
  Color _named(String name, Color fallback) => theme.color(name)?.flutter ?? fallback;

  /// The page's own background (a checkbox's and radio's inside).
  Color get primaryBackground => _named('primaryBackground', surface);

  /// Muted text: a hovered toggle's outline and off track.
  Color get tertiaryText => _named('tertiaryText', onSurface.withValues(alpha: .4));

  /// White on an accent (a thumb, a check mark).
  Color get onAccent => _named('onAccent', const Color(0xFFFFFFFF));

  /// A slider's rail.
  Color get track => _named('track', primaryBorder);

  /// A segmented control's well.
  Color get subtleFill => _named('subtleFill', tertiaryBackground);

  /// The page behind a panel (a dark segmented control's well).
  Color get secondaryBackground => _named('secondaryBackground', surface);

  /// Body text.
  Color get primaryText => _named('primaryText', onSurface);
}

/// A value eased toward a target on a [Ticker] (SSUI's state change:
/// `durations.control` along an ease-out), painting [owner] as it moves.
/// Where the tree does not animate (a design canvas) it jumps.
class ControlEase {
  ControlEase(this.owner, {double value = 0})
      : _value = value,
        _from = value,
        _to = value;

  /// What repaints while it moves.
  final RenderObject owner;

  /// How long a move takes.
  Duration duration = const Duration(milliseconds: 150);

  /// Its easing (SSUI's `curves.enter`: ease-out).
  api.AnimationCurve curve = api.AnimationCurve.easeOut;

  double _value, _from, _to;
  Duration? _start;
  Ticker? _ticker;

  /// Where it is now.
  double get value => _value;

  /// Where it is going.
  double get target => _to;

  /// Whether it is moving.
  bool get moving => _ticker?.isActive ?? false;

  /// Moves to [to], eased when [animate] (else at once).
  void animateTo(double to, {required bool animate}) {
    if (to == _to && (moving || _value == to)) return;
    if (!animate || duration == Duration.zero || !owner.attached) return jumpTo(to);
    _from = _value;
    _to = to;
    _start = null;
    final t = _ticker ??= Ticker(_tick, debugLabel: 'control');
    if (t.isActive) t.stop();
    t.start();
  }

  /// Puts it at [to] now.
  void jumpTo(double to) {
    _ticker?.stop();
    _from = _to = _value = to;
    owner.markNeedsPaint();
  }

  void _tick(Duration elapsed) {
    _start ??= elapsed;
    final ms = duration.inMicroseconds;
    final t = ms <= 0 ? 1.0 : ((elapsed - _start!).inMicroseconds / ms).clamp(0.0, 1.0);
    _value = _from + (_to - _from) * curve.transform(t);
    if (t >= 1) {
      _value = _to;
      _ticker?.stop();
    }
    owner.markNeedsPaint();
  }

  /// Its owner left the tree: it lands where it was going.
  void detach() {
    if (moving) {
      _ticker?.stop();
      _value = _to;
    }
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }
}

/// [a] to [b] at [t], with [a] or [b] null as transparent.
Color lerpColor(Color? a, Color? b, double t) =>
    Color.lerp(a ?? const Color(0x00000000), b ?? const Color(0x00000000), t) ?? const Color(0x00000000);

/// [s] as Flutter's side (the model's style and stroke alignment kept).
BorderSide borderSideOf(api.BorderSide s) => BorderSide(
      color: s.color?.flutter ?? const Color(0xFF000000),
      width: s.width,
      style: s.style == api.BorderStyle.none ? BorderStyle.none : BorderStyle.solid,
      strokeAlign: s.strokeAlign.value,
    );

/// A glyph prop as the icon render object draws it: a Material icon given
/// by name alone is looked up by name; null when it shows nothing.
Json? glyphOf(Json? glyph) {
  if (glyph == null || glyph.isEmpty || glyph['show'] == false) return null;
  final codepoint = readInt(glyph['codepoint']);
  if ((codepoint == null || codepoint <= 0) && readString(glyph['image']) == null) {
    if (readString(glyph['name']) case final String name when name.isNotEmpty) return iconWithName(glyph, name);
  }
  return glyph;
}

/// The label fields [own] sets over [inherited] (the node's default text
/// style), as Flutter's: unset fields stay null for the control to fill.
TextStyle labelStyleOf(api.TextStyle own, api.TextStyle? inherited) {
  final s = inherited == null ? own : inherited.merge(own);
  final w = s.fontWeight;
  return TextStyle(
    fontFamily: s.fontFamily,
    fontSize: s.fontSize,
    fontWeight: w == null ? null : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)],
    fontStyle: s.fontStyle == null ? null : FontStyle.values.byName(s.fontStyle!.name),
    letterSpacing: s.letterSpacing,
    height: s.height,
    color: s.color?.flutter,
  );
}

/// SSUI's check mark (Lucide's `check`: a 24-unit polyline from (20, 6)
/// through (9, 17) to (4, 12), round caps, stroked as its font draws it at
/// small sizes: 2.5 units) in a square of [side] centered on [center];
/// [indeterminate] draws Lucide's `minus`.
void paintCheckMark(Canvas canvas, Offset center, double side, Color color, {bool indeterminate = false}) {
  final u = side / 24;
  final o = center - Offset(side / 2, side / 2);
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5 * u
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (indeterminate) {
    canvas.drawLine(o + Offset(5 * u, 12 * u), o + Offset(19 * u, 12 * u), paint);
    return;
  }
  canvas.drawPath(
      Path()
        ..moveTo(o.dx + 20 * u, o.dy + 6 * u)
        ..lineTo(o.dx + 9 * u, o.dy + 17 * u)
        ..lineTo(o.dx + 4 * u, o.dy + 12 * u),
      paint);
}

/// Paints SSUI's focus ring around [shape]: a 1.5 px band of [color] a
/// pixel outside it (SSUI's spread ring over a 1 px gap of the surface).
void paintFocusRingAround(Canvas canvas, RRect shape, Color color, {double gap = 1, double width = 1.5}) {
  canvas.drawRRect(
    shape.inflate(gap + width / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color,
  );
}
