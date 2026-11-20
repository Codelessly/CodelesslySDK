// Shared elements between screens (a node's `hero` that flies
// `betweenScreens`, Flutter's `Hero`; one that flies `inPlace` is
// render/play.dart's RenderFlightBox): a mark in the node's chain that the
// app shell's flights (app/hero_flights.dart) find on the screens a
// navigation moves between, hide while they fly a drawing of the node in
// the navigator's overlay, and, with `placeholder: source`, that keeps the
// node it flew from drawn under it until its own images have loaded. On
// render objects: there is no widget per node to give Flutter's `Hero`.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

import 'convert.dart';
import 'node_tree.dart';
import 'paint/image_fill.dart';
import 'recipe.dart';

/// Adds node [n]'s hero mark to [chain] (inside its motion, so a flight
/// starts where the node is drawn). A design canvas has none.
void heroLayer(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final hero = n.behaviors.hero;
  if (!animates || hero == null || hero.flies == api.HeroFlies.inPlace) return;
  chain.add(
    b.obtain<RenderHeroMark>('hero', RenderHeroMark.new)
      ..tree = b.tree
      ..flies = hero.flies
      ..flight = hero.flight
      // A hidden node stays to keep its state; it doesn't fly.
      ..tag = n.visible ? hero.tag.trim() : ''
      ..flightShuttle = hero.flightShuttle
      ..placeholder = hero.placeholder
      ..corners = n.decoration.radius.flutter
      ..glow = _glowOf(n),
  );
}

/// The color of [n]'s first visible drop shadow (an arc flight's glow).
Color? _glowOf(Node n) {
  for (final e in n.decoration.effects) {
    if (e.visible && e.type == api.EffectType.dropShadow) return e.color.flutter;
  }
  return null;
}

/// Whether an image under [box] is still loading.
bool imagesPendingUnder(RenderObject box) {
  var pending = false;
  void visit(RenderObject o) {
    if (pending) return;
    if (o is ImageClient && o.imagesPending) {
      pending = true;
      return;
    }
    o.visitChildren(visit);
  }

  visit(box);
  return pending;
}

/// The marks of the shared elements of each tree on screen.
abstract final class HeroMarks {
  static final Map<RenderTree, Set<RenderHeroMark>> _byTree = {};

  /// The trees with marks.
  static Iterable<RenderTree> get trees => _byTree.keys;

  /// The attached marks of [tree] with a tag.
  static Iterable<RenderHeroMark> of(RenderTree tree) =>
      (_byTree[tree] ?? const {}).where((m) => m.attached && m.tag.isNotEmpty);

  /// Every attached lifted mark ([api.HeroFlies.lift]) with [tag], oldest
  /// first.
  static List<RenderHeroMark> lifted(String tag) => [
        for (final set in _byTree.values)
          for (final m in set)
            if (m.attached && m.flies == api.HeroFlies.lift && m.tag == tag) m,
      ]..sort((a, b) => a._seq.compareTo(b._seq));

  /// Every attached lifted mark with a tag.
  static Iterable<RenderHeroMark> get allLifted => [
        for (final set in _byTree.values)
          for (final m in set)
            if (m.attached && m.flies == api.HeroFlies.lift && m.tag.isNotEmpty) m,
      ];

  /// Whether a tree's screen is on its way out (its route closing): a
  /// lifted node there is going. Set by the runtime that knows the routes.
  static bool Function(RenderTree tree) leaving = _never;
  static bool _never(RenderTree tree) => false;

  /// Called when a lifted mark comes, goes or changes its tag: the app
  /// shell's lifts (app/ui/hero_flights.dart) look again.
  static void Function()? onLiftChange;

  static int _counter = 0;

  static void _add(RenderHeroMark m) {
    (_byTree[m.tree!] ??= {}).add(m);
    if (m.flies == api.HeroFlies.lift) onLiftChange?.call();
  }

  static void _remove(RenderHeroMark m) {
    final set = _byTree[m.tree];
    set?.remove(m);
    if (set != null && set.isEmpty) _byTree.remove(m.tree);
    if (m.flies == api.HeroFlies.lift) onLiftChange?.call();
  }
}

/// A shared element's place in its node's chain.
class RenderHeroMark extends RenderProxyBox {
  RenderTree? _tree;
  RenderTree? get tree => _tree;
  set tree(RenderTree? v) {
    if (identical(v, _tree)) return;
    if (attached && _tree != null) HeroMarks._remove(this);
    _tree = v;
    if (attached && v != null) HeroMarks._add(this);
  }

  String _tag = '';

  /// The tag it flies with now (bound); empty: it doesn't fly.
  String get tag => _tag;
  set tag(String v) {
    if (v == _tag) return;
    _tag = v;
    if (flies == api.HeroFlies.lift) {
      // A new tag is a new arrival: it lifts out of a node with that tag.
      _seq = ++HeroMarks._counter;
      liftFront = false;
      markNeedsPaint();
      if (attached) HeroMarks.onLiftChange?.call();
    }
  }

  /// When it flies: between screens, or lifted ([api.HeroFlies.lift]; an
  /// in-place hero has no mark).
  api.HeroFlies flies = api.HeroFlies.betweenScreens;

  /// How a lift flies (its duration and curve).
  api.Flight? flight;

  /// When it came (attached, or took its tag): the newest lifted mark of a
  /// tag is the one shown.
  int _seq = 0;

  /// Its order of arrival among the lifted marks of its tag.
  int get arrival => _seq;

  bool _liftFront = false;

  /// A lifted mark: the one of its tag shown now (the app shell's lifts set
  /// it). While no mark of the tag is, the newest shows.
  bool get liftFront => _liftFront;
  set liftFront(bool v) {
    if (v == _liftFront) return;
    _liftFront = v;
    if (attached) markNeedsPaint();
  }

  /// A lifted mark is drawn where it is laid out: it is the one of its tag
  /// shown and not flying. Another keeps its place, hidden (a gap).
  bool get liftShown {
    if (flies != api.HeroFlies.lift || _tag.isEmpty) return true;
    if (_flying) return false;
    if (_liftFront) return true;
    final all = HeroMarks.lifted(_tag);
    if (all.any((m) => m._liftFront)) return false;
    final shown = all.where((m) => m.tree == null || !HeroMarks.leaving(m.tree!));
    return identical(shown.lastOrNull ?? all.lastOrNull, this);
  }

  /// Where it was on screen (global) at the end of the last frame it was
  /// attached in ([notePlace]), for a flight back from a node that has gone.
  /// Not read for a node still on screen: a scroll can move it without a
  /// paint, so its place is read where it is ([rectIn]).
  Rect? lastRect;

  /// Records where it is on screen now in [lastRect]: called once a frame is
  /// laid out and drawn (app/ui/hero_flights.dart's lifts).
  void notePlace() {
    if (!attached || !hasSize) return;
    final r = rectIn(null);
    if (r != null) lastRect = r;
  }

  /// What its flight draws (`Hero.flightShuttleBuilder`).
  api.HeroFlightShuttle flightShuttle = api.HeroFlightShuttle.standard;
  api.HeroPlaceholder placeholder = api.HeroPlaceholder.none;

  /// The node's corners (a morphing flight turns one into the other).
  BorderRadius corners = BorderRadius.zero;

  /// An arc flight's glow; null: the other end's, else soft white.
  Color? glow;

  bool _flying = false;

  /// Hidden while a flight draws it in the overlay.
  bool get flying => _flying;
  set flying(bool v) {
    if (v == _flying) return;
    _flying = v;
    if (attached) markNeedsPaint();
  }

  RenderHeroMark? _source;

  /// The mark it flew from, drawn under it until its images have loaded
  /// (`placeholder: source`).
  set placeholderSource(RenderHeroMark? v) {
    if (identical(v, _source)) return;
    _source = v;
    markNeedsPaint();
  }

  /// Where it is in [ancestor]'s coordinates (null: not laid out there).
  Rect? rectIn(RenderObject? ancestor) {
    if (!attached || !hasSize) return null;
    try {
      return MatrixUtils.transformRect(getTransformTo(ancestor), Offset.zero & size);
    } catch (_) {
      return null;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _seq = ++HeroMarks._counter;
    _liftFront = false;
    if (_tree != null) HeroMarks._add(this);
  }

  @override
  void detach() {
    HeroMarks._remove(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_flying || !liftShown) return;
    final source = _source;
    final c = child;
    if (source != null && c != null) {
      if (!imagesPendingUnder(c)) {
        _source = null;
      } else if (source.attached && source.hasSize && source.child != null && !source.flying) {
        paintFitted(context, offset, size, source);
      }
    }
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !_flying && liftShown && super.hitTest(result, position: position);
}

/// Paints [mark]'s drawing (its child, at its own size) stretched over
/// [size] at [offset]: a node borrowed for a flight or a placeholder.
void paintFitted(PaintingContext context, Offset offset, Size size, RenderHeroMark mark) {
  final child = mark.child;
  if (child == null || !mark.hasSize || mark.size.isEmpty) return;
  final own = mark.size;
  final transform = Matrix4.translationValues(offset.dx, offset.dy, 0)
    ..scaleByDouble(size.width / own.width, size.height / own.height, 1, 1);
  context.pushTransform(true, Offset.zero, transform, (context, offset) => context.paintChild(child, offset));
}

/// Draws a mark's node stretched over the box it's given (the flight's box
/// in between), repainting with a listenable.
class RenderHeroMarkPaint extends RenderBox {
  RenderHeroMarkPaint(this._mark, this._repaint);

  RenderHeroMark _mark;
  set mark(RenderHeroMark v) {
    if (identical(v, _mark)) return;
    _mark = v;
    markNeedsPaint();
  }

  Listenable? _repaint;
  set repaint(Listenable? v) {
    if (identical(v, _repaint)) return;
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = v;
    if (attached) _repaint?.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_mark.attached) paintFitted(context, offset, size, _mark);
  }
}
