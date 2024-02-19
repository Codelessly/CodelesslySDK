import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import 'node_state_provider.dart';

/// A class that holds the scoped values for a widget/context. This is helpful
/// access context bound data in a widget tree. This makes it so that you don't
/// have to pass context around to access data and end up using context
/// across async gaps. This collects all the data you need in one place
/// before-hand so that you can access it later.
class ScopedValues {
  /// The indexed item provider if it exists in this context.
  late final IndexedItem? indexedItem;

  /// The exposed internal value of a node in the widget tree.
  late final Object? nodeState;

  /// The route params for this route/page for given context.
  late final Map<String, dynamic> routeParams;

  // private fields.
  late final WeakReference<CodelesslyContext>? _codelesslyContextRef;
  late final WeakReference<LocalDatabase>? _localStorageRef;
  late final WeakReference<CloudDatabase>? _cloudDatabaseRef;
  late final List<VariableData>? _variablesOverrides;
  late final Map<String, dynamic>? _dataOverrides;

  /// Codelessly context instance for the relative Codelessly instance.
  CodelesslyContext? get codelesslyContext => _codelesslyContextRef?.target;

  /// Local storage instance for the relative Codelessly instance.
  LocalDatabase? get localStorage => _localStorageRef?.target;

  /// Cloud storage instance for the relative Codelessly instance.
  CloudDatabase? get cloudDatabase => _cloudDatabaseRef?.target;

  /// Variable name -> Variable.
  Map<String, VariableData> get variables => {
        ...codelesslyContext?.variableNamesMap() ?? const {},
        for (final variable in _variablesOverrides ?? const [])
          variable.id: variable,
      };

  /// A map of data that is passed to loaded layouts for nodes to replace their
  /// values with.
  Map<String, dynamic> get data => {
        ...codelesslyContext?.data ?? const {},
        ..._dataOverrides ?? const {},
      };

  Map<String, Observable<List<ValueModel>>> get nodeValues =>
      codelesslyContext?.nodeValues ?? {};

  /// Creates a new scoped values instance with empty values.
  ScopedValues.empty()
      : _codelesslyContextRef = null,
        _localStorageRef = null,
        _cloudDatabaseRef = null,
        _variablesOverrides = null,
        _dataOverrides = null,
        indexedItem = null,
        nodeState = null,
        routeParams = {};

  /// Creates a new scoped values instance from a given context.
  ScopedValues.of(
    BuildContext context, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    _variablesOverrides = variablesOverrides;
    _dataOverrides = dataOverrides;
    final codelesslyContext = context.read<CodelesslyContext?>();
    if (codelesslyContext != null) {
      _codelesslyContextRef = WeakReference(codelesslyContext);
    }
    indexedItem = IndexedItemProvider.maybeOf(context);
    nodeState = NodeStateProvider.maybeOf(context)?.state;
    routeParams =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final instance = context.read<Codelessly?>();
    if (instance != null) {
      _localStorageRef = WeakReference(instance.localDatabase);
      _cloudDatabaseRef = instance.cloudDatabase == null
          ? null
          : WeakReference(instance.cloudDatabase!);
    } else {
      _localStorageRef = null;
      _cloudDatabaseRef = null;
    }
  }
}
