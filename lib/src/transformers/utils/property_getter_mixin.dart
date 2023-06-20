import 'dart:convert';

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

    return condition?.evaluate<T>(
        codelesslyContext.variableNamesMap(), codelesslyContext.data);
  }

  T? getPropertyValueFromVariable<T>(
      BuildContext context, BaseNode node, String property) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    final String? variablePath = node.variables[property];

    if (variablePath == null) return null;

    final match = VariableMatch.parse(variablePath.wrapWithVariableSyntax());

    if (match == null) return null;

    if (match.isPredefinedVariable) {
      return getPredefinedVariableValue<T>(context, match.name, match.fullPath);
    }

    final VariableData? variable =
        codelesslyContext.findVariableByName(match.name)?.value;

    if (variable == null) return null;

    if (match.hasPathOrAccessor) {
      if (variable.type == VariableType.map) {
        final Map<String, dynamic> json =
            variable.value.isNotEmpty ? jsonDecode(variable.value) : {};
        return substituteJsonPath(match.fullPath, {match.name: json})
            ?.typedValue<T>();
      } else if (variable.type == VariableType.list) {
        // TODO: support list type variable paths.
        return substituteJsonPath(match.fullPath, {match.name: variable.value})
            ?.typedValue<T>();
      }
    }

    return variable.value.typedValue<T>();
  }

  T? getPredefinedVariableValue<T>(
      BuildContext context, String name, String path) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    if (name == 'data') {
      // substitute path with data.
      return substituteJsonPath(
              path.wrapWithVariableSyntax(), {'data': codelesslyContext.data})
          ?.typedValue<T>();
    }

    if (name == 'index') {
      // substitute path with screen.
      final index = IndexedItemProvider.of(context)?.index;
      if (index == null) return null;

      return '$index'.typedValue<T>();
    }

    if (name == 'item') {
      // substitute path with screen.
      final item = IndexedItemProvider.of(context)?.item;
      if (item == null) return null;

      return substituteJsonPath(path.wrapWithVariableSyntax(), {'item': item})
          ?.typedValue<T>();
    }

    return null;
  }

  T? getPropertyValueFromNodeValues<T>(
          BuildContext context, BaseNode node, String property) =>
      context.getNodeValue<T>(node.id, property);
}
