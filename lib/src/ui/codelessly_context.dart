import 'dart:developer';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// Holds data passed from the Codelessly instance down the widget tree where
/// all of the [WidgetNodeTransformer]s have access to it.
class CodelesslyContext with ChangeNotifier, EquatableMixin {
  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  Map<String, dynamic> _data;

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  Map<String, dynamic> get data => _data;

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  set data(Map<String, dynamic> value) {
    _data = value;
    notifyListeners();
  }

  /// The passed ID of the layout to load.
  String? layoutID;

  /// A map of functions that is passed to loaded layouts for nodes to call when
  /// they are triggered.
  Map<String, CodelesslyFunction> functions;

  set setFunctions(Map<String, CodelesslyFunction> functions) {
    this.functions = functions;
    notifyListeners();
  }

  /// A map of widget builders used to build dynamic widgets.
  Map<String, WidgetBuilder> _externalComponentBuilders;

  Map<String, WidgetBuilder> get externalComponentBuilders =>
      _externalComponentBuilders;

  set externalComponentBuilders(Map<String, WidgetBuilder> builders) {
    _externalComponentBuilders = builders;
    notifyListeners();
  }

  /// A map that holds the current values of nodes that have internal values.
  final Map<String, Observable<List<ValueModel>>> nodeValues;

  /// A map that holds the current state of all variables.
  /// The key is the variable's id.
  final Map<String, Observable<VariableData>> variables;

  /// A map that holds the current state of all conditions.
  /// The key is the condition's id.
  final Map<String, BaseCondition> conditions;

  /// Creates a [CodelesslyContext] with the given [data], [functions], and
  /// [nodeValues].
  CodelesslyContext({
    required Map<String, dynamic> data,
    required this.functions,
    required Map<String, WidgetBuilder>? externalComponentBuilders,
    required this.nodeValues,
    required this.variables,
    required this.conditions,
    required this.layoutID,
  })  : _data = data,
        _externalComponentBuilders = externalComponentBuilders ?? {};

  /// Creates a [CodelesslyContext] with empty an empty map of each property.
  CodelesslyContext.empty({String? layoutID})
      : _data = {},
        functions = {},
        _externalComponentBuilders = {},
        nodeValues = {},
        variables = {},
        conditions = {};

  /// Returns a map of all of the [VariableData]s in [variables] mapped by their
  /// name.
  Map<String, VariableData> variableNamesMap() =>
      variables.map((key, value) => MapEntry(value.value.name, value.value));

  /// Creates a copy of this [CodelesslyContext] with the given [data],
  /// [functions], and [nodeValues].
  CodelesslyContext copyWith({
    Map<String, dynamic>? data,
    Map<String, CodelesslyFunction>? functions,
    Map<String, WidgetBuilder>? dynamicWidgetBuilders,
    Map<String, Observable<List<ValueModel>>>? nodeValues,
    Map<String, Observable<VariableData>>? variables,
    Map<String, BaseCondition>? conditions,
    String? layoutID,
    bool forceLayoutID = false,
  }) {
    return CodelesslyContext(
      data: data ?? this.data,
      functions: functions ?? this.functions,
      externalComponentBuilders:
          dynamicWidgetBuilders ?? externalComponentBuilders,
      nodeValues: nodeValues ?? this.nodeValues,
      variables: variables ?? this.variables,
      layoutID: forceLayoutID ? layoutID : layoutID ?? this.layoutID,
      conditions: conditions ?? this.conditions,
    );
  }

  /// Used for actions that are connected to one or more nodes.
  /// Ex. submit action is connected to a text field node to access its data to
  /// submit to the server.
  Future<void> handleActionConnections(
    ActionModel actionModel,
    Map<String, BaseNode> nodes,
  ) async {
    switch (actionModel.type) {
      case ActionType.submit:
        final action = actionModel as MailchimpSubmitAction;
        final BaseNode? primaryField = nodes[action.primaryTextField];
        final BaseNode? firstNameField = nodes[action.firstNameField];
        final BaseNode? lastNameField = nodes[action.lastNameField];
        if (primaryField != null) {
          addToNodeValues(primaryField, [StringValue(name: 'inputValue')]);
        }
        if (firstNameField != null) {
          addToNodeValues(firstNameField, [StringValue(name: 'inputValue')]);
        }
        if (lastNameField != null) {
          addToNodeValues(lastNameField, [StringValue(name: 'inputValue')]);
        }
      case ActionType.setValue:
        final action = actionModel as SetValueAction;
        final SceneNode? connectedNode = nodes[action.nodeID] as SceneNode?;
        // Populate node values with node's values, not action's values.
        if (connectedNode != null) {
          addToNodeValues(
              connectedNode,
              connectedNode.propertyVariables
                  .where((property) =>
                      action.values.any((value) => property.name == value.name))
                  .toList());
        }
      case ActionType.setVariant:
        final action = actionModel as SetVariantAction;
        final VarianceNode? connectedNode =
            nodes[action.nodeID] as VarianceNode?;
        // Populate node values with node's variant value, not action's variant
        // value.
        if (connectedNode != null) {
          addToNodeValues(connectedNode, [
            StringValue(
              name: 'currentVariantId',
              value: connectedNode.currentVariantId,
            )
          ]);
        }
      default:
    }
  }

  /// Add [values] to the [nodeValues] map corresponding to the [node].
  /// [values] refer to the local values of the node's properties that can be
  /// changed, for example, with set value action.
  void addToNodeValues(BaseNode node, List<ValueModel> values) {
    // Get current values for the node, if any.
    final List<ValueModel> currentValues = nodeValues[node.id]?.value ?? [];
    // New values.
    final List<ValueModel> newValues = [];
    // Filter out and populate new values.
    for (final ValueModel value in values) {
      if (!currentValues
          .any((currentValue) => currentValue.name == value.name)) {
        newValues.add(value);
      }
    }
    // Add new values to the node's values list.
    if (nodeValues[node.id] == null) {
      nodeValues[node.id] = Observable([...currentValues, ...newValues]);
    } else {
      nodeValues[node.id]!.value = [...currentValues, ...newValues];
    }
  }

  /// Returns a reverse-lookup of the [VariableData] associated with a given
  /// [name].
  Observable<VariableData>? findVariableByName(String? name) => variables.values
      .firstWhereOrNull((variable) => variable.value.name == name);

  /// Allows to easily [value] of a variable with a given [name].
  /// Returns false if the variable does not exist.
  /// Returns true if the variable was updated successfully.
  bool updateVariable(String name, Object? value) {
    final ValueNotifier<VariableData>? variable = findVariableByName(name);
    if (variable == null) {
      log('[CodelesslyContext] Variable with name $name does not exist.');
      return false;
    }
    final String newValue = value == null ? '' : '$value';

    // If the value is the same, then the underlying value notifier will not
    // notify listeners, so we need to return false.
    if (variable.value.value == newValue) {
      log('[CodelesslyContext] Variable with name $name already has the value $newValue.');
      return false;
    }
    variable.value = variable.value.copyWith(value: newValue);
    return true;
  }

  /// Allows to easily get the [newValue] of a variable with a given [name].
  /// Returns null if the variable does not exist.
  /// If [R] is provided, the returned value will be cast to that type.
  R? getVariableValue<R extends Object>(String name) {
    final ValueNotifier<VariableData>? variable = findVariableByName(name);
    if (variable == null) {
      log('[CodelesslyContext] Variable with name $name does not exist.');
      return null;
    }
    return variable.value.getValue().typedValue<R>();
  }

  @override
  List<Object?> get props => [layoutID, data, functions];
}
