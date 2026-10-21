import 'dart:async';

import 'package:flutter/widgets.dart';

import '../transformers/utils/scoped_values.dart';

/// The state shared by the actions of one chain: the actions a trigger runs
/// in order, or the actions nested in a for-each, an upload, a confirm or an
/// if/else.
///
/// A chain belongs to the moment its trigger fired, not to the widget that
/// fired it. It captures, once:
///
/// * [scopedValues]: the trigger's scope (its list item and index, the node's
///   value, the route's params, ...). Every action of the chain reads its
///   variables from this capture, so `${item}` stays the item that was
///   tapped even when the list rebuilds under the row while an action is
///   awaited (e.g. a cloud write that the list streams back).
/// * the trigger's context and the context of the [ActionChainHost] above
///   it (the [CodelesslyWidget]'s). When the trigger's widget unmounts mid
///   chain, e.g. a row that leaves the list after the chain removed its
///   document, the remaining actions run with the host's context, so toasts,
///   dialogs and navigation still happen. See [contextFor].
///
/// Its [result] is what the `${result}` variable resolves to: the value the
/// previous action produced (e.g. the id of a document it added), or the
/// current item while a for-each or an upload runs its nested actions.
class ActionChain {
  /// Creates an [ActionChain] that starts with [result].
  ActionChain({
    this.result,
    this.scopedValues,
    this._context,
    this._hostContext,
  });

  /// Creates a chain for a trigger that fired in [context], capturing its
  /// scope and host.
  factory ActionChain.capture(BuildContext context, {Object? result}) =>
      ActionChain(
        result: result,
        scopedValues: ScopedValues.of(context),
        context: context,
        hostContext: ActionChainHost.maybeOf(context),
      );

  /// What `${result}` resolves to.
  Object? result;

  /// The scope captured when the chain's trigger fired, which the chain's
  /// actions read variables from. Null for a chain that was started without
  /// a context.
  final ScopedValues? scopedValues;

  final BuildContext? _context;
  final BuildContext? _hostContext;

  static const Symbol _zoneKey = #codelesslyActionChain;

  /// The chain the running action belongs to, if any.
  static ActionChain? get current => Zone.current[_zoneKey] as ActionChain?;

  /// Sets the current chain's result, when an action runs in a chain. Map
  /// results merge into a map result, so values an earlier action produced
  /// (e.g. an upload's `url`) stay readable after a later one adds its own.
  static void setResult(Object? result) {
    final ActionChain? chain = current;
    if (chain == null) return;
    final Object? previous = chain.result;
    chain.result = previous is Map && result is Map
        ? {...previous, ...result}
        : result;
  }

  /// Runs [body] in a new chain whose `${result}` starts as [result].
  ///
  /// With [context], the chain starts at a trigger: it captures the scope and
  /// host of [context]. Without it, the chain nests in the current one (a
  /// for-each's or an upload's actions) and keeps its scope and contexts.
  static R run<R>(R Function() body, {Object? result, BuildContext? context}) {
    final ActionChain? parent = current;
    final ActionChain chain = context != null
        ? ActionChain.capture(context, result: result)
        : ActionChain(
            result: result,
            scopedValues: parent?.scopedValues,
            context: parent?._context,
            hostContext: parent?._hostContext,
          );
    return runZoned(body, zoneValues: {_zoneKey: chain});
  }

  /// The scope the running action reads variables from: the one its chain
  /// captured when its trigger fired, or [context]'s outside a chain.
  static ScopedValues scopedValuesOf(BuildContext context) =>
      current?.scopedValues ?? ScopedValues.of(context);

  /// A mounted context to run the next action with: [context] while it is
  /// mounted, else the chain's trigger context, else its host's. Null when
  /// all of them have unmounted, e.g. the whole screen was replaced.
  static BuildContext? contextFor(BuildContext context) {
    if (context.mounted) return context;
    final ActionChain? chain = current;
    if (chain == null) return null;
    for (final BuildContext? candidate in [
      chain._context,
      chain._hostContext,
    ]) {
      if (candidate != null && candidate.mounted) return candidate;
    }
    return null;
  }
}

/// Marks the widget whose context runs an action chain's remaining actions
/// when the widget that triggered the chain unmounts. [CodelesslyWidget]
/// places one below its providers, so its context reads the layout's
/// [CodelesslyContext], navigator and overlay.
class ActionChainHost extends InheritedWidget {
  /// Creates an [ActionChainHost] above [child].
  const ActionChainHost({super.key, required super.child});

  /// The context of the nearest [ActionChainHost] above [context], if any.
  /// It does not make [context] depend on the host.
  static BuildContext? maybeOf(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<ActionChainHost>();

  @override
  bool updateShouldNotify(ActionChainHost oldWidget) => false;
}
