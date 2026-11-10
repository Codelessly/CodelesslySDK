// Names a node gives the nodes inside it (and its own bindings and
// reactions): a drag track's `track`, a flip card's `flip`, a tilt's
// `tilt`, a transform gesture's `transform`, as value scopes: each such node has
// one [NodeValuesScope] (made by [NodeBinder.scopeFor]) between the scope
// around it and the scopes of the nodes inside it, which its render
// objects write as the node moves.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Node;

import 'package:flutter/foundation.dart' show Listenable;

import '../contracts.dart';
import 'scopes.dart';

/// The names a node of a kind declares for the nodes inside it, with the
/// values they read before its render objects say otherwise ([parent] is
/// the scope around the node). Null: the node declares none.
typedef NodeScopeDeclarer = Map<String, Object?>? Function(Node node, ValueScope parent);

/// The live values of one node, by name (`track`, `flip`, `tilt`...).
class NodeValuesScope extends ValuesScope {
  NodeValuesScope(super.values, super.parent);

  /// Sets [name] when [value] differs (maps compared by entry): readers
  /// re-apply only on a change.
  void update(String name, Object? value) {
    final old = this[name];
    if (old is Map && value is Map && _sameMap(old, value)) return;
    if (old == value && (old is! Map)) return;
    set(name, value);
  }

  static bool _sameMap(Map<Object?, Object?> a, Map<Object?, Object?> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (!b.containsKey(e.key)) return false;
      if (o is double && e.value is double && o.isNaN && (e.value! as double).isNaN) continue;
      if (o != e.value) return false;
    }
    return true;
  }
}

/// The node kinds that declare names, in order (a node with several
/// behaviours declares all their names in one scope).
final List<NodeScopeDeclarer> nodeScopeDeclarers = [trackScopeValues, flipScopeValues, tiltScopeValues, transformScopeValues];

/// What [node] declares (empty: nothing), read in [parent].
Map<String, Object?> nodeScopeValues(Node node, ValueScope parent) {
  Map<String, Object?>? out;
  for (final d in nodeScopeDeclarers) {
    final v = d(node, parent);
    if (v != null) (out ??= {}).addAll(v);
  }
  return out ?? const {};
}

/// Whether [node] declares any name for the nodes inside it.
bool declaresNodeScope(Node node) {
  final be = node.behaviours;
  return be.drag?.track != null ||
      be.flip != null ||
      be.tilt != null ||
      be.transformGesture != null ||
      be.zoomable ||
      ownSwitchPoints(node).isNotEmpty;
}

/// A responsive variance's own switch points (DESIGN.md §5.3), which
/// restate `screen` inside it; empty for any other node.
Map<String, double> ownSwitchPoints(Node node) =>
    node.isResponsive ? node.prop(api.VarianceProps.minWidths) : const {};

/// The scope of what [node] declares for the nodes inside it, around
/// [parent]: a [ResponsiveScreenScope] for a responsive variance with its
/// own switch points, else a [NodeValuesScope].
NodeValuesScope nodeValuesScopeFor(Node node, ValueScope parent) {
  final values = nodeScopeValues(node, parent);
  final own = ownSwitchPoints(node);
  return own.isEmpty ? NodeValuesScope(values, parent) : ResponsiveScreenScope(own, values, parent);
}

/// `screen` inside a responsive layout with its own switch points: the
/// screen around it with the breakpoint that layout picks, following the screen as it changes.
class ResponsiveScreenScope extends NodeValuesScope {
  ResponsiveScreenScope(this.minWidths, super.values, super.parent);

  final Map<String, double> minWidths;

  @override
  bool declares(String name) => name == 'screen' || super.declares(name);

  @override
  Object? valueOf(String name, ValueScope reader) {
    if (name != 'screen') return super.valueOf(name, reader);
    final around = readPath(parent, 'screen');
    return around is Map<String, Object?> ? screenWithMinWidths(around, minWidths) : around;
  }

  @override
  Listenable watch(String name) => name == 'screen' ? (watchName(parent, 'screen') ?? super.watch(name)) : super.watch(name);
}

/// A drag track's `track`: the value it's drawn at and its progress (as
/// the design canvas draws it), not dragged, fine or focused.
Map<String, Object?>? trackScopeValues(Node node, ValueScope parent) {
  final track = node.behaviours.drag?.track;
  if (track == null) return null;
  final value = trackValueIn(track, parent);
  return {'track': trackValues(track, value)};
}

/// `${track}` for [track] drawn at [value] (NaN: empty) at [progress]
/// (its rest place when null).
Map<String, Object?> trackValues(api.DragTrack track, double value,
        {double? progress, bool dragging = false, bool fine = false, bool focused = false}) {
  final shown = progress ?? track.restProgressOf(value);
  return {
    'value': value.isNaN ? null : value,
    // An endless track reports where it is within one turn.
    'progress': track.unbounded ? shown - shown.floorToDouble() : shown,
    'dragging': dragging,
    'fine': fine,
    'focused': focused,
  };
}

/// The value [track] is drawn at, read in [scope]: its bound value
/// (`drag.track.value`), else its variable's, else its default or start;
/// NaN (empty) for a track that parks such a value
/// ([api.DragTrack.parkedProgress]).
double trackValueIn(api.DragTrack track, ValueScope? scope) {
  final Object? raw = track.value ?? (track.hasVariable && scope != null ? readPath(scope, track.variable.trim()) : null);
  final double? value = switch (raw) {
    final num n when n.isFinite => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };
  if (value != null) return value;
  if (track.parkedProgress != null) return double.nan;
  return track.defaultValue ?? track.min;
}

/// A flip card's `flip`: on its back or not, and the turn (0 front, 1
/// back).
Map<String, Object?>? flipScopeValues(Node node, ValueScope parent) {
  final flip = node.behaviours.flip;
  if (flip == null) return null;
  final back = flipWantedIn(flip, parent);
  return {
    'flip': {'flipped': back, 'progress': back ? 1.0 : 0.0},
  };
}

/// Whether [flip] shows its back: its variable's value when it has one,
/// else `flipped` (bindable).
bool flipWantedIn(api.FlipCard flip, ValueScope? scope) {
  final name = flip.variable.trim();
  if (name.isEmpty || scope == null) return flip.flipped;
  final v = readPath(scope, name);
  if (v == null) return flip.flipped;
  if (v is bool) return v;
  return '$v'.trim().toLowerCase() == 'true';
}

/// A tilt's `tilt`: where the pointer is over it (-1–1) and whether it's
/// over it.
Map<String, Object?>? tiltScopeValues(Node node, ValueScope parent) {
  if (node.behaviours.tilt == null) return null;
  return const {
    'tilt': {'x': 0.0, 'y': 0.0, 'active': false},
  };
}

/// A transform gesture's `transform`, at rest (its render object writes
/// the live pose).
Map<String, Object?>? transformScopeValues(Node node, ValueScope parent) {
  final be = node.behaviours;
  if (be.transformGesture == null && !be.zoomable) return null;
  return const {
    'transform': {'x': 0, 'y': 0, 'scale': 1, 'rotation': 0, 'scaleX': 1, 'scaleY': 1, 'active': false, 'selected': true},
  };
}
