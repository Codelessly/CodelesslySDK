import 'dart:developer';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// Holds data passed from the Codelessly instance down the widget tree where
/// all of the [WidgetNodeTransformer]s have access to it.
class CodelesslyContext with ChangeNotifier, Equatable {
  /// The listeners added and not yet removed, in debug builds: a count that
  /// only grows as screens come and go means a widget left one behind (and
  /// with it, its screen).
  final List<VoidCallback> _debugListeners = [];

  /// How many listeners are registered (debug builds; 0 in release).
  int get debugListenerCount => _debugListeners.length;

  /// Contexts that have had a listener, held weakly (debug builds).
  static final List<WeakReference<CodelesslyContext>> _debugInstances = [];

  /// The listener counts of the contexts still alive that have had a
  /// listener (debug builds).
  static List<int> get debugLiveListenerCounts {
    _debugInstances.removeWhere((ref) => ref.target == null);
    return [
      for (final ref in _debugInstances)
        if (ref.target case final CodelesslyContext c) c.debugListenerCount,
    ];
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (kDebugMode) {
      if (_debugListeners.isEmpty &&
          !_debugInstances.any((ref) => identical(ref.target, this))) {
        _debugInstances.add(WeakReference(this));
      }
      _debugListeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (kDebugMode) _debugListeners.remove(listener);
  }

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

  /// The variables as published (name -> variable, with any value given in
  /// [data]), before any action changed them: `${initial.<name>}` reads
  /// them, so a Set variable action can put a variable back.
  final Map<String, VariableData> initialVariables = {};

  /// A map that holds the current state of all conditions.
  /// The key is the condition's id.
  final Map<String, BaseCondition> conditions;

  /// A notifier that is used to rebuild individual nodes.
  final ValueNotifier<String> nodeRebuildNotifier = ValueNotifier('');

  /// The drag in progress in this layout, which `${drag}` reads.
  final DragAndDropController dragAndDrop = DragAndDropController();

  /// The pagination controllers of this layout, by name; each writes its
  /// state into the map variable of that name (`${contacts.page}`).
  final PaginationRegistry pagination = PaginationRegistry();

  /// The layouts of this screen whose load actions have run. A layout's
  /// breakpoint canvases are one screen: the canvas shown for a new width
  /// (or the first one replaced by the right one at start-up) doesn't run
  /// them again. A copy starts empty, as a new screen does.
  final Set<String> _loadedLayouts = <String>{};

  /// Records that the load actions of [layoutId] run now, and whether this
  /// is the first time for this screen.
  bool markLayoutLoaded(String layoutId) => _loadedLayouts.add(layoutId);

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
    this.freezesClock = false,
  }) : _externalComponentBuilders = externalComponentBuilders ?? {};

  /// Whether nodes leave the clock alone: formulas that read `now()` keep
  /// the time they were built at instead of rebuilding every second. A
  /// design canvas shows values at rest, like its motion; rebuilding a
  /// whole screen every second there also makes the editor unusable.
  final bool freezesClock;

  /// Creates a [CodelesslyContext] with empty an empty map of each property.
  CodelesslyContext.empty({String? layoutID})
    : freezesClock = false,
      _data = {},
      functions = {},
      _externalComponentBuilders = {},
      nodeValues = {},
      variables = {},
      conditions = {};

  @override
  void dispose() {
    nodeRebuildNotifier.dispose();
    pagination.dispose();
    super.dispose();
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
      freezesClock: freezesClock,
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

  /// The variable an action naming [id] and [name] writes: the one in use
  /// with the name of the variable with [id], or else the one in use with
  /// [name].
  ///
  /// Bindings read a variable by its name (see [findVariableByName]), so a
  /// write goes to the variable they read. When two variables share a name
  /// (a screen variable over an app variable, or a project that holds the
  /// same app variable twice), writing the variable with [id] would change
  /// one that nothing shows.
  Observable<VariableData>? findVariable({String? id, String? name}) {
    final Observable<VariableData>? byId = id == null ? null : variables[id];
    if (byId == null) return findVariableByName(name);
    return findVariableByName(byId.value.name) ?? byId;
  }

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
    return PropertyValueDelegate.variableValue(
      variable.value,
      scopedValues: ScopedValues.preview(
        variables: variableNamesMap(),
        codelesslyContext: this,
      ),
    ).typedValue<R>();
  }

  @override
  List<Object?> get props => [layoutID, data, functions, variables, conditions];
}
