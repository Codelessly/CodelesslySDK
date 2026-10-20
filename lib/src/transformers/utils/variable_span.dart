import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// Resolves the values a design canvas shows for variables in place of their
/// live runtime values.
///
/// An editor sets [scopeResolver] so a node's `${...}` text shows the default
/// values of the variables it can see. Without a resolver, or when a path has
/// no value, the canvas shows a readable placeholder named after the path
/// (`${auth.displayName}` shows "Display name").
abstract final class VariablePreview {
  /// Returns the values that [node] can see on the design canvas, or null to
  /// fall back to placeholders.
  static ScopedValues? Function(BaseNode? node)? scopeResolver;

  /// Accessors that read a property of a value rather than name it, so the
  /// placeholder for `${item.title.initial}` is named after `title`.
  static const Set<String> _accessorNames = {
    'length',
    'initial',
    'upcase',
    'downcase',
    'capitalize',
    'timeAgo',
    'date',
    'first',
    'last',
    'isEmpty',
    'isNotEmpty',
    'count',
    'value',
    'data',
  };

  static const Set<String> _literals = {'true', 'false', 'null'};

  /// The text the design canvas shows for [expression], one `${...}` match.
  static String textFor(String expression, {BaseNode? node}) {
    final ScopedValues? scopedValues = scopeResolver?.call(node);
    if (scopedValues != null) {
      final String value = PropertyValueDelegate.substituteVariables(
        expression,
        scopedValues: scopedValues,
        nullSubstitutionMode: NullSubstitutionMode.noChange,
      );
      if (value.isNotEmpty && !variableSyntaxIdentifierRegex.hasMatch(value)) {
        return value;
      }
    }
    // A name can be wider than a fixed-width slot, so only nodes that grow
    // to fit their text show one; the rest show a compact marker.
    if (node != null && node.horizontalFit != SizeFit.shrinkWrap) return '…';
    return placeholderFor(expression);
  }

  /// A readable name for [expression]: its last meaningful path segment,
  /// split into words and capitalized.
  static String placeholderFor(String expression) {
    final String? formula = FormulaEvaluator.exactExpression(expression);
    if (formula != null) {
      // Name a formula after the first variable it reads.
      final String code = formula.replaceAll(
        RegExp(
          r'"[^"]*"'
          '|'
          r"'[^']*'",
        ),
        '',
      );
      final RegExpMatch? path = RegExp(
        r'(?<![\w.])([a-zA-Z]\w*(?:\.[a-zA-Z]\w*)*)(?![\w.]|\s*\()',
      ).allMatches(code).where((m) => !_literals.contains(m[1])).firstOrNull;
      if (path == null) return '…';
      expression = '\${${path[1]}}';
    }
    final RegExpMatch? match = variablePathRegex.firstMatch(expression);
    if (match == null) return '…';
    final List<String> segments = match
        .namedGroup('value')!
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .split('.');
    String name = segments.last;
    while (segments.length > 1 && _accessorNames.contains(name)) {
      segments.removeLast();
      name = segments.last;
    }
    return humanize(name);
  }

  /// `displayName` and `display_name` both become "Display name".
  static String humanize(String name) {
    final String words = name
        .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])([A-Z])'),
          (m) => ' ${m[1]!.toLowerCase()}',
        )
        .replaceAll('_', ' ')
        .trim();
    if (words.isEmpty) return '…';
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// A [TextSpan] that stands in for a variable on a design canvas, showing the
/// variable's default value or a readable placeholder (see [VariablePreview]).
class VariableSpan extends TextSpan {
  /// The variable expression, such as `${user.name}`.
  final String variable;

  /// Creates a [VariableSpan] for the [variable] expression of [node].
  VariableSpan({
    required this.variable,
    BaseNode? node,
    super.style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
  }) : super(text: VariablePreview.textFor(variable, node: node));
}
