import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../data/local_storage.dart';

/// Represents what to do when a variable path evaluates to null when
/// substituting variables in a text.
enum NullSubstitutionMode {
  /// If a variable path evaluates to null, it will be substituted with an empty
  /// string.
  emptyString,

  /// If a variable path evaluates to null, it won't be substituted at all.
  noChange,

  /// If a variable path evaluates to null, it will be substituted with
  /// 'null' string.
  nullValue,
}

/// A delegate class that helps retrieving the value of a node property from
/// multiple sources such as conditions, variables, data, and node values.
class PropertyValueDelegate {
  const PropertyValueDelegate._();

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
  static R? getPropertyValue<R extends Object>(
    BuildContext context,
    BaseNode node,
    String property, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    variablesOverrides =
        variablesOverrides?.isEmpty == true ? null : variablesOverrides;

    final R? conditionValue = getPropertyValueFromCondition<R>(
      context,
      node,
      property,
      variablesOverrides: variablesOverrides,
      dataOverrides: dataOverrides,
    );

    final R? variableValue = getPropertyValueFromVariable<R>(
      context,
      node,
      property,
      variablesOverrides: variablesOverrides,
      dataOverrides: dataOverrides,
    );

    final R? nodeValue = getPropertyValueFromNodeValues<R>(
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
  static R? getPropertyValueFromCondition<R extends Object>(
    BuildContext context,
    BaseNode node,
    String property, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    variablesOverrides =
        variablesOverrides?.isEmpty == true ? null : variablesOverrides;

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

    // if (condition != null) {
    //   print('----------------------------------------------------------------');
    //   print('CONDITION on ${node.name}-> ${property}:');
    //   print('----------------------------------------------------------------');
    //   condition.prettyPrint();
    //   print('----------------------------------------------------------------');
    // }
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
  static R? getPropertyValueFromVariable<R extends Object>(
    BuildContext context,
    BaseNode node,
    String property, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    variablesOverrides =
        variablesOverrides?.isEmpty == true ? null : variablesOverrides;

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
  ///
  /// [nullSubstitutionMode] determines what to do when a variable path
  /// evaluates to null. See [NullSubstitutionMode] for more details.
  static String substituteVariables(
    BuildContext context,
    String text, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
  }) {
    variablesOverrides =
        variablesOverrides?.isEmpty == true ? null : variablesOverrides;

    return text.splitMapJoinRegex(
      variablePathRegex,
      onNonMatch: (text) => text,
      onMatch: (match) {
        final path = match.namedGroup('value')!;
        final value = getVariableValueFromPath<String>(
          context,
          path,
          variablesOverrides: variablesOverrides,
          dataOverrides: dataOverrides,
        );

        if (value != null) return value;

        return switch (nullSubstitutionMode) {
          NullSubstitutionMode.emptyString => '',
          NullSubstitutionMode.nullValue => 'null',
          NullSubstitutionMode.noChange => match[0]!,
        };
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
  static R? getVariableValueFromPath<R extends Object>(
    BuildContext context,
    String path, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
    LocalStorage? storage,
  }) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    final Iterable<VariableData> variables = {
      ...codelesslyContext.variableNamesMap().values,
      ...variablesOverrides ?? {}
    };
    final Map<String, dynamic> data = {
      ...codelesslyContext.data,
      ...dataOverrides ?? {}
    };

    final Object? value = retrieveVariableValue(
      path,
      variables,
      data,
      IndexedItemProvider.of(context),
      storage,
    );

    return value?.typedValue<R>();
  }

  @internal
  static Object? retrieveVariableValue(
    String path,
    Iterable<VariableData> variables,
    Map<String, dynamic> data,
    IndexedItemProvider? itemProvider,
    LocalStorage? storage,
  ) {
    if (path.isEmpty) return null;
    final match = VariableMatch.parse(path.wrapWithVariableSyntax());
    if (match == null) return null;

    if (match.isPredefinedVariable) {
      final Object? value =
          retrievePredefinedVariableValue(match, data, itemProvider, storage);
      return value;
    }

    final VariableData? variable = variables.findByNameOrNull(match.name);
    if (variable == null) return null;
    if (match.hasAccessor) {
      if (variable.type.isText) {
        final characters = variable.getValue().toString().characters.toList();
        final Object? value =
            substituteJsonPath(match.fullPath, {match.name: characters});
        return value;
      }
      if (!variable.type.isList) return null;
      final Object? value =
          substituteJsonPath(match.fullPath, {match.name: variable.getValue()});

      return value;
    }

    if (!match.hasPath) return variable.getValue();

    final variableProps =
        getVariableProperties(variable.getValue(), variable.type);
    final Object? variableValue = variable.getValue();
    final Map<String, dynamic> values = {
      ...variableProps,
      if (variable.type.isMap && variableValue is Map<String, dynamic>)
        ...variableValue,
    };
    final Object? value =
        substituteJsonPath(match.fullPath, {match.name: values});

    return value;
  }

  @internal
  static Object? retrievePredefinedVariableValue(
    VariableMatch match,
    Map<String, dynamic> data,
    IndexedItemProvider? itemProvider,
    LocalStorage? storage,
  ) {
    final Object? variableValue = switch (match.name) {
      'data' => data,
      'item' => itemProvider?.item,
      'index' => itemProvider?.index,
      'storage' => storage?.getAll(),
      _ => null,
    };

    // substitute path with screen.
    if (variableValue == null) return null;
    final VariableType variableType =
        VariableType.fromObjectType(variableValue);

    if (match.hasAccessor) {
      if (variableType.isText) {
        final characters = variableValue.toString().characters.toList();
        final Object? value =
            substituteJsonPath(match.fullPath, {match.name: characters});
        return value;
      }
      if (!variableType.isList) return null;
      final Object? value =
          substituteJsonPath(match.text, {match.name: variableValue});
      return value;
    }

    if (!match.hasPath) return variableValue;

    final variableProps = getVariableProperties(variableValue, variableType);
    final Map<String, dynamic> values = {
      ...variableProps,
      if (variableType.isMap && variableValue is Map<String, dynamic>)
        ...variableValue,
    };
    final Object? value = substituteJsonPath(match.text, {match.name: values});
    return value;
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
  static R? getPredefinedVariableValue<R extends Object>(
    BuildContext context,
    String path, {
    Map<String, dynamic>? dataOverrides,
    LocalStorage? storage,
  }) {
    final match = VariableMatch.parse(path);
    if (match == null) return null;

    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    final Map<String, dynamic> data = {
      ...codelesslyContext.data,
      ...dataOverrides ?? {}
    };

    final Object? value = retrievePredefinedVariableValue(
      match,
      data,
      IndexedItemProvider.of(context),
      storage,
    );

    return value?.typedValue<R>();
  }

  /// Retrieves the value of a node [property] from node values by evaluating
  /// the node values if it exists.
  static R? getPropertyValueFromNodeValues<R extends Object>(
      BuildContext context, BaseNode node, String property) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    final List<ValueModel>? nodeValues =
        codelesslyContext.nodeValues[node.id]?.value;

    if (nodeValues == null) return null;

    final model =
        nodeValues.firstWhereOrNull((element) => element.name == property);

    if (model == null) return null;

    return model.value.typedValue<R>();
  }

  /// Substitutes json paths found in [text] with values from [data].
  /// supported text format:
  ///   - ${data.name}: will be replaced with data['name'].
  ///   - data.name: will be replaced with data['name'].
  ///
  static Object? substituteJsonPath(String text, Map<String, dynamic> data) {
    // If the text represents a JSON path, get the relevant value from [data] map.
    if (data.isEmpty) return null;

    if (!variableSyntaxIdentifierRegex.hasMatch(text)) {
      // text is not wrapped with ${}. Wrap it since a validation is done later.
      text = '\${$text}';
    }

    if (!text.isValidVariablePath) return null;

    // Remove $-sign and curly brackets.
    String path = variableSyntaxIdentifierRegex.hasMatch(text)
        ? text.substring(2, text.length - 1)
        : text;
    // Add $-sign and dot so that the expression matches JSON path standards.
    path = '\$.$path';
    // [text] represent a JSON path here. Decode it.
    final JsonPath jsonPath = JsonPath(path);
    // Retrieve values from JSON that match the path.
    final values = jsonPath.readValues(data);
    if (values.isEmpty) return null;
    // Return the first value.
    return values.first;
  }

  /// Creates a map of variable properties for given [value] and [type].
  /// This is experimental and is subject to change. It is used for development
  /// purposes only.
  @internal
  @experimental
  static Map<String, dynamic> getVariableProperties(
      Object? value, VariableType type) {
    return switch (value) {
      String() => {
          'length': value.length,
          'isEmpty': value.isEmpty,
          'isNotEmpty': value.isNotEmpty,
          'isBlank': value.trim().isEmpty,
          'upcase': value.toUpperCase(),
          'downcase': value.toLowerCase(),
          'capitalize': value.capitalized,
        },
      int() => {
          'isEven': value.isEven,
          'isOdd': value.isOdd,
          'isFinite': value.isFinite,
          'isInfinite': value.isInfinite,
          'isNegative': value.isNegative,
          'isPositive': !value.isNegative,
        },
      double() => {
          'isFinite': value.isFinite,
          'isInfinite': value.isInfinite,
          'isNegative': value.isNegative,
          'isPositive': !value.isNegative,
          'isNaN': value.isNaN,
          'whole': value.toInt(),
          'floor': value.floor(),
          'ceil': value.ceil(),
        },
      bool() => {
          'toggled': !value,
        },
      Map() => {
          'length': value.length,
          'isEmpty': value.isEmpty,
          'isNotEmpty': value.isNotEmpty,
          'keys': value.keys.toList(),
          'values': value.values.toList(),
        },
      List() => {
          'length': value.length,
          'isEmpty': value.isEmpty,
          'isNotEmpty': value.isNotEmpty
        },
      ColorRGBA() => {
          'red': value.r,
          'green': value.g,
          'blue': value.b,
          'alpha': value.a,
          'opacity': value.a / 255,
        },
      ColorRGB() => {
          'red': value.r,
          'green': value.g,
          'blue': value.b,
          'alpha': 255,
          'opacity': 1,
        },
      _ when type.isText => {
          'isBlank': true,
          'isEmpty': true,
          'isNotEmpty': false,
        },
      _ => {},
    };
  }
}
