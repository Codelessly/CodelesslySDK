import 'package:codelessly_api/codelessly_api.dart';

import '../../utils/formula.dart';

/// A visitor that returns the list of variable names used in a condition.
class ConditionVariablesVisitor
    implements
        ConditionVisitor<Set<String>>,
        ExpressionVisitor<Set<String>>,
        ExpressionPartVisitor<Set<String>>,
        ActionVisitor<Set<String>> {
  const ConditionVariablesVisitor({this.excludedVariableNames = const {}});

  final Set<String> excludedVariableNames;

  @override
  Set<String> visitCondition(Condition condition) {
    return {
      ...condition.expression.accept<Set<String>>(this) ?? {},
      ...condition.actions.expand(
        (action) => action.accept<Set<String>>(this) ?? <String>{},
      ),
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
    return {
      ...variablePathRegex
          .allMatches(part.valueString)
          .map((match) => match.namedGroup('name'))
          .nonNulls,
      ...FormulaEvaluator.referencedPathsInText(part.valueString)
          .map((path) => path.split(RegExp(r'[.\[]')).first),
    }.where((element) => !excludedVariableNames.contains(element)).toSet();
  }

  @override
  Set<String>? visitApiCall(ApiCallAction action) => {};

  @override
  Set<String>? visitCallFunctionAction(CallFunctionAction action) => {};

  @override
  Set<String>? visitLinkAction(LinkAction action) => {};

  @override
  Set<String>? visitShowToastAction(ShowToastAction action) => {};

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
              .nonNulls
              .where((element) => !excludedVariableNames.contains(element)),
        )
        .toSet();
  }

  @override
  Set<String>? visitSetStorageAction(SetStorageAction action) => {};

  @override
  Set<String>? visitSetCloudStorageAction(SetCloudStorageAction action) => {};

  @override
  Set<String>? visitShowDialogAction(ShowDialogAction action) => {};

  @override
  Set<String>? visitCloseModalAction(CloseModalAction action) => {};

  @override
  Set<String>? visitLoadFromCloudStorageAction(
    LoadFromCloudStorageAction action,
  ) => {};

  @override
  Set<String>? visitAuthAction(AuthAction action) => {};

  @override
  Set<String>? visitConditionalAction(ConditionalAction action) => {};

  @override
  Set<String>? visitConfirmAction(ConfirmAction action) => {};

  @override
  Set<String>? visitDelayAction(DelayAction action) => {};

  @override
  Set<String>? visitCopyToClipboardAction(CopyToClipboardAction action) => {};

  @override
  Set<String>? visitEditTextAction(EditTextAction action) => {};

  @override
  Set<String>? visitPaywallAction(PaywallAction action) => {};

  @override
  Set<String>? visitCloudDataAction(CloudDataAction action) => {};

  @override
  Set<String>? visitCloudBatchAction(CloudBatchAction action) => {};

  @override
  Set<String>? visitForEachAction(ForEachAction action) => {};

  @override
  Set<String>? visitCloudFilesAction(CloudFilesAction action) => {};
}

/// A visitor that returns the list of node IDs used in a condition's actions.
class ConditionNodesVisitor
    implements ConditionVisitor<Set<String>>, ActionVisitor<String> {
  const ConditionNodesVisitor();

  @override
  String? visitApiCall(ApiCallAction action) => null;

  @override
  String? visitCallFunctionAction(CallFunctionAction action) => null;

  @override
  Set<String>? visitCondition(Condition condition) => {
    ...condition.actions
        .map((action) => action.accept<String>(this))
        .nonNulls
        .toSet(),
  };

  @override
  Set<String>? visitConditionGroup(ConditionGroup condition) => {
    ...condition.ifCondition.actions,
    ...condition.elseIfConditions.expand((condition) => condition.actions),
    ...condition.elseCondition?.actions ?? [],
  }.map((action) => action.accept<String>(this)).nonNulls.toSet();

  @override
  Set<String>? visitElseCondition(ElseCondition condition) {
    return condition.actions
        .map((action) => action.accept<String>(this))
        .nonNulls
        .toSet();
  }

  @override
  String? visitLinkAction(LinkAction action) => null;

  @override
  String? visitShowToastAction(ShowToastAction action) => null;

  @override
  String? visitNavigationAction(NavigationAction action) => null;

  @override
  String? visitSetValueAction(SetValueAction action) => action.nodeID;

  @override
  String? visitSetVariableAction(SetVariableAction action) => null;

  @override
  String? visitSetVariantAction(SetVariantAction action) => action.nodeID;

  @override
  String? visitSubmitAction(SubmitAction action) => null;

  @override
  String? visitSetStorageAction(SetStorageAction action) => null;

  @override
  String? visitSetCloudStorageAction(SetCloudStorageAction action) => null;

  @override
  String? visitShowDialogAction(ShowDialogAction action) => null;

  @override
  String? visitCloseModalAction(CloseModalAction action) => null;

  @override
  String? visitLoadFromCloudStorageAction(LoadFromCloudStorageAction action) =>
      null;

  @override
  String? visitAuthAction(AuthAction action) => null;

  @override
  String? visitConditionalAction(ConditionalAction action) => null;

  @override
  String? visitConfirmAction(ConfirmAction action) => null;

  @override
  String? visitDelayAction(DelayAction action) => null;

  @override
  String? visitCopyToClipboardAction(CopyToClipboardAction action) => null;

  @override
  String? visitEditTextAction(EditTextAction action) => action.nodeId;

  @override
  String? visitPaywallAction(PaywallAction action) => null;

  @override
  String? visitCloudDataAction(CloudDataAction action) => null;

  @override
  String? visitCloudBatchAction(CloudBatchAction action) => null;

  @override
  String? visitForEachAction(ForEachAction action) => null;

  @override
  String? visitCloudFilesAction(CloudFilesAction action) => null;
}
