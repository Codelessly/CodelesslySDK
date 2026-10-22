import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import 'property_value_delegate.dart';
import 'scoped_values.dart';

/// Gives the nodes below it the [PropertyOverrides] of the states shown
/// around them: a property-override variant, or the interaction states of
/// an ancestor (or of the node itself). Nested scopes layer: the inner one
/// wins for the same node and property.
///
/// `PassiveNodeTransformerManager.applyStyleOverrides` reads it, so every
/// node applies the overrides the same way.
class PropertyOverrideScope extends InheritedWidget {
  /// The overrides of every scope above this one and of this one, merged.
  final PropertyOverrides overrides;

  const PropertyOverrideScope._({
    required this.overrides,
    required super.child,
  });

  /// Adds [overrides] over those of the enclosing scope. Returns [child] when
  /// there are none, unless [keepTree] asks for a scope anyway, so that a
  /// widget whose overrides come and go (an interaction state) keeps the same
  /// tree and the state below it.
  static Widget wrap(
    BuildContext context, {
    required PropertyOverrides overrides,
    required Widget child,
    bool keepTree = false,
  }) {
    final PropertyOverrides? outer = maybeOf(context);
    if (overrides.isEmpty && !keepTree) return child;
    return PropertyOverrideScope._(
      overrides: outer == null
          ? overrides
          : overrides.isEmpty
          ? outer
          : PropertyOverridePatch.merge([outer, overrides]),
      child: child,
    );
  }

  /// The overrides in effect at [context], if any.
  static PropertyOverrides? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PropertyOverrideScope>()
      ?.overrides;

  /// The patch of node [nodeId] in effect at [context], if any.
  static Map<String, dynamic>? patchFor(BuildContext context, String nodeId) =>
      maybeOf(context)?[nodeId];

  @override
  bool updateShouldNotify(PropertyOverrideScope oldWidget) =>
      !identical(overrides, oldWidget.overrides);
}

/// Whether [node] uses its interaction states or its `selected` and
/// `disabled` properties, so its widget needs an [InteractionStatesBox].
bool usesInteractionStates(BaseNode node) =>
    node.hasInteractionStates ||
    node.variables.containsKey('selected') ||
    node.variables.containsKey('disabled');

/// Tracks the pointer and focus over a node and shows its interaction
/// states: puts the overrides of every active state (in
/// [InteractionState] order, the later winning) in a [PropertyOverrideScope]
/// over [builder]. A disabled node ignores the pointer, so its actions do
/// not run.
class InteractionStatesBox extends StatefulWidget {
  /// The node whose states are shown.
  final BaseNode node;

  /// Builds the node's widget in a context that has the overrides.
  final WidgetBuilder builder;

  const InteractionStatesBox({
    super.key,
    required this.node,
    required this.builder,
  });

  /// The states of [node] that its properties switch on at [context]:
  /// `selected` and `disabled`, from a bound variable, formula or condition.
  static Set<InteractionState> propertyStates(
    BuildContext context,
    BaseNode node,
  ) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    return {
      for (final InteractionState state in InteractionState.values)
        if (state.property case final String property)
          if (PropertyValueDelegate.getPropertyValue<bool>(
                node,
                property,
                scopedValues: scopedValues,
              ) ==
              true)
            state,
    };
  }

  /// The overrides [node] shows with [active] states.
  static PropertyOverrides overridesFor(
    BaseNode node,
    Set<InteractionState> active,
  ) => PropertyOverridePatch.merge([
    for (final InteractionState state in InteractionState.values)
      if (active.contains(state))
        if (node.interactionStates[state] case final PropertyOverrides o) o,
  ]);

  @override
  State<InteractionStatesBox> createState() => _InteractionStatesBoxState();
}

class _InteractionStatesBoxState extends State<InteractionStatesBox> {
  /// The states the pointer and focus switch on.
  final Set<InteractionState> pointerStates = {};

  void toggle(InteractionState state, bool on) {
    if (pointerStates.contains(state) == on) return;
    setState(() => on ? pointerStates.add(state) : pointerStates.remove(state));
  }

  @override
  Widget build(BuildContext context) {
    final BaseNode node = widget.node;
    final Set<InteractionState> propertyStates =
        InteractionStatesBox.propertyStates(context, node);
    final bool disabled = propertyStates.contains(InteractionState.disabled);
    // A disabled node is not hovered or pressed.
    final Set<InteractionState> active = {
      ...propertyStates,
      for (final InteractionState state in pointerStates)
        if (!disabled || state == InteractionState.focused) state,
    };

    Widget child = Builder(builder: widget.builder);
    child = PropertyOverrideScope.wrap(
      context,
      overrides: InteractionStatesBox.overridesFor(node, active),
      keepTree: true,
      child: child,
    );

    final Map<InteractionState, PropertyOverrides> states =
        node.interactionStates;
    if (states.containsKey(InteractionState.focused)) {
      // Reports focus of any input inside without taking focus itself.
      child = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => toggle(InteractionState.focused, focused),
        child: child,
      );
    }
    if (states.containsKey(InteractionState.pressed)) {
      child = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => toggle(InteractionState.pressed, true),
        onPointerUp: (_) => toggle(InteractionState.pressed, false),
        onPointerCancel: (_) => toggle(InteractionState.pressed, false),
        child: child,
      );
    }
    if (states.containsKey(InteractionState.hovered)) {
      child = MouseRegion(
        opaque: false,
        onEnter: (_) => toggle(InteractionState.hovered, true),
        onExit: (_) => toggle(InteractionState.hovered, false),
        child: child,
      );
    }
    // A disabled node runs no actions. Always wrapped so that switching it
    // keeps the state below.
    child = IgnorePointer(ignoring: disabled, child: child);
    return child;
  }
}
