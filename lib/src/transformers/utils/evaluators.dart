import 'package:codelessly_api/codelessly_api.dart';

import '../../../codelessly_sdk.dart';

abstract class Evaluator<T> {
  const Evaluator();

  /// Evaluates the given [part] and returns the value.
  /// [ATTENTION]: [variables] is a map of variable names and their values.
  ///
  /// Note: this can also be done by extension method on [ExpressionPart] but
  /// that is not debuggable unfortunately.
  T? evaluate(Map<String, VariableData> variables);
}

class ConditionEvaluator<T> extends Evaluator<T> {
  final BaseCondition? condition;

  const ConditionEvaluator(this.condition);

  /// Evaluates the given [condition] and returns the typed result.
  ///
  /// [ATTENTION]:
  ///   1. [variables] is a map of variable names and their values.
  ///   2. despite condition storing multiple actions, only the first action is
  ///      evaluated and returned.
  ///
  /// Note: this can also be done by extension method on [BaseCondition] but
  /// that is not debuggable unfortunately.
  @override
  T? evaluate(Map<String, VariableData> variables) {
    final condition = this.condition;
    if (condition == null) return null;

    if (condition is Condition) {
      if (ExpressionEvaluator(condition.expression).evaluate(variables)) {
        return condition.actions.firstOrNull?.getValue<T?>();
      } else {
        return null;
      }
    } else if (condition is ConditionGroup) {
      if (ExpressionEvaluator(condition.ifCondition.expression)
          .evaluate(variables)) {
        return condition.ifCondition.actions.firstOrNull?.getValue<T?>();
      } else {
        for (final elseIfCondition in condition.elseIfConditions) {
          if (ExpressionEvaluator(elseIfCondition.expression)
              .evaluate(variables)) {
            return elseIfCondition.actions.firstOrNull?.getValue<T?>();
          }
        }
        return condition.elseCondition?.actions.firstOrNull?.getValue<T?>();
      }
    } else if (condition is ElseCondition) {
      return condition.actions.firstOrNull?.getValue<T?>();
    }

    return null;
  }
}

class ExpressionEvaluator extends Evaluator<bool> {
  final BaseExpression expression;

  const ExpressionEvaluator(this.expression);

  /// Evaluates the given [expression] and returns true or false.
  /// [ATTENTION]: [variables] is a map of variable names and their values.
  ///
  /// Note: this can also be done by extension method on [BaseExpression] but
  /// that is not debuggable unfortunately.
  @override
  bool evaluate(Map<String, VariableData> variables) {
    final expression = this.expression;
    if (expression is Expression) {
      final left =
          ExpressionPartEvaluator(expression.leftPart).evaluate(variables);
      final right =
          ExpressionPartEvaluator(expression.rightPart).evaluate(variables);
      switch (expression.operator) {
        case ConditionOperation.equalsTo:
          return left.toString().toLowerCase() ==
              right.toString().toLowerCase();
        case ConditionOperation.notEqualsTo:
          return left.toString().toLowerCase() !=
              right.toString().toLowerCase();
        case ConditionOperation.greaterThan:
          if (left is num && right is num) {
            return left > right;
          }
          return left
                  .toString()
                  .toLowerCase()
                  .compareTo(right.toString().toLowerCase()) >
              0;
        case ConditionOperation.lessThan:
          if (left is num && right is num) {
            return left < right;
          }
          return left
                  .toString()
                  .toLowerCase()
                  .compareTo(right.toString().toLowerCase()) <
              0;
      }
    }
    if (expression is ExpressionGroup) {
      final left =
          ExpressionEvaluator(expression.leftExpression).evaluate(variables);
      final right =
          ExpressionEvaluator(expression.rightExpression).evaluate(variables);
      switch (expression.join) {
        case ConditionJoin.and:
          return left && right;
        case ConditionJoin.or:
          return left || right;
      }
    }
    return false;
  }
}

class ExpressionPartEvaluator<T> extends Evaluator<T> {
  final ExpressionPart part;

  const ExpressionPartEvaluator(this.part);

  /// Evaluates the given [part] and returns the value.
  /// [ATTENTION]: [variables] is a map of variable names and their values.
  ///
  /// Note: this can also be done by extension method on [ExpressionPart] but
  /// that is not debuggable unfortunately.
  @override
  T? evaluate(Map<String, VariableData> variables) {
    final part = this.part;
    if (part is VariablePart) {
      // TODO: [Aachman] handle JSON path?
      return variables[part.variableName]?.value as T?;
    }
    if (part is RawValuePart) {
      return part.value as T?;
    }
    return null;
  }
}

/// Evaluates the given [condition] and returns the typed result.
///
/// [ATTENTION]:
///   1. [variables] is a map of variable names and their values.
///   2. despite condition storing multiple actions, only the first action is
///      evaluated and returned.
///
/// Note: this can also be done by extension method on [BaseCondition] but
/// that is not debuggable unfortunately.
T? evaluateCondition<T>(
    BaseCondition? condition, Map<String, VariableData> variables) {
  if (condition == null) return null;

  if (condition is Condition) {
    if (evaluateExpression(condition.expression, variables)) {
      return condition.actions.firstOrNull?.getValue<T?>();
    } else {
      return null;
    }
  } else if (condition is ConditionGroup) {
    if (evaluateExpression(condition.ifCondition.expression, variables)) {
      return condition.ifCondition.actions.firstOrNull?.getValue<T?>();
    } else {
      for (final elseIfCondition in condition.elseIfConditions) {
        if (evaluateExpression(elseIfCondition.expression, variables)) {
          return elseIfCondition.actions.firstOrNull?.getValue<T?>();
        }
      }
      return condition.elseCondition?.actions.firstOrNull?.getValue<T?>();
    }
  } else if (condition is ElseCondition) {
    return condition.actions.firstOrNull?.getValue<T?>();
  }

  return null;
}

/// Evaluates the given [expression] and returns true or false.
/// [ATTENTION]: [variables] is a map of variable names and their values.
///
/// Note: this can also be done by extension method on [BaseExpression] but
/// that is not debuggable unfortunately.
bool evaluateExpression(
  BaseExpression expression,
  Map<String, VariableData> variables,
) {
  if (expression is Expression) {
    final left = evaluateExpressionPart(expression.leftPart, variables);
    print('left: $left');
    final right = evaluateExpressionPart(expression.rightPart, variables);
    print('right: $right');
    switch (expression.operator) {
      case ConditionOperation.equalsTo:
        if (left is num && right is num) return left == right;
        if (left is bool && right is bool) return left == right;
        return left.toString().toLowerCase() == right.toString().toLowerCase();
      case ConditionOperation.notEqualsTo:
        if (left is num && right is num) return left != right;
        if (left is bool && right is bool) return left != right;
        return left.toString().toLowerCase() != right.toString().toLowerCase();
      case ConditionOperation.greaterThan:
        if (left is num && right is num) return left > right;
        // This is required since we have loose type checking.
        return left
                .toString()
                .toLowerCase()
                .compareTo(right.toString().toLowerCase()) >
            0;
      case ConditionOperation.lessThan:
        if (left is num && right is num) return left < right;
        // This is required since we have loose type checking.
        return left
                .toString()
                .toLowerCase()
                .compareTo(right.toString().toLowerCase()) <
            0;
    }
  }
  if (expression is ExpressionGroup) {
    final left = evaluateExpression(expression.leftExpression, variables);
    final right = evaluateExpression(expression.rightExpression, variables);
    switch (expression.join) {
      case ConditionJoin.and:
        return left && right;
      case ConditionJoin.or:
        return left || right;
    }
  }
  return false;
}

/// Evaluates the given [part] and returns the value.
/// [ATTENTION]: [variables] is a map of variable names and their values.
///
/// Note: this can also be done by extension method on [ExpressionPart] but
/// that is not debuggable unfortunately.
dynamic evaluateExpressionPart(
    ExpressionPart part, Map<String, VariableData> variables) {
  if (part is VariablePart) {
    if (part.jsonPath != null) {
      // TODO: [Aachman] handle JSON path?
      // This is a JSON path.
      return part.valueString;
    }

    if (part.valueString.isNotEmpty &&
        '\${${part.variableName}}' != part.valueString) {
      // Interpolation is required
      part =
          RawValuePart(substituteVariables(part.valueString, variables.values));
    } else {
      part = RawValuePart(variables[part.variableName]?.value.toString() ?? '');
    }
  }

  if (part is RawValuePart) {
    return num.tryParse(part.value) ?? bool.tryParse(part.value) ?? part.value;
  }

  return null;
}
