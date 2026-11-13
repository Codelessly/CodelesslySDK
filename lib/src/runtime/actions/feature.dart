// The plugin seam: a feature layer (auth, cloud data, commerce, media...)
// is a CodelesslyFeature, and the core runtime runs whatever features it's
// given without knowing any of them. Nothing here, or anywhere else in the
// core runtime, imports a feature (test/feature_isolation_test.dart).
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show ActionDef, CallFunctionAction;

import '../contracts.dart';
import '../expressions/scopes.dart' show NamedScope;
import 'runner.dart' show ActionRun;

/// Runs one action of a chain. Throws to stop the chain.
typedef ActionHandler = FutureOr<void> Function(ActionDef action, ActionRun run);

/// A function a feature gives call function actions, by name (`media.probe`):
/// what it returns is the chain's `${result}`. An app function of the same
/// name (`CodelesslyConfig.functions`) runs instead.
typedef FeatureFunction = FutureOr<Object?> Function(CallFunctionAction action, ActionRun run);

/// Builds a feature's value scope (what expressions read by its name) over
/// [parent], for the app [host] describes.
typedef FeatureScopeBuilder = NamedScope Function(FeatureScopeHost host, ValueScope parent);

/// One feature layer over the core runtime: the action types it runs, the
/// functions it gives call function actions, and the named values it gives
/// expressions. The core runs a document's `auth` action by finding the
/// handler some installed feature registered for `auth`; with no such
/// feature the action fails saying so.
///
/// ```dart
/// const analytics = CodelesslyFeature(
///   name: 'analytics',
///   actions: {'acme.track': _track},
///   functions: {'acme.sessionId': _sessionId},
/// );
///
/// CodelesslyConfig(actions: CodelesslyActions(features: [...kFirstPartyFeatures, analytics]));
/// ```
class CodelesslyFeature {
  const CodelesslyFeature({
    required this.name,
    this.actions = const {},
    this.functions = const {},
    this.scopes = const {},
  });

  /// What it's called (`auth`, `commerce`), for messages.
  final String name;

  /// Its handlers by action type (`auth`, `cloudData`, or a type the API
  /// doesn't declare: an `UnknownAction`'s).
  final Map<String, ActionHandler> actions;

  /// Its call function names.
  final Map<String, FeatureFunction> functions;

  /// Its value scopes by the name expressions read (`auth`, `storage`).
  final Map<String, FeatureScopeBuilder> scopes;

  @override
  String toString() => 'CodelesslyFeature($name)';
}

/// A scope that follows the signed-in account (entitlements). The scope that
/// knows the account ([FeatureScopeHost.accountChanged]) tells it, so the
/// two need not know each other.
abstract interface class AccountBound {
  /// The account is now [uid] (null: signed out); [reset] drops what was
  /// kept for the account before.
  void accountChanged(String? uid, {bool reset = false});
}

/// What a feature's scope is built for: the app's services and the other
/// feature scopes of the same app.
class FeatureScopeHost {
  FeatureScopeHost(this.services);

  final CodelesslyServices services;

  final Map<String, NamedScope> _scopes = {};
  bool _hasAccount = false;
  String? _uid;

  /// The feature scope expressions read as [name], if a feature gave one.
  NamedScope? operator [](String name) => _scopes[name];

  /// The feature scopes, innermost first.
  Iterable<NamedScope> get scopes => _scopes.values.toList().reversed;

  /// Builds [features]' scopes as one chain over [parent]; returns its
  /// innermost scope ([parent] when they give none).
  ValueScope build(Iterable<CodelesslyFeature> features, ValueScope parent) {
    var scope = parent;
    for (final feature in features) {
      for (final entry in feature.scopes.entries) {
        if (_scopes.containsKey(entry.key)) continue;
        final built = _scopes[entry.key] = entry.value(this, scope);
        // A scope built after the account was told hears it now.
        if (_hasAccount && built is AccountBound) (built as AccountBound).accountChanged(_uid);
        scope = built;
      }
    }
    return scope;
  }

  /// Tells every [AccountBound] scope the signed-in account.
  void accountChanged(String? uid, {bool reset = false}) {
    _hasAccount = true;
    _uid = uid;
    for (final scope in _scopes.values) {
      if (scope case final AccountBound bound) bound.accountChanged(uid, reset: reset);
    }
  }

  /// Disposes the feature scopes, innermost first.
  void dispose() {
    for (final scope in scopes) {
      scope.dispose();
    }
    _scopes.clear();
  }
}
