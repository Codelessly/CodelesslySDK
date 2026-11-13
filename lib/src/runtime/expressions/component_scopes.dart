// The scopes of a component instance (codelessly_api
// docs/design/06-sections-and-components.md §4.4, §6.2): a definition reads
// its parameters as `${props.x}`, its own variables (one set per instance,
// like a Flutter `State`), the project's variables and the runtime's scopes
// (`screen`, `route`, `theme`, `auth`...), and never its caller's variables.
// A `variable` parameter is a reference to a variable of the caller's scope
// (a `ValueNotifier` passed in): read live, written through.
import 'package:codelessly_api/core.dart' show ComponentDocument, Node, PropDef, jsonEquality;
import 'package:flutter/foundation.dart';

import '../../render/components.dart' show InstanceSource;
import '../contracts.dart';
import 'paths.dart';
import 'perf_scope.dart';
import 'scopes.dart';
import 'variable_writes.dart';

/// The three scopes of one instance: [variables] over [props] over
/// [ambient].
final class ComponentScopes {
  ComponentScopes(InstanceSource source, ValueScope caller,
      {ValueScope? project, required ValueScope? Function() callerScope}) {
    ambient = AmbientScope(caller, project: project);
    props = ComponentProps(source, callerScope, parent: ambient);
    variables = VariableScope(source.definition.document.componentVariables, parent: props);
  }

  /// What the instance reads around its own names.
  late final AmbientScope ambient;

  /// `props`.
  late final ComponentProps props;

  /// The definition's variables, this instance's values.
  late final VariableScope variables;

  void dispose() {
    variables.dispose();
    props.dispose();
    ambient.dispose();
  }
}

/// `props`: the call's parameters, bound in the caller's scope (a literal in
/// its `props`, or its `bind`'s `props.<key>`), each read as the
/// declaration's JSON (a `Color` as `#AARRGGBB`); an unset one is its
/// default. A `variable` parameter reads the caller's variable it names, and
/// writing `props.<key>` writes that variable. Notifies `props` when a value
/// changes (the call re-bound, the call edited, a passed variable set).
class ComponentProps extends NamedScope implements ReferenceScope {
  ComponentProps(this.source, this._callerScope, {super.parent});

  final InstanceSource source;
  final ValueScope? Function() _callerScope;

  Map<String, Object?>? _values;

  /// `variable` parameters: key → (the caller's scope, the variable's name).
  final Map<String, (ValueScope, String)> _references = {};
  List<Listenable> _inputs = const [];
  Listenable? _listening;
  bool _disposed = false;

  @override
  bool declares(String name) => name == 'props';

  @override
  Object? valueOf(String name, ValueScope reader) => name == 'props' ? (_values ??= _compute()) : null;

  Map<String, Object?> _compute() {
    final bound = source.resolveCall();
    final Node? call = bound?.node ?? source.call;
    final spec = source.definition.spec;
    final inputs = <Listenable>[...?bound?.watch, source.callSource.watch(source.instance.call)];
    _references.clear();
    final values = <String, Object?>{};
    if (call != null) {
      ValueScope? caller;
      for (final PropDef<Object?> p in spec.props) {
        final v = call.props.get(p);
        if (p.type.isVariable) {
          final name = '${v ?? ''}'.trim();
          if (name.isEmpty) {
            values[p.key] = null;
            continue;
          }
          caller ??= _callerScope();
          if (caller == null) continue;
          _references[p.key] = (caller, name);
          values[p.key] = readPath(caller, name);
          if (watchName(caller, rootOf(name)) case final Listenable w) inputs.add(w);
          continue;
        }
        try {
          values[p.key] = v == null ? null : p.encode(v);
        } catch (_) {
          values[p.key] = v;
        }
      }
      // Undeclared keys (a call decoded without the declaration) as written.
      for (final e in call.props.unknown.entries) {
        values.putIfAbsent(e.key, () => e.value);
      }
    }
    _listen(inputs);
    return values;
  }

  void _listen(List<Listenable> inputs) {
    if (_disposed || listEquals(inputs, _inputs)) return;
    _listening?.removeListener(_inputChanged);
    _inputs = inputs;
    _listening = Listenable.merge(inputs)..addListener(_inputChanged);
  }

  void _inputChanged() {
    if (_disposed) return;
    final before = _values;
    final next = _compute();
    _values = next;
    if (before == null || !jsonEquality.equals(before, next)) changed(const ['props']);
  }

  @override
  (ValueScope, String)? reference(String path) {
    final p = ValuePath.parse(path);
    if (p == null || p.root != 'props' || p.keys.isEmpty) return null;
    valueOf('props', this);
    final key = p.keys.first;
    final ref = key is String ? _references[key] : null;
    if (ref == null) return null;
    final t = path.trim();
    final head = 'props.$key';
    if (!t.startsWith(head)) return null;
    return (ref.$1, '${ref.$2}${t.substring(head.length)}');
  }

  @override
  void dispose() {
    _disposed = true;
    _listening?.removeListener(_inputChanged);
    _listening = null;
    super.dispose();
  }
}

/// What a component instance reads around its own names: the scopes around
/// its caller's ([around]) without the caller's variables, list items and
/// node scopes, down to the project's variables ([project]) and everything
/// around them. A name is answered by the first scope that may and does
/// declare it, and watched there.
class AmbientScope extends NamedScope implements ReferenceScope {
  AmbientScope(this.around, {ValueScope? project}) : project = project ?? _outermostVariables(around);

  final ValueScope around;

  /// The project's variables: the first variable scope it reads.
  final ValueScope? project;

  /// The outermost variable scope around [scope] when there are several
  /// (the app's, under a page's); null when there is one or none (it is
  /// the page's own).
  static ValueScope? _outermostVariables(ValueScope scope) {
    ValueScope? last;
    var count = 0;
    for (ValueScope? s = scope; s != null; s = s.parent) {
      if (s is VariableScope) {
        last = s;
        count++;
      }
    }
    return count > 1 ? last : null;
  }

  /// The scope that answers [name] for an instance, or null.
  ValueScope? declaring(String name) {
    var open = false;
    for (ValueScope? s = around; s != null; s = s.parent) {
      if (s is AmbientScope) return s.declaring(name);
      if (identical(s, project)) open = true;
      if (s is NamedScope) {
        // The caller's own names (its variables, items, node scopes, a
        // page's scripts) stay with it; ambient values pass.
        if (!open && !(s is ValuesScope || s is PerfScope)) continue;
        if (s.declares(name)) return s;
      } else if (s.read(name) != null) {
        return s;
      }
    }
    return null;
  }

  @override
  bool declares(String name) => declaring(name) != null;

  @override
  Object? valueOf(String name, ValueScope reader) {
    final s = declaring(name);
    if (s == null) return null;
    return s is NamedScope ? s.valueOf(name, reader) : s.read(name);
  }

  @override
  Listenable watch(String name) {
    final s = declaring(name);
    return (s == null ? null : watchName(s, name)) ?? super.watch(name);
  }

  @override
  (ValueScope, String)? reference(String path) {
    final s = declaring(rootOf(path));
    return s == null ? null : (s, path);
  }
}
