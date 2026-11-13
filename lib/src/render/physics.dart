// The physics every gesture's release shares (the API's GesturePhysics and
// GestureSnap, DESIGN.md §4.1): the spring a settle runs on, friction
// flings that spring back at their bounds, rubber-banding past the bounds,
// the range bounds allow, and velocity-projected snapping to points, a grid
// or the parent's edges. Used by a pan (Pan.physics), a drag
// source's return (DragSource.returnSpring) and a transform gesture
// (TransformGesture.physics).
import 'dart:math' as math;
import 'dart:ui';

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/physics.dart';

/// Flutter's `SpringDescription` for [spring]: `withDurationAndBounce` when
/// it's given by duration and bounce, else its mass, stiffness and damping
/// ([stiffnessIfNone] for a stiffness not above 0, [dampingIfNegative] for
/// a negative damping).
SpringDescription describeSpring(api.Spring spring, {double stiffnessIfNone = 380, double dampingIfNegative = 0}) {
  if (!spring.isPhysical) {
    return SpringDescription.withDurationAndBounce(
      duration: Duration(milliseconds: math.max(1, spring.duration)),
      bounce: spring.bounce.clamp(-0.95, 1.0),
    );
  }
  return SpringDescription(
    mass: spring.mass <= 0 ? 1 : spring.mass,
    stiffness: spring.stiffness! <= 0 ? stiffnessIfNone : spring.stiffness!,
    damping: spring.damping! < 0 ? dampingIfNegative : spring.damping!,
  );
}

/// The spring [physics] settles on.
SpringDescription springOf(api.GesturePhysics physics) => describeSpring(physics.spring);

/// How close a settle must come to be done: within a hundredth of a unit
/// (pixel, degree or scale) and slower than one unit a second.
const Tolerance gestureTolerance = Tolerance(distance: 0.01, velocity: 1);

/// [value] held back past [lo] and [hi] like a rubber band: inside it is
/// unchanged; past an end it moves less and less the further it goes,
/// [overscroll] (0 to 1) of the way at first. 1 follows freely and 0 stops
/// dead at the end.
double rubberBand(double value, double lo, double hi, double overscroll) {
  final k = overscroll.clamp(0.0, 1.0);
  if (k >= 1) return value;
  double band(double excess) {
    if (k <= 0) return 0;
    // Like iOS: (1 − 1 / (excess·c / d + 1))·d, with d the reach.
    const reach = 240.0;
    return (1 - 1 / (excess * k / reach + 1)) * reach;
  }

  if (value < lo) return lo - band(lo - value);
  if (value > hi) return hi + band(value - hi);
  return value;
}

/// The range a center at [center] (with [half] its half extent) may move
/// to so the box stays inside, or covers, [viewLo]..[viewHi], as an offset
/// range from where it is. Unbounded for [api.GestureBounds.none].
(double, double) boundsRange({
  required api.GestureBounds bounds,
  required double center,
  required double half,
  required double viewLo,
  required double viewHi,
}) {
  if (bounds == api.GestureBounds.none) return (double.negativeInfinity, double.infinity);
  final view = viewHi - viewLo;
  final size = half * 2;
  double lo, hi;
  final bigger = size > view + 0.001;
  if (bounds == api.GestureBounds.contain && !bigger) {
    // Keep the whole box inside.
    lo = viewLo + half;
    hi = viewHi - half;
  } else if (bigger) {
    // Cover: no gap at either end.
    lo = viewHi - half;
    hi = viewLo + half;
  } else {
    // Cover, but too small to: centered.
    lo = hi = (viewLo + viewHi) / 2;
  }
  return (lo - center, hi - center);
}

/// One axis of a release: a fling that slows by friction and springs back
/// at its bounds, or a spring straight to a target (a snap point, a bound
/// it was already past, a rotation snap). Done when it is at rest.
class AxisSettleSimulation extends Simulation {
  AxisSettleSimulation._(this._first, this._switchAt, this._then, this.finalX) : super(tolerance: gestureTolerance);

  /// Springs from [position] at [velocity] to [target].
  factory AxisSettleSimulation.spring({
    required api.GesturePhysics physics,
    required double position,
    required double velocity,
    required double target,
  }) =>
      AxisSettleSimulation._(
        SpringSimulation(springOf(physics), position, target, velocity, tolerance: gestureTolerance),
        double.infinity,
        null,
        target,
      );

  /// Settles a release at [position] moving at [velocity], inside [lo] to
  /// [hi]:
  /// - past an end, springs to it;
  /// - with [api.GesturePhysics.fling] and fast enough, coasts by friction
  ///   and, when it would leave the range, springs back from the end it
  ///   hits, keeping its speed (so it overshoots a little, by the spring);
  /// - otherwise stays.
  factory AxisSettleSimulation.release({
    required api.GesturePhysics physics,
    required double position,
    required double velocity,
    double lo = double.negativeInfinity,
    double hi = double.infinity,
  }) {
    if (lo > hi) lo = hi = (lo + hi) / 2;
    if (position < lo || position > hi) {
      return AxisSettleSimulation.spring(
        physics: physics,
        position: position,
        velocity: velocity,
        target: position < lo ? lo : hi,
      );
    }
    final v = velocity.clamp(-physics.maxFlingVelocity, physics.maxFlingVelocity);
    if (!physics.fling || v.abs() < physics.minFlingVelocity) {
      return AxisSettleSimulation._(_Still(position), double.infinity, null, position);
    }
    final friction = FrictionSimulation(physics.frictionDrag, position, v, tolerance: gestureTolerance);
    final end = friction.finalX;
    if (end >= lo && end <= hi) return AxisSettleSimulation._(friction, double.infinity, null, end);
    final edge = end < lo ? lo : hi;
    final at = friction.timeAtX(edge);
    if (!at.isFinite) return AxisSettleSimulation._(friction, double.infinity, null, end);
    return AxisSettleSimulation._(
      friction,
      at,
      SpringSimulation(springOf(physics), edge, edge, friction.dx(at), tolerance: gestureTolerance),
      edge,
    );
  }

  final Simulation _first;
  final double _switchAt;
  final Simulation? _then;

  /// Where it comes to rest.
  final double finalX;

  @override
  double x(double time) => time < _switchAt || _then == null ? _first.x(time) : _then.x(time - _switchAt);

  @override
  double dx(double time) => time < _switchAt || _then == null ? _first.dx(time) : _then.dx(time - _switchAt);

  @override
  bool isDone(double time) =>
      time < _switchAt || _then == null ? _first.isDone(time) && _then == null : _then.isDone(time - _switchAt);
}

class _Still extends Simulation {
  _Still(this.at);
  final double at;
  @override
  double x(double time) => at;
  @override
  double dx(double time) => 0;
  @override
  bool isDone(double time) => true;
}

/// Where a release snaps: the point and its index in the snap's list (−1
/// for a grid or edge).
typedef SnapTarget = ({Offset offset, int index});

/// The snap target of a release at [position] moving at [velocity], both
/// in pixels from rest, or null when [physics] has no snap. Picks the
/// target nearest to where a friction fling would stop (or to [position]
/// without [api.GestureSnap.projectVelocity]), among those inside [range].
///
/// [edges] are the offsets that put the node flush with each edge of its
/// parent, as (left, top, right, bottom); needed for [api.SnapKind.edges].
/// [axis] limits snapping to one axis: the other keeps [position].
SnapTarget? snapTargetOf({
  required api.GesturePhysics physics,
  required Offset position,
  required Offset velocity,
  Rect range = Rect.largest,
  Rect? edges,
  api.DragAxis axis = api.DragAxis.free,
}) {
  final snap = physics.snap;
  if (snap == null) return null;
  final projected = Offset(physics.projectFling(position.dx, velocity.dx), physics.projectFling(position.dy, velocity.dy));
  Offset keepAxis(Offset p) => switch (axis) {
        api.DragAxis.free => p,
        api.DragAxis.horizontal => Offset(p.dx, position.dy),
        api.DragAxis.vertical => Offset(position.dx, p.dy),
      };
  Offset clampTo(Offset p) => Offset(p.dx.clamp(range.left, range.right), p.dy.clamp(range.top, range.bottom));
  double distance(Offset p) => switch (axis) {
        api.DragAxis.free => (p - projected).distance,
        api.DragAxis.horizontal => (p.dx - projected.dx).abs(),
        api.DragAxis.vertical => (p.dy - projected.dy).abs(),
      };

  switch (snap.kind) {
    case api.SnapKind.points:
      if (snap.points.isEmpty) return null;
      var best = -1;
      var bestDistance = double.infinity;
      for (var i = 0; i < snap.points.length; i++) {
        final p = snap.points[i];
        final d = distance(clampTo(keepAxis(Offset(p.dx, p.dy))));
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      final p = snap.points[best];
      return (offset: clampTo(keepAxis(Offset(p.dx, p.dy))), index: best);
    case api.SnapKind.grid:
      double round(double v, double pitch) => pitch <= 0 ? v : (v / pitch).round() * pitch;
      return (
        offset: clampTo(keepAxis(Offset(
          snap.gridX <= 0 ? position.dx : round(projected.dx, snap.gridX),
          snap.gridY <= 0 ? position.dy : round(projected.dy, snap.gridY),
        ))),
        index: -1,
      );
    case api.SnapKind.edges:
      if (edges == null) return null;
      final x = (projected.dx - edges.left).abs() < (projected.dx - edges.right).abs() ? edges.left : edges.right;
      final y = (projected.dy - edges.top).abs() < (projected.dy - edges.bottom).abs() ? edges.top : edges.bottom;
      return (offset: clampTo(keepAxis(Offset(x, y))), index: -1);
  }
}

/// Runs several [Simulation]s, one per named value, off one clock and
/// reports when all are done. Values without a simulation hold still.
class SimulationGroup {
  final Map<String, Simulation> _simulations = {};

  /// Starts (or replaces) the simulation of [key].
  void set(String key, Simulation simulation) => _simulations[key] = simulation;

  /// Whether any simulation is set.
  bool get isEmpty => _simulations.isEmpty;

  /// The value of [key] at [time] seconds, or null without a simulation.
  double? x(String key, double time) => _simulations[key]?.x(time);

  /// The velocity of [key] at [time] seconds, or 0.
  double dx(String key, double time) => _simulations[key]?.dx(time) ?? 0;

  /// Whether every simulation is at rest at [time].
  bool isDone(double time) => _simulations.values.every((s) => s.isDone(time));

  /// Where the simulation of [key] comes to rest.
  double finalOf(String key) => switch (_simulations[key]) {
        final AxisSettleSimulation s => s.finalX,
        final Simulation s => s.x(1e6),
        null => 0,
      };

  /// Stops them all.
  void clear() => _simulations.clear();

  /// The keys that have a simulation.
  Iterable<String> get keys => _simulations.keys;
}
