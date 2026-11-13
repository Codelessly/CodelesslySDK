// Names a node gives the nodes inside it (and its own bindings and
// reactions): a drag track's `track`, a flip card's `flip`, a tilt's
// `tilt`, a transform gesture's `transform`, as value scopes: each such node has
// one [NodeValuesScope] (made by [NodeBinder.scopeFor]) between the scope
// around it and the scopes of the nodes inside it, which its render
// objects write as the node moves.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;

import 'package:flutter/foundation.dart' show Listenable;

import '../../render/behavior_values.dart';
import '../contracts.dart';
import 'scopes.dart';

export '../../render/behavior_values.dart' show trackValues;

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
/// behaviors declares all their names in one scope).
final List<NodeScopeDeclarer> nodeScopeDeclarers = [
  trackScopeValues, flipScopeValues, tiltScopeValues, transformScopeValues, stickyScopeValues, viewScopeValues, //
  animationScopeValues,
];

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
  final be = node.behaviors;
  return be.drag?.track != null ||
      be.flip != null ||
      be.tilt != null ||
      be.transformGesture != null ||
      be.zoomable ||
      be.sticky != null ||
      be.viewProgress != null ||
      be.animations.isNotEmpty ||
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

/// A node's `animation`: each animation's value, status and whether it
/// runs, by id (`${animation.spin.value}`), at rest until its player
/// publishes them (render/animations.dart).
Map<String, Object?>? animationScopeValues(Node node, ValueScope parent) {
  final animations = node.behaviors.animations;
  if (animations.isEmpty) return null;
  return {
    'animation': {
      for (final a in animations) a.id: {'value': 0.0, 'status': 'dismissed', 'isAnimating': false},
    },
  };
}

/// A drag track's `track`: the value it's drawn at and its progress (as
/// the design canvas draws it), not dragged, fine or focused.
Map<String, Object?>? trackScopeValues(Node node, ValueScope parent) {
  final track = node.behaviors.drag?.track;
  if (track == null) return null;
  final value = trackValueIn(track, parent);
  return {'track': trackValues(track, value)};
}

/// The value [track] is drawn at, read in [scope]: its bound value
/// (`drag.track.value`), else its variable's, else its default or start;
/// NaN (empty) for a track that parks such a value
/// ([api.DragTrack.parkedProgress]).
double trackValueIn(api.DragTrack track, ValueScope? scope) =>
    trackValueFrom(track, scope == null ? null : (path) => readPath(scope, path));

/// A flip card's `flip`: on its back or not, and the turn (0 front, 1
/// back).
Map<String, Object?>? flipScopeValues(Node node, ValueScope parent) {
  final flip = node.behaviors.flip;
  if (flip == null) return null;
  final back = flipWantedIn(flip, parent);
  return {
    'flip': {'flipped': back, 'progress': back ? 1.0 : 0.0},
  };
}

/// Whether [flip] shows its back: its variable's value when it has one,
/// else `flipped` (bindable).
bool flipWantedIn(api.FlipCard flip, ValueScope? scope) =>
    flipWantedFrom(flip, scope == null ? null : (path) => readPath(scope, path));

/// A tilt's `tilt`: where the pointer is over it (-1–1) and whether it's
/// over it.
Map<String, Object?>? tiltScopeValues(Node node, ValueScope parent) {
  if (node.behaviors.tilt == null) return null;
  return const {
    'tilt': {'x': 0.0, 'y': 0.0, 'active': false},
  };
}

/// A transform gesture's `transform`, at rest (its render object writes
/// the live pose).
Map<String, Object?>? transformScopeValues(Node node, ValueScope parent) {
  final be = node.behaviors;
  if (be.transformGesture == null && !be.zoomable) return null;
  return const {
    'transform': {'x': 0, 'y': 0, 'scale': 1, 'rotation': 0, 'scaleX': 1, 'scaleY': 1, 'active': false, 'selected': true},
  };
}

/// A sticky node's `sticky`: whether it is pinned now (its render object
/// writes it as the view scrolls).
Map<String, Object?>? stickyScopeValues(Node node, ValueScope parent) {
  if (node.behaviors.sticky == null) return null;
  return const {
    'sticky': {'stuck': false},
  };
}

/// A view progress's `view`: how far through its view the node has
/// scrolled (0–1) and whether any of it shows; its render object writes
/// them as the view scrolls.
Map<String, Object?>? viewScopeValues(Node node, ValueScope parent) {
  if (node.behaviors.viewProgress == null) return null;
  return const {
    'view': {'progress': 0.0, 'visible': false},
  };
}
