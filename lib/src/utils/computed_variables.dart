import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';

import '../../codelessly_sdk.dart';

/// Evaluates computed (derived) variables: variables whose
/// [VariableData.formula] gives their value from other variables, e.g.
/// `visible = ${= sortBy(filter(records, r => r.crate == crateId), sortBy)}`.
///
/// A computed variable is read like any other one, by name, in bindings and
/// formulas (`${= length(visible)}`, `${visible[0].title}`): its value is
/// materialized into the variable, so everything that reads variables reads
/// the formula's result.
///
/// Semantics:
///  - The formula is written like a binding: `${= expression}`, a single
///    path such as `${records}`, or a bare expression (`length(records)`).
///  - It reads other variables, including other computed ones, and the
///    `data` passed to the layout. Item scoped values (`item`, `index`,
///    `value`) don't exist where a computed variable lives and read as null.
///  - Its value is cached in the variable and computed again only when a
///    variable it reads changes (see [CodelesslyContext]).
///  - Computed variables that read themselves, directly or through others,
///    form a cycle: they evaluate to null (an empty value) and don't update.
///  - The result keeps the variable's declared type when it fits it (a
///    whole number for an integer, a list for a list, ...), and otherwise
///    takes the type of the result, so a formula producing a list reads as a
///    list even if the variable was declared as text.
///  - They are read-only: Set variable actions, two-way bindings and
///    [CodelesslyContext.updateVariable] leave them unchanged and report
///    that nothing was set.
abstract final class ComputedVariables {
  static final RegExp _exactPath = RegExp(r'^\$\{([^{}]+)\}$');

  /// The single variable path of [formula] when it is exactly one `${path}`.
  static String? _exactPathOf(String formula) {
    final RegExpMatch? match = _exactPath.firstMatch(formula.trim());
    if (match == null) return null;
    final String path = match.group(1)!.trim();
    if (path.startsWith('=')) return null;
    return path;
  }

  /// The formula expression of [formula]: the inside of `${= ...}`, or the
  /// whole text for a bare expression. Null when [formula] is one variable
  /// path, `${path}`.
  static String? expressionOf(String formula) {
    final String? exact = FormulaEvaluator.exactExpression(formula);
    if (exact != null) return exact;
    if (_exactPathOf(formula) != null) return null;
    return formula.trim();
  }

  /// Why [formula] can't be evaluated, or null when it parses.
  static String? errorOf(String formula) {
    final String? expression = expressionOf(formula);
    if (expression == null) return null;
    return FormulaEvaluator.errorOf(expression);
  }

  /// The names of the variables [variable]'s formula reads, e.g. `records`
  /// and `crateId`. Empty for a normal variable.
  static Set<String> inputsOf(VariableData variable) {
    final String? formula = variable.formula;
    if (formula == null) return const {};
    final String? path = _exactPathOf(formula);
    final Set<String> paths = path != null
        ? {path}
        : FormulaEvaluator.referencedPaths(expressionOf(formula)!);
    return {
      for (final String path in paths)
        if (VariableMatch.parse(path.wrapWithVariableSyntax())
            case final VariableMatch match)
          match.name,
    };
  }

  /// Evaluates [variable]'s formula, reading variables from [scopedValues].
  static Object? evaluate(
    VariableData variable, {
    required ScopedValues scopedValues,
  }) {
    final String? formula = variable.formula;
    if (formula == null) return null;
    final String? path = _exactPathOf(formula);
    if (path != null) {
      return PropertyValueDelegate.getVariableValueFromPath<Object>(
        path,
        scopedValues: scopedValues,
      );
    }
    return PropertyValueDelegate.evaluateFormula(
      expressionOf(formula)!,
      scopedValues: scopedValues,
    );
  }

  /// [variable] holding [result] as its value. See [ComputedVariables] for
  /// how the type is chosen.
  static VariableData withResult(VariableData variable, Object? result) {
    final VariableType type = result == null || _fits(result, variable.type)
        ? variable.type
        : _typeOf(result) ?? VariableType.text;
    return _rebuild(variable, type: type, value: _encode(result));
  }

  /// The names of the computed variables in [variables] (by name) that read
  /// themselves, directly or through other computed variables.
  static Set<String> cyclicNames(Map<String, VariableData> variables) {
    final Set<String> cyclic = {};
    final Map<String, Set<String>> edges = {
      for (final VariableData variable in variables.values)
        if (variable.isComputed)
          variable.name: {
            for (final String input in inputsOf(variable))
              if (variables[input]?.isComputed ?? false) input,
          },
    };
    // A computed variable is cyclic when it can reach itself.
    for (final String start in edges.keys) {
      final Set<String> seen = {};
      final List<String> stack = [...edges[start]!];
      while (stack.isNotEmpty) {
        final String name = stack.removeLast();
        if (name == start) {
          cyclic.add(start);
          break;
        }
        if (!seen.add(name)) continue;
        stack.addAll(edges[name] ?? const {});
      }
    }
    return cyclic;
  }

  /// The computed variables of [variables] (by name) ordered so that each
  /// comes after the computed variables it reads. Cyclic ones come last.
  static List<String> evaluationOrder(Map<String, VariableData> variables) {
    final Set<String> cyclic = cyclicNames(variables);
    final List<String> order = [];
    final Set<String> visited = {};
    void visit(String name) {
      if (!visited.add(name)) return;
      final VariableData? variable = variables[name];
      if (variable == null || !variable.isComputed) return;
      for (final String input in inputsOf(variable)) {
        if (!cyclic.contains(input)) visit(input);
      }
      order.add(name);
    }

    for (final VariableData variable in variables.values) {
      if (variable.isComputed && !cyclic.contains(variable.name)) {
        visit(variable.name);
      }
    }
    return [...order, ...cyclic];
  }

  /// [variables] (by name) with every computed variable holding its
  /// formula's result over the others, as a design canvas previews them with
  /// default values. [data] is what the formulas read as `data`.
  static Map<String, VariableData> resolveAll(
    Map<String, VariableData> variables, {
    Map<String, dynamic>? data,
  }) {
    if (!variables.values.any((variable) => variable.isComputed)) {
      return variables;
    }
    final Set<String> cyclic = cyclicNames(variables);
    final Map<String, VariableData> resolved = {...variables};
    final ScopedValues scope = ScopedValues.preview(
      variables: resolved,
      data: data,
    );
    for (final String name in evaluationOrder(variables)) {
      final VariableData variable = resolved[name]!;
      resolved[name] = withResult(
        variable,
        cyclic.contains(name) ? null : evaluate(variable, scopedValues: scope),
      );
    }
    return resolved;
  }

  static bool _fits(Object result, VariableType type) => switch (type) {
    VariableType.text => result is String || result is num || result is bool,
    VariableType.image => result is String,
    VariableType.integer =>
      result is num && result.isFinite && result == result.roundToDouble(),
    VariableType.decimal => result is num,
    VariableType.boolean => result is bool,
    VariableType.color => result is String || result is ColorRGBA,
    VariableType.list => result is List,
    VariableType.map => result is Map,
  };

  static VariableType? _typeOf(Object result) {
    try {
      return VariableType.fromObjectType(result);
    } catch (_) {
      return null;
    }
  }

  static String _encode(Object? result) => switch (result) {
    null => '',
    String() => result,
    num() || bool() => FormulaEvaluator.stringify(result),
    DateTime() => result.toIso8601String(),
    ColorRGBA() => result.toHex(),
    List() || Map() => jsonEncode(
      result,
      toEncodable: (value) =>
          value is DateTime ? value.toIso8601String() : value.toString(),
    ),
    _ => result.toString(),
  };

  /// A copy of [variable] of the same class with [type] and [value].
  /// [VariableData.copyWith] keeps the old value when the new one doesn't
  /// sanitize, so an empty result would not clear it.
  static VariableData _rebuild(
    VariableData variable, {
    required VariableType type,
    required String value,
  }) => switch (variable) {
    CanvasVariableData() => CanvasVariableData(
      id: variable.id,
      canvasId: variable.canvasId,
      name: variable.name,
      value: value,
      type: type,
      extra: variable.extra,
      formula: variable.formula,
    ),
    RuntimeVariableData() => RuntimeVariableData(
      id: variable.id,
      name: variable.name,
      value: value,
      type: type,
      extra: variable.extra,
      formula: variable.formula,
    ),
    _ => VariableData(
      id: variable.id,
      name: variable.name,
      value: value,
      type: type,
      extra: variable.extra,
      formula: variable.formula,
    ),
  };
}
