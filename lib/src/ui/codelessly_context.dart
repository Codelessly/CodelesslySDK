import 'dart:developer';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../codelessly_sdk.dart';

/// Holds data passed from the Codelessly instance down the widget tree where
/// all of the [WidgetNodeTransformer]s have access to it.
class CodelesslyContext with ChangeNotifier, Equatable {
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

  /// A notifier that is used to rebuild individual nodes.
  final ValueNotifier<String> nodeRebuildNotifier = ValueNotifier('');

  /// Creates a [CodelesslyContext] with the given [_data], [functions], and
  /// [nodeValues].
  CodelesslyContext({
    required this._data,
    required this.functions,
    required Map<String, WidgetBuilder>? externalComponentBuilders,
    required this.nodeValues,
    required this.variables,
    required this.conditions,
    required this.layoutID,
  }) : _externalComponentBuilders = externalComponentBuilders ?? {};

  /// Creates a [CodelesslyContext] with empty an empty map of each property.
  CodelesslyContext.empty({String? layoutID})
    : _data = {},
      functions = {},
      _externalComponentBuilders = {},
      nodeValues = {},
      variables = {},
      conditions = {};

  @override
  void dispose() {
    unbindComputedVariables();
    nodeRebuildNotifier.dispose();
    super.dispose();
  }

  /// Listeners that keep computed variables up to date, by the notifier
  /// they listen to. See [bindComputedVariables].
  final List<(Listenable, VoidCallback)> _computedListeners = [];

  /// The computed variables being evaluated, by id, to stop a cycle from
  /// evaluating forever.
  final Set<String> _computing = {};

  /// Computes the value of every computed variable (a variable with a
  /// [VariableData.formula]) in [variables] and keeps it up to date: each is
  /// computed again when a variable its formula reads changes, or when
  /// [data] changes. Their values are cached in their notifiers, so bindings
  /// read and listen to them like any other variable.
  ///
  /// Computed variables in a cycle hold an empty value. Call this again when
  /// [variables] changes; the previous listeners are removed.
  /// See [ComputedVariables].
  void bindComputedVariables() {
    unbindComputedVariables();
    final Map<String, VariableData> byName = variableNamesMap();
    if (!byName.values.any((variable) => variable.isComputed)) return;
    final Set<String> cyclic = ComputedVariables.cyclicNames(byName);
    // The variables as declared: a result can change a computed variable's
    // type, but each evaluation starts from the declared one.
    final Map<String, VariableData> declared = {
      for (final VariableData variable in byName.values)
        if (variable.isComputed) variable.name: variable,
    };

    final List<VoidCallback> recomputeAll = [];
    final List<Observable<VariableData>> ordered = [
      for (final String name in ComputedVariables.evaluationOrder(byName))
        ?findVariableByName(name),
    ];
    for (final Observable<VariableData> notifier in ordered) {
      final VariableData variable = declared[notifier.value.name]!;
      if (cyclic.contains(variable.name)) {
        notifier.value = ComputedVariables.withResult(variable, null);
        continue;
      }
      void recompute() => _recompute(notifier, variable);
      recompute();
      recomputeAll.add(recompute);
      // Listeners are added in evaluation order, so of two computed
      // variables reading the same input, the one the other reads updates
      // first.
      for (final String input in ComputedVariables.inputsOf(variable)) {
        final Observable<VariableData>? source = findVariableByName(input);
        if (source == null || identical(source, notifier)) continue;
        source.addListener(recompute);
        _computedListeners.add((source, recompute));
      }
    }
    // Formulas can read `data`, which is set while widgets build: compute
    // again after the frame, as setting a variable rebuilds its readers.
    void onDataChanged() {
      void run() {
        for (final VoidCallback recompute in recomputeAll) {
          recompute();
        }
      }

      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) => run());
      } else {
        run();
      }
    }

    addListener(onDataChanged);
    _computedListeners.add((this, onDataChanged));
  }

  /// Removes the listeners [bindComputedVariables] added.
  void unbindComputedVariables() {
    for (final (Listenable listenable, VoidCallback listener)
        in _computedListeners) {
      listenable.removeListener(listener);
    }
    _computedListeners.clear();
  }

  void _recompute(Observable<VariableData> notifier, VariableData declared) {
    if (!_computing.add(declared.id)) return;
    try {
      final Object? result = ComputedVariables.evaluate(
        declared,
        scopedValues: ScopedValues.preview(
          variables: const {},
          codelesslyContext: this,
        ),
      );
      notifier.value = ComputedVariables.withResult(declared, result);
    } catch (error) {
      log('[CodelesslyContext] Computed variable ${declared.name}: $error');
    } finally {
      _computing.remove(declared.id);
    }
  }

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

  void rebuildNode(String nodeId) {
    nodeRebuildNotifier.value = nodeId;
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
                .where(
                  (property) =>
                      action.values.any((value) => property.name == value.name),
                )
                .toList(),
          );
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
            ),
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
      if (!currentValues.any(
        (currentValue) => currentValue.name == value.name,
      )) {
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
  ///
  /// When a screen variable and a shared (app or page) variable have the same
  /// name, the screen's own variable wins, as it does when bindings read
  /// [variableNamesMap]: shared variables are loaded first, so the last
  /// variable with the name is the one in use.
  Observable<VariableData>? findVariableByName(String? name) => variables.values
      .lastWhereOrNull((variable) => variable.value.name == name);

  /// The variable with [id], or else the one in use with [name].
  Observable<VariableData>? findVariable({String? id, String? name}) =>
      (id == null ? null : variables[id]) ?? findVariableByName(name);

  /// Allows to easily [value] of a variable with a given [name].
  /// Returns false if the variable does not exist.
  /// Returns true if the variable was updated successfully.
  /// A computed variable (see [VariableData.formula]) can't be set: this
  /// returns false and leaves it unchanged.
  bool updateVariable(String name, Object? value) {
    final ValueNotifier<VariableData>? variable = findVariableByName(name);
    if (variable == null) {
      log('[CodelesslyContext] Variable with name $name does not exist.');
      return false;
    }
    if (variable.value.isComputed) {
      log('[CodelesslyContext] Variable $name is computed and read-only.');
      return false;
    }
    final String newValue = value == null ? '' : '$value';

    // If the value is the same, then the underlying value notifier will not
    // notify listeners, so we need to return false.
    if (variable.value.value == newValue) {
      log(
        '[CodelesslyContext] Variable with name $name already has the value $newValue.',
      );
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
  List<Object?> get props => [layoutID, data, functions, variables, conditions];
}
