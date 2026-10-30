import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
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

  /// The item of the list around [indexedItem]'s list, for a list nested in
  /// another list's item: what `${parent.item}` and `${parent.index}` read.
  late final IndexedItem? parentIndexedItem;

  /// The exposed internal value of a node in the widget tree.
  late final Object? nodeState;

  /// How far the nearest hold-to-confirm above this context has been held,
  /// 0 to 1, or null outside one.
  late final double? holdProgress;

  /// The drag of the nearest draggable node above this context (see
  /// [NodeDrag]), or null outside one: what the `drag` variable reads.
  late final DragValues? dragValues;

  /// The drag track of the nearest value control above this context (see
  /// [NodeDragTrack]), or null outside one: what the `track` variable reads.
  late final TrackValues? trackValues;

  /// The route params for this route/page for given context.
  late final Map<String, dynamic> routeParams;

  /// The signed-in app user, as the `auth` variable sees it. It is read
  /// live from the Codelessly instance, so an action chain that holds on to
  /// its scope sees a sign-in that an earlier action of the chain made.
  Map<String, dynamic>? get appUser =>
      _instanceRef?.target?.appUser.value ?? _appUser;

  late final Map<String, dynamic>? _appUser;

  /// The size of the screen, which the `screen` variable describes.
  late final Size? screenSize;

  /// The value of the `parent` variable: the `width` and `height` the
  /// node's parent gives it (see [ParentSizeScope]).
  late final Map<String, dynamic>? parentSize;

  // private fields.
  late final WeakReference<CodelesslyContext>? _codelesslyContextRef;
  // The Codelessly instance, read live: its cloud database can become
  // ready, and its user sign in, after the scope was captured.
  late final WeakReference<Codelessly>? _instanceRef;
  late final List<VariableData>? _variablesOverrides;
  late final Map<String, dynamic>? _dataOverrides;
  Map<String, VariableData>? _previewVariables;

  /// Codelessly context instance for the relative Codelessly instance.
  CodelesslyContext? get codelesslyContext => _codelesslyContextRef?.target;

  /// Local storage instance for the relative Codelessly instance.
  LocalDatabase? get localStorage => _instanceRef?.target?.localDatabase;

  /// Cloud storage instance for the relative Codelessly instance.
  CloudDatabase? get cloudDatabase => _instanceRef?.target?.cloudDatabase;

  /// Variable name -> Variable.
  Map<String, VariableData> get variables => {
    ...?_previewVariables,
    ...codelesslyContext?.variableNamesMap() ?? const {},
    // By name, as everything reading this map looks variables up (a
    // formula's `formStart`); keyed by id an override was never found.
    for (final variable in _variablesOverrides ?? const [])
      variable.name: variable,
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
      _instanceRef = null,
      _variablesOverrides = null,
      _dataOverrides = null,
      indexedItem = null,
      parentIndexedItem = null,
      nodeState = null,
      holdProgress = null,
      dragValues = null,
      trackValues = null,
      routeParams = {},
      _appUser = null,
      screenSize = null,
      parentSize = null;

  /// Creates scoped values for a design canvas, where [variables] (by name)
  /// hold their default values and nothing is read from a running app.
  /// [codelesslyContext] supplies conditions; the caller keeps it alive.
  /// [routeParams] are sample params for `${route.…}`, such as the ones a
  /// dialog canvas is designed with.
  ScopedValues.preview({
    required Map<String, VariableData> variables,
    CodelesslyContext? codelesslyContext,
    this.indexedItem,
    this.parentIndexedItem,
    this._appUser,
    this.screenSize,
    this.parentSize,
    Map<String, dynamic>? data,
    Map<String, dynamic>? routeParams,
  }) : _codelesslyContextRef = codelesslyContext == null
           ? null
           : WeakReference(codelesslyContext),
       _instanceRef = null,
       _variablesOverrides = null,
       _dataOverrides = data,
       _previewVariables = variables,
       nodeState = null,
       holdProgress = null,
       dragValues = null,
       trackValues = null,
       routeParams = routeParams ?? {};

  /// Creates a new scoped values instance from a given context.
  ScopedValues.of(
    BuildContext context, {
    List<VariableData>? variablesOverrides,
    Map<String, dynamic>? dataOverrides,
  }) {
    _variablesOverrides = variablesOverrides;
    _dataOverrides = dataOverrides;
    final codelesslyContext = context.read<CodelesslyContext?>();
    _codelesslyContextRef = codelesslyContext == null
        ? null
        : WeakReference(codelesslyContext);
    indexedItem = IndexedItemProvider.maybeOf(context);
    parentIndexedItem = IndexedItemProvider.parentOf(context);
    screenSize = MediaQuery.maybeSizeOf(context);
    parentSize = ParentSizeScope.valueOf(context);
    nodeState = NodeStateProvider.maybeOf(context)?.state;
    holdProgress = HoldProgressProvider.maybeOf(context);
    dragValues = DragScope.maybeOf(context);
    trackValues = TrackScope.maybeOf(context);
    final instance = context.read<Codelessly?>();
    // Screens the app navigates to carry their parameters; the first screen
    // shows in the host's route and takes them from the app's link.
    routeParams =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        (instance ?? Codelessly.instance).linkParamsFor(
          codelesslyContext?.layoutID,
        ) ??
        {};
    _appUser = null;
    _instanceRef = instance == null ? null : WeakReference(instance);
  }
}
