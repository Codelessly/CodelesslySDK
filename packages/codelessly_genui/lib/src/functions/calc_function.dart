import 'package:a2ui_core/a2ui_core.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart' show FormulaEvaluator;
import 'package:json_schema_builder/json_schema_builder.dart' show Schema;

/// Functions a GenUI formula may not call: they read the clock or make
/// random ids, so a formula calling them would not be a pure function of
/// the data model.
const Set<String> kImpureFormulaFunctions = {
  'now',
  'nowMs',
  'today',
  'wallTime',
  'newId',
};

/// Converts a Codelessly formula path (`items[0].qty`) to a JSON pointer
/// (`items/0/qty`, relative). Returns null for a path that is not data.
String? formulaPathToPointer(String path) {
  final buffer = StringBuffer();
  final RegExp part = RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)|\[(\d+)\]|\.');
  int index = 0;
  for (final Match m in part.allMatches(path)) {
    if (m.start != index) return null;
    index = m.end;
    final String? name = m.group(1);
    final String? item = m.group(2);
    if (name != null) {
      if (buffer.isNotEmpty) buffer.write('/');
      buffer.write(name.replaceAll('~', '~0').replaceAll('/', '~1'));
    } else if (item != null) {
      buffer.write('/$item');
    }
  }
  if (index != path.length || buffer.isEmpty) return null;
  return buffer.toString();
}

/// Converts a JSON pointer (`/items/0/qty`) to a Codelessly formula path
/// (`items[0].qty`).
String pointerToFormulaPath(String pointer) {
  final segments = pointer
      .split('/')
      .where((s) => s.isNotEmpty)
      .map((s) => s.replaceAll('~1', '/').replaceAll('~0', '~'));
  final buffer = StringBuffer();
  for (final String s in segments) {
    if (RegExp(r'^\d+$').hasMatch(s)) {
      buffer.write('[$s]');
    } else {
      if (buffer.isNotEmpty) buffer.write('.');
      buffer.write(s);
    }
  }
  return buffer.toString();
}

/// Whether [expression] parses and calls no impure function.
String? calcExpressionError(String expression) {
  if (!FormulaEvaluator.parses(expression)) {
    return 'calc expression does not parse: $expression';
  }
  for (final String name in kImpureFormulaFunctions) {
    if (RegExp('\\b$name\\s*\\(').hasMatch(expression)) {
      return 'calc may not call $name(): formulas must be pure.';
    }
  }
  return null;
}

/// The `calc` function: a Codelessly formula ([FormulaEvaluator]) evaluated
/// against the surface's data model.
///
/// The formula is pure: the evaluator writes nothing, and the clock and
/// random-id functions are refused. Every data path the formula names is
/// read through a signal, so the result recomputes, on the device, each
/// time one of them changes; the agent is not asked.
///
/// Identifiers resolve against the current data scope first (a List
/// template item), then against the data model root, then against `vars`.
class CalcFunction extends FunctionImplementation {
  CalcFunction()
    : super(
        name: 'calc',
        returnType: A2uiReturnType.any,
        description: 'Evaluates a pure Codelessly formula over the data model.',
        argumentSchema: Schema.fromMap({
          'type': 'object',
          'properties': {
            'expr': {'type': 'string'},
            'vars': {'type': 'object'},
          },
          'required': ['expr'],
        }),
      );

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) {
    final Object? expr = args['expr'];
    if (expr is! String) return null;
    if (calcExpressionError(expr) != null) return null;
    final Map<String, Object?> vars = switch (args['vars']) {
      final Map m => {for (final e in m.entries) '${e.key}': e.value},
      _ => const {},
    };
    final Map<String, ReadonlySignal<Object?>> relative = {};
    final Map<String, ReadonlySignal<Object?>> absolute = {};
    for (final String path in FormulaEvaluator.referencedPaths(expr)) {
      final String root = path.split(RegExp(r'[.\[]')).first;
      if (vars.containsKey(root)) continue;
      final String? pointer = formulaPathToPointer(root);
      if (pointer == null) continue;
      relative[root] = context.resolveSignal({'path': pointer});
      absolute[root] = context.resolveSignal({'path': '/$pointer'});
    }
    return computed(() {
      final Map<String, Object?> scope = {...vars};
      for (final MapEntry<String, ReadonlySignal<Object?>> entry
          in relative.entries) {
        scope[entry.key] = entry.value.value ?? absolute[entry.key]!.value;
      }
      return evaluateCalc(expr, scope);
    });
  }
}

/// Evaluates [expression] with [scope] holding its root names. Returns null
/// when the formula fails.
Object? evaluateCalc(String expression, Map<String, Object?> scope) {
  if (calcExpressionError(expression) != null) return null;
  try {
    return FormulaEvaluator.evaluate(expression, (path) {
      Object? value = scope;
      for (final Match m in RegExp(
        r'([A-Za-z_$][A-Za-z0-9_$]*)|\[(\d+)\]',
      ).allMatches(path)) {
        final String? name = m.group(1);
        final String? index = m.group(2);
        if (name != null) {
          value = value is Map ? value[name] : null;
        } else if (index != null) {
          final int i = int.parse(index);
          value = value is List && i < value.length ? value[i] : null;
        }
      }
      return value;
    });
  } catch (_) {
    return null;
  }
}
