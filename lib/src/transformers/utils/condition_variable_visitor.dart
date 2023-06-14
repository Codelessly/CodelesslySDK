import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';

import '../../utils/utils.dart';

/// A visitor that returns the list of variable names used in a condition.
class ConditionVariablesVisitor
    implements
        ConditionVisitor<Set<String>>,
        ExpressionVisitor<Set<String>>,
        ExpressionPartVisitor<Set<String>> {
  const ConditionVariablesVisitor();

  @override
  Set<String> visitCondition(Condition condition) {
    return condition.expression.accept<Set<String>>(this) ?? {};
  }

  @override
  Set<String> visitConditionGroup(ConditionGroup condition) {
    return <String>{
      ...condition.ifCondition.accept<Set<String>>(this) ?? {},
      ...condition.elseIfConditions
          .expand((condition) => condition.accept<Set<String>>(this) ?? {}),
    };
  }

  @override
  Set<String> visitElseCondition(ElseCondition condition) {
    return {};
  }

  @override
  Set<String> visitExpression(Expression expression) {
    return <String>{
      ...expression.leftPart.accept<Set<String>>(this) ?? {},
      ...expression.rightPart.accept<Set<String>>(this) ?? {},
    };
  }

  @override
  Set<String> visitExpressionGroup(ExpressionGroup expression) {
    return <String>{
      ...expression.leftExpression.accept<Set<String>>(this) ?? {},
      ...expression.rightExpression.accept<Set<String>>(this) ?? {},
    };
  }

  @override
  Set<String> visitRawValuePart(RawValuePart part) {
    return {};
  }

  @override
  Set<String> visitVariablePart(VariablePart part) {
    return variableNameRegex
        .allMatches(part.valueString)
        // group 1 is the variable name without the $ prefix, curly braces, and
        // the path.
        .map((match) => match.group(1))
        .whereNotNull()
        .toSet();
  }
}
