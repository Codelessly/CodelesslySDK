import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';
import 'package:meta/meta.dart';
import 'package:rfc_6901/rfc_6901.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/action_chain.dart';

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

    final BaseCondition? condition = codelesslyContext.conditions
        .findByNodeProperty(node.id, property);

    // if (condition != null) {
    //   print('----------------------------------------------------------------');
    //   print('CONDITION on ${node.name}-> $property:');
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
  /// Substitutes variables in a JSON [template] value by value, so the
  /// result stays valid JSON whatever the values contain: a string that is
  /// exactly one `${path}` becomes the path's value as is (a list, a number,
  /// null, ...), and other strings get their paths substituted as text.
  ///
  /// Returns null when [template] isn't JSON before substitution, e.g. when a
  /// path stands unquoted for a number.
  static Map<String, dynamic>? substituteVariablesInJson(
    String template, {
    required ScopedValues scopedValues,
  }) {
    final Object? parsed = tryJsonDecode(template.trim());
    if (parsed is! Map) return null;
    return Map<String, dynamic>.from(
      _substituteJsonValue(parsed, scopedValues) as Map,
    );
  }

  /// Substitutes variables in a decoded JSON [value]: see
  /// [substituteVariablesInJson].
  static Object? substituteJsonValue(
    Object? value,
    ScopedValues scopedValues,
  ) => _substituteJsonValue(value, scopedValues);

  static Object? _substituteJsonValue(
    Object? value,
    ScopedValues scopedValues,
  ) {
    return switch (value) {
      String() when FormulaEvaluator.exactExpression(value) != null =>
        evaluateFormula(
          FormulaEvaluator.exactExpression(value)!,
          scopedValues: scopedValues,
        ),
      String() =>
        RegExp(r'^\$\{[^{}]+\}$').hasMatch(value.trim())
            ? _retrieveVariableValue(value.trim(), scopedValues: scopedValues)
            : substituteVariables(
                value,
                scopedValues: scopedValues,
                nullSubstitutionMode: NullSubstitutionMode.emptyString,
              ),
      List() => [
        for (final item in value) _substituteJsonValue(item, scopedValues),
      ],
      Map() => {
        for (final MapEntry(:key, :value) in value.entries)
          substituteVariables(
            key.toString(),
            scopedValues: scopedValues,
            nullSubstitutionMode: NullSubstitutionMode.emptyString,
          ): _substituteJsonValue(
            value,
            scopedValues,
          ),
      },
      _ => value,
    };
  }

  static String substituteVariables(
    String text, {
    required ScopedValues scopedValues,
    required NullSubstitutionMode nullSubstitutionMode,
  }) {
    if (text.trim().isEmpty) return text;
    // Formulas first, so `${= ...}` isn't read as a path.
    text = FormulaEvaluator.substitute(
      text,
      (path) =>
          getVariableValueFromPath<Object>(path, scopedValues: scopedValues),
      nullText: switch (nullSubstitutionMode) {
        NullSubstitutionMode.nullValue => 'null',
        _ => '',
      },
    );
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

  /// Evaluates a formula [expression] (the part after `${=`), reading its
  /// variable paths from [scopedValues]. See [FormulaEvaluator].
  /// Whether [variable] is computed: its value is a `${= ...}` formula,
  /// worked out from other variables whenever it is read.
  static bool isComputedVariable(VariableData variable) =>
      FormulaEvaluator.exactExpression(variable.value) != null;

  static int _computedDepth = 0;

  /// The value of [variable]: its formula's result for a computed variable,
  /// else its stored value. Computed variables can read each other; a cycle
  /// gives null instead of recursing forever.
  static Object? variableValueOf(
    VariableData variable,
    ScopedValues scopedValues,
  ) {
    final String? expression = FormulaEvaluator.exactExpression(variable.value);
    if (expression == null) return variable.getValue();
    if (_computedDepth >= 16) return null;
    _computedDepth++;
    try {
      return evaluateFormula(expression, scopedValues: scopedValues);
    } finally {
      _computedDepth--;
    }
  }

  static Object? evaluateFormula(
    String expression, {
    required ScopedValues scopedValues,
  }) => FormulaEvaluator.evaluate(
    expression,
    (path) =>
        getVariableValueFromPath<Object>(path, scopedValues: scopedValues),
  );

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
    final String? expression = FormulaEvaluator.exactExpression(path);
    if (expression != null) {
      final Object? value = evaluateFormula(
        expression,
        scopedValues: scopedValues,
      );
      if (R == String) return FormulaEvaluator.stringify(value) as R?;
      return value?.typedValue<R>();
    }
    final match = VariableMatch.parse(path.wrapWithVariableSyntax());
    if (match == null) return null;

    final List<String> segments = match.fullPath.split(r'.');
    // remove variable name
    final initial = segments.removeAt(0);

    Object? value = _retrieveVariableValue(initial, scopedValues: scopedValues);

    if (segments.isEmpty) return value?.typedValue<R>();
    if (value == null) return null;

    final variable = match.isPredefinedVariable
        ? predefinedVariables.findByNameOrNull(match.name)
        : scopedValues.variables.values.findByNameOrNull(match.name);

    if (variable == null) return null;

    // Predefined variables like item hold any type, so read accessors for
    // the value they hold (an item can be a string, a map, ...).
    VariableType accessorType = match.hasAccessor || match.isPredefinedVariable
        ? VariableType.fromObjectType(value)
        : variable.type;
    List<Accessor> accessors = variable.name.startsWith('api')
        ? getApiResponseAccessorsForType(VariableType.map)
        : getAccessorsForType(accessorType);

    while (segments.isNotEmpty) {
      if (value == null) return null;
      String accessor = segments.removeAt(0);

      // A map's own key wins over a built-in accessor of the same name, so
      // a rig's `length` field isn't read as the number of its fields.
      final Accessor? matchedAccessor =
          value is Map && value.containsKey(accessor)
          ? null
          : accessors.firstWhereOrNull((element) => element.name == accessor);

      if (matchedAccessor == null) {
        // If the accessor is not found, it means that the path is invalid. But
        // it could be a json path. So we will try to substitute it with the
        // value and see if it is a valid json path.
        if (value is Map) {
          (value, _) = substituteJsonPath(accessor, {...value});
        } else {
          return null;
        }
      } else {
        value = matchedAccessor.getValue(value);
      }

      if (value == null) return null;
      accessorType =
          matchedAccessor?.type ?? VariableType.fromObjectType(value);
      accessors = getAccessorsForType(accessorType);
    }

    return value?.typedValue<R>();
  }

  static Object? _retrieveVariableValue(
    String path, {
    required ScopedValues scopedValues,
  }) {
    if (path.isEmpty) return null;
    final match = VariableMatch.parse(path.wrapWithVariableSyntax());
    if (match == null) return null;

    if (match.isPredefinedVariable) {
      final Object? value = retrievePredefinedVariableValue(
        match,
        scopedValues,
      );
      return value;
    }

    final VariableData? variable = scopedValues.variables[match.name];
    if (variable == null) return null;
    final bool computed = isComputedVariable(variable);
    final Object? variableValue = variableValueOf(variable, scopedValues);
    // A computed variable's type is whatever its formula returns.
    final VariableType type = computed && variableValue != null
        ? VariableType.fromObjectType(variableValue)
        : variable.type;
    if (match.hasAccessor) {
      if (type.isText) {
        final characters = variableValue.toString().characters.toList();
        final (Object? value, _) = substituteJsonPath(match.fullPath, {
          match.name: characters,
        });
        return value;
      }
      if (!type.isList) return null;
      final (Object? value, _) = substituteJsonPath(match.fullPath, {
        match.name: variableValue,
      });

      return value;
    }

    if (!match.hasPath) return variableValue;

    final variableProps = getVariableProperties(variableValue, type);
    final Map<String, dynamic> values = {
      ...variableProps,
      if (variableValue is Map) ...Map<String, dynamic>.from(variableValue),
    };
    final (Object? value, _) = substituteJsonPath(match.fullPath, {
      match.name: values,
    });

    return value;
  }

  @internal
  static Object? retrievePredefinedVariableValue(
    VariableMatch match,
    ScopedValues scopedValues,
  ) {
    final Object? variableValue = switch (match.name) {
      'data' => scopedValues.data,
      'item' => scopedValues.indexedItem?.item,
      'index' => scopedValues.indexedItem?.index,
      'value' => scopedValues.nodeState,
      'storage' => scopedValues.localStorage?.getAll(),
      'route' => scopedValues.routeParams,
      'auth' => scopedValues.appUser,
      'result' => ActionChain.current?.result,
      'screen' => scopedValues.screenSize?.let(screenVariableValue),
      'parent' => scopedValues.parentSize,
      _ => null,
    };

    if (variableValue == null) return null;
    final VariableType variableType = VariableType.fromObjectType(
      variableValue,
    );

    if (match.hasAccessor) {
      if (variableType.isText) {
        final characters = variableValue.toString().characters.toList();
        final (Object? value, _) = substituteJsonPath(match.fullPath, {
          match.name: characters,
        });
        return value;
      }
      if (!variableType.isList) return null;
      final (Object? value, _) = substituteJsonPath(match.text, {
        match.name: variableValue,
      });
      return value;
    }

    if (!match.hasPath) return variableValue;

    final variableProps = getVariableProperties(variableValue, variableType);
    final Map<String, dynamic> values = {
      ...variableProps,
      if (variableType.isMap && variableValue is Map)
        ...Map.from(variableValue),
    };
    final (Object? value, _) = substituteJsonPath(match.text, {
      match.name: values,
    });
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

    final model = nodeValues.firstWhereOrNull(
      (element) => element.name == property,
    );

    if (model == null) return null;

    return model.value.typedValue<R>();
  }

  /// Substitutes json paths found in [text] with values from [data].
  /// supported text format:
  ///   - ${data.name}: will be replaced with data['name'].
  ///   - data.name: will be replaced with data['name'].
  ///
  static (Object?, JsonPointer?) substituteJsonPath(
    String text,
    Map<String, dynamic> data,
  ) {
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
    // JSON path reads `.length` as the size of the value, which hides a field
    // named length (a rig's length); the bracket form reads the field, and a
    // value without one falls back to the computed length below.
    path = '\$.$path'.replaceAllMapped(
      RegExp(r'\.length(?=$|[.\[])'),
      (_) => "['length']",
    );
    // [text] represent a JSON path here. Decode it.
    final JsonPath jsonPath = JsonPath(path);
    // Retrieve values from JSON that match the path.
    final values = jsonPath.read(data);
    if (values.isEmpty) return _substituteComputedProperty(text, data);
    // Return the first value.
    return (values.first.value, values.first.pointer);
  }

  /// Resolves a path that ends in a computed property of a nested value, like
  /// `${item.memberIds.length}` or `${item.createdAt.timeAgo}`, which plain
  /// JSON paths can't read: the rest of the path is resolved first, then the
  /// property is read from [getVariableProperties] of that value.
  static (Object?, JsonPointer?) _substituteComputedProperty(
    String text,
    Map<String, dynamic> data,
  ) {
    final String path = text.substring(2, text.length - 1);
    final int dot = path.lastIndexOf('.');
    if (dot <= 0) return (null, null);
    final String property = path.substring(dot + 1);
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(property)) return (null, null);
    final (Object? parent, _) = substituteJsonPath(
      path.substring(0, dot),
      data,
    );
    if (parent == null) return (null, null);
    final Map<String, dynamic> properties = getVariableProperties(
      parent,
      VariableType.fromObjectType(parent),
    );
    if (!properties.containsKey(property)) return (null, null);
    return (properties[property], null);
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
          (traversedValue, _) = substituteJsonPath(token, {
            match.name: traversedValue,
          });
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
        final index = match.accessor!
            .replaceAll('[', '')
            .replaceAll(']', '')
            .toInt();
        if (index != null) {
          traversedValue[index] = substituteJsonPath(leafKey, {
            match.name: value,
          }).$1;
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
    Object? value,
    VariableType type,
  ) {
    return switch (value) {
      String() => {
        'length': value.length,
        'isEmpty': value.isEmpty,
        'isNotEmpty': value.isNotEmpty,
        'isBlank': value.trim().isEmpty,
        'upcase': value.toUpperCase(),
        'downcase': value.toLowerCase(),
        'capitalize': value.capitalized,
        'initial': value.trim().isEmpty
            ? ''
            : value.trim().characters.first.toUpperCase(),
        if (DateTime.tryParse(value) case final DateTime date) ...{
          'timeAgo': formatTimeAgo(date),
          'date': formatDate(date),
        },
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
      bool() => {'toggled': !value},
      // Cloud documents carry createdAt and updatedAt as dates.
      DateTime() => {
        'timeAgo': formatTimeAgo(value),
        'date': formatDate(value),
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
        'isNotEmpty': value.isNotEmpty,
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

/// Defines accessors for a variable based on its type.
List<Accessor> getAccessorsForType(VariableType type) {
  switch (type) {
    case VariableType.image:
    case VariableType.text:
    case VariableType.choice:
      return [
        Accessor(
          name: 'length',
          type: VariableType.integer,
          getValue: (value) => value?.toString().length,
        ),
        Accessor(
          name: 'upcase',
          type: VariableType.text,
          getValue: (value) => value?.toString().toUpperCase(),
        ),
        Accessor(
          name: 'downcase',
          type: VariableType.text,
          getValue: (value) => value?.toString().toLowerCase(),
        ),
        Accessor(
          name: 'capitalize',
          type: VariableType.text,
          getValue: (value) => value?.toString().capitalized,
        ),
        Accessor(
          name: 'isEmpty',
          type: VariableType.boolean,
          getValue: (value) => value?.toString().isEmpty,
        ),
        Accessor(
          name: 'isNotEmpty',
          type: VariableType.boolean,
          getValue: (value) => value?.toString().isNotEmpty,
        ),
        Accessor(
          name: 'isBlank',
          type: VariableType.boolean,
          getValue: (value) => value?.toString().trim().isEmpty,
        ),
        Accessor(
          name: 'initial',
          type: VariableType.text,
          getValue: (value) {
            final String text = value?.toString().trim() ?? '';
            return text.isEmpty ? '' : text.characters.first.toUpperCase();
          },
        ),
        Accessor(
          name: 'timeAgo',
          type: VariableType.text,
          getValue: (value) => switch (DateTime.tryParse('${value ?? ''}')) {
            final DateTime date => formatTimeAgo(date),
            null => null,
          },
        ),
        Accessor(
          name: 'date',
          type: VariableType.text,
          getValue: (value) => switch (DateTime.tryParse('${value ?? ''}')) {
            final DateTime date => formatDate(date),
            null => null,
          },
        ),
      ];
    case VariableType.integer:
      return [
        Accessor(
          name: 'isEven',
          type: VariableType.boolean,
          getValue: (value) => value?.toInt()?.isEven,
        ),
        Accessor(
          name: 'isOdd',
          type: VariableType.boolean,
          getValue: (value) => value?.toInt()?.isOdd,
        ),
        Accessor(
          name: 'isFinite',
          type: VariableType.boolean,
          getValue: (value) => value?.toInt()?.isFinite,
        ),
        Accessor(
          name: 'isInfinite',
          type: VariableType.boolean,
          getValue: (value) => value?.toInt()?.isInfinite,
        ),
        Accessor(
          name: 'isNegative',
          type: VariableType.boolean,
          getValue: (value) => value?.toInt()?.isNegative,
        ),
        Accessor(
          name: 'isPositive',
          type: VariableType.boolean,
          getValue: (value) {
            final int? parsedValue = value?.toInt();
            if (parsedValue == null) return null;
            return !parsedValue.isNegative;
          },
        ),
      ];
    case VariableType.decimal:
      return [
        Accessor(
          name: 'whole',
          type: VariableType.integer,
          getValue: (value) => value?.toDouble()?.toInt(),
        ),
        Accessor(
          name: 'floor',
          type: VariableType.integer,
          getValue: (value) => value?.toDouble()?.floor(),
        ),
        Accessor(
          name: 'ceil',
          type: VariableType.integer,
          getValue: (value) => value?.toDouble()?.ceil(),
        ),
        Accessor(
          name: 'isFinite',
          type: VariableType.boolean,
          getValue: (value) => value?.toDouble()?.isFinite,
        ),
        Accessor(
          name: 'isInfinite',
          type: VariableType.boolean,
          getValue: (value) => value?.toDouble()?.isInfinite,
        ),
        Accessor(
          name: 'isNegative',
          type: VariableType.boolean,
          getValue: (value) => value?.toDouble()?.isNegative,
        ),
        Accessor(
          name: 'isPositive',
          type: VariableType.boolean,
          getValue: (value) {
            final newValue = value?.toDouble();
            if (newValue == null) return null;
            return !newValue.isNegative;
          },
        ),
        Accessor(
          name: 'isNaN',
          type: VariableType.boolean,
          getValue: (value) => value?.toDouble()?.isNaN,
        ),
      ];
    case VariableType.boolean:
      return [
        LeafAccessor(
          name: 'toggled',
          type: VariableType.boolean,
          getValue: (value) => !(value?.toBool() ?? false),
        ),
      ];
    case VariableType.map:
      return [
        Accessor(
          name: 'length',
          type: VariableType.integer,
          getValue: (value) => value?.toMap()?.length,
        ),
        Accessor(
          name: 'keys',
          type: VariableType.list,
          getValue: (value) => value?.toMap()?.keys,
        ),
        Accessor(
          name: 'values',
          type: VariableType.list,
          getValue: (value) => value?.toMap()?.values,
        ),
        Accessor(
          name: 'isEmpty',
          type: VariableType.boolean,
          getValue: (value) {
            final newValue = value?.toMap();
            if (newValue == null) return null;
            return newValue.isEmpty;
          },
        ),
        Accessor(
          name: 'isNotEmpty',
          type: VariableType.boolean,
          getValue: (value) {
            final newValue = value?.toMap();
            if (newValue == null) return null;
            return newValue.isNotEmpty;
          },
        ),
      ];
    case VariableType.list:
      return [
        Accessor(
          name: 'length',
          type: VariableType.integer,
          getValue: (value) => value?.toList()?.length,
        ),
        Accessor(
          name: 'isEmpty',
          type: VariableType.boolean,
          getValue: (value) {
            final newValue = value?.toList();
            if (newValue == null) return null;
            return newValue.isEmpty;
          },
        ),
        Accessor(
          name: 'isNotEmpty',
          type: VariableType.boolean,
          getValue: (value) {
            final newValue = value?.toList();
            if (newValue == null) return null;
            return newValue.isNotEmpty;
          },
        ),
      ];
    case VariableType.color:
      return [
        Accessor(
          name: 'red',
          type: VariableType.integer,
          getValue: (value) {
            final newValue = value.toColorRGBA();
            if (newValue == null) return null;
            return (newValue.r * 255).toInt();
          },
        ),
        Accessor(
          name: 'green',
          type: VariableType.integer,
          getValue: (value) {
            final newValue = value.toColorRGBA();
            if (newValue == null) return null;
            return (newValue.g * 255).toInt();
          },
        ),
        Accessor(
          name: 'blue',
          type: VariableType.integer,
          getValue: (value) {
            final newValue = value.toColorRGBA();
            if (newValue == null) return null;
            return (newValue.b * 255).toInt();
          },
        ),
        Accessor(
          name: 'alpha',
          type: VariableType.integer,
          getValue: (value) {
            final newValue = value.toColorRGBA();
            if (newValue == null) return null;
            return (newValue.a * 255).toInt();
          },
        ),
        Accessor(
          name: 'opacity',
          type: VariableType.integer,
          getValue: (value) {
            final newValue = value.toColorRGBA();
            if (newValue == null) return null;
            return (newValue.a).toInt();
          },
        ),
      ];
  }
}

/// Defines accessors for an api variable based on the type of date it holds.
List<Accessor> getApiResponseAccessorsForType(VariableType dataType) => [
  Accessor(
    name: 'url',
    type: VariableType.text,
    getValue: (value) => value.toMap()?['url'],
  ),
  Accessor(
    name: 'status',
    type: VariableType.text,
    getValue: (value) => value.toMap()?['status']?.toString(),
  ),
  Accessor(
    name: 'statusCode',
    type: VariableType.integer,
    getValue: (value) => value.toMap()?['statusCode']?.toInt(),
  ),
  Accessor(
    name: 'isIdle',
    type: VariableType.boolean,
    getValue: (value) => value.toMap()?['isIdle']?.toBool(),
  ),
  Accessor(
    name: 'isLoading',
    type: VariableType.boolean,
    getValue: (value) => (value.toMap()?['isLoading']).toBool(),
  ),
  Accessor(
    name: 'isError',
    type: VariableType.boolean,
    getValue: (value) => (value.toMap()?['isError']).toBool(),
  ),
  Accessor(
    name: 'isSuccess',
    type: VariableType.boolean,
    getValue: (value) => (value.toMap()?['isSuccess']).toBool(),
  ),
  Accessor(
    name: 'hasData',
    type: VariableType.boolean,
    getValue: (value) => (value.toMap()?['hasData']).toBool(),
  ),
  Accessor(
    name: 'data',
    type: dataType,
    getValue: (value) => value.toMap()?['data'],
  ),
  Accessor(
    name: 'error',
    type: dataType,
    getValue: (value) => value.toMap()?['error'],
  ),
  Accessor(
    name: 'headers',
    type: VariableType.map,
    getValue: (value) => value.toMap()?['headers']?.toMap(),
  ),
];

/// Defines accessors for a cloud data variable based on the type of date it holds.
List<Accessor> getCloudDataVariableAccessorsForType(VariableType dataType) => [
  Accessor(
    name: 'url',
    type: VariableType.text,
    getValue: (value) => value.toMap()?['url'],
  ),
  Accessor(
    name: 'status',
    type: VariableType.text,
    getValue: (value) => value.toMap()?['status']?.toString(),
  ),
  Accessor(
    name: 'isIdle',
    type: VariableType.boolean,
    getValue: (value) => value.toMap()?['isIdle']?.toBool(),
  ),
  Accessor(
    name: 'isLoading',
    type: VariableType.boolean,
    getValue: (value) => value.toMap()?['isLoading']?.toBool(),
  ),
  Accessor(
    name: 'isError',
    type: VariableType.boolean,
    getValue: (value) => value.toMap()?['isError']?.toBool(),
  ),
  Accessor(
    name: 'isSuccess',
    type: VariableType.boolean,
    getValue: (value) => value.toMap()?['isSuccess']?.toBool(),
  ),
  Accessor(
    name: 'hasData',
    type: VariableType.boolean,
    getValue: (value) => value.toMap()?['hasData']?.toBool(),
  ),
  Accessor(
    name: 'data',
    type: dataType,
    getValue: (value) => value.toMap()?['data'],
  ),
  Accessor(
    name: 'error',
    type: dataType,
    getValue: (value) => value.toMap()?['error'],
  ),
];

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats [date] like `Oct 14, 2026`, in local time.
String formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  return '${_monthNames[local.month - 1]} ${local.day}, ${local.year}';
}

/// Formats [date] relative to now: `Just now`, `5 min ago`, `2 hours ago`,
/// `3 days ago`, then [formatDate] after a week.
String formatTimeAgo(DateTime date, {DateTime? now}) {
  final Duration diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
  }
  return formatDate(date);
}
