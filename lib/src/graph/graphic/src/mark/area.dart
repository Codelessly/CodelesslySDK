import 'dart:async';
import 'dart:ui';

import 'package:codelessly_sdk/src/graph/graphic/src/dataflow/tuple.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/encode/color.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/encode/elevation.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/encode/gradient.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/encode/label.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/algebra/varset.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/encode/shape.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/encode/size.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/graffiti/transition.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/interaction/selection/selection.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/shape/area.dart';

import 'function.dart';
import 'modifier/modifier.dart';
import 'mark.dart';

/// The specification of an area mark.
///
/// An area graphing produces a graph containing all points within the region between
/// two lines.
///
/// It will check and complete position points by the rule of:
///
/// ```
/// [start, end] | [end] => [start, end]
/// ```
class AreaMark extends FunctionMark<AreaShape> {
  /// Creates an area mark.
  AreaMark({
    ColorEncode? color,
    ElevationEncode? elevation,
    GradientEncode? gradient,
    LabelEncode? label,
    Varset? position,
    ShapeEncode<AreaShape>? shape,
    SizeEncode? size,
    List<Modifier>? modifiers,
    int? layer,
    Selected? selected,
    StreamController<Selected?>? selectionStream,
    Transition? transition,
    Set<MarkEntrance>? entrance,
    String? Function(Tuple)? tag,
  }) : super(
          color: color,
          elevation: elevation,
          gradient: gradient,
          label: label,
          position: position,
          shape: shape,
          size: size,
          modifiers: modifiers,
          layer: layer,
          selected: selected,
          selectionStream: selectionStream,
          transition: transition,
          entrance: entrance,
          tag: tag,
        );
}

/// The position completer of the area mark.
///
/// It will check and complete position points by the rule of:
///
/// ```
/// [start, end] | [end] => [start, end]
/// ```
List<Offset> areaCompleter(List<Offset> position, Offset origin) {
  assert(position.length == 1 || position.length == 2);
  if (position.length == 1) {
    final normalZero = origin.dy;
    final end = position.first;
    return [
      Offset(end.dx, normalZero),
      end,
    ];
  }
  return position;
}
