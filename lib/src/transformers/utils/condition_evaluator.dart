import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../codelessly_sdk.dart';

class ConditionEvaluator<R extends Object>
    implements
        ConditionVisitor<R>,
        ExpressionVisitor<bool>,
        ExpressionPartVisitor,
        ConditionOperatorVisitor,
        ActionVisitor<R> {
  final ScopedValues scopedValues;

  ConditionEvaluator({required this.scopedValues});

  @override
  R? visitCondition(Condition condition) {
    if (condition.expression.accept<bool>(this) == true) {
      return condition.actions.firstOrNull?.accept<R>(this);
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
    return condition.actions.firstOrNull?.accept<R>(this);
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
  Object? visitVariablePart(VariablePart part) {
    final value =
        part.valueString.splitMapJoinRegex(variablePathRegex, onMatch: (match) {
      final Object? value = PropertyValueDelegate.getVariableValueFromPath(
        match[0]!,
        scopedValues: scopedValues,
      );

      return value?.typedValue<String>() ?? 'null';
    });
    return _visitRawValue(value);
  }

  @override
  Object? visitRawValuePart(RawValuePart part) => _visitRawValue(part.value);

  Object? _visitRawValue(String value) => value.parsedValue();

  @override
  bool visitEqualsOperator(Object? left, Object? right) {
    if (left == null && right == null) return true;
    if (left is num && right is num) return left == right;

    if (left == null && right != null) return false;
    if (left != null && right == null) return false;

    if (left is bool && right is bool) return left == right;

    return left.toString().toLowerCase() == right.toString().toLowerCase();
  }

  @override
  bool visitNotEqualsOperator(Object? left, Object? right) {
    if (left == null && right != null) return true;
    if (left != null && right == null) return true;
    if (left == null && right == null) return false;

    if (left is num && right is num) return left != right;
    if (left is bool && right is bool) return left != right;

    return left.toString().toLowerCase() != right.toString().toLowerCase();
  }

  @override
  bool visitGreaterThanOperator(Object? left, Object? right) {
    if (left is num && right is num) return left > right;

    if (left == null || right == null) return false;

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

    if (left == null || right == null) return false;

    // This is required since we have loose type checking.
    return left
            .toString()
            .toLowerCase()
            .compareTo(right.toString().toLowerCase()) <
        0;
  }

  @override
  bool visitGreaterThanOrEqualToOperator(Object? left, Object? right) {
    if (left is num && right is num) return left >= right;

    if (left == null || right == null) return false;

    // This is required since we have loose type checking.
    return left
            .toString()
            .toLowerCase()
            .compareTo(right.toString().toLowerCase()) >=
        0;
  }

  @override
  bool visitLessThanOrEqualToOperator(Object? left, Object? right) {
    if (left is num && right is num) return left <= right;

    if (left == null || right == null) return false;

    // This is required since we have loose type checking.
    return left
            .toString()
            .toLowerCase()
            .compareTo(right.toString().toLowerCase()) <=
        0;
  }

  @override
  bool visitIsEmptyOperator(Object? left) {
    if (left is List) return left.isEmpty;
    if (left is String) return left.isEmpty;
    if (left is Map) return left.isEmpty;

    return false;
  }

  @override
  bool visitIsNotEmptyOperator(Object? left) {
    if (left is List) return left.isNotEmpty;
    if (left is String) return left.isNotEmpty;
    if (left is Map) return left.isNotEmpty;

    return false;
  }

  @override
  bool visitContainsOperator(Object? left, Object? right) {
    if (left is List) return left.contains(right);
    if (left is String && right != null) return left.contains(right.toString());
    if (left is Map) return left.containsKey(right);

    return false;
  }

  @override
  bool visitIsOddOperator(Object? value) {
    if (value is int) return value.isOdd;
    return false;
  }

  @override
  bool visitIsEvenOperator(Object? value) {
    if (value is int) return value.isEven;
    return false;
  }

  @override
  bool visitIsNullOperator(Object? value) {
    if (value == null) return true;
    if (value == 'null') return true;
    return false;
  }

  @override
  bool visitIsTrueOperator(Object? left) {
    if (left is bool) return left == true;
    if (left is String) return left.toLowerCase() == 'true';

    return false;
  }

  @override
  bool visitIsFalseOperator(Object? left) {
    if (left is bool) return left == false;
    if (left is String) return left.toLowerCase() == 'false';

    return false;
  }

  @override
  R? visitSetValueAction(SetValueAction action) {
    final ValueModel value = action.values.first;
    if (value is StringValue) {
      return visitVariablePart(VariablePart(valueString: value.value))
          .typedValue<R>();
    }
    return value.value.typedValue<R>();
  }

  @override
  R? visitSetVariantAction(SetVariantAction action) =>
      action.variantID.typedValue<R>();

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

  @override
  R? visitSetStorageAction(SetStorageAction action) => null;

  @override
  R? visitSetCloudStorageAction(SetCloudStorageAction action) => null;

  @override
  R? visitShowDialogAction(ShowDialogAction action) => null;

  @override
  R? visitLoadFromCloudStorageAction(LoadFromCloudStorageAction action) => null;
}

class ConditionPrinter
    implements
        ConditionVisitor<void>,
        ExpressionVisitor<void>,
        ExpressionPartVisitor<Object>,
        ActionVisitor<void> {
  final StringBuffer _buffer = StringBuffer();

  void printCondition(BaseCondition condition) {
    _buffer.clear();
    condition.accept(this);
    print('\n${_buffer.toString()}');
  }

  String prettify(BaseCondition condition) {
    printCondition(condition);
    return _buffer.toString();
  }

  @override
  void visitApiCall(ApiCallAction action) {}

  @override
  void visitCallFunctionAction(CallFunctionAction action) {
    _buffer.writeln('\tCall Function ${action.name} with ${action.params}');
  }

  @override
  void visitCondition(Condition condition) {
    _buffer.write('${condition.mode.label.toUpperCase()} ');
    condition.expression.accept(this);
    _buffer.write(' {\n');
    condition.actions.first.accept(this);
    _buffer.write('} ');
  }

  @override
  void visitConditionGroup(ConditionGroup condition) {
    condition.ifCondition.accept(this);
    for (final elseIfCondition in condition.elseIfConditions) {
      elseIfCondition.accept(this);
    }
    condition.elseCondition?.accept(this);
  }

  @override
  void visitElseCondition(ElseCondition condition) {
    _buffer.write('ELSE { \n');
    condition.actions.first.accept(this);
    _buffer.write('} ');
  }

  @override
  void visitExpression(Expression expression) {
    _buffer.write('( ');
    expression.leftPart.accept(this);
    _buffer
        .write(' ${expression.operator.sign ?? expression.operator.sentence} ');
    expression.rightPart.accept(this);
    _buffer.write(' )');
  }

  @override
  void visitExpressionGroup(ExpressionGroup expression) {
    _buffer.write('( ');
    expression.leftExpression.accept(this);
    _buffer.write(' ${expression.join.sign} ');
    expression.rightExpression.accept(this);
    _buffer.write(' )');
  }

  @override
  void visitLinkAction(LinkAction action) {}

  @override
  void visitNavigationAction(NavigationAction action) {}

  @override
  void visitRawValuePart(RawValuePart part) => _buffer.write(part.value);

  @override
  void visitSetValueAction(SetValueAction action) {
    _buffer.writeln(
        '\tSet Value of ${action.values.first.name} to ${valueModelToString(action.values.first)}');
  }

  String valueModelToString(ValueModel model) {
    if (model is PaintValue) {
      return 'Color(0x${model.value?.color?.toFlutterColor(opacity: model.value?.opacity ?? 1).hex})';
    }
    if (model is ColorValue) {
      return 'Color(0x${model.value?.toFlutterColor().hex})';
    }

    return model.value.toString();
  }

  @override
  void visitSetVariableAction(SetVariableAction action) {
    _buffer.writeln(
        '\tSet Variable ${action.variable.name} to ${action.variable.value}');
  }

  @override
  void visitSetVariantAction(SetVariantAction action) {
    _buffer.writeln('\tSetVariant to ${action.variantID}');
  }

  @override
  void visitSubmitAction(SubmitAction action) {}

  @override
  void visitVariablePart(VariablePart part) => _buffer.write(part.valueString);

  @override
  void visitSetStorageAction(SetStorageAction action) {}

  @override
  void visitSetCloudStorageAction(SetCloudStorageAction action) {}

  @override
  void visitShowDialogAction(ShowDialogAction action) {}

  @override
  void visitLoadFromCloudStorageAction(LoadFromCloudStorageAction action) {}
}