import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';

import '../../../codelessly_sdk.dart';

class ConditionEvaluator<R>
    implements
        ConditionVisitor<R>,
        ExpressionVisitor<bool>,
        ExpressionPartVisitor,
        ConditionOperatorVisitor {
  final Map<String, VariableData> variables;

  const ConditionEvaluator(this.variables);

  @override
  R? visitCondition(Condition condition) {
    if (condition.expression.accept<bool>(this) == true) {
      return condition.actions.firstOrNull?.getValue<R?>();
    }
    return null;
  }

  @override
  R? visitConditionGroup(ConditionGroup condition) {
    return condition.ifCondition.accept<R>(this) ??
        condition.elseIfConditions
            .map((condition) => condition.accept<R>(this))
            .firstWhereOrNull((element) => element != null) ??
        condition.elseCondition?.accept<R>(this);
  }

  @override
  R? visitElseCondition(ElseCondition condition) {
    return condition.actions.firstOrNull?.getValue<R?>();
  }

  @override
  bool visitExpression(Expression expression) {
    final left = expression.leftPart.accept(this);
    final right = expression.rightPart.accept(this);

    return expression.operator.accept(this, left, right);
  }

  @override
  bool visitExpressionGroup(ExpressionGroup expression) {
    final bool left = expression.leftExpression.accept<bool>(this)!;
    final bool right = expression.rightExpression.accept<bool>(this)!;

    switch (expression.join) {
      case ConditionJoin.and:
        return left && right;
      case ConditionJoin.or:
        return left || right;
    }
  }

  @override
  dynamic visitVariablePart(VariablePart part) {
    if (part.jsonPath != null) {
      // TODO: [Aachman] handle JSON path?
      // This is a JSON path.
      return part.valueString;
    }

    if (part.valueString.isNotEmpty &&
        '\${${part.variableName}}' != part.valueString) {
      // Interpolation is required
      return _visitRawValue(
          substituteVariables(part.valueString, variables.values));
    } else {
      return _visitRawValue(
          variables[part.variableName]?.value.toString() ?? '');
    }
  }

  @override
  dynamic visitRawValuePart(RawValuePart part) => _visitRawValue(part.value);

  dynamic _visitRawValue(String value) {
    final parsedValue = num.tryParse(value) ?? bool.tryParse(value) ?? value;
    return parsedValue;
  }

  @override
  bool visitEqualsOperator(Object? left, Object? right) {
    if (left is num && right is num) return left == right;
    if (left is bool && right is bool) return left == right;
    return left.toString().toLowerCase() == right.toString().toLowerCase();
  }

  @override
  bool visitNotEqualsOperator(Object? left, Object? right) {
    if (left is num && right is num) return left != right;
    if (left is bool && right is bool) return left != right;
    return left.toString().toLowerCase() == right.toString().toLowerCase();
  }

  @override
  bool visitGreaterThanOperator(Object? left, Object? right) {
    if (left is num && right is num) return left > right;
    // This is required since we have loose type checking.
    return left
            .toString()
            .toLowerCase()
            .compareTo(right.toString().toLowerCase()) >
        0;
  }

  @override
  bool visitLessThanOperator(Object? left, Object? right) {
    if (left is num && right is num) return left < right;
    // This is required since we have loose type checking.
    return left
            .toString()
            .toLowerCase()
            .compareTo(right.toString().toLowerCase()) <
        0;
  }
}
