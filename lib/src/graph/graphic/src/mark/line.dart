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
import 'package:codelessly_sdk/src/graph/graphic/src/shape/line.dart';

import 'function.dart';
import 'modifier/modifier.dart';
import 'mark.dart';

/// The specification of a line mark.
///
/// A line graphing visits all points and connets all points with a line. Note this
/// definition is more like the *path* in the Grammer of Graphics.
///
/// It will check and complete position points by the rule of:
///
/// ```
/// [point] => [point]
/// ```
class LineMark extends FunctionMark<LineShape> {
  /// Creates a line mark.
  LineMark({
    ColorEncode? color,
    ElevationEncode? elevation,
    GradientEncode? gradient,
    LabelEncode? label,
    Varset? position,
    ShapeEncode<LineShape>? shape,
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

/// The position completer of the line mark.
///
/// It will check and complete position points by the rule of:
///
/// ```
/// [point] => [point]
/// ```
List<Offset> lineCompleter(List<Offset> position, Offset origin) {
  assert(position.length == 1);
  return position;
}
