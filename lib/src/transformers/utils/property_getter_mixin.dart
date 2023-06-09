import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

/// A mixin that provides a method to get property value from different sources
/// like conditions, variables and node values.
mixin PropertyValueGetterMixin {
  T? getPropertyValue<T>(BuildContext context, BaseNode node, String property) {
    final T? conditionValue =
        getPropertyValueFromCondition(context, node, property);

    final T? variableValue =
        getPropertyValueFromVariable(context, node, property);

    final T? nodeValue =
        getPropertyValueFromNodeValues(context, node, property);

    return conditionValue ?? variableValue ?? nodeValue;
  }

  T? getPropertyValueFromCondition<T>(
      BuildContext context, BaseNode node, String property) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    final BaseCondition? condition =
        codelesslyContext.conditions.findByNodeProperty(node.id, property);

    return condition?.evaluate<T>(codelesslyContext.variableNamesMap());
  }

  T? getPropertyValueFromVariable<T>(
      BuildContext context, BaseNode node, String property) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    return codelesslyContext
        .findVariableById(node.variables[property])
        ?.typedValue<T>();
  }

  T? getPropertyValueFromNodeValues<T>(
          BuildContext context, BaseNode node, String property) =>
      context.getNodeValue<T>(node.id, property);
}
