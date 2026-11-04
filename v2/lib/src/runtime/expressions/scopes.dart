// Value scopes: where expressions read names from. A screen's variables, a
// list item (`item`, `index`, `parent`), fixed values the app provides
// (`route`, `screen`, `storage`, `auth`...). Scopes nest; a name is read
// from the nearest scope that declares it, and each name can be watched on
// its own, so a change re-applies only what read it.
import 'package:codelessly_api/codelessly_api.dart' show Variable, VariableType;
import 'package:flutter/foundation.dart';

import '../contracts.dart';
import 'formula.dart';
import 'paths.dart';

/// A scope that declares its names: the nearest scope declaring a path's
/// root answers it, and each name is watched on its own.
abstract class NamedScope extends ChangeNotifier implements ValueScope {
  NamedScope({this.parent});

  @override
  final ValueScope? parent;

  /// Whether this scope answers [name] (even with null).
  bool declares(String name);

  /// The value of [name] as read from [reader] (this scope or one nested in
  /// it): a computed value reads its inputs through [reader].
  Object? valueOf(String name, ValueScope reader);

  /// Notifies when [name]'s value may have changed.
  Listenable watch(String name) => _watchers.putIfAbsent(name, _Notifier.new);

  final Map<String, _Notifier> _watchers = {};

  /// Notifies the watchers of [names], then this scope's listeners.
  @protected
  void changed(Iterable<String> names) {
    for (final n in names.toSet()) {
      _watchers[n]?.notify();
    }
    notifyListeners();
  }

  @override
  Object? read(String path) => readPath(this, path);

  @override
  void dispose() {
    for (final w in _watchers.values) {
      w.dispose();
    }
    _watchers.clear();
    super.dispose();
  }
}

class _Notifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// The value at [path] (`user.name`, `cart[0].qty`) read from [scope] and
/// the scopes around it. A path that indexes by a value
/// (`pal[item.key]`) is evaluated as a formula.
Object? readPath(ValueScope? scope, String path) {
  if (scope == null) return null;
  final p = ValuePath.parse(path);
  if (p == null) {
    return FormulaEvaluator.evaluate(path, (inner) => ValuePath.parse(inner) == null ? null : readPath(scope, inner));
  }
  for (ValueScope? s = scope; s != null; s = s.parent) {
    if (s is NamedScope) {
      if (s.declares(p.root)) return p.readFrom(s.valueOf(p.root, scope));
    } else {
      final v = s.read(path);
      if (v != null) return v;
    }
  }
  return null;
}

/// What tells [scope]'s readers that [name] changed: the declaring scope's
/// watcher, a scope that doesn't declare its names itself, or null when no
/// scope declares it.
Listenable? watchName(ValueScope? scope, String name) {
  for (ValueScope? s = scope; s != null; s = s.parent) {
    if (s is NamedScope) {
      if (s.declares(name)) return s.watch(name);
    } else {
      return s;
    }
  }
  return null;
}

/// The root name of a path (`cart` of `cart[0].qty`).
String rootOf(String path) {
  final m = RegExp(r'^\s*([A-Za-z_$][\w$]*)').firstMatch(path);
  return m?[1] ?? path.trim();
}

/// A screen's variables: their current values, starting at their defaults.
/// Computed variables (a formula) are worked out when read, from the scope
/// that reads them, and notify when what they read changes.
class VariableScope extends NamedScope {
  VariableScope(Iterable<Variable> variables, {super.parent, Map<String, Object?> values = const {}}) {
    for (final v in variables) {
      _defs[v.name] = v;
    }
    _values.addAll({for (final v in _defs.values) v.name: v.value});
    values.forEach(set);
    _indexDependents();
  }

  final Map<String, Variable> _defs = {};
  final Map<String, Object?> _values = {};

  /// Computed variable → the names its formula reads.
  final Map<String, Set<String>> _reads = {};

  /// Name → the computed variables that read it, directly or not.
  final Map<String, Set<String>> _dependents = {};
  int _version = 0;

  Iterable<Variable> get variables => _defs.values;
  Variable? variable(String name) => _defs[name];

  @override
  bool declares(String name) => _defs.containsKey(name);

  /// The current values of the plain (not computed) variables.
  Map<String, Object?> get values => Map.unmodifiable(_values);

  /// Declares [v] (replacing a variable of its name), at its default value.
  void define(Variable v) {
    _defs[v.name] = v;
    _values[v.name] = v.value;
    _indexDependents();
    _cache.clear();
    _version++;
    changed([v.name, ...?_dependents[v.name]]);
  }

  /// Sets [name] to [value], read as the variable's type (a number from
  /// `"3"`, a color from `#F00`...). Ignored for an undeclared or computed
  /// variable; false then, or when nothing changed.
  bool set(String name, Object? value) {
    final v = _defs[name];
    if (v == null || v.isComputed) return false;
    final next = value == null ? null : (v.type.coerce(value) ?? _loose(v.type, value));
    // A value the type can't hold leaves the variable as it was (v1 kept it).
    if (value != null && next == null) return false;
    if (_same(_values[name], next)) return false;
    _values[name] = next;
    _version++;
    changed([name, ...?_dependents[name]]);
    return true;
  }

  /// Sets [name] back to its default.
  bool reset(String name) => _defs[name] == null ? false : set(name, _defs[name]!.value);

  static Object? _loose(VariableType type, Object value) => switch (type) {
        // A list or map variable takes JSON text too.
        VariableType.list || VariableType.map when value is String => type.coerce(parseLoose(value)),
        _ => null,
      };

  static bool _same(Object? a, Object? b) =>
      identical(a, b) || (a is! List && a is! Map && a == b);

  @override
  Object? valueOf(String name, ValueScope reader) {
    final v = _defs[name];
    if (v == null) return null;
    if (!v.isComputed) return _values[name];
    if (v.isFunction) {
      return FormulaFunction(v.parameters, v.formula, (p) => readPath(reader, p));
    }
    return _computed(v, reader);
  }

  final Map<String, (int, Object?)> _cache = {};
  final Set<String> _computing = {};

  Object? _computed(Variable v, ValueScope reader) {
    // A formula reading only this scope's variables gives the same value
    // whoever reads it: worked out once per change. One reading the clock
    // or other scopes' names (an item) is worked out per read.
    final local = _isLocal(v.name, {});
    if (local) {
      final cached = _cache[v.name];
      if (cached != null && cached.$1 == _version) return cached.$2;
    }
    if (!_computing.add(v.name)) return null;
    try {
      final value = FormulaEvaluator.evaluate(v.formula, (p) => readPath(local ? this : reader, p));
      // Only a top-level read: one inside a cycle saw a partial value.
      if (local && _computing.length == 1) _cache[v.name] = (_version, value);
      return value;
    } finally {
      _computing.remove(v.name);
    }
  }

  bool _isLocal(String name, Set<String> seen) {
    final v = _defs[name];
    if (v == null) return false;
    if (!v.isComputed) return true;
    if (!seen.add(name)) return true;
    if (FormulaEvaluator.readsClock(v.formula) || FormulaEvaluator.readsFrameClock(v.formula)) return false;
    return (_reads[name] ?? const {}).every((r) => _isLocal(r, seen));
  }

  void _indexDependents() {
    _reads.clear();
    _dependents.clear();
    for (final v in _defs.values) {
      if (!v.isComputed) continue;
      final paths = v.isFunction
          ? FormulaFunction(v.parameters, v.formula, (_) => null).externalPaths
          : FormulaEvaluator.referencedPaths(v.formula);
      _reads[v.name] = {...paths.map(rootOf), ...FormulaEvaluator.userFunctionCalls(v.formula)};
    }
    for (final name in _reads.keys) {
      // Every name [name] reads, through other computed variables.
      final seen = <String>{};
      final stack = [..._reads[name]!];
      while (stack.isNotEmpty) {
        final r = stack.removeLast();
        if (!seen.add(r)) continue;
        (_dependents[r] ??= {}).add(name);
        stack.addAll(_reads[r] ?? const {});
      }
    }
  }

  /// The names a computed variable reads that this scope doesn't declare
  /// (an item, the route...): who reads it watches those too.
  Set<String> foreignReads(String name) {
    final out = <String>{};
    final seen = <String>{};
    final stack = [name];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      if (!seen.add(n)) continue;
      for (final r in _reads[n] ?? const <String>{}) {
        _defs.containsKey(r) ? stack.add(r) : out.add(r);
      }
    }
    return out;
  }
}

/// Fixed values by name, set by the app: `route` (the route's params),
/// `screen` (its size and breakpoint), `storage`, `auth`, `data`, `value`...
class ValuesScope extends NamedScope {
  ValuesScope([Map<String, Object?> values = const {}, ValueScope? parent]) : super(parent: parent) {
    _values.addAll(values);
  }

  final Map<String, Object?> _values = {};

  @override
  bool declares(String name) => _values.containsKey(name);

  @override
  Object? valueOf(String name, ValueScope reader) => _values[name];

  Object? operator [](String name) => _values[name];

  /// Sets (declares) [name].
  void set(String name, Object? value) {
    if (_values.containsKey(name) && identical(_values[name], value)) return;
    _values[name] = value;
    changed([name]);
  }

  void remove(String name) {
    if (_values.remove(name) != null) changed([name]);
  }
}

/// One item of a repeating widget (a list, grid or page view built from
/// data): `item`, `index`, and `parent` (the item around it: `parent.item`,
/// `parent.index`).
class ItemScope extends NamedScope {
  ItemScope({required this._index, this._item, super.parent});

  int _index;
  Object? _item;

  int get index => _index;
  Object? get item => _item;

  static const _names = {'item', 'index', 'parent'};

  @override
  bool declares(String name) => _names.contains(name);

  @override
  Object? valueOf(String name, ValueScope reader) => switch (name) {
        'item' => _item,
        'index' => _index,
        'parent' => _outer()?.let((o) => {'item': o._item, 'index': o._index}) ?? const <String, Object?>{},
        _ => null,
      };

  ItemScope? _outer() {
    for (var s = parent; s != null; s = s.parent) {
      if (s is ItemScope) return s;
    }
    return null;
  }

  /// Moves to [item] at [index] (the data changed).
  void update({required int index, Object? item}) {
    final names = <String>[
      if (!identical(item, _item) && item != _item) 'item',
      if (index != _index) 'index',
    ];
    _index = index;
    _item = item;
    if (names.isNotEmpty) changed(names);
  }
}

/// The value of the `screen` name for a screen [width] × [height]: its
/// size, breakpoint (mobile below 600, tablet below 1024, else desktop),
/// orientation and brightness.
Map<String, Object?> screenValues(double width, double height, {bool dark = false}) {
  final breakpoint = width < 600 ? 'mobile' : (width < 1024 ? 'tablet' : 'desktop');
  final portrait = height >= width;
  return {
    'width': width,
    'height': height,
    'breakpoint': breakpoint,
    'isMobile': breakpoint == 'mobile',
    'isTablet': breakpoint == 'tablet',
    'isDesktop': breakpoint == 'desktop',
    'orientation': portrait ? 'portrait' : 'landscape',
    'isPortrait': portrait,
    'isLandscape': !portrait,
    'brightness': dark ? 'dark' : 'light',
    'isDark': dark,
  };
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
