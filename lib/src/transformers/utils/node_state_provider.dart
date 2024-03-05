import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Stores a state object for a given [NodeProvider] per widget.
class NodeStateWrapper {
  /// The state object associated with the [NodeProvider] widget.
  Object? state;

  /// Creates a new [NodeStateWrapper].
  NodeStateWrapper();
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

  /// Returns the [BaseNode] provided by the closest [NodeStateProvider] ancestor,
  /// if any.
  ///
  /// If there is no [NodeStateProvider] ancestor, returns null.
  static NodeStateProvider? maybeOf(BuildContext context) {
    final NodeStateProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeStateProvider>();
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
  static void setState(BuildContext context, Object? state) {
    final NodeStateProvider? provider = maybeOf(context);
    if (provider == null) return;
    provider.state = state;
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
