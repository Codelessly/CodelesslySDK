// The ActionContext a screen's actions run with: its value scope, the
// expression engine, the services, the UI (navigation, modals, toasts) and
// the screen's node tree.
import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart' show ActionDef, Json, NavigateAction, Variable, VariableType;
import 'package:flutter/foundation.dart';

import '../../render/node_tree.dart';
import '../../services/services.dart';
import '../contracts.dart';
import '../expressions/engine.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'node_values.dart';
import 'ui.dart';
import 'values.dart';

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
  NodeTree? get tree;

  /// Where set value and set variant actions put node values.
  NodeValues? get nodeValues;

  /// Runs when the screen goes (cloud data streams a load action opened).
  void onDispose(VoidCallback callback);

  /// This context reading from [scope] (a list item's) instead.
  ActionHost withScope(ValueScope scope);

  /// Reports an action that failed (its chain stopped).
  void reportError(Object error, StackTrace stack, {String? action});
}

/// The [ActionContext] (and [ActionHost]) of a screen.
class RuntimeActionContext implements ActionHost {
  RuntimeActionContext({
    required this.scope,
    this.expressions = const Expressions(),
    CodelesslyServices? services,
    this.ui = const NoActionUi(),
    this.functions = const {},
    this.tree,
    this.nodeValues,
    this.onError,
    this.declareMissing = false,
    this.paywall,
    List<VoidCallback>? disposers,
  })  : services = services ?? const _NoServices(),
        _disposers = disposers ?? [];

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
  final NodeTree? tree;

  @override
  final NodeValues? nodeValues;

  /// Gets the errors of failed actions; null: logged to the services'
  /// analytics when they have it, else printed.
  final void Function(Object error, StackTrace stack, String? action)? onError;

  /// Whether [setVariable] declares a variable no scope declares (the app
  /// setting values), on the nearest variable scope. Actions only set
  /// declared variables.
  final bool declareMissing;

  final List<VoidCallback> _disposers;

  /// The paywall a paywall screen's actions act on.
  final PaywallSession? paywall;

  @override
  RuntimeActionContext withScope(ValueScope scope) => RuntimeActionContext(
        scope: scope,
        expressions: expressions,
        services: services,
        ui: ui,
        functions: functions,
        tree: tree,
        nodeValues: nodeValues,
        onError: onError,
        declareMissing: declareMissing,
        paywall: paywall,
        disposers: _disposers,
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
    if (onError != null) return onError!(error, stack, action);
    final s = services;
    if (s is Services) {
      s.analytics.logError(error, stackTrace: stack, message: 'Action ${action ?? ''} failed', type: 'action_failed');
      return;
    }
    debugPrint('Codelessly: action ${action ?? ''} failed: $error');
  }
}

/// Sets [name] (a variable, or a path into one) in the [VariableScope] of
/// [scope]'s chain that declares its root. With [declare], a variable no
/// scope declares is declared on the nearest variable scope. Returns
/// whether a variable changed.
bool setVariableIn(ValueScope scope, String name, Object? value, {bool declare = false}) {
  final path = ValuePath.parse(name.trim());
  if (path == null) return false;
  for (ValueScope? s = scope; s != null; s = s.parent) {
    if (s is VariableScope && s.declares(path.root)) {
      if (path.keys.isEmpty) return s.set(path.root, value);
      final root = s.valueOf(path.root, s);
      final next = setAtPath(root, path.keys, value);
      return next != null && s.set(path.root, next);
    }
    if (s is NamedScope && s.declares(path.root)) {
      if (s is ValuesScope && path.keys.isEmpty) {
        s.set(path.root, value);
        return true;
      }
      return false;
    }
  }
  if (!declare || path.keys.isNotEmpty) return false;
  for (ValueScope? s = scope; s != null; s = s.parent) {
    if (s is VariableScope) {
      s.define(Variable(name: path.root, type: typeOf(value), value: value));
      return true;
    }
  }
  return false;
}

/// The variable type that holds [value].
VariableType typeOf(Object? value) => switch (value) {
      int() => VariableType.integer,
      double() => VariableType.decimal,
      bool() => VariableType.boolean,
      List() => VariableType.list,
      Map() => VariableType.map,
      _ => VariableType.text,
    };

/// The variable [name]'s root declares, and its scope, from [scope].
(VariableScope, Variable)? variableOf(ValueScope scope, String name) {
  final root = rootOf(name);
  for (ValueScope? s = scope; s != null; s = s.parent) {
    if (s is VariableScope && s.declares(root)) return (s, s.variable(root)!);
    if (s is NamedScope && s.declares(root)) return null;
  }
  return null;
}

class _NoServices implements CodelesslyServices {
  const _NoServices();

  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async => null;

  @override
  Future<bool> openUrl(String url) async => false;
}
