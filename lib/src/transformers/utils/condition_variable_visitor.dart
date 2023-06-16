import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';

import '../../utils/regexes.dart';

/// A visitor that returns the list of variable names used in a condition.
class ConditionVariablesVisitor
    implements
        ConditionVisitor<Set<String>>,
        ExpressionVisitor<Set<String>>,
        ExpressionPartVisitor<Set<String>>,
        ActionVisitor<Set<String>> {
  const ConditionVariablesVisitor({
    this.excludedVariableNames = const {},
  });

  final Set<String> excludedVariableNames;

  @override
  Set<String> visitCondition(Condition condition) {
    return {
      ...condition.expression.accept<Set<String>>(this) ?? {},
      ...condition.actions
          .expand((action) => action.accept<Set<String>>(this) ?? <String>{}),
    };
  }

  @override
  Set<String> visitConditionGroup(ConditionGroup condition) {
    return <String>{
      ...condition.ifCondition.accept<Set<String>>(this) ?? {},
      ...condition.elseIfConditions
          .expand((action) => action.accept<Set<String>>(this) ?? <String>{})
          .toSet(),
      ...condition.elseCondition?.accept<Set<String>>(this) ?? {},
    };
  }

  @override
  Set<String> visitElseCondition(ElseCondition condition) {
    return condition.actions
        .expand((action) => action.accept<Set<String>>(this) ?? <String>{})
        .toSet();
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
    return variablePathRegex
        .allMatches(part.valueString)
        .map((match) => match.namedGroup('name'))
        .whereNotNull()
        .where((element) => !excludedVariableNames.contains(element))
        .toSet();
  }

  @override
  Set<String>? visitApiCall(ApiCallAction action) => {};

  @override
  Set<String>? visitCallFunctionAction(CallFunctionAction action) => {};

  @override
  Set<String>? visitLinkAction(LinkAction action) => {};

  @override
  Set<String>? visitNavigationAction(NavigationAction action) => {};

  @override
  Set<String>? visitSubmitAction(SubmitAction action) => {};

  @override
  Set<String>? visitSetVariableAction(SetVariableAction action) => {};

  @override
  Set<String>? visitSetVariantAction(SetVariantAction action) => {};

  @override
  Set<String>? visitSetValueAction(SetValueAction action) {
    return action.values
        .whereType<StringValue>()
        .expand(
          (value) => variablePathRegex
              .allMatches(value.value.toString())
              .map((match) => match.namedGroup('name'))
              .whereNotNull()
              .where((element) => !excludedVariableNames.contains(element)),
        )
        .toSet();
  }
}
