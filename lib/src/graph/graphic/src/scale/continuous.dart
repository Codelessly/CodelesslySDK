import 'package:codelessly_sdk/src/graph/graphic/src/util/assert.dart';

import 'package:codelessly_sdk/src/graph/graphic/src/util/collection.dart';

import 'scale.dart';

/// The specification of a continuous scale.
///
/// A continuous scale converts original tuple values to [double]s normalized to `[0, 1]`.
abstract class ContinuousScale<V> extends Scale<V, double> {
  /// Creates a continuous scale.
  ContinuousScale({
    this.min,
    this.max,
    this.marginMin,
    this.marginMax,
    this.niceRange,
    String? title,
    String? Function(V)? formatter,
    List<V>? ticks,
    int? tickCount,
  })  : assert(isSingle([min, marginMin], allowNone: true)),
        assert(isSingle([max, marginMax], allowNone: true)),
        super(
          title: title,
          formatter: formatter,
          ticks: ticks,
          tickCount: tickCount,
        );

  /// Indicates the minimum input boundary directly.
  ///
  /// If null, it will be calculated by minimum input value and [marginMin].
  V? min;

  /// Indecates the maximum input boundary directly.
  ///
  /// If null, it will be calculated by maximum input value and [marginMax].
  V? max;

  /// The margin ratio from minimum input value to calculated [min].
  double? marginMin;

  /// The margin ratio from maxinum input value to calculated [max].
  double? marginMax;

  /// Whether to extend the [min] and [max] to get nice round values.
  bool? niceRange;

  @override
  bool operator ==(Object other) =>
      other is ContinuousScale<V> &&
      super == other &&
      min == other.min &&
      max == other.max &&
      marginMin == other.marginMin &&
      marginMax == other.marginMax;
}

/// The continuous scale converter.
abstract class ContinuousScaleConv<V> extends ScaleConv<V, double> {
  /// The minimum input boundary.
  V? min;

  /// The maximum input boundary
  V? max;

  @override
  double normalize(double scaledValue) => scaledValue;

  @override
  double denormalize(double normalValue) => normalValue;

  @override
  bool operator ==(Object other) =>
      other is ContinuousScaleConv<V> &&
      super == other &&
      min == other.min &&
      max == other.max;
}

/// A continuous scale's domain and ticks given from outside the data: the
/// part of it a viewport shows.
///
/// Codelessly fork: upstream fits a scale to all of its data once, and pans
/// and zooms by stretching the coordinate's range, so ticks and the other
/// axis never follow the visible part. A window makes the domain an input of
/// the dataflow ([ChartView.window]).
class ScaleWindow {
  const ScaleWindow(this.min, this.max, [this.ticks]);

  final num min;
  final num max;

  /// The ticks to draw; null for nice numbers of the domain.
  final List<num>? ticks;

  @override
  bool operator ==(Object other) =>
      other is ScaleWindow &&
      min == other.min &&
      max == other.max &&
      deepCollectionEquals(ticks, other.ticks);

  @override
  int get hashCode => Object.hash(min, max);
}
