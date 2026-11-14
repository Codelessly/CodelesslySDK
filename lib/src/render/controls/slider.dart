// The slider as a render object (`slider`), with no Material widget in its
// path. Unstyled it is SSUI's slider (design_systems/ssui: SoftSaaSSlider):
// a 6 px pill rail in `secondaryBorder` (`track` in dark), the active part in
// `primary` from the start to the thumb, a 14 px white thumb ringed by a
// 1 px `secondaryBorder` in light (never a shadow: SSUI's own casts one,
// Material's did), and a 24 px `primary` halo at 12 % while hovered, dragged or
// focused. A hugging slider is 200 × 28 (its design size when it has one).
//
// The thumb travels inside the rail (its centre half a thumb in from each
// end), except on a ruler, whose pointer travels the whole width. Drag and
// tap set the value (snapped to `divisions`, kept within `selectableMin` /
// `selectableMax`); the keys move it: arrows a step (a division, else 1 %
// of the range), Page Up / Page Down ten steps, Home / End the ends. Every
// track, thumb, tick, value indicator and colour prop of the old island
// applies; the node's `customPaint` is drawn between the parts as before
// (render/custom_paint.dart: `painter` over the track, `foregroundPainter`
// over the thumb, reading `slider.value`, `min`, `max`, `trackRect` and
// `thumbCenter` in the slider's own frame, turned for a vertical one).
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node, SliderProps;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../custom_paint.dart' show RenderCustomPaintLayer;
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../recipe.dart';
import 'kit.dart';
import 'kit_toggles.dart';
import 'overlay.dart';
import 'root.dart';
import 'tokens.dart';

/// The recipe of `slider` (lib/src/widgets/controls.dart registers it).
void sliderRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  // Its custom paint is drawn between its parts.
  final paint = chain.whereType<RenderCustomPaintLayer>().lastOrNull?..drawnByContent = true;
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final box = b.obtain<RenderSlider>('slider', RenderSlider.new)
    ..interactive = interactive
    ..configure(n, ControlTokens.of(b), Size(l.width.value, l.height.value))
    ..customPaint = paint
    ..onChanged = interactive ? (v) => fireTrigger(b, 'changed', event: {'value': v}) : null
    ..onChangeEnd = interactive ? (v) => fireTrigger(b, 'changeEnd', event: {'value': v}) : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive && n.prop(SliderProps.autofocus);
  chain.add(box);
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!box.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

/// [n]'s value indicator text: its label with `${value}` replaced.
String? sliderLabel(Node n, double value) {
  final label = n.prop(SliderProps.label);
  if (label == null || n.prop(SliderProps.showValueIndicator) == api.ShowValueIndicator.never) return null;
  final digits = n.prop(SliderProps.labelFractionDigits);
  return label.replaceAll(r'${value}', digits > 0 ? value.toStringAsFixed(digits) : value.round().toString());
}

/// A slider: its track, thumb, ticks and value, dragged, tapped and moved by
/// keys.
class RenderSlider extends RenderControl {
  RenderSlider() {
    focusNode.onKey = _key;
    _tapper = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = ((d) => _start(d.localPosition))
      ..onTapUp = ((_) => _end())
      ..onTapCancel = _cancelTap;
  }

  late final TapGestureRecognizer _tapper;
  DragGestureRecognizer? _drag;

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app).
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  Node? _node;
  late ControlTokens _tokens;
  Size _design = Size.zero;
  bool _configured = false;

  Node get node => _node!;
  ControlTokens get tokens => _tokens;

  /// The node it draws, its tokens and its design size.
  void configure(Node n, ControlTokens tokens, Size design) {
    final changed = !_configured || n != _node || design != _design || tokens.theme != _tokens.theme || tokens.dark != _tokens.dark;
    final vertical = n.prop(SliderProps.orientation) == api.Axis.vertical;
    if (_drag == null || vertical != _vertical) {
      _drag?.dispose();
      _drag = (vertical ? VerticalDragGestureRecognizer(debugOwner: this) : HorizontalDragGestureRecognizer(debugOwner: this))
        ..onStart = ((d) => _start(d.localPosition))
        ..onUpdate = ((d) => _moveTo(d.localPosition))
        ..onEnd = ((_) => _end())
        ..onCancel = _end;
    }
    _node = n;
    _tokens = tokens;
    _design = design;
    final bound = n.prop(SliderProps.value);
    if (!_configured || bound != _bound) {
      _bound = bound;
      _value = bound;
    }
    _configured = true;
    if (changed) {
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    }
    _syncIndicator();
  }

  /// The node's custom paint, drawn between its parts.
  RenderCustomPaintLayer? customPaint;

  /// Reports a new value (`changed`) and the end of a change (`changeEnd`).
  void Function(double value)? onChanged, onChangeEnd;

  double? _bound;
  double _value = 0;

  bool get _vertical => _node != null && node.prop(SliderProps.orientation) == api.Axis.vertical;

  double get min => node.prop(SliderProps.min);
  double get max => math.max(min, node.prop(SliderProps.max));
  int? get divisions => switch (node.prop(SliderProps.divisions)) { final d? when d > 0 => d, _ => null };

  /// The value shown: within the range and the selectable part of it.
  double get value => _selectable(_value.clamp(min, max));

  double _selectable(double v) {
    final lo = (node.prop(SliderProps.selectableMin) ?? min).clamp(min, max);
    final hi = (node.prop(SliderProps.selectableMax) ?? max).clamp(lo, max);
    return v.clamp(lo, hi);
  }

  double _snap(double v) {
    v = v.clamp(min, max);
    final d = divisions, range = max - min;
    if (d != null && range > 0) {
      final unit = range / d;
      return min + ((v - min) / unit).round() * unit;
    }
    return v;
  }

  /// Where the value is in the range (0–1).
  double get fraction => max <= min ? 0 : ((value - min) / (max - min)).clamp(0.0, 1.0);

  void _set(double v, {bool end = false}) {
    final kept = _selectable(_snap(v));
    if (kept != _value) {
      _value = kept;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
      _syncIndicator();
      onChanged?.call(kept);
    }
    if (end) onChangeEnd?.call(value);
  }

  // --- pointer -----------------------------------------------------------------------

  bool _dragging = false;

  /// Whether a drag or press is moving the thumb.
  bool get dragging => _dragging;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_interactive || !enabled) return;
    if (event is PointerDownEvent) {
      _drag?.addPointer(event);
      _tapper.addPointer(event);
    }
  }

  @override
  MouseCursor get cursor => _interactive ? super.cursor : MouseCursor.defer;

  void _start(Offset local) {
    if (!enabled) return;
    if (!focusNode.hasFocus) focusNode.requestFocus();
    _dragging = true;
    _set(_valueAt(local));
    markNeedsPaint();
    _syncIndicator();
  }

  void _moveTo(Offset local) {
    if (!_dragging) return;
    _set(_valueAt(local));
  }

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    markNeedsPaint();
    _syncIndicator();
    onChangeEnd?.call(value);
  }

  // A tap that a drag took over: the drag goes on.
  void _cancelTap() {}

  /// The value under [local] (in the box).
  double _valueAt(Offset local) {
    final frame = _vertical ? Offset(size.height - local.dy, local.dx) : local;
    final (:start, :end) = _travel;
    var t = end <= start ? 0.0 : ((frame.dx - start) / (end - start)).clamp(0.0, 1.0);
    if (node.prop(SliderProps.inverted)) t = 1 - t;
    return min + t * (max - min);
  }

  // --- keyboard ------------------------------------------------------------------------

  /// A key step: a division, else 1 % of the range.
  double get step {
    final d = divisions, range = max - min;
    return d != null ? range / d : range / 100;
  }

  bool _key(KeyEvent event) {
    if (!_interactive || !enabled) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final k = event.logicalKey;
    final inverted = node.prop(SliderProps.inverted);
    double? to;
    if (k == LogicalKeyboardKey.arrowUp) {
      to = value + step;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      to = value - step;
    } else if (k == LogicalKeyboardKey.arrowRight) {
      to = value + (inverted && !_vertical ? -step : step);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      to = value - (inverted && !_vertical ? -step : step);
    } else if (k == LogicalKeyboardKey.pageUp) {
      to = value + _pageStep;
    } else if (k == LogicalKeyboardKey.pageDown) {
      to = value - _pageStep;
    } else if (k == LogicalKeyboardKey.home) {
      to = min;
    } else if (k == LogicalKeyboardKey.end) {
      to = max;
    }
    if (to == null) return false;
    _set(to, end: true);
    return true;
  }

  /// Ten steps (a tenth of a discrete slider's divisions, at least one).
  double get _pageStep {
    final d = divisions;
    return d != null ? step * math.max(1, (d / 10).round()) : step * 10;
  }

  void increase() => _set(value + step, end: true);
  void decrease() => _set(value - step, end: true);

  // --- geometry ------------------------------------------------------------------------

  Size get _natural => Size(_design.width > 0 ? _design.width : 200, _design.height > 0 ? _design.height : 28);

  @override
  double computeMinIntrinsicWidth(double height) => _natural.width;
  @override
  double computeMaxIntrinsicWidth(double height) => _natural.width;
  @override
  double computeMinIntrinsicHeight(double width) => _natural.height;
  @override
  double computeMaxIntrinsicHeight(double width) => _natural.height;
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(_natural);
  @override
  void performLayout() => size = constraints.constrain(_natural);

  /// Its own frame: along the track × across it (a vertical slider's is
  /// its box turned a quarter, the minimum at the bottom).
  Size get frame => _vertical ? Size(size.height, size.width) : size;

  bool get _ruler => node.prop(SliderProps.trackShape) == api.SliderTrackShape.ruler;

  double get trackHeight => node.prop(SliderProps.trackHeight) ?? 6;

  /// The track in the frame.
  Rect get trackRect {
    final f = frame;
    final pad = node.prop(SliderProps.padding)?.flutter ?? EdgeInsets.zero;
    final cy = pad.top + (f.height - pad.vertical) / 2;
    final h = _ruler ? 2.0 : trackHeight;
    return Rect.fromLTRB(pad.left, cy - h / 2, math.max(pad.left, f.width - pad.right), cy + h / 2);
  }

  /// The thumb's size (along the track × across it).
  Size get thumbSize {
    final n = node;
    if (!n.prop(SliderProps.showThumb)) return Size.zero;
    final s = n.prop(SliderProps.thumbSize);
    return switch (n.prop(SliderProps.thumbShape)) {
      api.SliderThumbShape.circle => Size.square(2 * _thumbRadius),
      api.SliderThumbShape.pointer => const Size(14, 28),
      _ => Size(s.dx, s.dy),
    };
  }

  /// A round thumb's radius: SSUI's 7 unless the node sets one.
  double get _thumbRadius => node.props.has(SliderProps.thumbRadius) ? node.prop(SliderProps.thumbRadius) : 7;

  /// Where the thumb's centre runs: inside the track by half the thumb (a
  /// ruler's pointer: the whole track).
  ({double start, double end}) get _travel {
    final r = trackRect;
    final half = _ruler ? 0.0 : thumbSize.width / 2;
    return (start: r.left + half, end: math.max(r.left + half, r.right - half));
  }

  /// The frame's x of [t] (0–1 of the range).
  double _x(double t) {
    final (:start, :end) = _travel;
    final along = node.prop(SliderProps.inverted) ? 1 - t : t;
    return start + along * (end - start);
  }

  /// The thumb's centre in the frame.
  Offset get thumbCentre => Offset(_x(fraction), trackRect.center.dy);

  // --- look ------------------------------------------------------------------------------

  Color? _c(api.Color? c) => c?.flutter;

  Color get activeTrackColor => _c(node.prop(SliderProps.activeTrackColor)) ?? _tokens.primary;

  /// The rail: SSUI's `secondaryBorder`, its `track` in dark.
  Color get inactiveTrackColor =>
      _c(node.prop(SliderProps.inactiveTrackColor)) ?? (_tokens.dark ? _tokens.track : _tokens.secondaryBorder);

  Color get thumbColor => _c(node.prop(SliderProps.thumbColor)) ?? _tokens.onAccent;

  /// Whether the halo shows (hovered, dragged or focused).
  bool get haloShown => _interactive && enabled && node.prop(SliderProps.showThumb) && (hovered || _dragging || focusNode.hasFocus);

  /// The shadows the thumb casts: none (the glow is the node's own).
  List<BoxShadow> get thumbShadows => const [];

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (255; disabled 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintSlider, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintSlider(context, offset);
  }

  void _paintSlider(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (_vertical) {
      canvas.translate(0, size.height);
      canvas.rotate(-math.pi / 2);
    }
    final track = trackRect;
    final thumb = thumbCentre;
    _paintTrack(canvas, track, thumb);
    _paintTicks(canvas, track);
    final locals = <String, Object?>{
      'slider': {
        'value': value,
        'min': min,
        'max': max,
        'trackRect': {'left': track.left, 'top': track.top, 'width': track.width, 'height': track.height},
        'thumbCenter': {'x': thumb.dx, 'y': thumb.dy},
      },
    };
    customPaint?.drawFor(this, canvas, Offset.zero, frame, locals, foreground: false);
    _paintThumb(canvas, thumb);
    customPaint?.drawFor(this, canvas, Offset.zero, frame, locals, foreground: true);
    canvas.restore();
  }

  void _paintTrack(Canvas canvas, Rect track, Offset thumb) {
    final n = node;
    final kind = n.prop(SliderProps.trackShape);
    final inactive = Paint()..color = inactiveTrackColor;
    final active = Paint()..color = activeTrackColor;
    if (kind == api.SliderTrackShape.ruler) {
      // A strip across the whole width, the active colour from zero (or the
      // minimum) to the value under it.
      final cy = track.center.dy, base = cy + 1;
      canvas.drawRect(Rect.fromLTRB(track.left, cy - 9, track.right, base), inactive);
      final range = max - min;
      final zeroT = range <= 0 || min > 0 || max < 0 ? 0.0 : (0 - min) / range;
      final zero = _x(zeroT);
      canvas.drawRect(Rect.fromLTRB(math.min(zero, thumb.dx), base + 1, math.max(zero, thumb.dx), base + 4), active);
      return;
    }
    final radius = Radius.circular(kind == api.SliderTrackShape.rectangle ? 0 : track.height / 2);
    RRect rr(Rect r) => RRect.fromRectAndRadius(r, radius);
    // The active part runs from the start (the end when filling from the
    // end; the other way when inverted) to the thumb.
    final fromEnd = n.prop(SliderProps.fillFromEnd) != n.prop(SliderProps.inverted);
    final gap = kind == api.SliderTrackShape.gapped ? thumbSize.width / 2 + 6 : 0.0;
    if (gap > 0) {
      // Gapped: two parts with a gap round the thumb.
      final before = Rect.fromLTRB(track.left, track.top, math.max(track.left, thumb.dx - gap), track.bottom);
      final after = Rect.fromLTRB(math.min(track.right, thumb.dx + gap), track.top, track.right, track.bottom);
      if (before.width > 0) canvas.drawRRect(rr(before), fromEnd ? inactive : active);
      if (after.width > 0) canvas.drawRRect(rr(after), fromEnd ? active : inactive);
    } else {
      canvas.drawRRect(rr(track), inactive);
      final secondary = n.prop(SliderProps.secondaryTrackValue);
      if (secondary != null && max > min) {
        final sx = _x(((secondary.clamp(min, max) - min) / (max - min)));
        final r = fromEnd
            ? Rect.fromLTRB(math.min(sx, thumb.dx), track.top, thumb.dx, track.bottom)
            : Rect.fromLTRB(thumb.dx, track.top, math.max(sx, thumb.dx), track.bottom);
        if (r.width > 0) {
          canvas.drawRRect(
              rr(r), Paint()..color = _c(n.prop(SliderProps.secondaryActiveTrackColor)) ?? activeTrackColor.withValues(alpha: .3));
        }
      }
      final fill = fromEnd
          ? Rect.fromLTRB(thumb.dx, track.top, track.right, track.bottom)
          : Rect.fromLTRB(track.left, track.top, thumb.dx, track.bottom);
      if (fill.width > 0) canvas.drawRRect(rr(fill), active);
    }
  }

  void _paintTicks(Canvas canvas, Rect track) {
    final n = node, d = divisions;
    if (d == null) return;
    if (n.prop(SliderProps.tickMarkStyle) == api.SliderTickMarkStyle.notch) {
      // Thin notches under the track, every `notchEvery` division, every
      // fifth of those longer.
      final every = math.max(1, n.prop(SliderProps.notchEvery));
      final paint = Paint()..color = _c(n.prop(SliderProps.inactiveTickMarkColor)) ?? _tokens.tertiaryText;
      final top = track.center.dy + trackHeight / 2 + 3;
      for (var i = 0; i <= d; i += every) {
        final x = _x(i / d);
        final major = (i ~/ every) % 5 == 0;
        canvas.drawRect(Rect.fromLTWH(x - 0.5, top, 1, major ? 8 : 5), paint);
      }
      return;
    }
    // Dots on the track, only when the node asks for them (SSUI draws none).
    final radius = n.prop(SliderProps.tickMarkRadius);
    final activeColor = _c(n.prop(SliderProps.activeTickMarkColor));
    final inactiveColor = _c(n.prop(SliderProps.inactiveTickMarkColor));
    if (radius == null && activeColor == null && inactiveColor == null) return;
    final r = radius ?? trackHeight / 4;
    final at = fraction;
    for (var i = 0; i <= d; i++) {
      final t = i / d;
      final on = n.prop(SliderProps.fillFromEnd) ? t >= at : t <= at;
      final color = on ? activeColor ?? _tokens.onAccent.withValues(alpha: .54) : inactiveColor ?? _tokens.primary.withValues(alpha: .54);
      canvas.drawCircle(Offset(_x(t), track.center.dy), r, Paint()..color = color);
    }
  }

  void _paintThumb(Canvas canvas, Offset c) {
    final n = node;
    if (!n.prop(SliderProps.showThumb)) return;
    final shape = n.prop(SliderProps.thumbShape);
    final size = thumbSize;
    if (haloShown && shape != api.SliderThumbShape.pointer) {
      final halo = _c(n.prop(SliderProps.overlayColor)) ?? _tokens.primary.withValues(alpha: .12);
      if (halo.a > 0) canvas.drawCircle(c, n.prop(SliderProps.overlayRadius) ?? 12, Paint()..color = halo);
    }
    final glow = _c(n.prop(SliderProps.thumbGlowColor));
    if (glow != null && glow.a > 0 && !size.isEmpty) {
      final blur = n.prop(SliderProps.thumbGlowBlur);
      final grow = math.max(0.0, n.prop(SliderProps.thumbGlowSpread));
      final paint = Paint()..color = glow;
      if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      if (shape == api.SliderThumbShape.circle) {
        canvas.drawCircle(c, size.shortestSide / 2 + grow, paint);
      } else {
        final rect = Rect.fromCenter(center: c, width: size.width + grow * 2, height: size.height + grow * 2);
        final radius = math.min(n.prop(SliderProps.thumbCornerRadius) + grow, rect.shortestSide / 2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
      }
    }
    switch (shape) {
      case api.SliderThumbShape.circle:
        final r = _thumbRadius;
        if (r <= 0) return;
        canvas.drawCircle(c, r, Paint()..color = thumbColor);
        // A ring of the node's stroke, else SSUI's hairline where a white
        // thumb would not stand out from a light page.
        final own = _c(n.prop(SliderProps.thumbStrokeColor));
        final width = own != null ? math.min(n.prop(SliderProps.thumbStrokeWidth), r) : (thumbColor.a > .9 && !_tokens.dark ? 1.0 : 0.0);
        final color = own ?? _tokens.secondaryBorder;
        if (width > 0 && color.a > 0) {
          canvas.drawCircle(
              c,
              r - width / 2,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = width
                ..color = color);
        }
      case api.SliderThumbShape.roundedRect:
        if (size.isEmpty) return;
        final radius = math.max(0.0, math.min(n.prop(SliderProps.thumbCornerRadius), size.shortestSide / 2));
        final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: size.width, height: size.height), Radius.circular(radius));
        canvas.drawRRect(rect, Paint()..color = thumbColor);
        final stroke = _c(n.prop(SliderProps.thumbStrokeColor));
        final w = n.prop(SliderProps.thumbStrokeWidth);
        if (stroke != null && w > 0) {
          final width = math.min(w, size.shortestSide / 2);
          canvas.drawRRect(
              rect.deflate(width / 2),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = width
                ..color = stroke);
        }
      case api.SliderThumbShape.rectangle:
        if (size.isEmpty) return;
        final body =
            RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: size.width, height: size.height), Radius.circular(n.prop(SliderProps.thumbCornerRadius)));
        canvas.drawRRect(body, Paint()..color = thumbColor);
        final border = _c(n.prop(SliderProps.thumbBorderColor));
        final bw = n.prop(SliderProps.thumbBorderWidth);
        if (border != null && border.a > 0 && bw > 0) {
          canvas.drawRRect(
              body.deflate(bw / 2),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = bw
                ..color = border);
        }
      case api.SliderThumbShape.pointer:
        // A ruler's index: a hairline down across the track and a triangle
        // under it pointing up, outlined in the stroke colour.
        final stroke = _c(n.prop(SliderProps.thumbStrokeColor)) ?? const Color(0xFF000000);
        final color = _c(n.prop(SliderProps.thumbColor)) ?? stroke;
        final x = c.dx, cy = c.dy;
        canvas.drawLine(
            Offset(x, cy - 13),
            Offset(x, cy + 5),
            Paint()
              ..color = color
              ..strokeWidth = 2);
        final triangle = Path()
          ..moveTo(x, cy + 5)
          ..lineTo(x - 7, cy + 14)
          ..lineTo(x + 7, cy + 14)
          ..close();
        canvas.drawPath(triangle, Paint()..color = color);
        canvas.drawPath(
            triangle,
            Paint()
              ..color = stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
    }
  }

  // --- value indicator -------------------------------------------------------------------

  RenderSliderValueIndicator? _bubble;
  RenderControlRoot? _bubbleRoot;
  bool _bubbleScheduled = false;

  /// Whether the value indicator shows now (Flutter's `ShowValueIndicator`).
  bool get indicatorShown {
    if (!_interactive || !attached || sliderLabel(node, value) == null) return false;
    return switch (node.prop(SliderProps.showValueIndicator)) {
      api.ShowValueIndicator.never => false,
      api.ShowValueIndicator.alwaysVisible => true,
      api.ShowValueIndicator.onDrag => _dragging,
      api.ShowValueIndicator.onlyForContinuous => _dragging && divisions == null,
      null || api.ShowValueIndicator.onlyForDiscrete => _dragging && divisions != null,
    };
  }

  /// Shows, moves or hides the bubble after this frame (never while laying
  /// out or painting).
  void _syncIndicator() {
    if (_bubbleScheduled || (_bubble == null && !indicatorShown)) return;
    _bubbleScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _bubbleScheduled = false;
      _updateIndicator();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _updateIndicator() {
    if (!indicatorShown) return _hideIndicator();
    final root = RenderControlRoot.of(this);
    if (root == null || !hasSize) return;
    final b = _bubble ??= RenderSliderValueIndicator();
    b
      ..text = sliderLabel(node, value)!
      ..tokens = _tokens
      ..fill = _c(node.prop(SliderProps.valueIndicatorColor))
      ..textStyle = node.prop(SliderProps.valueIndicatorTextStyle)
      ..shape = node.prop(SliderProps.valueIndicatorShape);
    // The thumb, in the root.
    final c = thumbCentre;
    final local = _vertical ? Offset(c.dy, size.height - c.dx) : c;
    final half = math.max(thumbSize.height, thumbSize.width) / 2;
    b.anchorRect = MatrixUtils.transformRect(getTransformTo(root), Rect.fromCenter(center: local, width: 2 * half, height: 2 * half));
    if (!identical(_bubbleRoot, root)) {
      _bubbleRoot?.hideOverlay(b);
      _bubbleRoot = root..showOverlay(b);
    }
    b.markNeedsLayout();
  }

  void _hideIndicator() {
    final b = _bubble;
    if (b == null) return;
    _bubbleRoot?.hideOverlay(b);
    _bubbleRoot = null;
    _bubble = null;
    b.dispose();
  }

  /// The value indicator showing now (null: none).
  RenderSliderValueIndicator? get indicator => _bubble;

  // --- lifecycle ---------------------------------------------------------------------------

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (!_interactive) focusNode.leave();
    _syncIndicator();
  }

  @override
  void detach() {
    _dragging = false;
    final b = _bubble;
    if (b != null) {
      _bubbleRoot?.hideOverlay(b);
      _bubbleRoot = null;
      _bubble = null;
      b.dispose();
    }
    super.detach();
  }

  // --- semantics ---------------------------------------------------------------------------

  @override
  String get semanticsName => '';

  String _percent(double v) => max <= min ? '0%' : '${(((v - min) / (max - min)).clamp(0.0, 1.0) * 100).round()}%';

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSlider = true
      ..value = _percent(value)
      ..increasedValue = _percent(_selectable(_snap(value + step)))
      ..decreasedValue = _percent(_selectable(_snap(value - step)));
    if (_interactive && enabled) {
      config
        ..onIncrease = increase
        ..onDecrease = decrease;
    }
  }

  @override
  void dispose() {
    _tapper.dispose();
    _drag?.dispose();
    _opacity.layer = null;
    super.dispose();
  }
}

/// A slider's value indicator: its label in SSUI's tooltip pill above the
/// thumb, in the root's overlay layer.
class RenderSliderValueIndicator extends RenderOverlayEntry {
  String _text = '';
  String get text => _text;
  set text(String v) {
    if (v == _text) return;
    _text = v;
    markNeedsLayout();
  }

  ControlTokens? tokens;

  /// The node's colour (else SSUI's tooltip background).
  Color? fill;

  /// The node's `valueIndicatorTextStyle` (its colour and size).
  api.TextStyle textStyle = api.TextStyle.empty;

  /// Flutter's shape name: a rectangle has square corners, the others SSUI's
  /// pill.
  api.SliderValueIndicatorShape? shape;

  /// The thumb, in the root.
  Rect anchorRect = Rect.zero;

  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const _gap = 6.0;

  final TextPainter _painter = TextPainter(textDirection: TextDirection.ltr);

  @override
  void performLayout() {
    final t = tokens;
    _painter.text = TextSpan(
      text: _text,
      style: TextStyle(
        fontFamily: t?.fontFamily,
        fontSize: textStyle.fontSize ?? 11.5,
        fontWeight: FontWeight.w500,
        height: 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        color: textStyle.color?.flutter ?? t?.tooltipText ?? const Color(0xFFFFFFFF),
      ),
    );
    _painter.layout();
    size = constraints.constrain(Size(_painter.width + _padding.horizontal, _painter.height + _padding.vertical));
  }

  @override
  Offset placeIn(RenderControlRoot root, Size rootSize) {
    final a = anchorRect;
    var top = a.top - _gap - size.height;
    if (top < 0) top = a.bottom + _gap;
    final left = (a.center.dx - size.width / 2).clamp(0.0, math.max(0.0, rootSize.width - size.width)).toDouble();
    return Offset(left, top);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final t = tokens;
    final radius = shape == api.SliderValueIndicatorShape.rectangle ? 2.0 : t?.radius('inner', 5) ?? 5;
    context.canvas.drawRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(radius)),
        Paint()..color = fill ?? t?.tooltipBackground ?? const Color(0xFF111827));
    _painter.paint(context.canvas, offset + _padding.topLeft);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..liveRegion = true
      ..label = _text
      ..textDirection = TextDirection.ltr;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}
