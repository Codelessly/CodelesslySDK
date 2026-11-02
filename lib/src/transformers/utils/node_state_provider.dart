import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Stores a state object for a given [NodeProvider] per widget.
class NodeStateWrapper {
  /// The state object associated with the [NodeProvider] widget.
  Object? state;

  /// Whether the user changed [state], so it holds something the layout
  /// cannot rebuild: what they typed, toggled or picked.
  bool get changedByUser => _changedByUser;
  bool _changedByUser = false;

  /// Called once, when the user first changes [state].
  VoidCallback? onChangedByUser;

  /// Creates a new [NodeStateWrapper].
  NodeStateWrapper();

  /// Sets [state] to [value]. [byUser] says the value comes from the user
  /// interacting with the node rather than from building it.
  void update(Object? value, {required bool byUser}) {
    final bool changed = value != state;
    state = value;
    if (byUser && changed && !_changedByUser) {
      _changedByUser = true;
      onChangedByUser?.call();
    }
  }
}

/// A widget that provides a [BaseNode] to its descendants.
///
/// This widget uses the [InheritedWidget] mechanism to provide a [BaseNode]
/// to its descendants without requiring them to explicitly pass around
/// a reference.
class NodeStateProvider extends InheritedWidget {
  /// The [BaseNode] provided by this widget.
  final BaseNode node;

  final NodeStateWrapper _stateWrapper;

  /// The associated state object.
  Object? get state => _stateWrapper.state;

  /// Sets the associated state object.
  set state(Object? state) => _stateWrapper.state = state;

  /// Creates a new [NodeStateProvider].
  ///
  /// The [child] and [node] arguments are required and must not be null.
  NodeStateProvider({
    super.key,
    required super.child,
    required this.node,
    NodeStateWrapper? state,
  }) : _stateWrapper = state ?? NodeStateWrapper();

  /// Creates a [NodeStateProvider] for [child] that shares the node and
  /// state of [other], e.g. to give a hero flight's copy of a node the
  /// state of the node it copies.
  NodeStateProvider.sharing(NodeStateProvider other, {required super.child})
    : node = other.node,
      _stateWrapper = other._stateWrapper;

  /// Returns the [BaseNode] provided by the closest [NodeStateProvider] ancestor,
  /// if any.
  ///
  /// If there is no [NodeStateProvider] ancestor, returns null.
  static NodeStateProvider? maybeOf(BuildContext context) {
    final NodeStateProvider? provider = context
        .dependOnInheritedWidgetOfExactType<NodeStateProvider>();
    if (provider == null) return null;
    return provider;
  }

  /// Returns the [BaseNode] provided by the closest [NodeStateProvider] ancestor.
  ///
  /// If there is no [NodeStateProvider] ancestor, an error is thrown.
  static NodeStateProvider of(BuildContext context) {
    final NodeStateProvider? result = maybeOf(context);
    assert(result != null, 'No NodeProvider found in context');
    return result!;
  }

  /// Returns the value associated with the [BaseNode] provided by the closest
  /// [NodeStateProvider] ancestor, if any.
  ///
  /// If there is no [NodeStateProvider] ancestor, returns null.
  static Object? getState(BuildContext context) {
    final NodeStateProvider? provider = maybeOf(context);
    if (provider == null) return null;
    return provider.state;
  }

  /// Sets the value associated with the [BaseNode] provided by the closest
  /// [NodeStateProvider] ancestor, if any.
  ///
  /// If there is no [NodeStateProvider] ancestor, does nothing.
  ///
  /// [byUser] says the value comes from the user interacting with the node
  /// (the default). A node the user changed is kept alive when a lazy list
  /// scrolls it away, so what they entered survives; every other node is
  /// disposed off-screen like any list item.
  static void setState(
    BuildContext context,
    Object? state, {
    bool byUser = true,
  }) {
    final NodeStateProvider? provider = maybeOf(context);
    if (provider == null) return;
    provider._stateWrapper.update(state, byUser: byUser);
  }

  /// Determines whether the widget should notify its descendants.
  ///
  /// In this case, the widget notifies its descendants whenever the provided
  /// [BaseNode] changes.
  @override
  bool updateShouldNotify(covariant NodeStateProvider oldWidget) {
    return oldWidget.node != node;
  }

  /// Adds properties associated with this widget to the given
  /// [DiagnosticPropertiesBuilder].
  ///
  /// This enables the widget to have its properties displayed in the Flutter
  /// inspector.
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('id', node.id));
    properties.add(StringProperty('name', node.name));
    properties.add(StringProperty('type', node.type));
    properties.add(StringProperty('state', state.toString()));
  }
}
