// Writing a variable from a scope: the scope of the chain that declares it
// takes the value.
import 'package:codelessly_api/core.dart' show Variable, VariableType;

import '../actions/values.dart' show setAtPath;
import '../contracts.dart';
import 'paths.dart';
import 'scopes.dart';

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
