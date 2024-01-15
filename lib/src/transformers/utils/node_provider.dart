import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Stores a state object for a given [NodeProvider] per widget.
class NodeProviderState {
  /// The state object associated with the [NodeProvider] widget.
  Object? state;

  /// Creates a new [NodeProviderState].
  NodeProviderState();
}

/// A widget that provides a [BaseNode] to its descendants.
///
/// This widget uses the [InheritedWidget] mechanism to provide a [BaseNode]
/// to its descendants without requiring them to explicitly pass around
/// a reference.
class NodeProvider extends InheritedWidget {
  /// The [BaseNode] provided by this widget.
  final BaseNode node;

  final NodeProviderState _state;

  /// The associated state object.
  Object? get state => _state.state;

  /// Sets the associated state object.
  set state(Object? state) => _state.state = state;

  /// Creates a new [NodeProvider].
  ///
  /// The [child] and [node] arguments are required and must not be null.
  NodeProvider({
    super.key,
    required super.child,
    required this.node,
    NodeProviderState? state,
  }) : _state = state ?? NodeProviderState();

  /// Returns the [BaseNode] provided by the closest [NodeProvider] ancestor.
  ///
  /// If there is no [NodeProvider] ancestor, an error is thrown.
  static NodeProvider of(BuildContext context) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    assert(provider != null, 'No NodeProvider found in context');
    return provider!;
  }

  /// Returns the [BaseNode] provided by the closest [NodeProvider] ancestor,
  /// if any.
  ///
  /// If there is no [NodeProvider] ancestor, returns null.
  static NodeProvider? maybeOf(BuildContext context) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    if (provider == null) return null;
    return provider;
  }

  /// Returns the value associated with the [BaseNode] provided by the closest
  /// [NodeProvider] ancestor, if any.
  ///
  /// If there is no [NodeProvider] ancestor, returns null.
  static Object? getState(BuildContext context) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    if (provider == null) return null;
    return provider.state;
  }

  /// Sets the value associated with the [BaseNode] provided by the closest
  /// [NodeProvider] ancestor, if any.
  ///
  /// If there is no [NodeProvider] ancestor, does nothing.
  static void setState(BuildContext context, Object? state) {
    final NodeProvider? provider =
        context.dependOnInheritedWidgetOfExactType<NodeProvider>();
    if (provider == null) return;
    provider.state = state;
  }

  /// Determines whether the widget should notify its descendants.
  ///
  /// In this case, the widget notifies its descendants whenever the provided
  /// [BaseNode] changes.
  @override
  bool updateShouldNotify(covariant NodeProvider oldWidget) {
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
