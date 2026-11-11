// Runs reactions: a trigger's actions in order, as one chain. Each action
// type has a typed handler (handlers.dart) over an ActionContext; nothing
// here holds a BuildContext.
//
// * A blocking action is awaited before the next; a non-blocking one isn't,
//   and its failure doesn't stop the chain.
// * A failing action stops its chain. The failure is reported to the
//   context ([ActionHost.reportError]); it never reaches the caller, so one
//   reaction can't break another, or the gesture that fired it.
// * A chain is canceled with its [ActionCancellation] (the node that fired
//   it left the tree): the action running finishes, and no other starts. A
//   delay ends at once.
// * `${result}` is what the previous action gave: an API's response, a
//   document id, a confirm's values, a for-each's item; the trigger's event
//   first.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show ActionDef, Json, Node, Reaction, TriggerType, UnknownAction;

import '../contracts.dart';
import '../expressions/engine.dart';
import '../expressions/formula.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'action_error.dart';
export 'action_error.dart' show ActionFailed;
import 'handlers.dart';
import 'key_matching.dart';
import 'ui.dart';

/// Cancels the chains it's given to: [cancel] stops them between actions.
class ActionCancellation {
  bool _canceled = false;
  final List<void Function()> _listeners = [];

  bool get isCanceled => _canceled;

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    for (final l in [..._listeners]) {
      l();
    }
    _listeners.clear();
  }

  /// Calls [listener] on cancel (at once when canceled already); returns
  /// what removes it.
  void Function() onCancel(void Function() listener) {
    if (_canceled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}

/// A chain stopped because it was canceled.
class ActionsCanceled implements Exception {
  const ActionsCanceled();

  @override
  String toString() => 'The actions were canceled.';
}

/// A chain stopped by an outcome the person chose (a cancelled purchase,
/// nothing to restore): not a failure, so nothing is logged as an error,
/// but the screen's actionError reaction still hears it, with [code], to
/// say so.
class ActionsStopped extends ActionsCanceled {
  const ActionsStopped(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// One running chain: what its actions read and share.
class ActionRun {
  ActionRun._(this.context, this.host, this.scope, this.cancellation, this.node, this.value, [ActionCancellation? stopped])
      : _stopped = stopped ?? ActionCancellation();

  final ActionCancellation _stopped;

  /// Stops only this invocation and nested actions, preserving later retries.
  void stop() => _stopped.cancel();

  void Function() onCancel(void Function() listener) {
    var called = false;
    void once() { if (!called) { called = true; listener(); } }
    final removeParent = cancellation.onCancel(once);
    final removeStop = _stopped.onCancel(once);
    return () { removeParent(); removeStop(); };
  }

  /// What the actions run with.
  final ActionContext context;

  /// [context]'s UI, node tree and functions (defaults when it has none).
  final ActionHost host;

  /// Where the actions read names: the context's scope, with `result`.
  final ValuesScope scope;
  final ActionCancellation cancellation;

  /// The node whose reaction runs.
  final Node? node;

  /// The trigger's value (an input's new value: a set value action's sync
  /// mode sets it).
  final Object? value;

  Expressions get expressions =>
      context.expressions is Expressions ? context.expressions as Expressions : const Expressions();

  bool get isCanceled => cancellation.isCanceled || _stopped.isCanceled;

  /// What `${result}` reads.
  Object? get result => scope['result'];

  /// Sets `${result}`. A map merges into a map result, so what an earlier
  /// action gave stays readable.
  set result(Object? value) {
    final previous = result;
    scope.set('result', previous is Map && value is Map ? {...previous, ...value} : value);
  }

  /// A chain nested in this one (a for-each's body, an API's branch) whose
  /// `${result}` starts as [result]; [names] are more names its actions
  /// read (a for-each turn's `loop`).
  ActionRun nested(Object? result, {Json names = const {}}) =>
      ActionRun._(context, host, ValuesScope({...names, 'result': result}, scope), cancellation, node, value, _stopped);

  /// [text] with its `${...}` evaluated (text).
  String text(String text) => expressions.interpolate(text, scope);

  /// [expression] evaluated (a value).
  Object? evaluate(String expression) => expressions.evaluate(expression, scope);

  /// [json] with its strings evaluated (params).
  Json json(Json json) {
    final out = expressions.substituteJson(json, scope);
    return out is Map ? {for (final e in out.entries) '${e.key}': e.value} : const {};
  }

  /// Waits [duration], unless canceled first (then throws
  /// [ActionsCanceled]).
  Future<void> wait(Duration duration) {
    if (isCanceled) return Future.error(const ActionsCanceled());
    final done = Completer<void>();
    late final void Function() remove;
    final timer = Timer(duration, () {
      remove();
      if (!done.isCompleted) done.complete();
    });
    remove = onCancel(() {
      timer.cancel();
      if (!done.isCompleted) done.completeError(const ActionsCanceled());
    });
    return done.future;
  }

  /// Runs [actions] in order in this chain.
  Future<void> run(List<ActionDef> actions) => runActions(actions, this);
}

/// The default [ActionRunner]: runs a node's reactions with the typed
/// handlers of [handlers] (the built-in ones, which an app can override or
/// extend by action type).
class CodelesslyActions implements ActionRunner {
  const CodelesslyActions({this.handlers = const {}});

  /// Handlers by action type (`setVariable`, `callApi`...), over the
  /// built-in ones.
  final Map<String, ActionHandler> handlers;

  @override
  Future<void> trigger(Node node, String trigger, ActionContext context, {Json event = const {}}) =>
      run(node, trigger, context, event: event);

  /// Runs [node]'s reactions to [trigger] (all of them, in order, as one
  /// chain), unless [cancellation] cancels them. A debounced trigger runs
  /// once, after a burst. Completes when the chain ends (or is canceled);
  /// never throws.
  Future<void> run(Node node, String trigger, ActionContext context,
      {Json event = const {}, ActionCancellation? cancellation, Object? instance}) {
    if (trigger == TriggerType.actionError.name && context is RuntimeActionContext) {
      context = context.withoutActionErrorEvents();
    }
    final reactions = [
      for (final r in node.actions)
        if (_matchesReaction(r, trigger, event) && _allowed(r, context, event) &&
            (trigger != 'valueChanged' || event['changedVariable'] == null || r.trigger.variable.trim() == event['changedVariable'])) r,
    ];
    if (reactions.isEmpty) return Future.value();
    final debounce = reactions.fold<int>(0, (m, r) => r.trigger.debounceMs > m ? r.trigger.debounceMs : m);
    if (debounce > 0) {
      final key = (node.id, instance, trigger, event['changedVariable']);
      final owner = (context is ActionHost ? context.tree : null) ?? context;
      final pending = _debounced[owner]?[key];
      pending?.$1.cancel();
      if (pending != null && !pending.$2.isCompleted) pending.$2.complete();
      final done = Completer<void>();
      final timer = Timer(Duration(milliseconds: debounce), () {
        _debounced[owner]?.remove(key);
        if (cancellation?.isCanceled ?? false) return done.complete();
        done.complete(_run(node, reactions, context, event, cancellation));
      });
      (_debounced[owner] ??= {})[key] = (timer, done);
      cancellation?.onCancel(timer.cancel);
      return done.future;
    }
    return _run(node, reactions, context, event, cancellation);
  }


  // A trigger guard applies to every trigger, not only the keyboard's
  // event listener. Evaluate against the triggering event before any action
  // runs, so timer/click/change reactions obey the same condition contract.
  static bool _allowed(Reaction reaction, ActionContext context, Json event) {
    final when = reaction.trigger.when.trim();
    if (when.isEmpty) return true;
    final result = event.containsKey('result') ? event['result'] : (event.containsKey('value') ? event['value'] : (event.isEmpty ? null : event));
    final scope = ValuesScope({'result': result, if (event.containsKey('value')) 'value': event['value']}, context.scope);
    try {
      final value = FormulaEvaluator.exactExpression(when) != null
          ? context.expressions.evaluate(when, scope)
          : context.expressions.evaluate('\${= $when}', scope);
      return value == true;
    } finally {
      scope.dispose();
    }
  }

  bool _matchesReaction(Reaction reaction, String trigger, Json event) {
    final t = reaction.trigger;
    if (t.type.name != trigger) return false;
    if (t.type != TriggerType.keyDown && t.type != TriggerType.keyUp) return true;
    final value = event['result'] is Map ? event['result'] as Map : event;
    return runtimeKeyMatches(t.keyCombo, '${value['key'] ?? ''}',
        meta: value['meta'] == true, shift: value['shift'] == true,
        alt: value['alt'] == true);

  }

  static final Expando<Map<Object, (Timer, Completer<void>)>> _debounced = Expando('debounce');

  Future<void> _run(Node node, List<Reaction> reactions, ActionContext context, Json event, ActionCancellation? cancellation) async {
    final host = context is ActionHost ? context : _BareHost(context);
    final result = event.containsKey('result') ? event['result'] : (event.containsKey('value') ? event['value'] : (event.isEmpty ? null : event));
    final run = ActionRun._(
      context,
      host,
      // `value` too: an input's new value is also read by that name (a
      // search field's `query = \${value}`).
      ValuesScope({'result': result, if (event.containsKey('value')) 'value': event['value']}, context.scope),
      cancellation ?? ActionCancellation(),
      node,
      event['value'],
    );
    // A clock can share its node with other clocks: gate each reaction,
    // rather than the whole trigger chain, against the current scope.
    bool clockRuns(Reaction reaction) {
      if(reaction.trigger.type!=TriggerType.clock || reaction.trigger.runWhen.trim().isEmpty)return true;
      final expression=reaction.trigger.runWhen;
      return (expression.contains(r'${') ? run.evaluate(expression) : run.expressions.formula(expression,run.scope))==true;
    }
    final actions = [for (final reaction in reactions) if(clockRuns(reaction)) ...reaction.actions];
    final scoped = handlers.isEmpty ? null : _HandlerOverrides(handlers);
    try {
      await (scoped == null
          ? runActions(actions, run)
          : runZoned(() => runActions(actions, run), zoneValues: {#codelesslyHandlers: scoped}));
    } on ActionsStopped catch (stop) {
      if (host case final RuntimeActionContext context) {
        context.onActionErrorEvent?.call(actionErrorEvent(stop, action: 'paywall'));
      }
    } on ActionsCanceled {
      // The node left: the rest doesn't run.
    } catch (error, stack) {
      host.reportError(error, stack, action: _failing(error));
    }
  }

  static String? _failing(Object error) => error is ActionFailed ? error.action : null;
}

class _HandlerOverrides {
  const _HandlerOverrides(this.handlers);
  final Map<String, ActionHandler> handlers;
}

/// Runs [actions] in [run]: each enabled one whose `when` holds, blocking
/// ones awaited. Throws (stopping the chain) when a blocking one fails or
/// the chain is canceled.
Future<void> runActions(List<ActionDef> actions, ActionRun run) async {
  for (final a in actions) {
    if (run.isCanceled) throw const ActionsCanceled();
    if (!a.enabled || a is UnknownAction) continue;
    if (a.when case final w? when !run.expressions.test(w, run.scope)) continue;
    if (a.nonBlocking) {
      unawaited(_perform(a, run).catchError((Object e, StackTrace s) {
        if (e is! ActionsCanceled) run.host.reportError(e, s, action: a.type);
      }));
    } else {
      await _perform(a, run);
    }
  }
}

Future<void> _perform(ActionDef a, ActionRun run) async {
  final overrides = Zone.current[#codelesslyHandlers] as _HandlerOverrides?;
  final handler = overrides?.handlers[a.type];
  try {
    if (handler != null) {
      await handler(a, run);
    } else {
      await handleAction(a, run);
    }
  } on ActionsCanceled {
    rethrow;
  } on ActionFailed {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(ActionFailed(a.type, error, nodeId: run.node?.id), stack);
  }
}

/// An [ActionHost] for a context that isn't one: no UI, no tree.
class _BareHost implements ActionHost {
  _BareHost(this.context);
  final ActionContext context;

  @override
  ValueScope get scope => context.scope;
  @override
  ExpressionEngine get expressions => context.expressions;
  @override
  CodelesslyServices get services => context.services;
  @override
  void setVariable(String name, Object? value) => context.setVariable(name, value);
  @override
  Future<void> navigate(Json action) => context.navigate(action);
  @override
  ActionUi get ui => const NoActionUi();
  @override
  Map<String, AppFunction> get functions => const {};
  @override
  get tree => null;
  @override
  get nodeValues => null;
  @override
  void onDispose(void Function() callback) {}
  @override
  ActionHost withScope(ValueScope scope) => this;
  @override
  void reportError(Object error, StackTrace stack, {String? action}) =>
      // ignore: avoid_print
      print('Codelessly: action ${action ?? ''} failed: $error');
}

/// The trigger types a node has reactions to.
Set<TriggerType> triggersOf(Node node) => {for (final r in node.actions) r.trigger.type};
