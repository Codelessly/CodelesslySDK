// The runtime's seams. Each is implemented by one runtime area, so the areas
// can be built (and swapped, and tested) separately:
//
// * runtime/expressions: [ValueScope], [ExpressionEngine], bindings.
// * runtime/actions: [ActionRunner].
// * services: [CodelesslyServices] (data, network, auth, storage, analytics).
// * app: Codelessly, CodelesslyWidget, navigation, publish loading.
//
// No BuildContext crosses these seams: the runtime runs headless and in tests.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Json, Node;
import 'package:flutter/foundation.dart';

/// Values expressions read: variables, the current list item, route
/// params, data. Scopes nest (a list item's scope over its screen's).
abstract interface class ValueScope implements Listenable {
  /// The value at [path] (`user.name`, `item.price`), or null.
  Object? read(String path);

  /// The enclosing scope.
  ValueScope? get parent;
}

/// Evaluates `${...}` text and formulas against a [ValueScope].
abstract interface class ExpressionEngine {
  /// [expression] (`${user.name}`, `${= price * qty}`) as a value.
  Object? evaluate(String expression, ValueScope scope);

  /// [text] with every `${...}` replaced by its value's text.
  String interpolate(String text, ValueScope scope);

  /// [node] with its bound properties ([Node.bind]) applied, read in
  /// [scope]; the paths each binding read, to rebuild when they change.
  (Node, Set<String> reads) resolve(Node node, ValueScope scope);
}

/// Runs a node's reactions ([Node.actions]).
abstract interface class ActionRunner {
  /// Runs the actions of [node] whose trigger is [trigger] (`click`,
  /// `load`, `changed`...), with [event] values (`value`, `index`...).
  Future<void> trigger(Node node, String trigger, ActionContext context, {Json event = const {}});
}

/// What an action can do, without a BuildContext.
abstract interface class ActionContext {
  ValueScope get scope;
  ExpressionEngine get expressions;
  CodelesslyServices get services;

  /// Sets variable [name] (in the scope that declares it).
  void setVariable(String name, Object? value);

  /// Navigation (implemented by the app shell).
  Future<void> navigate(Json action);
}

/// Pluggable services, configured by the app (Firebase, HTTP, mocks).
abstract interface class CodelesslyServices {
  /// Calls a configured API (`apis` in the publish model).
  Future<Object?> callApi(String apiId, {Json params = const {}});

  /// Opens [url] (links).
  Future<bool> openUrl(String url);
}

/// Services that give their parts by type: how a feature reaches its own
/// service (`service<AuthService>()`) without the runtime knowing which
/// services there are. `Services` is one.
abstract interface class ServiceLocator {
  /// The service of type [T], or null when there is none.
  T? service<T extends Object>();
}

/// [ServiceLocator.service] on any services (null when they aren't a locator).
extension ServiceLookup on CodelesslyServices {
  T? lookup<T extends Object>() => switch (this) {
        final ServiceLocator locator => locator.service<T>(),
        _ => null,
      };
}
