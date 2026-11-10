// What a write does to a value (set variable, set storage, a cloud field):
// SDK 8.x's number, boolean, list and map operations, on typed values.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' show ValueWrite, VariableType, WriteOp;

import '../contracts.dart';
import '../expressions/engine.dart';
import '../expressions/formula.dart';
import '../expressions/paths.dart';

/// [text] as a value: one `${path}` or `${= formula}` keeps its value's type
/// (a list stays a list); other text is interpolated, then read as JSON when
/// it's a list or map literal.
Object? evaluateValue(String text, Expressions e, ValueScope scope) {
  if (FormulaEvaluator.exactExpression(text) != null || exactPath(text) != null) return e.evaluate(text, scope);
  final t = text.trim();
  if ((t.startsWith('[') && t.endsWith(']')) || (t.startsWith('{') && t.endsWith('}'))) {
    try {
      return e.substituteJson(jsonDecode(t), scope);
    } on FormatException {
      // Text that only looks like JSON.
    }
  }
  return e.interpolate(text, scope);
}

/// [current] (of [type]) after [write], its value, index and key evaluated in
/// [scope]. Returns [current] when the write can't apply (a bad index).
Object? applyWrite(Object? current, VariableType type, ValueWrite write, Expressions e, ValueScope scope) {
  Object? value() => evaluateValue(write.value, e, scope);
  // An item written into a list or map is read loosely (`2` is a number,
  // `true` a bool), as SDK 8.x read it, unless an expression gave it.
  Object? item() {
    final v = value();
    if (v is! String || FormulaEvaluator.exactExpression(write.value) != null || exactPath(write.value) != null) return v;
    return v.isEmpty ? v : (parseLoose(v) ?? v);
  }

  int? index() => int.tryParse(e.interpolate(write.index, scope).trim());
  String key() => e.interpolate(write.mapKey, scope);

  switch (type) {
    case VariableType.boolean:
      if (write.op == WriteOp.toggle) return !(_bool(current) ?? false);
      return _bool(value());
    case VariableType.integer || VariableType.decimal:
      final v = _num(value());
      if (v == null) return current;
      final c = _num(current) ?? 0;
      final out = switch (write.op) {
        WriteOp.add => c + v,
        WriteOp.subtract => c - v,
        _ => v,
      };
      return type == VariableType.integer ? out.round() : out.toDouble();
    case VariableType.list:
      final list = [...?_list(current)];
      switch (write.op) {
        case WriteOp.add:
          final v = item();
          final items = _list(v);
          items == null ? list.add(v) : list.addAll(items);
        case WriteOp.insert:
          final i = index();
          if (i == null || i < 0 || i > list.length) return current;
          list.insert(i, item());
        case WriteOp.insertAll:
          final i = index();
          if (i == null || i < 0 || i > list.length) return current;
          list.insertAll(i, _list(value()) ?? const []);
        case WriteOp.removeAt:
          final i = index();
          if (i == null || i < 0 || i >= list.length) return current;
          list.removeAt(i);
        case WriteOp.remove:
          final v = value();
          list.removeWhere((x) => x == v || '$x' == '$v');
        case WriteOp.update:
          final i = index();
          if (i == null || i < 0 || i > list.length) return current;
          i == list.length ? list.add(item()) : list[i] = item();
        case WriteOp.set || WriteOp.toggle || WriteOp.subtract:
          return _list(value()) ?? const <Object?>[];
      }
      return list;
    case VariableType.map:
      final map = <String, Object?>{...?_map(current)};
      switch (write.op) {
        case WriteOp.add:
          map.addAll(_map(value()) ?? const {});
        case WriteOp.remove:
          map.remove(key());
        case WriteOp.update:
          map[key()] = item();
        default:
          return _map(value()) ?? const <String, Object?>{};
      }
      return map;
    case VariableType.text || VariableType.image || VariableType.choice || VariableType.color:
      final v = value();
      return v == null ? '' : (v is String ? v : pathText(v));
  }
}

bool? _bool(Object? v) => switch (v) {
      final bool b => b,
      final String s => switch (s.trim().toLowerCase()) { 'true' => true, 'false' => false, _ => null },
      final num n => n != 0,
      _ => null,
    };

num? _num(Object? v) => switch (v) {
      final num n => n,
      final String s => num.tryParse(s.trim()),
      _ => null,
    };

List<Object?>? _list(Object? v) => switch (v) {
      final List l => l.cast<Object?>(),
      final String s => switch (parseLoose(s)) { final List l => l.cast<Object?>(), _ => null },
      _ => null,
    };

Map<String, Object?>? _map(Object? v) => switch (v) {
      final Map m => {for (final e in m.entries) '${e.key}': e.value},
      final String s => switch (parseLoose(s)) { final Map m => {for (final e in m.entries) '${e.key}': e.value}, _ => null },
      _ => null,
    };

/// [root] with the value at [keys] (map keys and list indexes) set to
/// [value]; missing maps are made on the way. Null when a key can't apply.
Object? setAtPath(Object? root, List<Object> keys, Object? value) {
  if (keys.isEmpty) return value;
  final k = keys.first;
  final rest = keys.sublist(1);
  if (k is int) {
    final list = [...?_list(root)];
    if (k < 0 || k > list.length) return null;
    final child = setAtPath(k < list.length ? list[k] : null, rest, value);
    if (child == null && rest.isNotEmpty) return null;
    k == list.length ? list.add(child) : list[k] = child;
    return list;
  }
  final map = <String, Object?>{...?_map(root)};
  final child = setAtPath(map['$k'], rest, value);
  if (child == null && rest.isNotEmpty) return null;
  map['$k'] = child;
  return map;
}

/// [root] without the value at [keys]; [root] when there's none.
Object? removeAtPath(Object? root, List<Object> keys) {
  if (keys.isEmpty) return null;
  final k = keys.first;
  if (keys.length == 1) {
    if (k is int && root is List && k >= 0 && k < root.length) return [...root]..removeAt(k);
    if (root is Map) return {for (final e in root.entries) if ('${e.key}' != '$k') '${e.key}': e.value};
    return root;
  }
  final child = member(root, k);
  if (child == null) return root;
  return setAtPath(root, [k], removeAtPath(child, keys.sublist(1)));
}

/// The value at [path] (`a.b[0]`) of node JSON [json] (a property of a node,
/// for toggling it).
Object? readJsonPath(Object? json, String path) {
  Object? v = json;
  for (final part in path.replaceAll('[', '.').replaceAll(']', '').split('.')) {
    if (part.isEmpty) continue;
    v = member(v, int.tryParse(part) ?? part);
    if (v == null) return null;
  }
  return v;
}
