import 'dart:async';

import 'package:flutter/widgets.dart';

import '../logging/error_logger.dart';
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
/// * the trigger's context and the contexts of the [ActionChainHost]s it
///   runs in: the [CodelesslyWidget]s above it, nearest first, and, for a
///   layout shown as a dialog or pushed as a page, the hosts of the layout
///   that opened it (see [ActionChainOpener]). When the trigger's widget
///   unmounts mid chain, e.g. a row that leaves the list after the chain
///   removed its document, the remaining actions run with the first host
///   still mounted, so toasts, dialogs and navigation still happen. See
///   [contextFor].
///
/// Something the chain registers to run later, such as a toast's Undo
/// button, runs on the same chain through [defer].
///
/// Its [result] is what the `${result}` variable resolves to: the value the
/// previous action produced (e.g. the id of a document it added), or the
/// current item while a for-each or an upload runs its nested actions.
class ActionChain {
  /// Creates an [ActionChain] that starts with [result].
  ActionChain({
    this.result,
    this.scopedValues,
    this.event,
    this._context,
    this._hosts = const [],
  });

  /// Creates a chain for a trigger that fired in [context], capturing its
  /// scope and hosts.
  factory ActionChain.capture(
    BuildContext context, {
    Object? result,
    Map<String, Object?>? event,
  }) => ActionChain(
    result: result,
    event: event,
    scopedValues: ScopedValues.of(context),
    context: context,
    hosts: ActionChainHost.hostsOf(context),
  );

  /// What `${result}` resolves to.
  Object? result;

  /// What `${event}` resolves to: details of the gesture that fired the
  /// chain's trigger. A click gives `x` and `y`, where the tap landed as a
  /// fraction (0..1) of the tapped node's width and height, plus `localX`,
  /// `localY` (pixels from its top left), `width` and `height`. Null for
  /// triggers that carry no gesture.
  final Map<String, Object?>? event;

  /// The scope captured when the chain's trigger fired, which the chain's
  /// actions read variables from. Null for a chain that was started without
  /// a context.
  final ScopedValues? scopedValues;

  final BuildContext? _context;
  final List<BuildContext> _hosts;

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

  /// A chain nested in this one: same scope and contexts, its own result.
  ActionChain _nested(Object? result, {Map<String, Object?>? event}) =>
      ActionChain(
        result: result,
        event: event ?? this.event,
        scopedValues: scopedValues,
        context: _context,
        hosts: _hosts,
      );

  /// Runs [body] in a new chain whose `${result}` starts as [result].
  ///
  /// With [context], the chain starts at a trigger: it captures the scope and
  /// hosts of [context]. Without it, the chain nests in the current one (a
  /// for-each's or an upload's actions) and keeps its scope and contexts.
  static R run<R>(
    R Function() body, {
    Object? result,
    BuildContext? context,
    Map<String, Object?>? event,
  }) {
    final ActionChain chain = context != null
        ? ActionChain.capture(context, result: result, event: event)
        : current?._nested(result, event: event) ??
              ActionChain(result: result, event: event);
    return runZoned(body, zoneValues: {_zoneKey: chain});
  }

  /// Wraps [body] as a callback to run later on the current chain, e.g. when
  /// the user presses a toast's button: [body] then reads the chain's
  /// captured scope and `${result}` as they were now, and gets the first of
  /// [context], the chain's trigger and its hosts that is still mounted.
  ///
  /// Outside a chain, the chain is captured from [context] now. When none of
  /// the contexts is mounted any more, the callback reports that [label] did
  /// not run instead of running [body].
  static VoidCallback defer(
    BuildContext context,
    FutureOr<void> Function(BuildContext context) body, {
    required String label,
  }) {
    final ActionChain chain = current ?? ActionChain.capture(context);
    final Object? result = chain.result;
    return () => runZoned(() {
      final BuildContext? actionContext = contextFor(context);
      if (actionContext == null) {
        reportDetached(label);
        return;
      }
      unawaited(
        Future<void>.sync(() => body(actionContext)).catchError(
          (Object error, StackTrace stackTrace) =>
              ErrorLogger.instance.captureException(
                error,
                message: '$label failed',
                type: 'action_failed',
                stackTrace: stackTrace,
              ),
        ),
      );
    }, zoneValues: {_zoneKey: chain._nested(result)});
  }

  /// Reports that [what] did not run because every context its chain could
  /// run with has unmounted.
  static void reportDetached(String what) =>
      ErrorLogger.instance.captureException(
        'Action chain detached',
        message: '$what did not run: the screen that started it is gone.',
        type: 'action_chain_detached',
      );

  /// The scope the running action reads variables from: the one its chain
  /// captured when its trigger fired, or [context]'s outside a chain.
  static ScopedValues scopedValuesOf(BuildContext context) =>
      current?.scopedValues ?? ScopedValues.of(context);

  /// A mounted context to run the next action with: [context] while it is
  /// mounted, else the chain's trigger context, else the first of its hosts
  /// still mounted. Null when all of them have unmounted, e.g. the app
  /// replaced the whole screen.
  static BuildContext? contextFor(BuildContext context) {
    if (context.mounted) return context;
    final ActionChain? chain = current;
    if (chain == null) return null;
    for (final BuildContext? candidate in [chain._context, ...chain._hosts]) {
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

  /// The contexts of the hosts a chain triggered in [context] can fall back
  /// to, nearest first: every [ActionChainHost] above [context] (a layout
  /// embedded in another has its own), then, past an [ActionChainOpener],
  /// the hosts of the layout that opened this one as a dialog or a page.
  static List<BuildContext> hostsOf(BuildContext context) {
    final List<BuildContext> hosts = [];
    context.visitAncestorElements((element) {
      final Widget widget = element.widget;
      if (widget is ActionChainHost) hosts.add(element);
      if (widget is ActionChainOpener) {
        hosts.addAll(widget.openerHosts);
        return false;
      }
      return true;
    });
    return hosts;
  }

  @override
  bool updateShouldNotify(ActionChainHost oldWidget) => false;
}

/// Links a layout shown as a dialog or pushed as a page to the context that
/// opened it, so a chain triggered in it can finish on the opener's hosts
/// after the dialog or page has closed (e.g. Navigate back, then a toast).
class ActionChainOpener extends InheritedWidget {
  /// Creates an [ActionChainOpener] above [child]. Get [openerHosts] with
  /// [hostsFor] when the action that opens the layout runs, not in a route
  /// builder: the opener may have unmounted by the time that builds.
  const ActionChainOpener({
    super.key,
    required this.openerHosts,
    required super.child,
  });

  /// The hosts of the layout, and of the chain, that opened this one,
  /// nearest first.
  final List<BuildContext> openerHosts;

  /// The hosts a layout opened by an action running in [context] falls back
  /// to: those above [context], then those of the running chain.
  static List<BuildContext> hostsFor(BuildContext context) => {
    if (context.mounted) ...ActionChainHost.hostsOf(context),
    ...?ActionChain.current?._hosts,
  }.toList();

  @override
  bool updateShouldNotify(ActionChainOpener oldWidget) => false;
}
