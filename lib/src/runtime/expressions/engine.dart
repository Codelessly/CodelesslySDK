// The expression language: `${path}` reads a value, `${= formula}` computes
// one, and any other `${...}` in a text is replaced by its value's text.
import 'package:codelessly_api/codelessly_api.dart' show Node, Predicate, Comparison, Junction, Join, ConditionOp,
    ConditionOperand;

import '../contracts.dart';
import 'bindings.dart';
import 'formula.dart';
import 'paths.dart';
import 'scopes.dart';

/// Evaluates expressions over [ValueScope]s.
///
/// * `${user.name}` (exactly one path) is the value as is: a list stays a
///   list.
/// * `${= price * qty}` (exactly one formula) is the formula's value.
/// * Any other text with `${...}` in it is text, each `${...}` replaced by
///   its value's text ([nullSubstitution] for one that reads nothing).
/// * Text without `${` is itself.
class Expressions implements ExpressionEngine {
  const Expressions({this.nullSubstitution = NullSubstitution.emptyString});

  /// What a `${path}` that reads nothing becomes in [interpolate].
  final NullSubstitution nullSubstitution;

  @override
  Object? evaluate(String expression, ValueScope scope) {
    if (!expression.contains(r'${')) return expression;
    final f = FormulaEvaluator.exactExpression(expression);
    if (f != null) return formula(f, scope);
    final p = exactPath(expression);
    if (p != null) return readPath(scope, p);
    return interpolate(expression, scope);
  }

  /// The value of formula [expression] (what goes in `${= ...}`).
  Object? formula(String expression, ValueScope scope) =>
      FormulaEvaluator.evaluate(expression, (p) => readPath(scope, p));

  @override
  String interpolate(String text, ValueScope scope, {NullSubstitution? mode}) {
    if (!text.contains(r'${')) return text;
    final m = mode ?? nullSubstitution;
    // Formulas first, so `${= ...}` isn't read as a path.
    final withFormulas = FormulaEvaluator.substitute(
      text,
      (p) => readPath(scope, p),
      nullText: m == NullSubstitution.nullValue ? 'null' : '',
    );
    return withFormulas.replaceAllMapped(expressionSyntax, (match) {
      final path = (match as RegExpMatch).namedGroup('value')!.trim();
      final value = readPath(scope, path);
      if (value != null) return pathText(value);
      return switch (m) {
        NullSubstitution.emptyString => '',
        NullSubstitution.nullValue => 'null',
        NullSubstitution.noChange => match[0]!,
      };
    });
  }

  /// [value] (decoded JSON: an API body, a query) with its strings
  /// evaluated: a string that is one `${path}` or `${= formula}` becomes
  /// the value as is (a list, a number, null), others are interpolated;
  /// map keys are interpolated.
  Object? substituteJson(Object? value, ValueScope scope) => switch (value) {
        final String s when !s.contains(r'${') => s,
        final String s when FormulaEvaluator.exactExpression(s) != null || exactPath(s) != null => evaluate(s, scope),
        final String s => interpolate(s, scope, mode: NullSubstitution.emptyString),
        final List<Object?> l => [for (final v in l) substituteJson(v, scope)],
        final Map<Object?, Object?> m => {
            for (final e in m.entries) interpolate('${e.key}', scope): substituteJson(e.value, scope),
          },
        _ => value,
      };

  @override
  (Node, Set<String>) resolve(Node node, ValueScope scope) {
    final b = NodeBindings.of(node);
    final reads = <String>{};
    var out = node;
    for (final p in [...b.properties, ?b.visible]) {
      reads.addAll(p.reads);
      out = p.applyTo(out, this, scope);
    }
    return (out, reads);
  }

  // --- conditions -------------------------------------------------------------

  /// Whether [p] holds in [scope].
  bool test(Predicate p, ValueScope scope) => switch (p) {
        final Comparison c => compare(operand(c.left, scope), c.op, c.op.takesRight ? operand(c.right, scope) : null),
        // Every part is evaluated.
        Junction(join: Join.and, :final parts) => parts.map((x) => test(x, scope)).toList().every((x) => x),
        Junction(join: Join.or, :final parts) => parts.map((x) => test(x, scope)).toList().any((x) => x),
      };

  /// The value of a condition operand: one path or formula keeps its value's
  /// type; other text is substituted (`null` for what reads nothing) and
  /// read loosely ([parseLoose]).
  Object? operand(ConditionOperand o, ValueScope scope) {
    if (o.raw) return parseLoose(o.text);
    final text = o.text.trim();
    final f = FormulaEvaluator.exactExpression(text);
    if (f != null) return formula(f, scope);
    final p = exactPath(text);
    if (p != null) {
      final v = readPath(scope, p);
      if (v is List || v is Map) return v;
    }
    return parseLoose(interpolate(o.text, scope, mode: NullSubstitution.nullValue));
  }

  /// [left] [op] [right], loosely: numbers as numbers, booleans as booleans,
  /// anything else as case-insensitive text.
  static bool compare(Object? left, ConditionOp op, Object? right) {
    int? order() {
      if (left is num && right is num) return left.compareTo(right);
      if (left == null || right == null) return null;
      return left.toString().toLowerCase().compareTo(right.toString().toLowerCase());
    }

    bool equals() {
      if (left == null && right == null) return true;
      if (left is num && right is num) return left == right;
      if (left == null || right == null) return false;
      if (left is bool && right is bool) return left == right;
      return left.toString().toLowerCase() == right.toString().toLowerCase();
    }

    final o = switch (op) {
      ConditionOp.greaterThan ||
      ConditionOp.lessThan ||
      ConditionOp.greaterThanOrEqualTo ||
      ConditionOp.lessThanOrEqualTo =>
        order(),
      _ => null,
    };
    return switch (op) {
      ConditionOp.equalsTo => equals(),
      ConditionOp.notEqualsTo => !equals(),
      ConditionOp.greaterThan => o != null && o > 0,
      ConditionOp.lessThan => o != null && o < 0,
      ConditionOp.greaterThanOrEqualTo => o != null && o >= 0,
      ConditionOp.lessThanOrEqualTo => o != null && o <= 0,
      ConditionOp.isEmpty => switch (left) {
          null => true,
          final List l => l.isEmpty,
          final String s => s.isEmpty,
          final Map m => m.isEmpty,
          _ => false,
        },
      ConditionOp.isNotEmpty => switch (left) {
          final List l => l.isNotEmpty,
          final String s => s.isNotEmpty,
          final Map m => m.isNotEmpty,
          _ => false,
        },
      ConditionOp.contains => switch (left) {
          final List l => l.contains(right),
          final String s when right != null => s.contains(right.toString()),
          final Map m => m.containsKey(right),
          _ => false,
        },
      ConditionOp.isOdd => left is int && left.isOdd,
      ConditionOp.isEven => left is int && left.isEven,
      ConditionOp.isNull => left == null || left == 'null',
      ConditionOp.isTrue => left is bool ? left : (left is String && left.toLowerCase() == 'true'),
      ConditionOp.isFalse => left is bool ? !left : (left is String && left.toLowerCase() == 'false'),
    };
  }

  // --- what an expression reads -------------------------------------------------

  /// The paths [expression] reads (`user.name`, `cart`), for watching.
  static Set<String> readsOf(String expression) {
    if (!expression.contains(r'${')) return const {};
    final out = <String>{};
    for (final m in expressionSyntax.allMatches(expression)) {
      final v = m.namedGroup('value')!.trim();
      if (v.startsWith('=')) {
        out.addAll(FormulaEvaluator.referencedPaths(v.substring(1)));
        out.addAll(FormulaEvaluator.userFunctionCalls(v.substring(1)));
      } else if (ValuePath.parse(v) != null) {
        out.add(v);
      } else {
        out.addAll(FormulaEvaluator.referencedPaths(v));
      }
    }
    return out;
  }

  /// Whether [expression] reads the clock (`now()`, `today()`, `nowMs()`).
  static bool readsClock(String expression) =>
      expression.contains(r'${=') &&
      (FormulaEvaluator.textReadsClock(expression) || FormulaEvaluator.textReadsFrameClock(expression));

  /// The paths [p]'s operands read.
  static Set<String> readsOfPredicate(Predicate p) => {
        for (final o in p.operands)
          if (!o.raw) ...readsOf(o.text),
      };
}
