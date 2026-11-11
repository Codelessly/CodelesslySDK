// What a design canvas shows for `${...}` in a text: the value the
// variables' defaults give (when the editor provides them as a scope), else
// a readable placeholder named after the path (`${auth.displayName}` shows
// "Display name").
import 'package:flutter/painting.dart';

import '../contracts.dart';
import 'engine.dart';
import 'formula.dart';
import 'paths.dart';

abstract final class VariablePreview {
  /// Accessors that read a property of a value rather than name it, so the
  /// placeholder for `${item.title.initial}` is named after `title`.
  static const Set<String> _accessorNames = {
    'length', 'initial', 'upcase', 'downcase', 'capitalize', 'timeAgo', 'date', 'first', 'last', 'isEmpty', //
    'isNotEmpty', 'count', 'value', 'data',
  };

  static const Set<String> _literals = {'true', 'false', 'null'};

  /// The text a design canvas shows for [expression] (one `${...}`): its
  /// value in [scope] (the variables' defaults) when it has one, else a
  /// placeholder. A placeholder wider than [width] (a fixed-width text, in
  /// [style]) is `…`.
  static String textFor(
    String expression, {
    ValueScope? scope,
    double? width,
    TextStyle? style,
    Expressions engine = const Expressions(),
  }) {
    if (scope != null) {
      // A formula that yields empty text means "show nothing", unlike one
      // that can't be evaluated (null), which gets a placeholder.
      final formula = FormulaEvaluator.exactExpression(expression);
      if (formula != null && engine.formula(formula, scope) == '') return '';
      // So does a path whose value is empty text (`${item.before}` of a
      // match at the start); only a missing value (null) gets a placeholder.
      if (formula == null && engine.evaluate(expression, scope) == '') return '';
      final value = engine.interpolate(expression, scope, mode: NullSubstitution.noChange);
      // A path that resolves to empty text (`''`) shows nothing too; one that
      // doesn't resolve stays `${...}` (noChange) and gets a placeholder.
      if (formula == null && value.isEmpty) return '';
      if (value.isNotEmpty && !expressionSyntax.hasMatch(value)) return value;
    }
    final placeholder = placeholderFor(expression);
    if (width != null && !fitsWidth(placeholder, width, style)) return '…';
    return placeholder;
  }

  /// Whether [text] fits on one line within [width] in [style], leaving
  /// room for glyphs that overhang their advance and for a font that isn't
  /// loaded yet measuring narrower.
  static bool fitsWidth(String text, double width, TextStyle? style) {
    final effective = style ?? const TextStyle(fontSize: 14);
    final margin = (effective.fontSize ?? 14) * 0.25;
    if (width - margin <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: effective),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= width - margin;
    painter.dispose();
    return fits;
  }

  /// A readable name for [expression]: its last meaningful path segment,
  /// split into words and capitalized; a formula is named after the first
  /// variable it reads.
  static String placeholderFor(String expression) {
    final formula = FormulaEvaluator.exactExpression(expression);
    if (formula != null) {
      final code = formula.replaceAll(RegExp(r'"[^"]*"' '|' r"'[^']*'"), '');
      final path = RegExp(r'(?<![\w.])([a-zA-Z]\w*(?:\.[a-zA-Z]\w*)*)(?![\w.]|\s*\()')
          .allMatches(code)
          .where((m) => !_literals.contains(m[1]))
          .firstOrNull;
      if (path == null) return '…';
      expression = '\${${path[1]}}';
    }
    final match = pathSyntax.firstMatch(expression);
    if (match == null) return '…';
    final segments = match.namedGroup('value')!.replaceAll(RegExp(r'\[\d+\]'), '').split('.');
    var name = segments.last;
    while (segments.length > 1 && _accessorNames.contains(name)) {
      segments.removeLast();
      name = segments.last;
    }
    return humanize(name);
  }

  /// `displayName` and `display_name` both become "Display name".
  static String humanize(String name) {
    final words = name
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}')
        .replaceAll('_', ' ')
        .trim();
    if (words.isEmpty) return '…';
    return words[0].toUpperCase() + words.substring(1);
  }
}
