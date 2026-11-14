// A slider's own `customPaint`, drawn between the slider's parts: the
// `painter` list over the track and under the thumb (as a custom
// `SliderTrackShape` paints after the track it extends), the
// `foregroundPainter` list over the thumb. Both read `size` (the slider's
// box) and `slider`: its `value`, `min`, `max`, `trackRect` (`left`, `top`,
// `width`, `height`: SliderTrackShape.getPreferredRect) and `thumbCenter`
// (`x`, `y`), in the slider's own frame (a vertical slider's is turned).
// The slider's shapes are Material's (the island is a Material Slider).
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../render/custom_paint.dart' show RenderCustomPaintLayer;

/// [data] with its track and thumb shapes drawing [layer]'s lists; the
/// slider shows [value] between [min] and [max].
SliderThemeData paintedSliderTheme(SliderThemeData data, RenderCustomPaintLayer layer,
    {required double value, required double min, required double max}) {
  // The track the Slider would take: Flutter's default for the theme's year.
  final SliderTrackShape track = data.trackShape ??
      // ignore: deprecated_member_use
      (data.year2023 == false ? const GappedSliderTrackShape() : const RoundedRectSliderTrackShape());
  final state = _Drawn(layer, value, min, max);
  return data.copyWith(
    trackShape: _PaintedTrack(track, state),
    thumbShape: data.thumbShape == null ? null : _PaintedThumb(data.thumbShape!, state),
  );
}

/// What the track drew at, for the thumb drawn after it.
class _Drawn {
  _Drawn(this.layer, this.value, this.min, this.max);
  final RenderCustomPaintLayer layer;
  final double value, min, max;
  Offset offset = Offset.zero;
  Map<String, Object?> locals = const {};

  void record(RenderBox box, Offset offset, Rect track, Offset thumb) {
    this.offset = offset;
    final t = track.shift(-offset), c = thumb - offset;
    locals = {
      'slider': {
        'value': value,
        'min': min,
        'max': max,
        'trackRect': {'left': t.left, 'top': t.top, 'width': t.width, 'height': t.height},
        'thumbCenter': {'x': c.dx, 'y': c.dy},
      },
    };
  }
}

class _PaintedTrack extends SliderTrackShape {
  const _PaintedTrack(this.track, this.drawn);
  final SliderTrackShape track;
  final _Drawn drawn;

  @override
  bool get isRounded => track.isRounded;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) =>
      track.getPreferredRect(
          parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    track.paint(context, offset,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        enableAnimation: enableAnimation,
        thumbCenter: thumbCenter,
        secondaryOffset: secondaryOffset,
        isEnabled: isEnabled,
        isDiscrete: isDiscrete,
        textDirection: textDirection);
    final rect = track.getPreferredRect(
        parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);
    drawn.record(parentBox, offset, rect, thumbCenter);
    drawn.layer.drawFor(parentBox, context.canvas, offset, parentBox.size, drawn.locals, foreground: false);
  }
}

class _PaintedThumb extends SliderComponentShape {
  const _PaintedThumb(this.thumb, this.drawn);
  final SliderComponentShape thumb;
  final _Drawn drawn;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => thumb.getPreferredSize(isEnabled, isDiscrete);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    thumb.paint(context, center,
        activationAnimation: activationAnimation,
        enableAnimation: enableAnimation,
        isDiscrete: isDiscrete,
        labelPainter: labelPainter,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        textDirection: textDirection,
        value: value,
        textScaleFactor: textScaleFactor,
        sizeWithOverflow: sizeWithOverflow);
    drawn.layer.drawFor(parentBox, context.canvas, drawn.offset, parentBox.size, drawn.locals, foreground: true);
  }
}
