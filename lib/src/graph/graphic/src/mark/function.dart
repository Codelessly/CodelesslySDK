import 'dart:async';

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
import 'package:codelessly_sdk/src/graph/graphic/src/shape/function.dart';

import 'mark.dart';
import 'modifier/modifier.dart';

/// The specification of a function mark.
///
/// Functions map values in a domain to values in the range for any selected value
/// in the domain.
abstract class FunctionMark<S extends FunctionShape> extends Mark<S> {
  /// Creates a funcion mark.
  FunctionMark({
    ColorEncode? color,
    ElevationEncode? elevation,
    GradientEncode? gradient,
    LabelEncode? label,
    Varset? position,
    ShapeEncode<S>? shape,
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
