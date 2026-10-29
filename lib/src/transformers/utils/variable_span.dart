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
  /// fall back to placeholders. Row-specific values are overlaid by [scopeOf].
  static ScopedValues? Function(BaseNode? node)? scopeResolver;

  /// The values [node] can see on the design canvas when built in [context].
  static ScopedValues? resolve(BaseNode? node, [BuildContext? context]) =>
      scopeOf(node, context: context);

  /// The values that [node] sees on the design canvas where it is built in
  /// [context], or null to fall back to placeholders.
  ///
  /// [scopeResolver] only knows the node, and a list's item template is one
  /// node that every row of the list builds: it can only give the sample
  /// item of the nearest data-bound list (its first). The row being built
  /// is known from [context]: its [IndexedItemProvider] gives that row's
  /// own item, as at runtime, so each row previews its own data.
  ///
  /// A row without an item of its own (a list that only sets an item count,
  /// or a row past the end of the data) keeps the sample item but reads
  /// its own `index`.
  static ScopedValues? scopeOf(
    BaseNode? node, {
    BuildContext? context,
    IndexedItem? item,
  }) {
    final ScopedValues? values = scopeResolver?.call(node);
    if (values == null) return values;
    final IndexedItem? row =
        item ?? (context == null ? null : IndexedItemProvider.maybeOf(context));
    if (row == null || row == values.indexedItem) return values;
    return ScopedValues.preview(
      variables: values.variables,
      codelesslyContext: values.codelesslyContext,
      screenSize: values.screenSize,
      parentSize: values.parentSize,
      data: values.data,
      indexedItem: row.item != null || values.indexedItem == null
          ? row
          : IndexedItem(row.index, values.indexedItem!.item),
    );
  }

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
  /// The row's [item] overrides the resolver's sample item when present.
  static String textFor(
    String expression, {
    BaseNode? node,
    TextStyle? style,
    IndexedItem? item,
    BuildContext? context,
  }) {
    final ScopedValues? scopedValues = scopeOf(
      node,
      item: item,
      context: context,
    );
    if (scopedValues != null) {
      // A formula that yields empty text means "show nothing", unlike one
      // that can't be evaluated (null), which gets a placeholder.
      final String? formula = FormulaEvaluator.exactExpression(expression);
      if (formula != null &&
          PropertyValueDelegate.evaluateFormula(
                formula,
                scopedValues: scopedValues,
              ) ==
              '') {
        return '';
      }
      final String value = PropertyValueDelegate.substituteVariables(
        expression,
        scopedValues: scopedValues,
        nullSubstitutionMode: NullSubstitutionMode.noChange,
      );
      if (value.isNotEmpty && !variableSyntaxIdentifierRegex.hasMatch(value)) {
        return value;
      }
    }
    final String placeholder = placeholderFor(expression);
    // A name can be wider than a fixed-width slot; show a compact marker
    // only when it would not fit.
    if (node != null &&
        node.horizontalFit != SizeFit.shrinkWrap &&
        !fitsWidth(placeholder, node.innerBoxLocal.width, style)) {
      return '…';
    }
    return placeholder;
  }

  /// Whether [text] fits on one line within [width] in [style], leaving
  /// room for glyphs such as serifs and italics that overhang their advance
  /// width, and for a font that isn't loaded yet measuring narrower.
  static bool fitsWidth(String text, double width, TextStyle? style) {
    final TextStyle effective = style ?? const TextStyle(fontSize: 14);
    final double margin = (effective.fontSize ?? 14) * 0.25;
    if (width - margin <= 0) return false;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: effective),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final bool fits = painter.width <= width - margin;
    painter.dispose();
    return fits;
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

  /// Creates a [VariableSpan] for the [variable] expression of [node], in
  /// list row [item] when it is built for one.
  VariableSpan({
    required this.variable,
    BaseNode? node,
    IndexedItem? item,
    BuildContext? context,
    super.style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
  }) : super(
         text: VariablePreview.textFor(
           variable,
           node: node,
           style: style,
           item: item,
           context: context,
         ),
       );
}
