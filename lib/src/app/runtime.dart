// What the app shell runs screens with, beside the runtime itself
// (Expressions, CodelesslyActions, Services: CodelesslyConfig's defaults):
// opt-outs that do nothing (a layout as designed), the app's data scope, a
// node source for an expression engine of the app's own, and a screen's
// action context.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Json, NavigateAction, Node, OpenLinkAction, PublishLayout, jsonEquality;
import 'package:flutter/foundation.dart';

import '../render/source.dart';
import '../runtime/actions/context.dart';
import '../runtime/contracts.dart';

/// An [ExpressionEngine] that evaluates nothing: text stays as written and
/// nodes as designed.
class NoopExpressionEngine implements ExpressionEngine {
  const NoopExpressionEngine();

  @override
  Object? evaluate(String expression, ValueScope scope) => expression;

  @override
  String interpolate(String text, ValueScope scope) => text;

  @override
  (Node, Set<String>) resolve(Node node, ValueScope scope) => (node, const {});
}

/// An [ActionRunner] that runs nothing.
class NoopActionRunner implements ActionRunner {
  const NoopActionRunner();

  @override
  Future<void> trigger(Node node, String trigger, ActionContext context, {Json event = const {}}) async {}
}

/// An [ActionRunner] that runs only navigation (`navigate`) and links
/// (`openLink`): moving between the screens of an app without running
/// anything else. Every other action is skipped.
class NavigationActionRunner implements ActionRunner {
  const NavigationActionRunner();

  @override
  Future<void> trigger(Node node, String trigger, ActionContext context, {Json event = const {}}) async {
    for (final reaction in node.actions) {
      if (reaction.trigger.type.name != trigger) continue;
      for (final action in reaction.actions) {
        switch (action) {
          case NavigateAction():
            await context.navigate(action.toJson());
          case OpenLinkAction(:final url) when url.isNotEmpty:
            await context.services.openUrl(url);
          default:
        }
      }
    }
  }
}

/// Whether [node] has a reaction to [trigger].
bool reactsTo(Node node, String trigger) => node.actions.any((r) => r.trigger.type.name == trigger);

/// [CodelesslyServices] that call nothing: APIs return null and links don't
/// open. Apps configure real ones (HTTP, Firebase, url_launcher...).
class NoServices implements CodelesslyServices {
  const NoServices();

  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async => null;

  @override
  Future<bool> openUrl(String url) async => false;
}

/// A [ValueScope] over a map of named values: the app's data, a screen's
/// variables and route params. Paths read into maps and lists
/// (`user.name`, `items[0].price`, `items.0`); a name this scope doesn't
/// hold is read from [parent].
class MapValueScope extends ChangeNotifier implements ValueScope {
  MapValueScope({Map<String, Object?> values = const {}, this.parent}) : _values = {...values} {
    parent?.addListener(notifyListeners);
  }

  final Map<String, Object?> _values;

  @override
  final ValueScope? parent;

  /// The values this scope holds (not its parent's).
  Map<String, Object?> get values => Map.unmodifiable(_values);

  /// Whether this scope holds [name].
  bool declares(String name) => _values.containsKey(name);

  /// Sets [name] here and notifies, when it changes.
  void set(String name, Object? value) {
    if (_values.containsKey(name) && _deepEquals(_values[name], value)) return;
    _values[name] = value;
    notifyListeners();
  }

  /// Sets several values at once (one notification).
  void setAll(Map<String, Object?> values) {
    var changed = false;
    for (final e in values.entries) {
      if (_values.containsKey(e.key) && _deepEquals(_values[e.key], e.value)) continue;
      _values[e.key] = e.value;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// The scope (this or an ancestor) holding [name], or null.
  MapValueScope? scopeOf(String name) {
    ValueScope? s = this;
    while (s != null) {
      if (s is MapValueScope && s.declares(name)) return s;
      s = s.parent;
    }
    return null;
  }

  @override
  Object? read(String path) {
    final segments = pathSegments(path);
    if (segments.isEmpty) return null;
    if (!_values.containsKey(segments.first)) return parent?.read(path);
    Object? v = _values[segments.first];
    for (final s in segments.skip(1)) {
      v = switch (v) {
        final Map m => m[s],
        final List l => int.tryParse(s).let((i) => i != null && i >= 0 && i < l.length ? l[i] : null),
        _ => null,
      };
      if (v == null) return null;
    }
    return v;
  }

  @override
  void dispose() {
    parent?.removeListener(notifyListeners);
    super.dispose();
  }

  /// `a.b[0].c` → `[a, b, 0, c]`.
  static List<String> pathSegments(String path) => [
        for (final s in path.replaceAll('[', '.').replaceAll(']', '').split('.'))
          if (s.trim().isNotEmpty) s.trim(),
      ];

  static bool _deepEquals(Object? a, Object? b) => jsonEquality.equals(a, b);
}

/// The initial values of the variables canvas [canvasId] of [layout]
/// declares, by name.
Map<String, Object?> initialVariables(PublishLayout layout, String canvasId) => {
      for (final v in layout.variablesOf(canvasId))
        if (!v.isComputed) v.name: v.value,
    };

/// A [NodeSource] over [base] with each node's bindings applied by
/// [engine] in [scope]. A node re-resolves when its source node changes, or
/// when the scope changes and its last resolution read a value.
class BoundSource implements NodeSource {
  BoundSource(this.base, this.engine, this.scope) {
    scope.addListener(_scopeChanged);
  }

  final NodeSource base;
  final ExpressionEngine engine;
  final ValueScope scope;

  final Map<String, ValueNotifier<Node?>> _watched = {};
  final Map<String, VoidCallback> _baseListeners = {};
  final Map<String, (Node, Node, Set<String>)> _resolved = {};

  /// Whether nothing is bound (the engine resolves every node as is).
  bool get _identity => engine is NoopExpressionEngine;

  Node? _resolve(String id) {
    final n = base.node(id);
    if (n == null || _identity) return n;
    final cached = _resolved[id];
    if (cached != null && identical(cached.$1, n)) return cached.$2;
    final (out, reads) = engine.resolve(n, scope);
    _resolved[id] = (n, out, reads);
    return out;
  }

  @override
  Node? node(String id) => _resolve(id);

  @override
  String? parentOf(String id) => base.parentOf(id);

  @override
  ValueListenable<Node?> watch(String id) {
    final existing = _watched[id];
    if (existing != null) return existing;
    final notifier = ValueNotifier<Node?>(_resolve(id));
    final source = base.watch(id);
    void changed() => notifier.value = _resolve(id);
    source.addListener(changed);
    _baseListeners[id] = () => source.removeListener(changed);
    return _watched[id] = notifier;
  }

  void _scopeChanged() {
    if (_identity) return;
    for (final e in _watched.entries) {
      final cached = _resolved[e.key];
      if (cached != null && cached.$3.isEmpty) continue;
      _resolved.remove(e.key);
      e.value.value = _resolve(e.key);
    }
  }

  void dispose() {
    scope.removeListener(_scopeChanged);
    for (final remove in _baseListeners.values) {
      remove();
    }
    _baseListeners.clear();
    for (final n in _watched.values) {
      n.dispose();
    }
    _watched.clear();
  }
}

/// The [ActionContext] of one screen: its variables (over the route's
/// params and the app's data), services, UI and node tree. The app can set
/// variables no screen declares ([RuntimeActionContext.declareMissing]).
class ScreenActionContext extends RuntimeActionContext {
  ScreenActionContext({
    required super.scope,
    required super.expressions,
    required super.services,
    required super.ui,
    super.functions,
    super.tree,
    super.nodeValues,
    super.onError,
    super.scripts,
  }) : super(declareMissing: true);
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
