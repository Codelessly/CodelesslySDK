import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/painting.dart';

import '../transformers/utils/property_value_delegate.dart';
import '../transformers/utils/scoped_values.dart';
import '../utils/formula.dart';

/// Reads the color bindings of an action (its `variables`, e.g.
/// [ShowToastAction.variables] and [ConfirmAction.variables]): a color
/// field's name mapped to a variable path or formula that gives a color,
/// such as `${pal.surface}` or `${= alpha(pal.gold, 0.5)}`.
abstract final class ActionColorBindings {
  /// The colors [variables] give, by field name, read with [scopedValues].
  /// Only the [keys] are read when given. A binding that gives no color
  /// (empty, unknown path, not a color) is left out, so the field it binds
  /// keeps its own value.
  static Map<String, Color> resolve(
    Map<String, String> variables,
    ScopedValues scopedValues, {
    Iterable<String>? keys,
  }) {
    final Map<String, Color> colors = <String, Color>{};
    for (final MapEntry<String, String> entry in variables.entries) {
      if (keys != null && !keys.contains(entry.key)) continue;
      final Color? color = colorOf(entry.value, scopedValues);
      if (color != null) colors[entry.key] = color;
    }
    return colors;
  }

  /// The color [template] gives with [scopedValues]: a single `${path}` or
  /// `${= formula}` read as a value, or text with paths in it (e.g.
  /// `#${theme.hex}`) filled in and read as a hex color. Null when it gives
  /// no color.
  static Color? colorOf(String template, ScopedValues scopedValues) {
    final String text = template.trim();
    if (text.isEmpty) return null;
    ColorRGBA? color;
    if (FormulaEvaluator.exactExpression(text) != null ||
        RegExp(r'^\$\{[^{}]+\}$').hasMatch(text)) {
      color = PropertyValueDelegate.getVariableValueFromPath<ColorRGBA>(
        text,
        scopedValues: scopedValues,
      );
    } else {
      final String filled = PropertyValueDelegate.substituteVariables(
        text,
        scopedValues: scopedValues,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ).trim();
      color = ColorRGBA.fromHex(filled);
    }
    if (color == null) return null;
    return Color.from(
      alpha: color.a,
      red: color.r,
      green: color.g,
      blue: color.b,
    );
  }
}
