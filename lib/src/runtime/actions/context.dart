// The ActionContext a screen's actions run with: its value scope, the
// expression engine, the services, the UI (navigation, modals, toasts) and
// the screen's node tree.
import 'dart:async';

import 'package:codelessly_api/core.dart'
    show ActionDef, Json, NavigateAction, ScriptDef;
import 'package:flutter/foundation.dart';

import '../../render/node_tree.dart';
import '../../services/analytics.dart' show AnalyticsService;
import '../contracts.dart';
import '../expressions/engine.dart';
import '../expressions/variable_writes.dart';
import 'node_values.dart';
import 'action_error.dart';
import 'ui.dart';

export '../expressions/variable_writes.dart' show setVariableIn, typeOf, variableOf;

/// A function the app registers for call function actions: [params]
/// evaluated; its result is the chain's `${result}`.
typedef AppFunction = FutureOr<Object?> Function(ActionContext context, Json params);

/// What an action can reach beyond [ActionContext]: the UI, the app's
/// functions, the screen's node tree and runtime node values. A context
/// that isn't one gets [NoActionUi] and nothing else.
abstract interface class ActionHost implements ActionContext {
  ActionUi get ui;
  Map<String, AppFunction> get functions;

  /// The screen's node tree (scroll to a node, its text fields).
  RenderTree? get tree;

  /// Where set value and set variant actions put node values.
  NodeValues? get nodeValues;

  /// Runs when the screen goes (cloud data streams a load action opened).
  void onDispose(VoidCallback callback);

  /// This context reading from [scope] (a list item's) instead.
  ActionHost withScope(ValueScope scope);

  /// Reports an action that failed (its chain stopped).
  void reportError(Object error, StackTrace stack, {String? action});
}

/// The [ActionContext] (and [ActionHost]) of a screen, as the core runtime
/// knows it: no feature's fields. What the app shell gives a feature's
/// handlers rides in [extensions], found by type. `RuntimeActionContext`
/// (features/context.dart) is this with the first-party features' fields
/// as named parameters.
class CoreActionContext implements ActionHost {
  CoreActionContext({
    required this.scope,
    this.expressions = const Expressions(),
    CodelesslyServices? services,
    this.ui = const NoActionUi(),
    this.functions = const {},
    this.tree,
    this.nodeValues,
    this.onError,
    this.onActionErrorEvent,
    this.declareMissing = false,
    this.scripts = const [],
    this.extensions = const [],
    List<VoidCallback>? disposers,
    FailedActions? failed,
  })  : services = services ?? const _NoServices(),
        _disposers = disposers ?? [],
        failed = failed ?? FailedActions();

  /// The failed action chain the screen's `actionError` reaction can run
  /// again (`retryFailed`); shared by this context's copies.
  final FailedActions failed;

  @override
  final ValueScope scope;

  @override
  final ExpressionEngine expressions;

  @override
  final CodelesslyServices services;

  @override
  final ActionUi ui;

  @override
  final Map<String, AppFunction> functions;

  @override
  final RenderTree? tree;

  @override
  final NodeValues? nodeValues;

  /// Gets the errors of failed actions; null: logged to the services'
  /// analytics when they have it, else printed.
  final void Function(Object error, StackTrace stack, String? action)? onError;

  /// Whether [setVariable] declares a variable no scope declares (the app
  /// setting values), on the nearest variable scope. Actions only set
  /// declared variables.
  final bool declareMissing;

  /// Authored canvas error reactions; separate from the host's raw error
  /// callback. Omitted while running an error reaction to prevent recursion.
  final void Function(Json event)? onActionErrorEvent;

  final List<VoidCallback> _disposers;

  /// What [onDispose] registered: shared by this context's copies ([copy]).
  @protected
  List<VoidCallback> get disposers => _disposers;

  /// The scripts its run script actions run (the layout's).
  final List<ScriptDef> scripts;

  /// What the app shell attaches for its features' handlers, found by type
  /// ([extension]): the core carries them without reading them.
  final List<Object> extensions;

  /// The attachment of type [T], if any.
  T? extension<T extends Object>() {
    for (final e in extensions) {
      if (e is T) return e;
    }
    return null;
  }

  @override
  CoreActionContext withScope(ValueScope scope) => copy(scope);

  /// An error reaction keeps the same services, variables and host error
  /// callback, but cannot recursively dispatch more authored error events.
  CoreActionContext withoutActionErrorEvents() => copy(scope, suppressErrorEvents: true);

  /// This context over [scope] (without its error events, with
  /// [suppressErrorEvents]). A subclass overrides it to stay itself.
  @protected
  CoreActionContext copy(ValueScope scope, {bool suppressErrorEvents = false}) => CoreActionContext(
        scope: scope,
        expressions: expressions,
        services: services,
        ui: ui,
        functions: functions,
        tree: tree,
        nodeValues: nodeValues,
        onError: onError,
        onActionErrorEvent: suppressErrorEvents ? null : onActionErrorEvent,
        declareMissing: declareMissing,
        scripts: scripts,
        extensions: extensions,
        disposers: _disposers,
        failed: failed,
      );

  /// Sets variable [name] (or a path into one: `draft.title`, `rows[1]`) in
  /// the scope that declares it; the boxes that read it re-apply.
  @override
  void setVariable(String name, Object? value) => setVariableIn(scope, name, value, declare: declareMissing);

  @override
  Future<void> navigate(Json action) {
    final a = ActionDef.fromJson(action);
    if (a is! NavigateAction) return Future.value();
    return ui.navigate(a, params: a.params, baseParams: a.baseParams);
  }

  @override
  void onDispose(VoidCallback callback) => _disposers.add(callback);

  /// Runs what [onDispose] registered.
  void dispose() {
    for (final d in _disposers.reversed.toList()) {
      d();
    }
    _disposers.clear();
  }

  @override
  void reportError(Object error, StackTrace stack, {String? action}) {
    try {
      if (onError != null) {
        onError!(error, stack, action);
      } else {
        _logError(error, stack, action);
      }
    } catch (callbackError, callbackStack) {
      // Reporting must not break another gesture or recursively report itself.
      _logError(callbackError, callbackStack, 'host_error_callback');
    }
    // The chain that just failed (the runner set it), if it can run again:
    // the error reaction's `retryFailed` runs it.
    final retry = failed.pending;
    failed.pending = null;
    failed.last = retry;
    try {
      onActionErrorEvent?.call(actionErrorEvent(error, action: action, retryable: retry != null));
    } catch (callbackError, callbackStack) {
      _logError(callbackError, callbackStack, 'action_error_callback');
    }
  }

  void _logError(Object error, StackTrace stack, String? action) {
    final analytics = services.lookup<AnalyticsService>();
    if (analytics != null) {
      analytics.logError(error, stackTrace: stack, message: 'Action ${action ?? ''} failed', type: 'action_failed');
      return;
    }
    debugPrint('Codelessly: action ${action ?? ''} failed: $error');
  }
}

class _NoServices implements CodelesslyServices {
  const _NoServices();

  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async => null;

  @override
  Future<bool> openUrl(String url) async => false;
}

/// A failed action chain that can run again (see [CoreActionContext.failed]).
class FailedActions {
  /// Set by the runner just before it reports the chain's failure.
  Future<void> Function()? pending;

  /// The latest reported failure's chain, if it can run again.
  Future<void> Function()? last;

  /// Runs [last] again (once); whether there was one.
  bool retry() {
    final run = last;
    last = null;
    if (run == null) return false;
    unawaited(run());
    return true;
  }
}
