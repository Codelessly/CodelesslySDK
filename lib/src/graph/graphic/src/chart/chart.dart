import 'dart:async';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/chart/size.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/coord/coord.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/coord/polar.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/coord/rect.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/data/data_set.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/mark/mark.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/guide/annotation/annotation.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/guide/axis/axis.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/guide/interaction/crosshair.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/guide/interaction/tooltip.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/interaction/gesture.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/interaction/selection/selection.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/util/collection.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/variable/transform/transform.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/variable/variable.dart';

import 'view.dart';

/// A widget to display the chart.
///
/// Specifications details of data visualization are seen in this class properties.
/// The are set in the constructor[new Chart].
///
/// Usually, if any specification or data is changed, the chart will rebuild or
/// reevaluate automatically. Some subtle setting is controlled by [rebuild] and
/// [changeData]. Note that function properties will always be regarded unchanged.
///
/// The generic [D] is the type of datum in [data] list.
///
/// The properties of this chart sepcification are final because it is also an immutable
/// [StatefulWidget], but other specifications can be modified.
// Codelessly fork: a chart is its specification only. Upstream's Chart is
// also the widget that hosts it (its state, gestures and painter); here a
// host owns a ChartView and paints its graffiti (lib/src/graph).
class Chart<D> {
  /// Creates a chart specification.
  const Chart({
    required this.data,
    this.changeData,
    required this.variables,
    this.transforms,
    required this.marks,
    this.coord,
    this.padding,
    this.axes,
    this.tooltip,
    this.crosshair,
    this.annotations,
    this.selections,
    this.rebuild,
    this.gestureStream,
    this.resizeStream,
    this.changeDataStream,
  });

  /// The data list to visualize.
  final List<D> data;

  /// Name identifiers and specifications of variables.
  ///
  /// The name identifier string will represent the variable in other specifications.
  final Map<String, Variable<D, dynamic>> variables;

  /// Specifications of transforms applied to variable data.
  final List<VariableTransform>? transforms;

  /// Specifications of geometry marks.
  final List<Mark> marks;

  /// Specification of the coordinate.
  ///
  /// If null, a default [RectCoord] is set.
  final Coord? coord;

  /// The padding from coordinate region to the widget border.
  ///
  /// This is a function with chart size as input that you may need to calculate
  /// the padding.
  ///
  /// Usually, the [axes] is attached to the border of coordinate region (See details
  /// in [Coord]), and in the [padding] space.
  ///
  /// If null, a default `EdgeInsets.fromLTRB(40, 5, 10, 20)` for [RectCoord] and
  /// `EdgeInsets.all(10)` for [PolarCoord] is set.
  final EdgeInsets Function(Size)? padding;

  /// Specifications of axes.
  final List<AxisGuide>? axes;

  /// Specification of tooltip on [selections].
  final TooltipGuide? tooltip;

  /// Specification of pointer crosshair on [selections].
  final CrosshairGuide? crosshair;

  /// Specifications of annotations.
  final List<Annotation>? annotations;

  /// Name identifiers and specifications of selection definitions.
  ///
  /// The name identifier string will represent the selection in other specifications.
  final Map<String, Selection>? selections;

  /// The behavior of chart rebuilding when widget is updated.
  ///
  /// If null, new [Chart] will be compared with the old one, and chart will rebuild
  /// only when specifications are changed.
  ///
  /// If true, chart will always rebuild. **So be cautious to set true**.
  ///
  /// If false, chart will never rebuild.
  final bool? rebuild;

  /// The behavior of data reevaluation when widget is updated.
  ///
  /// If null, new [data] will be compared with the old one, a [ChangeDataEvent]
  /// will be emitted and the chart will be reevaluated only when they are not the
  /// same instance.
  ///
  /// If true, a [ChangeDataEvent] will always be emitted and the chart will always
  /// be reevaluated. **So be cautious to set true**.
  ///
  /// If false, a [ChangeDataEvent] will never be emitted and the chart will never
  /// be reevaluated.
  final bool? changeData;

  /// The interaction stream of gesture events.
  ///
  /// You can either get gesture events by listening to it's stream, or mannually
  /// emit gesture events into this chart by adding to it's sink.
  ///
  /// You can also share it with other charts for sharing gesture events, in which
  /// case make sure it is broadcast.
  final StreamController<GestureEvent>? gestureStream;

  /// The interaction stream of resize events.
  ///
  /// You can either get resize events by listening to it's stream, or mannually
  /// emit resize events into this chart by adding to it's sink.
  ///
  /// You can also share it with other charts for sharing resize events, in which
  /// case make sure it is broadcast.
  final StreamController<ResizeEvent>? resizeStream;

  /// The interaction stream of change data events.
  ///
  /// You can either get change data events by listening to it's stream, or mannually
  /// emit change data events into this chart by adding to it's sink.
  ///
  /// You can also share it with other charts for sharing change data events, in which
  /// case make sure it is broadcast.
  final StreamController<ChangeDataEvent<D>>? changeDataStream;

  /// Checks the equlity of two chart specifications.
  bool equalSpecTo(Object other) =>
      other is Chart<D> &&
      // data are checked by changeData.
      deepCollectionEquals(variables, other.variables) &&
      deepCollectionEquals(transforms, other.transforms) &&
      deepCollectionEquals(marks, other.marks) &&
      coord == other.coord &&
      deepCollectionEquals(axes, other.axes) &&
      tooltip == other.tooltip &&
      crosshair == other.crosshair &&
      deepCollectionEquals(annotations, other.annotations) &&
      deepCollectionEquals(selections, other.selections) &&
      rebuild == other.rebuild &&
      changeData == other.changeData &&
      gestureStream == other.gestureStream &&
      resizeStream == other.resizeStream &&
      changeDataStream == other.changeDataStream;

}
