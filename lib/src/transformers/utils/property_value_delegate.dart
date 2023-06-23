import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

/// A delegate class that helps retrieving the value of a node property from
/// multiple sources such as conditions, variables, data, and node values.
class PropertyValueDelegate {
  /// Retrieves the value of a node [property] from multiple sources.
  /// Sources: Conditions, Variables, Data, item, index, and Node Values.
  ///
  /// This operates on [BaseNode.variables] to determine if the value is
  /// coming from a variable. If the value is coming from a variable, it will
  /// be parsed and evaluated.
  ///
  /// Precedence:
  ///  1. Conditions
  ///  2. Variables
  ///  3. Node Values
  ///
  /// For [BaseNode.multipleVariables], Use [substituteVariables] to substitute
  /// variables in a string.
  ///
  /// Generic type [R] is the expected return type of the variable value and
  /// it must be specified.
  ///
  /// If [variablesOverrides] is provided, it will be used to instead of the
  /// variables retrieved from [CodelesslyContext].
  ///
  /// If [dataOverrides] is provided, it will be used to instead of the
  /// data retrieved from [CodelesslyContext].
  static R? getPropertyValue<R>(
    BuildContext context,
    BaseNode node,
    String property, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    final R? conditionValue = getPropertyValueFromCondition(
      context,
      node,
      property,
      variablesOverrides: variablesOverrides,
      dataOverrides: dataOverrides,
    );

    final R? variableValue = getPropertyValueFromVariable(
      context,
      node,
      property,
      variablesOverrides: variablesOverrides,
      dataOverrides: dataOverrides,
    );

    final R? nodeValue = getPropertyValueFromNodeValues(
      context,
      node,
      property,
    );

    return conditionValue ?? variableValue ?? nodeValue;
  }

  /// Retrieves the value of a node [property] from a condition by evaluating
  /// the condition if it exists.
  ///
  /// Generic type [R] is the expected return type of the variable value and
  /// it must be specified.
  ///
  /// If [variablesOverrides] is provided, it will be used to instead of the
  /// variables retrieved from [CodelesslyContext].
  ///
  /// If [dataOverrides] is provided, it will be used to instead of the
  /// data retrieved from [CodelesslyContext].
  static R? getPropertyValueFromCondition<R>(
    BuildContext context,
    BaseNode node,
    String property, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    final BaseCondition? condition =
        codelesslyContext.conditions.findByNodeProperty(node.id, property);

    // Variable name -> Variable.
    final Map<String, VariableData> variables = variablesOverrides
            ?.asMap()
            .map((key, value) => MapEntry(value.name, value)) ??
        codelesslyContext.variableNamesMap();

    final Map<String, dynamic> data = dataOverrides ?? codelesslyContext.data;

    return condition?.evaluate<R>(context, variables, data);
  }

  /// Retrieves the value of a node [property] from a variable by evaluating
  /// the variable path if it exists. This also supports predefined variables
  /// such as data, index, and item.
  ///
  /// This operates on [BaseNode.variables] to retrieve the variable path.
  ///
  /// For [BaseNode.multipleVariables], Use [substituteVariables] to substitute
  /// variables in a string.
  ///
  /// Generic type [R] is the expected return type of the variable value and
  /// it must be specified.
  ///
  /// If [variablesOverrides] is provided, it will be used to instead of the
  /// variables retrieved from [CodelesslyContext].
  ///
  /// If [dataOverrides] is provided, it will be used to instead of the
  /// data retrieved from [CodelesslyContext].
  static R? getPropertyValueFromVariable<R>(
    BuildContext context,
    BaseNode node,
    String property, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    final String? variablePath = node.variables[property];

    if (variablePath == null) return null;

    return getVariableValueFromPath<R>(
      context,
      variablePath,
      variablesOverrides: variablesOverrides,
      dataOverrides: dataOverrides,
    );
  }

  /// Substitutes variables & data paths used in given [text] with their values.
  ///
  /// This is useful for [BaseNode.multipleVariables] where the actual value
  /// is a string that is stored in a node property and contains variables
  /// and data paths that need to be evaluated by substitution.
  ///
  /// Retrieve [text] value using [getPropertyValue] to make sure that you have
  /// the correct value from the correct source before substituting variables.
  ///
  /// If [variablesOverrides] is provided, it will be used to instead of the
  /// variables retrieved from [CodelesslyContext].
  ///
  /// If [dataOverrides] is provided, it will be used to instead of the
  /// data retrieved from [CodelesslyContext].
  static String substituteVariables(
    BuildContext context,
    String text, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    return text.splitMapJoinRegex(
      variablePathRegex,
      onNonMatch: (text) => text,
      onMatch: (match) {
        final path = match.group(0)!;
        final value = getVariableValueFromPath<String>(
          context,
          path,
          variablesOverrides: variablesOverrides,
          dataOverrides: dataOverrides,
        );

        return value ?? path;
      },
    );
  }

  /// Retrieves the value of a variable [path]. This also supports predefined
  /// variables such as data, index, and item.
  ///
  /// If [path] is not wrapped with variable syntax(${}), it will be wrapped
  /// automatically.
  ///
  /// Generic type [R] is the expected return type of the variable value and
  /// it must be specified.
  ///
  /// If [variablesOverrides] is provided, it will be used to instead of the
  /// variables retrieved from [CodelesslyContext].
  ///
  /// If [dataOverrides] is provided, it will be used to instead of the
  /// data retrieved from [CodelesslyContext].
  static R? getVariableValueFromPath<R>(
    BuildContext context,
    String path, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    if (path.isEmpty) return null;

    final match = VariableMatch.parse(path.wrapWithVariableSyntax());

    if (match == null) return null;

    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    if (match.isPredefinedVariable) {
      return getPredefinedVariableValue<R>(
        context,
        match.name,
        match.fullPath,
        dataOverrides: dataOverrides,
      );
    }

    final VariableData? variable =
        variablesOverrides?.findByNameOrNull(match.name) ??
            codelesslyContext.findVariableByName(match.name)?.value;

    if (variable == null) return null;

    if (match.hasPathOrAccessor) {
      if (variable.type == VariableType.map) {
        final dynamic value = substituteJsonPath(match.fullPath,
            {match.name: variable.typedValue<Map>(defaultValue: {})});

        return value as R?;
      } else if (variable.type == VariableType.list) {
        final dynamic value = substituteJsonPath(match.fullPath,
            {match.name: variable.typedValue<List>(defaultValue: [])});

        return value as R?;
      }
    }

    return variable.value.typedValue<R>();
  }

  /// Retrieves the value of a predefined variable [name] using given [path].
  /// Predefined variables are data, index, and item.
  ///
  /// [BuildContext] is required to retrieve the data from [CodelesslyContext]
  /// and [IndexedItemProvider].
  ///
  /// If [path] is not wrapped with variable syntax(${}), it will be wrapped
  /// automatically.
  ///
  /// Generic type [R] is the expected return type of the variable value and
  /// it must be specified.
  ///
  /// If [dataOverrides] is provided, it will be used to instead of the
  /// data retrieved from [CodelesslyContext].
  static R? getPredefinedVariableValue<R>(
    BuildContext context,
    String name,
    String path, {
    Map<String, dynamic>? dataOverrides,
  }) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    if (name == 'data') {
      // substitute path with data.
      final dynamic value = substituteJsonPath(path.wrapWithVariableSyntax(),
          {'data': dataOverrides ?? codelesslyContext.data});

      return value as R?;
    }

    if (name == 'index') {
      // substitute path with screen.
      final index = IndexedItemProvider.of(context)?.index;
      if (index == null) return null;

      return '$index'.typedValue<R>();
    }

    if (name == 'item') {
      // substitute path with screen.
      final item = IndexedItemProvider.of(context)?.item;
      if (item == null) return null;

      final dynamic value =
          substituteJsonPath(path.wrapWithVariableSyntax(), {'item': item});

      return value as R?;
    }

    return null;
  }

  /// Retrieves the value of a node [property] from node values by evaluating
  /// the node values if it exists.
  static R? getPropertyValueFromNodeValues<R>(
      BuildContext context, BaseNode node, String property) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    final List<ValueModel>? nodeValues =
        codelesslyContext.nodeValues[node.id]?.value;

    if (nodeValues == null) return null;

    final model =
        nodeValues.firstWhereOrNull((element) => element.name == property);

    if (model == null) return null;

    return model.value as R?;
  }
}
