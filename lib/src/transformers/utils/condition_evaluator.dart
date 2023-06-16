import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';

import '../../../codelessly_sdk.dart';

class ConditionEvaluator<R>
    implements
        ConditionVisitor<R>,
        ExpressionVisitor<bool>,
        ExpressionPartVisitor,
        ConditionOperatorVisitor,
        ActionVisitor<R> {
  final Map<String, VariableData> variables;
  final Map<String, dynamic> data;

  const ConditionEvaluator({required this.variables, required this.data});

  @override
  R? visitCondition(Condition condition) {
    if (condition.expression.accept<bool>(this) == true) {
      return condition.actions.firstOrNull?.accept<R?>(this);
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
    return condition.actions.firstOrNull?.accept<R?>(this);
  }

  @override
  bool visitExpression(Expression expression) {
    final left = expression.leftPart.accept(this);
    final right = expression.rightPart.accept(this);

    return expression.operator.accept(left, right, this);
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
    final value =
        part.valueString.splitMapJoin(variablePathRegex, onMatch: (match) {
      // value of the variable without $-sign and curly brackets.
      final RegExpMatch regexMatch = variablePathRegex.firstMatch(match[0]!)!;
      final variableValue = regexMatch.namedGroup('name')!;
      if (variableValue == 'data') {
        // json data path.
        final value =
            substituteJsonPath(match[0]!.replaceFirst('data.', ''), data);
        return value;
      } else {
        // variable name
        return variables[variableValue]?.value.toString() ?? '';
      }
    });
    return _visitRawValue(value);
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

  @override
  R? visitSetValueAction(SetValueAction action) {
    final ValueModel value = action.values.first;
    if (value is StringValue) {
      return visitVariablePart(VariablePart(valueString: value.value));
    }
    return value.value as R?;
  }

  @override
  R? visitSetVariantAction(SetVariantAction action) => action.variantID as R?;

  @override
  R? visitApiCall(ApiCallAction action) => null;

  @override
  R? visitCallFunctionAction(CallFunctionAction action) => null;

  @override
  R? visitLinkAction(LinkAction action) => null;

  @override
  R? visitNavigationAction(NavigationAction action) => null;

  @override
  R? visitSetVariableAction(SetVariableAction action) => null;

  @override
  R? visitSubmitAction(SubmitAction action) => null;
}
