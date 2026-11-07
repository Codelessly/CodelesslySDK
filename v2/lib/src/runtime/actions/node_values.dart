// Node values: properties set at runtime by set value and set variant
// actions (SDK 8.x's node values), over the nodes a source gives. Only the
// nodes they set re-apply.
import 'package:codelessly_api_v2/codelessly_api.dart' show BindPaths, Node;
import 'package:flutter/foundation.dart';

import '../../render/source.dart';

/// A [NodeSource] over [base] with runtime values set on its nodes: a node
/// shows [base]'s, with each value set on it applied at its binding path.
class NodeValues implements NodeSource {
  NodeValues(this.base);

  final NodeSource base;

  /// Node id → path → value.
  final Map<String, Map<String, Object?>> _values = {};
  final Map<String, ValueNotifier<Node?>> _watched = {};
  final Map<String, VoidCallback> _unlisten = {};

  /// The values set on node [id], by path.
  Map<String, Object?> valuesOf(String id) => Map.unmodifiable(_values[id] ?? const {});

  /// Sets property [path] of node [id] to [value].
  void set(String id, String path, Object? value) {
    (_values[id] ??= {})[path] = value;
    _changed(id);
  }

  /// Takes the values of node [id] away (all, or the one at [path]).
  void clear(String id, [String? path]) {
    if (path == null) {
      _values.remove(id);
    } else {
      _values[id]?.remove(path);
    }
    _changed(id);
  }

  void _changed(String id) {
    final w = _watched[id];
    if (w != null) w.value = node(id);
  }

  @override
  Node? node(String id) {
    final n = base.node(id);
    final values = _values[id];
    if (n == null || values == null || values.isEmpty) return n;
    var out = n;
    for (final e in values.entries) {
      out = BindPaths.apply(out, e.key, e.value);
    }
    return out;
  }

  @override
  String? parentOf(String id) => base.parentOf(id);

  @override
  ValueListenable<Node?> watch(String id) {
    final existing = _watched[id];
    if (existing != null) return existing;
    final source = base.watch(id);
    final notifier = ValueNotifier<Node?>(node(id));
    void changed() => notifier.value = node(id);
    source.addListener(changed);
    _unlisten[id] = () => source.removeListener(changed);
    return _watched[id] = notifier;
  }

  void dispose() {
    for (final u in _unlisten.values) {
      u();
    }
    for (final n in _watched.values) {
      n.dispose();
    }
    _watched.clear();
    _unlisten.clear();
  }
}
