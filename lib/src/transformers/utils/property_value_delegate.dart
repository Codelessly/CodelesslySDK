import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';
import 'package:meta/meta.dart';
import 'package:rfc_6901/rfc_6901.dart';

import '../../../codelessly_sdk.dart';

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
  /// [scopedValues] is required to retrieve the data from various sources.
  static R? getPropertyValue<R extends Object>(
    BaseNode node,
    String property, {
    required ScopedValues scopedValues,
  }) {
    final R? conditionValue = getPropertyValueFromCondition<R>(
      node,
      property,
      scopedValues: scopedValues,
    );

    final R? variableValue = getPropertyValueFromVariable<R>(
      node,
      property,
      scopedValues: scopedValues,
    );

    // If a variable/json-path is not found then variableValue will be null.
    // In that case, a node value might exist but we may not wanna use it
    // in this situation as we may wanna fall back to default value when a
    // variable is not found. This checks takes care of that, making sure that
    // node value is only used when a variable is not found.
    //
    // One serious example of this is, a node inside a list view. Since list
    // view duplicates the node for each item, the node value will be duplicated
    // as well. If we use node value as a fallback, it will use the value of
    // the first item for all items. So if a checkbox is checked in the first
    // item, it will be checked in all items. This specifically prevents that.
    final R? retrievedNodeValue = node.variables[property] == null
        ? getPropertyValueFromNodeValues<R>(
            node,
            property,
            scopedValues: scopedValues,
          )
        : null;

    return conditionValue ?? variableValue ?? retrievedNodeValue;
  }

  /// Retrieves the value of a node [property] from a condition by evaluating
  /// the condition if it exists.
  ///
  /// Generic type [R] is the expected return type of the variable value and
  /// it must be specified.
  ///
  /// [scopedValues] is required to retrieve the data from various sources.
  static R? getPropertyValueFromCondition<R extends Object>(
    BaseNode node,
    String property, {
    required ScopedValues scopedValues,
  }) {
    final CodelesslyContext? codelesslyContext = scopedValues.codelesslyContext;

    if (codelesslyContext == null) return null;

    final BaseCondition? condition =
        codelesslyContext.conditions.findByNodeProperty(node.id, property);

    // if (condition != null) {
    //   print('----------------------------------------------------------------');
    //   print('CONDITION on ${node.name}-> ${property}:');
    //   print('----------------------------------------------------------------');
    //   condition.prettyPrint();
    //   print('----------------------------------------------------------------');
    // }
    return condition?.evaluate<R>(scopedValues);
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
  /// [scopedValues] is required to retrieve the data from various sources.
  static R? getPropertyValueFromVariable<R extends Object>(
    BaseNode node,
    String property, {
    required ScopedValues scopedValues,
  }) {
    final String? variablePath = node.variables[property];

    if (variablePath == null) return null;

    return getVariableValueFromPath<R>(
      variablePath,
      scopedValues: scopedValues,
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
  /// [nullSubstitutionMode] determines what to do when a variable path
  /// evaluates to null. See [NullSubstitutionMode] for more details.
  ///
  /// [scopedValues] is required to retrieve the data from various sources.
  static String substituteVariables(
    String text, {
    required ScopedValues scopedValues,
    required NullSubstitutionMode nullSubstitutionMode,
  }) {
    return text.splitMapJoinRegex(
      variablePathRegex,
      onNonMatch: (text) => text,
      onMatch: (match) {
        final path = match.namedGroup('value')!;
        final value = getVariableValueFromPath<String>(
          path,
          scopedValues: scopedValues,
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
  /// [scopedValues] is required to retrieve the data from various sources.
  static R? getVariableValueFromPath<R extends Object>(
    String path, {
    required ScopedValues scopedValues,
  }) {
    final Object? value =
        retrieveVariableValue(path, scopedValues: scopedValues);

    return value?.typedValue<R>();
  }

  @internal
  static Object? retrieveVariableValue(
    String path, {
    required ScopedValues scopedValues,
  }) {
    if (path.isEmpty) return null;
    final match = VariableMatch.parse(path.wrapWithVariableSyntax());
    if (match == null) return null;

    if (match.isPredefinedVariable) {
      final Object? value =
          retrievePredefinedVariableValue(match, scopedValues);
      return value;
    }

    final VariableData? variable = scopedValues.variables[match.name];
    if (variable == null) return null;
    if (match.hasAccessor) {
      if (variable.type.isText) {
        final characters = variable.getValue().toString().characters.toList();
        final (Object? value, _) =
            substituteJsonPath(match.fullPath, {match.name: characters});
        return value;
      }
      if (!variable.type.isList) return null;
      final (Object? value, _) =
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
    final (Object? value, _) =
        substituteJsonPath(match.fullPath, {match.name: values});

    return value;
  }

  @internal
  static Object? retrievePredefinedVariableValue(
    VariableMatch match,
    ScopedValues scopedValues,
    Object? nodeValue,
  ) {
    final Object? variableValue = switch (match.name) {
      'data' => scopedValues.data,
      'item' => scopedValues.indexedItem?.item,
      'index' => scopedValues.indexedItem?.index,
      'value' => nodeValue,
      'storage' => scopedValues.localStorage?.getAll(),
      'route' => scopedValues.routeParams,
      _ => null,
    };

    // substitute path with screen.
    if (variableValue == null) return null;
    final VariableType variableType =
        VariableType.fromObjectType(variableValue);

    if (match.hasAccessor) {
      if (variableType.isText) {
        final characters = variableValue.toString().characters.toList();
        final (Object? value, _) =
            substituteJsonPath(match.fullPath, {match.name: characters});
        return value;
      }
      if (!variableType.isList) return null;
      final (Object? value, _) =
          substituteJsonPath(match.text, {match.name: variableValue});
      return value;
    }

    if (!match.hasPath) return variableValue;

    final variableProps = getVariableProperties(variableValue, variableType);
    final Map<String, dynamic> values = {
      ...variableProps,
      if (variableType.isMap && variableValue is Map)
        ...Map.from(variableValue),
    };
    final (Object? value, _) =
        substituteJsonPath(match.text, {match.name: values});
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
  static R? getPredefinedVariableValue<R extends Object>(
    String path, {
    required ScopedValues scopedValues,
    required Object? nodeValue,
  }) {
    final match = VariableMatch.parse(path);
    if (match == null) return null;

    final Object? value = retrievePredefinedVariableValue(match, scopedValues);

    return value?.typedValue<R>();
  }

  /// Retrieves the value of a node [property] from node values by evaluating
  /// the node values if it exists.
  static R? getPropertyValueFromNodeValues<R extends Object>(
    BaseNode node,
    String property, {
    required ScopedValues scopedValues,
  }) {
    final List<ValueModel>? nodeValues =
        scopedValues.nodeValues[node.id]?.value;

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
  static (Object?, JsonPointer?) substituteJsonPath(
      String text, Map<String, dynamic> data) {
    // If the text represents a JSON path, get the relevant value from [data] map.
    if (data.isEmpty) return (null, null);

    if (!variableSyntaxIdentifierRegex.hasMatch(text)) {
      // text is not wrapped with ${}. Wrap it since a validation is done later.
      text = '\${$text}';
    }

    if (!text.isValidVariablePath) return (null, null);

    // Remove $-sign and curly brackets.
    String path = variableSyntaxIdentifierRegex.hasMatch(text)
        ? text.substring(2, text.length - 1)
        : text;
    // Add $-sign and dot so that the expression matches JSON path standards.
    path = '\$.$path';
    // [text] represent a JSON path here. Decode it.
    final JsonPath jsonPath = JsonPath(path);
    // Retrieve values from JSON that match the path.
    final values = jsonPath.read(data);
    if (values.isEmpty) return (null, null);
    // Return the first value.
    return (values.first.value, values.first.pointer);
  }

  static void putValueInJsonPath(
    String path,
    Object? value,
    Map<String, dynamic> data,
  ) {
    final tokens = path.split('.');
    final leafKey = tokens.removeLast();
    Object? traversedValue;
    for (final token in tokens) {
      final match = VariableMatch.parse(token.wrapWithVariableSyntax());
      if (match != null && match.hasAccessor) {
        if (traversedValue is List) {
          (traversedValue, _) =
              substituteJsonPath(token, {match.name: traversedValue});
        } else {
          traversedValue = [];
        }
      } else if (traversedValue is Map) {
        traversedValue = traversedValue[token];
      } else {
        traversedValue = {};
      }
    }
    final match = VariableMatch.parse(leafKey.wrapWithVariableSyntax());

    traversedValue ??= match != null
        ? data[match.name] ?? (match.hasAccessor ? [] : {})
        : data[path];

    if (match != null && match.hasAccessor) {
      if (traversedValue is List) {
        final index =
            match.accessor!.replaceAll('[', '').replaceAll(']', '').toInt();
        if (index != null) {
          traversedValue[index] =
              substituteJsonPath(leafKey, {match.name: value}).$1;
        }
      }
    } else if (traversedValue is Map) {
      traversedValue[leafKey] = value;
    }
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
