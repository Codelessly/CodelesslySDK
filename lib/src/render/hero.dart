// Shared elements (a node's `hero`): a mark in the node's chain that the
// app shell's flights (app/hero_flights.dart) find on the screens a
// navigation moves between, hide while they fly a drawing of the node in
// the navigator's overlay, and, with `placeholder: source`, that keeps the
// node it flew from drawn under it until its own images have loaded. SDK
// 8.x's NodeHero, on render objects: there is no widget per node to give
// Flutter's `Hero`.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Node;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'convert.dart';
import 'node_tree.dart';
import 'paint/image_fill.dart';
import 'recipe.dart';

/// Adds node [n]'s hero mark to [chain] (inside its rotation and motion, so
/// a flight starts where the node is drawn). A design canvas has none.
void heroLayer(NodeBuilder b, Node n, List<RenderBox> chain, {required bool animates}) {
  final hero = n.behaviours.hero;
  if (!animates || hero == null) return;
  chain.add(
    b.obtain<RenderHeroMark>('hero', RenderHeroMark.new)
      ..tree = b.tree
      // A hidden node stays to keep its state; it doesn't fly.
      ..tag = n.visible ? hero.tag.trim() : ''
      ..flight = hero.flight
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
  static final Map<NodeTree, Set<RenderHeroMark>> _byTree = {};

  /// The trees with marks.
  static Iterable<NodeTree> get trees => _byTree.keys;

  /// The attached marks of [tree] with a tag.
  static Iterable<RenderHeroMark> of(NodeTree tree) =>
      (_byTree[tree] ?? const {}).where((m) => m.attached && m.tag.isNotEmpty);

  static void _add(RenderHeroMark m) => (_byTree[m.tree!] ??= {}).add(m);

  static void _remove(RenderHeroMark m) {
    final set = _byTree[m.tree];
    set?.remove(m);
    if (set != null && set.isEmpty) _byTree.remove(m.tree);
  }
}

/// A shared element's place in its node's chain.
class RenderHeroMark extends RenderProxyBox {
  NodeTree? _tree;
  NodeTree? get tree => _tree;
  set tree(NodeTree? v) {
    if (identical(v, _tree)) return;
    if (attached && _tree != null) HeroMarks._remove(this);
    _tree = v;
    if (attached && v != null) HeroMarks._add(this);
  }

  /// The tag it flies with now (bound); empty: it doesn't fly.
  String tag = '';
  api.HeroFlightShuttle flight = api.HeroFlightShuttle.standard;
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
    markNeedsPaint();
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
    if (_tree != null) HeroMarks._add(this);
  }

  @override
  void detach() {
    HeroMarks._remove(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_flying) return;
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
  bool hitTest(BoxHitTestResult result, {required Offset position}) => !_flying && super.hitTest(result, position: position);
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

/// Draws [mark]'s node stretched over the box it's given (the flight's box
/// in between), repainting with [repaint].
class HeroMarkPaint extends LeafRenderObjectWidget {
  const HeroMarkPaint({super.key, required this.mark, this.repaint});

  final RenderHeroMark mark;
  final Listenable? repaint;

  @override
  RenderHeroMarkPaint createRenderObject(BuildContext context) => RenderHeroMarkPaint(mark, repaint);

  @override
  void updateRenderObject(BuildContext context, RenderHeroMarkPaint renderObject) => renderObject
    ..mark = mark
    ..repaint = repaint;
}

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
