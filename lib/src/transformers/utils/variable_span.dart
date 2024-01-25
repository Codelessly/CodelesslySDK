import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A [TextSpan] that represents a variable by rendering an "FX" symbol instead
/// of the variable name.
class VariableSpan extends TextSpan {
  /// The name of the variable.
  final String variable;

  /// Creates a [VariableSpan] with the given [variable] name and [style].
  VariableSpan({
    required this.variable,
    TextStyle? style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
  }) : super(
          text: 'fx',
          style: style?.merge(GoogleFonts.unna(fontStyle: FontStyle.italic)),
        );
}
