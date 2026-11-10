// Nodes → render objects, without a widget or element per node.
//
// Each node is one [NodeBox]. Its chain of render objects is, layer by layer,
// what SDK 8.x built as widgets for the same node (outer decorations, the
// shell's size, decoration and clip, padding, then the content), configured
// directly. The layout render objects are SDK 8.x's own (render/layout), so
// the semantics aren't re-derived. Parity: test/parity_test.dart compares
// every node's rect with SDK 8.x on real projects.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Json, Node, SizeFit, FlexProps, ScrollProps, TextProps, IconProps;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show WidgetBuilder;

import 'behaviours.dart';
import 'hero.dart';
import 'play.dart';
import '../runtime/gestures/drag_and_drop.dart' show dragAndDropLayers;
import '../runtime/gestures/drag_motion.dart' show RenderDragMotion, dragMotionLayers;
import 'convert.dart';
import 'layout/design_scroll.dart';
import 'layout/fit_box.dart';
import 'layout/freeform.dart';
import 'layout/hug_cross.dart';
import 'layout/text_box.dart';
import 'layout/wrap.dart';
import 'paint/icon_glyph.dart';
import 'paint/node_paint.dart';
import 'paint/path_paint.dart';
import 'islands.dart';
import 'paint/spread_shadow.dart';
import 'recipe.dart';
import 'source.dart';
import '../runtime/expressions/bindings.dart' show BoundNode, NodeBinder;
import '../widgets/collections.dart' show listBuildsAllItems;
import '../widgets/registry.dart';

/// How a node is laid out by its parent.
enum SlotKind {
  /// The tree's root (a screen rendered on its own, or a standalone node).
  root,

  /// A child of a row/column.
  flex,

  /// A child of a freeform container (stack).
  freeform,

  /// A screen's body.
  canvasBody,
}

@immutable
class Slot {
  const Slot(this.kind, [this.parent]);
  const Slot.root() : this(SlotKind.root);

  final SlotKind kind;

  /// The parent node instance (identity: a parent edit re-applies children,
  /// since their wrappers depend on it).
  final Node? parent;

  @override
  bool operator ==(Object other) => other is Slot && other.kind == kind && identical(other.parent, parent);

  @override
  int get hashCode => Object.hash(kind, identityHashCode(parent));
}

/// A running app's interaction layers: what wires a node's reactions (taps,
/// hover, viewport, timers...) into its box. Set on [NodeTree.interactions];
/// used only while the tree is interactive (see [NodeTree.animates]).
abstract interface class NodeInteractions {
  /// Adds [box]'s interaction layers for node [n] (as shown) to [chain],
  /// between its rotation and its loops.
  void addLayers(NodeBox box, Node n, List<RenderBox> chain);

  /// An event of [box]'s node from inside it: an input's `changed` or
  /// `submitted`, a button's `click` (islands report them). Completes when
  /// the chain it starts ends.
  Future<void> fire(NodeBox box, String trigger, {Json event = const {}});

  /// [box] left the tree: what it runs stops.
  void released(NodeBox box);

  /// [box] was put in or taken out of the render tree ([NodeBox.attached]:
  /// its view came or went, or it's moving).
  void attachChanged(NodeBox box);
}

/// Reports trigger [trigger] of the node [b] builds (an island's input
/// changed, a button was pressed), when its tree has [NodeTree.interactions].
void fireTrigger(NodeBuilder b, String trigger, {Json event = const {}}) {
  if (b is NodeBox && b.tree.animates) b.tree.interactions?.fire(b, trigger, event: event);
}

/// [fireTrigger], completing when the chain it starts ends (a swiped card's
/// reactions, before it comes back).
Future<void> runTrigger(NodeBuilder b, String trigger, {Json event = const {}}) async {
  if (b is NodeBox && b.tree.animates) await b.tree.interactions?.fire(b, trigger, event: event);
}

/// Hooks for tools (the editor's geometry cache, perf counters).
abstract class NodeTreeObserver {
  void nodeLaidOut(NodeBox box);
  void nodePainted(NodeBox box);
}

/// The screen a tree's responsive variances pick their variant for: the
/// project's [breakpoints] and the screen's [width].
@immutable
final class ResponsiveWidth {
  const ResponsiveWidth(this.breakpoints, this.width);
  final api.Breakpoints breakpoints;
  final double width;

  @override
  bool operator ==(Object other) => other is ResponsiveWidth && other.width == width && other.breakpoints == breakpoints;

  @override
  int get hashCode => Object.hash(breakpoints, width);
}

typedef _Container = ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>;

/// Owns the boxes built from one [NodeSource].
class NodeTree {
  NodeTree(this.source,
      {this.observer, IslandEnvironment environment = const IslandEnvironment(), NodeBinder? binder, NodeInteractions? interactions})
      : islands = IslandManager(environment) {
    _binder = binder;
    _interactions = interactions;
  }

  final NodeSource source;
  NodeTreeObserver? observer;

  /// The islands (widget-built nodes) of this tree.
  final IslandManager islands;

  /// Wires the nodes' reactions while the tree is interactive (a running
  /// app); null: nodes don't react. Setting it re-applies every box.
  NodeInteractions? get interactions => _interactions;
  NodeInteractions? _interactions;
  set interactions(NodeInteractions? value) {
    if (identical(value, _interactions)) return;
    for (final b in _boxes.values) {
      _interactions?.released(b);
    }
    _interactions = value;
    for (final b in _boxes.values.toList()) {
      b._apply();
    }
  }

  /// Whether behaviours play (a running app: entrances, loops, spins) or
  /// rest (a design canvas).
  bool get animates => islands.environment.interactive;

  /// The interaction states held by each node (in a repeat instance).
  final Map<(String, Object?), Set<api.WidgetState>> _states = {};

  /// The interaction states node [id] is in.
  Set<api.WidgetState> statesOf(String id, {Object? instance}) => _states[(id, instance)] ?? const {};

  /// Turns [state] of node [id] on or off: the nodes its state styles
  /// patch re-apply (see [api.StateStyles]).
  void setState(String id, api.WidgetState state, bool on, {Object? instance}) {
    final key = (id, instance);
    final current = _states[key] ?? const <api.WidgetState>{};
    if (current.contains(state) == on) return;
    final next = {...current};
    on ? next.add(state) : next.remove(state);
    next.isEmpty ? _states.remove(key) : _states[key] = next;
    final affected = {id, ...?source.node(id)?.behaviours.states.targets};
    for (final b in _boxes.values.toList()) {
      if (b.instance == instance && affected.contains(b.id)) b._apply();
    }
  }

  NodeBinder? _binder;

  /// Applies the nodes' bindings (variables, conditions, `${...}` text) when
  /// set; null renders the nodes as stored. Setting it re-applies every box.
  NodeBinder? get binder => _binder;
  set binder(NodeBinder? value) {
    if (identical(value, _binder)) return;
    _binder = value;
    for (final b in _boxes.values.toList()) {
      b._apply();
    }
  }

  /// The screen responsive variances pick their variant for (DESIGN.md
  /// §5.3): the project's breakpoints and the width the layout is shown at
  /// (a running app sets it); null shows each variance's `current` variant
  /// (a design canvas, which sets `current` itself).
  ResponsiveWidth? get responsive => _responsive;
  ResponsiveWidth? _responsive;
  set responsive(ResponsiveWidth? value) {
    if (value == _responsive) return;
    final before = _responsive;
    _responsive = value;
    for (final b in _boxes.values.toList()) {
      final n = source.node(b.id);
      if (n == null || !n.isResponsive) continue;
      // Only the ones that now show another variant.
      if (before != null && value != null && n.variantForWidth(before.width, before.breakpoints)?['id'] == n.variantForWidth(value.width, value.breakpoints)?['id']) {
        continue;
      }
      b._apply();
    }
  }

  /// Re-applies the boxes of nodes [ids] (every instance): what they show
  /// changed outside their node and the names they read (an editor changed
  /// the conditions that set them).
  void reapply(Iterable<String> ids) {
    final set = ids is Set<String> ? ids : ids.toSet();
    if (set.isEmpty) return;
    for (final b in _boxes.values.toList()) {
      if (set.contains(b.id)) b._apply();
    }
  }

  /// Node [id] as shown: the source's, patched by the active interaction
  /// states that style it, its bindings applied ([binder]).
  Node? resolve(String id, {Object? instance}) => resolveBound(id, instance: instance)?.node;

  /// [resolve], with whether a binding hides the node and what it read.
  BoundNode? resolveBound(String id, {Object? instance}) {
    final n = _patched(id, instance);
    if (n == null) return null;
    return _binder?.bind(source, n, instance) ?? BoundNode(n);
  }

  Node? _patched(String id, Object? instance) {
    final n = source.node(id);
    if (n == null || _states.isEmpty) return n;
    var out = n;
    for (final e in _states.entries) {
      if (e.key.$2 != instance) continue;
      final patch = source.node(e.key.$1)?.behaviours.states.patchFor(id, e.value);
      if (patch != null) out = out.patched(patch);
    }
    return out;
  }

  /// The key of node [id]'s box in [instance] (null: outside repeats).
  static String keyOf(String id, Object? instance) => instance == null ? id : '$instance/$id';

  final Map<String, NodeBox> _boxes = {};
  final Set<NodeBox> _orphans = {};
  bool _sweepScheduled = false;

  NodeBox? boxOf(String id, {Object? instance}) => _boxes[keyOf(id, instance)];
  int get length => _boxes.length;

  NodeBox obtain(String id, Slot slot, {Object? instance}) {
    final key = keyOf(id, instance);
    final existing = _boxes[key];
    if (existing != null) {
      _orphans.remove(existing);
      existing._setSlot(slot);
      return existing;
    }
    final box = NodeBox._(this, id, slot, instance);
    _boxes[key] = box;
    box._subscribe();
    box._apply();
    return box;
  }

  /// [box] was taken out of its parent: unless something places it again by
  /// the end of the frame (a moved node, a list item, a node inside an
  /// island, which places its nodes while laid out), it's released.
  void orphan(NodeBox box) {
    if (!identical(_boxes[box.key], box)) return;
    _orphans.add(box);
    if (_sweepScheduled) return;
    _sweepScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _sweepScheduled = false;
      final orphans = _orphans.toList();
      _orphans.clear();
      for (final b in orphans) {
        if (b.parent == null && identical(_boxes[b.key], b)) release(b);
      }
    }, debugLabel: 'NodeTree.orphan');
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void release(NodeBox box) {
    if (box.parent != null) box.detachFromParent();
    box._releaseSubtree();
  }

  void dispose() {
    for (final b in _boxes.values.toList()) {
      b._unsubscribe();
    }
    _boxes.clear();
    islands.dispose();
  }
}

extension _NodeLayout on Node {
  bool get isFlex => type == 'row' || type == 'column';
  bool get isRow => type == 'row';
  SizeFit get hFit => layout.width.fit;
  SizeFit get vFit => layout.height.fit;
  Size get designSize => Size(layout.width.value, layout.height.value);
  double get outerWidth => layout.width.value + layout.margin.horizontal;
  double get outerHeight => layout.height.value + layout.margin.vertical;
  Size get innerSize => Size(
        math.max(0, layout.width.value - layout.padding.horizontal),
        math.max(0, layout.height.value - layout.padding.vertical),
      );
  bool get scrolls => prop(ScrollProps.scrollable);
  api.Axis get scrollDirection => prop(ScrollProps.scrollDirection);
  bool get wraps => isFlex && prop(FlexProps.wrap);
}

/// One node in the render tree.
class NodeBox extends RenderProxyBox implements NodeBuilder {
  NodeBox._(this.tree, this.id, this._slot, this.instance);

  @override
  final NodeTree tree;
  @override
  final String id;
  @override
  final Object? instance;
  String get key => NodeTree.keyOf(id, instance);
  Slot _slot;
  @override
  Slot get slot => _slot;
  Node? _node;

  /// The node as rendered.
  Node? get node => _node;
  ValueListenable<Node?>? _listenable;

  static final Map<String, int> debugApplyCounts = {};
  static bool debugCountApplies = false;

  /// The node's own box (margin excluded).
  RenderBox? contentBox;

  List<RenderBox> _chain = const [];
  final Map<String, RenderBox> _objects = {};
  _Container? _container;

  bool _hidden = false;
  bool get hidden => _hidden;
  set hidden(bool v) {
    if (v == _hidden) return;
    _hidden = v;
    markNeedsPaint();
  }

  /// This node's rect (margin excluded) relative to [ancestor].
  Rect? rectIn(RenderObject ancestor) {
    final box = contentBox ?? this;
    if (!box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(box.getTransformTo(ancestor), Offset.zero & box.size);
  }

  /// Hidden by a binding or condition (not by its own `visible`): it takes
  /// no space, as SDK 8.x's `Visibility` without `maintainSize`.
  bool get collapsed => _collapsed;
  bool _collapsed = false;
  List<Listenable> _bindingWatch = const [];
  Listenable? _bindingListenable;

  void _watchBindings(List<Listenable> watch) {
    if (listEquals(watch, _bindingWatch)) return;
    _bindingListenable?.removeListener(_apply);
    _bindingWatch = watch;
    _bindingListenable = watch.isEmpty ? null : (Listenable.merge(watch)..addListener(_apply));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (_collapsed) {
      size = constraints.smallest;
    } else if (child == null) {
      size = constraints.smallest;
    } else {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    }
    tree.observer?.nodeLaidOut(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    tree.interactions?.attachChanged(this);
  }

  @override
  void detach() {
    super.detach();
    tree.interactions?.attachChanged(this);
  }

  /// Whether it draws (not hidden, collapsed or invisible).
  bool get drawn => !(_hidden || _collapsed || (_node != null && !_node!.visible));

  @override
  void paint(PaintingContext context, Offset offset) {
    tree.observer?.nodePainted(this);
    if (_hidden || _collapsed || (_node != null && !_node!.visible)) return;
    super.paint(context, offset);
  }

  /// Takes a hit outside the box's size (a drag track's area or hit area,
  /// beyond its node); set by the node's layers on each apply.
  bool Function(BoxHitTestResult result, Offset position)? outsideHitTest;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_hidden || _collapsed || (_node != null && !_node!.visible)) return false;
    // A dragged node is hit where it is drawn, outside its layout box.
    if (child case final RenderDragMotion drag) {
      if (!drag.hitTest(result, position: position)) return false;
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    final outside = outsideHitTest;
    if (outside != null && hasSize && !size.contains(position)) return outside(result, position);
    return super.hitTest(result, position: position);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _collapsed ? constraints.smallest : super.computeDryLayout(constraints);

  @override
  double computeMinIntrinsicWidth(double height) => _collapsed ? 0 : super.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) => _collapsed ? 0 : super.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _collapsed ? 0 : super.computeMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _collapsed ? 0 : super.computeMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _collapsed ? null : super.computeDistanceToActualBaseline(baseline);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_collapsed) super.visitChildrenForSemantics(visitor);
  }

  // --- reconciliation ---------------------------------------------------------

  void _subscribe() => _listenable = tree.source.watch(id)..addListener(_apply);

  void _unsubscribe() {
    _listenable?.removeListener(_apply);
    _listenable = null;
    _watchBindings(const []);
  }

  void _setSlot(Slot slot) {
    if (slot == _slot) return;
    _slot = slot;
    _apply();
  }

  @override
  Node? nodeOf(String id) => tree.source.node(id);

  @override
  T obtain<T extends RenderBox>(String key, T Function() create) => _obtain(key, create);

  @override
  RenderFitBox fitBox(String key, SizeFit h, SizeFit v, Size size) => _fitBox(key, h, v, size);

  @override
  void shell(Node n, List<RenderBox> chain, {void Function(List<RenderBox> inner)? content, bool padded = true}) =>
      _shell(n, chain, content: content, padded: padded);

  @override
  void flex(Node n, List<RenderBox> chain) => _rowColumn(n, chain);

  @override
  void freeform(Node n, List<RenderBox> chain, {List<String>? children}) => _freeform(n, chain, children: children);

  @override
  void syncChildren(ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>> container, List<String> ids,
          Slot childSlot, {Object? instance, List<Object?>? instances}) =>
      _syncChildren(container, ids, childSlot, instance: instance, instances: instances);

  final Map<String, IslandHost> _islands = {};
  final Set<String> _islandsUsed = {};

  @override
  RenderBox island(String key, WidgetBuilder build) {
    _islandsUsed.add(key);
    final existing = _islands[key];
    if (existing != null && !existing.disposed) {
      existing.builder = build;
      return existing;
    }
    return _islands[key] = tree.islands.host('$id#$key', build);
  }

  void _releaseUnusedIslands() {
    for (final k in _islands.keys.toList()) {
      if (!_islandsUsed.contains(k)) _islands.remove(k)!.release();
    }
    _islandsUsed.clear();
  }

  T _obtain<T extends RenderBox>(String key, T Function() create) {
    final existing = _objects[key];
    if (existing is T) return existing;
    final made = create();
    _objects[key] = made;
    return made;
  }

  Node? _applied;

  void _apply() {
    if (debugCountApplies) debugApplyCounts.update(id, (v) => v + 1, ifAbsent: () => 1);
    final bound = tree.resolveBound(id, instance: instance);
    final resolved = bound?.node;
    // Bindings give a new node each time: the same one keeps its identity,
    // which the children's slots compare (else re-applying a row whose
    // structure depends on its children re-applies them, and so on).
    final n = resolved != null && _applied != null && resolved == _applied ? _applied : resolved;
    _watchBindings(bound?.watch ?? const []);
    if ((bound?.collapsed ?? false) != _collapsed) {
      _collapsed = !_collapsed;
      markNeedsLayout();
      _applyParentData();
    }
    // A top-level node that only moved: its content doesn't depend on where
    // it sits (the host offsets it), so nothing re-applies or repaints.
    if (_slot.kind == SlotKind.root && n != null && _applied != null && _onlyMoved(_applied!, n)) {
      _node = n;
      _applied = n;
      return;
    }
    _node = n;
    _applied = n;
    contentBox = null;
    if (n == null) {
      _releaseContainerChildren();
      _wire(const []);
      _releaseUnusedIslands();
      _relayoutHuggingAncestors();
      return;
    }
    final chain = <RenderBox>[];
    _previousInner = [
      for (final c in _innerChains.values) ...c,
      for (final e in _stackExtras.values) ...[...e.$1, ...e.$2],
    ];
    _innerChains.clear();
    _stackExtras.clear();
    _filledStacks.clear();

    _parentSideWrappers(n, chain);
    outsideHitTest = null;
    // A node that follows the pointer moves with its margin (outermost).
    dragMotionLayers(this, n, chain);

    // Outer layers, outermost first: margin, constraints, motion and scale
    // (render/behaviours.dart), rotation, loops, opacity, blurs and stroke
    // path.
    final margin = n.layout.margin.flutter;
    if (margin != EdgeInsets.zero) {
      chain.add(_obtain<RenderPadding>('margin', () => RenderPadding(padding: margin, textDirection: TextDirection.ltr))
        ..padding = margin);
    }
    if (!n.layout.constraints.isEmpty) {
      final c = n.layout.constraints.flutter;
      chain.add(_obtain<RenderConstrainedBox>('constraints', () => RenderConstrainedBox(additionalConstraints: c))
        ..additionalConstraints = c);
    }
    playLayers(this, n, chain, animates: tree.animates);
    motionLayers(this, n, chain, animates: tree.animates);
    if (n.layout.rotation != 0) {
      final m = n.layout.margin;
      chain.add(_obtain<RenderTransform>('rotation', () => RenderTransform(transform: Matrix4.identity()))
        ..transform = Matrix4.rotationZ(n.layout.rotation * math.pi / 180)
        ..origin = Offset(m.left / 2 - m.right / 2, m.top / 2 - m.bottom / 2)
        ..alignment = Alignment.center);
    }
    heroLayer(this, n, chain, animates: tree.animates);
    // Drag and drop around the reactions (gestures/drag_and_drop.dart).
    dragAndDropLayers(this, n, chain);
    if (tree.animates) tree.interactions?.addLayers(this, n, chain);
    loopLayers(this, n, chain, animates: tree.animates);
    if (n.opacity < 0.99) {
      chain.add(_obtain<RenderOpacity>('opacity', () => RenderOpacity(opacity: n.opacity))..opacity = n.opacity);
    }
    paintLayers(this, n, chain);
    final contentStart = chain.length;
    final ratio = n.layout.aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      chain.add(_fitBox('aspect', n.hFit, n.vFit, n.designSize)..aspectRatio = ratio);
    }
    _content(n, chain);
    contentBox = chain.length > contentStart ? chain[contentStart] : null;

    _wire(chain);
    _releaseUnusedIslands();
    _notifyDependentAncestors();
    _applyParentData();
    _relayoutHuggingAncestors();
  }

  /// A row/column that hugs its cross axis and stretches its children
  /// measures them unstretched, then lays them out stretched, which makes
  /// them relayout boundaries: a change inside one stops there. This node
  /// changed, so the hugging layouts above it measure again (as a fresh
  /// render would). Not while the tree lays out (a node built inside an
  /// island or a list item): the layout under way measures it already, and
  /// marking its ancestors would assert.
  void _relayoutHuggingAncestors() {
    if (!attached) return;
    var laying = false;
    assert(() {
      laying = owner?.debugDoingLayout ?? false;
      return true;
    }());
    if (!laying) RenderHugCross.relayoutAbove(this);
  }

  /// [a] and [b] differ at most in their position.
  static bool _onlyMoved(Node a, Node b) {
    if (identical(a, b)) return true;
    if (a.layout.width != b.layout.width || a.layout.height != b.layout.height) return false;
    return a.copyWith(layout: b.layout) == b;
  }

  bool _dependsOnDescendants = false;
  bool _reapplyScheduled = false;

  /// Row/columns above whose structure depends on their descendants
  /// re-decide it (coalesced, after the current change).
  void _notifyDependentAncestors() {
    var p = tree.source.parentOf(id);
    while (p != null) {
      final box = tree._boxes[NodeTree.keyOf(p, instance)];
      if (box != null && box._dependsOnDescendants) box._reapplySoon();
      p = tree.source.parentOf(p);
    }
  }

  void _reapplySoon() {
    if (_reapplyScheduled) return;
    _reapplyScheduled = true;
    scheduleMicrotask(() {
      _reapplyScheduled = false;
      if (tree._boxes[key] == this) _apply();
    });
  }

  // --- content per type -------------------------------------------------------

  void _content(Node n, List<RenderBox> chain) {
    switch (n.type) {
      case 'spacer':
        _spacer(n, chain);
      case 'variance':
        _variance(n, chain);
      case 'canvas':
        _canvas(n, chain);
      case 'row' || 'column':
        _shell(n, chain, content: (inner) => _rowColumn(n, inner));
      case 'stack':
        if (n.scrolls) {
          _shell(n, chain, padded: false, content: (inner) => _scrollingFreeform(n, inner));
        } else {
          _shell(n, chain, content: (inner) => _freeform(n, inner));
        }
      case 'box':
        if (n.prop(api.BoxProps.path).isNotEmpty) {
          buildBoxPath(this, n, chain);
        } else {
          _shell(n, chain);
        }
      case 'text':
        _text(n, chain);
      case 'icon':
        _icon(n, chain);
      default:
        final recipe = widgetRecipes[n.type];
        if (recipe != null) {
          recipe(this, n, chain);
        } else {
          // A type this SDK doesn't render yet: its box, at its size.
          chain.add(_fitBox('placeholder', n.hFit, n.vFit, n.designSize));
        }
    }
  }

  bool get _isPlaceholder {
    final parent = _slot.parent;
    return parent != null && parent.type == 'canvas' && parent.slots['body'] == id;
  }

  /// The shell (PassiveRectangleWidget): fit box → shadows → decoration →
  /// stroke → clip → stack [paint layers, (padding) content].
  void _shell(Node n, List<RenderBox> chain, {void Function(List<RenderBox> inner)? content, bool padded = true}) {
    final isPlaceholder = _isPlaceholder;
    final contentSized = _scrollsFlexiblyOnMainAxis(n);
    final hFit = isPlaceholder || (contentSized && n.isRow) ? SizeFit.hug : n.hFit;
    final vFit = isPlaceholder || (contentSized && !n.isRow) ? SizeFit.hug : n.vFit;
    chain.add(_fitBox('shellFit', hFit, vFit, n.designSize));

    final d = n.decoration;
    final radius = d.radius.isZero ? null : d.radius.flutter;
    final rounded = radius != null;
    final shadows = [
      for (final e in d.effects)
        if (e.visible && e.type == api.EffectType.dropShadow) boxShadow(e),
    ];
    final spread = [if (rounded) for (final sh in shadows) if (sh.spreadRadius != 0) sh];
    if (spread.isNotEmpty) {
      chain.add(_obtain<RenderCustomPaint>('spread', RenderCustomPaint.new)
        ..painter = SpreadShadowPainter(shadows: spread, borderRadius: radius!));
    }
    final plan = _PaintPlan.of(n);
    chain.add(_obtain<RenderDecoratedBox>('decoration', () => RenderDecoratedBox(decoration: const BoxDecoration()))
      ..decoration = BoxDecoration(
        boxShadow: [for (final sh in shadows) if (!spread.contains(sh)) sh],
        borderRadius: radius,
        color: plan.native ? plan.fill : null,
      ));
    if (plan.native && plan.border != null) {
      chain.add(_obtain<RenderDecoratedBox>('stroke', () => RenderDecoratedBox(decoration: const BoxDecoration()))
        ..decoration = BoxDecoration(borderRadius: radius, border: plan.border));
    }
    final clipBehavior = clip(d.clip);
    if (clipBehavior != Clip.none) {
      if (rounded) {
        chain.add(_obtain<RenderClipRRect>('clipRRect', () => RenderClipRRect(clipBehavior: clipBehavior))
          ..borderRadius = radius
          ..clipBehavior = clipBehavior);
      } else {
        chain.add(_obtain<RenderClipRect>('clipRect', () => RenderClipRect(clipBehavior: clipBehavior))
          ..clipBehavior = clipBehavior);
      }
    }
    final under = <RenderBox>[], over = <RenderBox>[];
    final canStack = content != null || (hFit != SizeFit.hug && vFit != SizeFit.hug);
    if (canStack && !plan.native) {
      under.add(_obtain<RenderNodePaint>('under', RenderNodePaint.new)
        ..decoration = d
        ..foreground = false);
    }
    if (canStack && plan.foreground) {
      over.add(_obtain<RenderNodePaint>('over', RenderNodePaint.new)
        ..decoration = d
        ..foreground = true);
    }
    if (canStack && tree.animates && n.behaviours.inkWell != null) under.add(inkOverlay(this, n, radius));
    if (content == null && under.isEmpty && over.isEmpty) return;
    final stack = _obtain<RenderStack>('shellStack',
        () => RenderStack(alignment: AlignmentDirectional.topStart, textDirection: TextDirection.ltr, clipBehavior: Clip.none));
    _stackExtras[stack] = (under, over);
    if (content == null) {
      _innerChains[stack] = const [];
      chain.add(stack);
      return;
    }
    final inner = <RenderBox>[];
    final padding = n.layout.padding.flutter;
    final applyPadding = padded && !n.scrolls;
    if (applyPadding && padding != EdgeInsets.zero) {
      inner.add(_fitBox('padFit', isPlaceholder ? SizeFit.hug : n.hFit, isPlaceholder ? SizeFit.hug : n.vFit, n.designSize));
      inner.add(_obtain<RenderPadding>('pad', () => RenderPadding(padding: padding, textDirection: TextDirection.ltr))
        ..padding = padding);
      inner.add(_obtain<RenderStack>('padStack',
          () => RenderStack(alignment: AlignmentDirectional.topStart, textDirection: TextDirection.ltr, clipBehavior: Clip.none)));
    }
    content(inner);
    _innerChains[stack] = inner;
    // SDK 8.x put the content of a shell with ink in its InkWell, filling
    // the shell (Positioned.fill) when the shell has a size on both axes:
    // its content then sizes nothing (no intrinsic size either).
    if (n.behaviours.inkWell != null && n.hFit != SizeFit.hug && n.vFit != SizeFit.hug) _filledStacks.add(stack);
    chain.add(stack);
  }

  /// Shell stacks whose content fills them (positioned) instead of sizing
  /// them.
  final Set<RenderStack> _filledStacks = {};

  final Map<RenderStack, List<RenderBox>> _innerChains = {};
  final Map<RenderStack, (List<RenderBox>, List<RenderBox>)> _stackExtras = {};
  List<RenderBox> _previousInner = const [];

  RenderFitBox _fitBox(String key, SizeFit h, SizeFit v, Size size) {
    return _obtain<RenderFitBox>(key, () => RenderFitBox())
      ..width = h == SizeFit.hug ? null : size.width
      ..height = v == SizeFit.hug ? null : size.height
      ..fillWidth = h == SizeFit.fill
      ..fillHeight = v == SizeFit.fill
      ..aspectRatio = null;
  }

  /// A row/column that scrolls along its main axis and is flexible on it:
  /// as long as its content, capped by its Flexible parent.
  static bool _scrollsFlexiblyOnMainAxis(Node n) {
    if (!n.isFlex || n.wraps || !n.scrolls) return false;
    if (n.scrollDirection != (n.isRow ? api.Axis.horizontal : api.Axis.vertical)) return false;
    return (n.isRow ? n.hFit : n.vFit) == SizeFit.flexible;
  }

  void _rowColumn(Node n, List<RenderBox> chain) {
    final isRow = n.isRow;
    final isPlaceholder = _isPlaceholder;
    final contentSized = _scrollsFlexiblyOnMainAxis(n);
    final scrolls = n.scrolls;
    final padding = scrolls ? api.EdgeInsets.zero : n.layout.padding;
    final c = n.layout.constraints;

    double? outerExtent(SizeFit fit, double design, double? max, double inset) => switch (fit) {
          SizeFit.hug => null,
          SizeFit.fill => max == null ? design : math.max(0, max - inset),
          SizeFit.fixed || SizeFit.flexible => design,
        };
    bool fills(SizeFit fit, double? max) => fit == SizeFit.fill && max == null;

    final ow = contentSized && isRow ? null : outerExtent(n.hFit, n.outerWidth, c.maxWidth, padding.horizontal);
    final ofw = fills(n.hFit, c.maxWidth);
    final placeholderFlexHeight = isPlaceholder && (n.vFit == SizeFit.fill || n.vFit == SizeFit.flexible);
    final oh = contentSized && !isRow
        ? null
        : placeholderFlexHeight
            ? c.minHeight
            : outerExtent(n.vFit, n.outerHeight, c.maxHeight, padding.vertical);
    final ofh = !placeholderFlexHeight && fills(n.vFit, c.maxHeight);
    if (ow != null || oh != null || ofw || ofh) {
      if (!ofw && !ofh) {
        final bc = BoxConstraints.tightFor(width: ow, height: oh);
        chain.add(_obtain<RenderConstrainedBox>('outerSized', () => RenderConstrainedBox(additionalConstraints: bc))
          ..additionalConstraints = bc);
      } else {
        chain.add(_obtain<RenderFitBox>('outerFit', () => RenderFitBox())
          ..width = ow
          ..height = oh
          ..fillWidth = ofw
          ..fillHeight = ofh
          ..aspectRatio = null);
      }
    }
    double? minExtent(double? min, double inset) => min == null ? null : math.max(0, min - inset);
    final minW = n.hFit == SizeFit.hug ? minExtent(c.minWidth, padding.horizontal) : null;
    final minH = n.vFit == SizeFit.hug && !placeholderFlexHeight ? minExtent(c.minHeight, padding.vertical) : null;
    if (minW != null || minH != null) {
      final bc = BoxConstraints(minWidth: minW ?? 0, minHeight: minH ?? 0);
      chain.add(_obtain<RenderConstrainedBox>('minExtent', () => RenderConstrainedBox(additionalConstraints: bc))
        ..additionalConstraints = bc);
    }

    final children = [for (final cid in n.children) ?tree.source.node(cid)];
    if (n.wraps) {
      _dependsOnDescendants = false;
      _wrap(n, chain, scrolls: scrolls);
      return;
    }
    if (scrolls) _scrollView(n, chain, children, contentSized: contentSized);
    final crossWraps = isRow ? n.vFit == SizeFit.hug : n.hFit == SizeFit.hug;
    final crossMin = isRow ? c.minHeight : c.minWidth;
    final cross = n.prop(FlexProps.crossAxisAlignment);
    final stretches = cross == api.CrossAxisAlignment.stretch;
    var measureCross = false, stretchFallsBack = false, hugStretch = false;
    _dependsOnDescendants = crossMin == null && crossWraps;
    if (crossMin == null && crossWraps) {
      final anyAlign = children.any((ch) => ch.layout.align != null);
      if (stretches) {
        hugStretch = true;
      } else if (anyAlign || _fillsAcrossWrapping(isRow, children)) {
        final blocked = children.any(_subtreeBlocksIntrinsics);
        measureCross = !blocked;
        stretchFallsBack = blocked && stretches;
      }
    }
    if (measureCross) {
      chain.add(isRow
          ? _obtain<RenderIntrinsicHeight>('intrH', RenderIntrinsicHeight.new)
          : _obtain<RenderIntrinsicWidth>('intrW', RenderIntrinsicWidth.new));
    } else if (hugStretch) {
      chain.add(_obtain<RenderHugCross>('hugCross', RenderHugCross.new));
    }
    final crossAlign = stretchFallsBack ? CrossAxisAlignment.start : crossAxisAlignment(cross);
    final mainFit = isRow ? n.hFit : n.vFit;
    final flex = _obtain<RenderCodelesslyFlex>('flex', () => RenderCodelesslyFlex(textDirection: TextDirection.ltr))
      ..direction = isRow ? Axis.horizontal : Axis.vertical
      ..mainAxisAlignment = mainAxisAlignment(n.prop(FlexProps.mainAxisAlignment))
      ..crossAxisAlignment = crossAlign
      ..textBaseline = crossAlign == CrossAxisAlignment.baseline ? TextBaseline.alphabetic : null
      ..mainAxisSize = mainFit == SizeFit.hug ? MainAxisSize.min : MainAxisSize.max
      ..gap = n.prop(FlexProps.spacing)
      ..squeeze = n.prop(FlexProps.squeezeChildren);
    _syncChildren(flex, n.children, Slot(SlotKind.flex, n));
    chain.add(flex);
  }

  /// A row/column whose children flow onto new runs (SDK 8.x's
  /// CodelesslyWrap): main-axis alignment within each run, cross-axis
  /// alignment within a run and for the runs; a scrollable one scrolls
  /// through its runs.
  void _wrap(Node n, List<RenderBox> chain, {required bool scrolls}) {
    final cross = n.prop(FlexProps.crossAxisAlignment);
    final runAlignment = switch (cross) {
      api.CrossAxisAlignment.center => WrapAlignment.center,
      api.CrossAxisAlignment.end => WrapAlignment.end,
      _ => WrapAlignment.start,
    };
    if (scrolls) {
      _scrollView(n, chain, const [],
          contentSized: false, fillViewport: runAlignment != WrapAlignment.start || n.prop(FlexProps.fillViewport));
    }
    final wrap = _obtain<RenderCodelesslyWrap>('wrap', RenderCodelesslyWrap.new)
      ..direction = n.isRow ? Axis.horizontal : Axis.vertical
      ..alignment = switch (n.prop(FlexProps.mainAxisAlignment)) {
        api.MainAxisAlignment.start => WrapAlignment.start,
        api.MainAxisAlignment.end => WrapAlignment.end,
        api.MainAxisAlignment.center => WrapAlignment.center,
        api.MainAxisAlignment.spaceBetween => WrapAlignment.spaceBetween,
        api.MainAxisAlignment.spaceAround => WrapAlignment.spaceAround,
        api.MainAxisAlignment.spaceEvenly => WrapAlignment.spaceEvenly,
      }
      ..spacing = n.prop(FlexProps.spacing)
      ..runAlignment = runAlignment
      ..runSpacing = n.prop(FlexProps.runSpacing)
      ..crossAxisAlignment = switch (cross) {
        api.CrossAxisAlignment.center => WrapCrossAlignment.center,
        api.CrossAxisAlignment.end => WrapCrossAlignment.end,
        _ => WrapCrossAlignment.start,
      }
      ..textDirection = TextDirection.ltr;
    _syncChildren(wrap, n.children, Slot(SlotKind.flex, n));
    chain.add(wrap);
  }

  /// A child fills the cross axis of a wrapping row/column while another
  /// gives it a thickness (IntrinsicHeight(Row(...))).
  static bool _fillsAcrossWrapping(bool isRow, List<Node> children) {
    bool fills(Node c) => c.type != 'spacer' && (isRow ? c.vFit : c.hFit) == SizeFit.fill;
    return children.any(fills) && children.any((c) => c.type != 'spacer' && !fills(c));
  }

  /// Whether intrinsic measurement can't see into [node]'s subtree
  /// (scrolling content).
  bool _subtreeBlocksIntrinsics(Node node) {
    if (const {'gridView', 'pageView', 'webView'}.contains(node.type)) return true;
    if (node.type == 'listView' && !listBuildsAllItems(node)) return true;
    if (node.type != 'canvas' && node.scrolls) return true;
    for (final c in node.childIds) {
      final child = tree.source.node(c);
      if (child != null && _subtreeBlocksIntrinsics(child)) return true;
    }
    return false;
  }

  /// A scroll view at rest: fit box → viewport → padding → content extent.
  void _scrollView(Node n, List<RenderBox> chain, List<Node> children,
      {required bool contentSized, bool? fillViewport}) {
    final vertical = n.scrollDirection == api.Axis.vertical;
    chain.add(_fitBox(
      'scrollFit',
      contentSized && !vertical ? SizeFit.hug : n.hFit,
      contentSized && vertical ? SizeFit.hug : n.vFit,
      n.designSize,
    ));
    final axis = vertical ? Axis.vertical : Axis.horizontal;
    final viewport = _obtain<RenderDesignScroll>('scroll', () => RenderDesignScroll(axis: axis))
      ..axis = axis
      ..reverse = n.prop(ScrollProps.reverse)
      ..clipBehavior = clip(n.prop(ScrollProps.clipBehavior));
    chain.add(viewport);
    final pad = n.layout.padding.flutter;
    if (pad != EdgeInsets.zero) {
      chain.add(_obtain<RenderPadding>('scrollPad', () => RenderPadding(padding: pad, textDirection: TextDirection.ltr))
        ..padding = pad);
    }
    fillViewport ??= n.isFlex &&
        !contentSized &&
        (n.prop(FlexProps.mainAxisAlignment) != api.MainAxisAlignment.start || n.prop(FlexProps.fillViewport));
    final flexContent = n.isFlex && children.any((c) => (n.isRow ? c.hFit : c.vFit) == SizeFit.fill || (n.isRow ? c.hFit : c.vFit) == SizeFit.flexible);
    if (fillViewport || flexContent) {
      final extent = _obtain<RenderScrollContentExtent>(
          'scrollExtent', () => RenderScrollContentExtent(axis: axis, viewportExtent: double.infinity))
        ..axis = axis;
      viewport.onViewport = (max) {
        final e = max - (vertical ? pad.vertical : pad.horizontal);
        extent.viewportExtent = e.isFinite && e > 0 ? e : double.infinity;
      };
      chain.add(extent);
    } else {
      viewport.onViewport = null;
    }
  }

  void _freeform(Node n, List<RenderBox> chain, {List<String>? children}) {
    final layout = _obtain<RenderFreeformLayout>(
        'freeform', () => RenderFreeformLayout(wrapsWidth: false, wrapsHeight: false, designSize: Size.zero))
      ..wrapsWidth = n.hFit == SizeFit.hug
      ..wrapsHeight = n.vFit == SizeFit.hug
      ..designSize = n.innerSize
      ..textDirection = TextDirection.ltr;
    _syncChildren(layout, children ?? n.children, Slot(SlotKind.freeform, n));
    chain.add(layout);
  }

  void _scrollingFreeform(Node n, List<RenderBox> chain) {
    _scrollView(n, chain, const [], contentSized: false);
    _freeform(n, chain);
  }

  /// The current variant's first child, in a freeform layout.
  void _variance(Node n, List<RenderBox> chain) {
    final variants = n.prop(api.VarianceProps.variants);
    final current = n.prop(api.VarianceProps.current);
    // A responsive one shows the variant for the screen's width.
    final responsive = tree.responsive;
    final variant = (responsive != null && n.isResponsive ? n.variantForWidth(responsive.width, responsive.breakpoints) : null) ??
        variants.firstWhere((v) => v['id'] == current, orElse: () => variants.firstOrNull ?? const {});
    final kids = api.readStrings(variant['children']);
    if (kids.isEmpty) {
      final c = BoxConstraints.tight(n.designSize);
      chain.add(_obtain<RenderConstrainedBox>('empty', () => RenderConstrainedBox(additionalConstraints: c))
        ..additionalConstraints = c);
      return;
    }
    _shell(n, chain, content: (inner) => _freeform(n, inner, children: [kids.first]));
  }

  /// A screen: its rectangle at its size, its body in the shell's stack.
  void _canvas(Node n, List<RenderBox> chain) {
    _shell(n, chain, content: (inner) {
      final body = n.slots['body'];
      final stack = _obtain<RenderStack>('bodyStack',
          () => RenderStack(alignment: AlignmentDirectional.topStart, textDirection: TextDirection.ltr, clipBehavior: Clip.none));
      _syncChildren(stack, [if (body != null && tree.source.node(body) != null) body], Slot(SlotKind.canvasBody, n));
      inner.add(stack);
    });
  }

  void _spacer(Node n, List<RenderBox> chain) {
    final parent = _slot.parent;
    if (_slot.kind == SlotKind.flex && parent != null && parent.wraps) {
      // No room in a run but its own length along it.
      final isRow = parent.isRow;
      final c = BoxConstraints.tightFor(width: isRow ? n.outerWidth : 0, height: isRow ? 0 : n.outerHeight);
      chain.add(_obtain<RenderConstrainedBox>('spacerSized', () => RenderConstrainedBox(additionalConstraints: c))
        ..additionalConstraints = c);
      return;
    }
    if (_slot.kind == SlotKind.flex && parent != null && parent.isFlex) {
      final isRow = parent.isRow;
      final mainFit = isRow ? n.hFit : n.vFit;
      final outer = isRow ? n.outerWidth : n.outerHeight;
      if (mainFit == SizeFit.fill || mainFit == SizeFit.flexible) {
        chain.add(_obtain<RenderFitBox>('spacerFit', () => RenderFitBox())
          ..width = isRow ? outer : null
          ..height = isRow ? null : outer
          ..fillWidth = isRow
          ..fillHeight = !isRow
          ..aspectRatio = null);
      } else {
        final c = BoxConstraints.tightFor(width: isRow ? outer : null, height: isRow ? null : outer);
        chain.add(_obtain<RenderConstrainedBox>('spacerSized', () => RenderConstrainedBox(additionalConstraints: c))
          ..additionalConstraints = c);
      }
      return;
    }
    chain.add(_fitBox('spacerAdaptive', n.hFit, n.vFit, n.designSize));
  }

  /// Text (TextNodeBox): sized box → slack → min height → align → paragraph.
  void _text(Node n, List<RenderBox> chain) {
    final hFit = n.hFit, vFit = n.vFit;
    final hugsWidth = hFit == SizeFit.hug || hFit == SizeFit.flexible;
    final minHeight = vFit != SizeFit.hug && vFit != SizeFit.fill;
    final c = BoxConstraints.tightFor(
      width: switch (hFit) {
        SizeFit.hug || SizeFit.flexible => null,
        SizeFit.fill => double.infinity,
        SizeFit.fixed => n.layout.width.value,
      },
      height: vFit == SizeFit.fill ? double.infinity : null,
    );
    chain.add(_obtain<RenderConstrainedBox>('textSized', () => RenderConstrainedBox(additionalConstraints: c))
      ..additionalConstraints = c);
    if (hFit == SizeFit.hug) chain.add(_obtain<RenderTextIntrinsicSlack>('textSlack', RenderTextIntrinsicSlack.new));
    if (minHeight) {
      chain.add(_obtain<RenderTextMinHeight>('textMin', () => RenderTextMinHeight(minHeight: 0))
        ..minHeight = n.layout.height.value);
    }
    final textAlign = n.prop(TextProps.textAlign);
    final y = switch (n.prop(TextProps.textAlignVertical)) {
      api.TextAlignVertical.top => -1.0,
      api.TextAlignVertical.center => 0.0,
      api.TextAlignVertical.bottom => 1.0,
    };
    final x = switch (textAlign) {
      api.TextAlign.center => 0.0,
      api.TextAlign.right || api.TextAlign.end => 1.0,
      _ => -1.0,
    };
    chain.add(_obtain<RenderPositionedBox>('textAlign', () => RenderPositionedBox(textDirection: TextDirection.ltr))
      ..alignment = Alignment(x, y)
      ..widthFactor = hugsWidth ? 1 : null
      ..heightFactor = vFit == SizeFit.fill ? null : 1);
    final span = _textSpan(n);
    final paragraph = _obtain<RenderParagraph>('paragraph', () => RenderParagraph(span, textDirection: TextDirection.ltr))
      ..text = span
      ..textAlign = flutterTextAlign(textAlign)
      ..maxLines = n.prop(TextProps.maxLines)
      ..overflow = textOverflow(n.prop(TextProps.overflow));
    if (n.prop(TextProps.scaleDown)) {
      chain.add(_obtain<RenderFittedBox>('textScale', () => RenderFittedBox(fit: BoxFit.scaleDown, textDirection: TextDirection.ltr))
        ..alignment = Alignment(x, y));
    }
    chain.add(paragraph);
  }

  static TextAlign flutterTextAlign(api.TextAlign a) => a == api.TextAlign.start ? TextAlign.left : textAlign(a);

  /// The node's text as spans: each run's characters in its style, merged
  /// over the text's base style.
  static TextSpan _textSpan(Node n) {
    final text = n.prop(TextProps.text);
    final base = n.prop(TextProps.style);
    final runs = n.prop(TextProps.runs);
    if (runs.isEmpty) return TextSpan(text: text, style: textStyle(base));
    return TextSpan(children: [
      for (final r in runs)
        TextSpan(
          text: text.substring(r.start.clamp(0, text.length), r.end.clamp(r.start.clamp(0, text.length), text.length)),
          style: textStyle(base.merge(r.style)),
        ),
    ]);
  }

  void _icon(Node n, List<RenderBox> chain) {
    chain.add(_fitBox('iconFit', n.hFit, n.vFit, n.designSize));
    final glyph = _obtain<RenderIconGlyph>('glyph', RenderIconGlyph.new)
      ..icon = n.prop(IconProps.icon)
      ..color = n.prop(IconProps.color)?.flutter
      ..designSize = n.designSize;
    chain.add(glyph);
  }

  // --- parent-side wrapping ---------------------------------------------------

  void _parentSideWrappers(Node n, List<RenderBox> chain) {
    final parent = _slot.parent;
    if (_slot.kind != SlotKind.flex || parent == null || !parent.isFlex) return;
    if (n.type == 'spacer') return;
    if (parent.wraps) {
      _inRun(n, chain);
      return;
    }
    final isRow = parent.isRow;
    final crossFit = isRow ? n.vFit : n.hFit;
    final parentHugsCross = (isRow ? parent.vFit : parent.hFit) == SizeFit.hug;
    final cross = parent.prop(FlexProps.crossAxisAlignment);
    final Alignment? align = n.layout.align?.flutter ??
        (cross == api.CrossAxisAlignment.stretch && crossFit == SizeFit.hug && !parentHugsCross ? Alignment.topLeft : null);
    if (align != null) {
      chain.add(_obtain<RenderPositionedBox>('slotAlign', () => RenderPositionedBox(alignment: align, textDirection: TextDirection.ltr))
        ..alignment = align);
    }
  }

  /// A child of a wrapping row/column (SDK 8.x's wrapChildInRun): fills
  /// and flexes mean nothing in a run, so a flexing axis hugs its content
  /// (measured intrinsically), or takes its design size when its subtree
  /// can't be measured. Its own alignment doesn't apply.
  void _inRun(Node n, List<RenderBox> chain) {
    bool flexes(SizeFit f) => f == SizeFit.fill || f == SizeFit.flexible;
    final fh = flexes(n.hFit), fv = flexes(n.vFit);
    if (!fh && !fv) return;
    if (!n.isFlex || _subtreeBlocksIntrinsics(n)) {
      final c = BoxConstraints.tightFor(width: fh ? n.outerWidth : null, height: fv ? n.outerHeight : null);
      chain.add(_obtain<RenderConstrainedBox>('runSized', () => RenderConstrainedBox(additionalConstraints: c))
        ..additionalConstraints = c);
      return;
    }
    if (fv) chain.add(_obtain<RenderIntrinsicHeight>('runH', RenderIntrinsicHeight.new));
    if (fh) chain.add(_obtain<RenderIntrinsicWidth>('runW', RenderIntrinsicWidth.new));
  }

  void _applyParentData() {
    final n = _node;
    final pd = parentData;
    final p = parent;
    final parentNode = _slot.parent;
    if (n == null) return;
    if (pd is CodelesslyFlexParentData && parentNode != null && parentNode.isFlex) {
      final isRow = parentNode.isRow;
      final mainFit = isRow ? n.hFit : n.vFit;
      final c = n.layout.constraints;
      final mainMax = isRow ? c.maxWidth : c.maxHeight;
      final flexValue = n.layout.flex;
      bool isFlexFit(SizeFit f) => f == SizeFit.fill || f == SizeFit.flexible;
      int? flex;
      FlexFit? fit;
      if (parentNode.wraps) {
        // Nothing flexes in a run.
      } else if (n.type == 'spacer') {
        if (mainFit == SizeFit.fill) (flex, fit) = (flexValue, FlexFit.tight);
        if (mainFit == SizeFit.flexible) (flex, fit) = (flexValue, FlexFit.loose);
      } else if (n.hFit == n.vFit) {
        if (n.hFit == SizeFit.fill) (flex, fit) = (flexValue, mainMax != null ? FlexFit.loose : FlexFit.tight);
        if (n.hFit == SizeFit.flexible) (flex, fit) = (flexValue, FlexFit.loose);
      } else if (isFlexFit(mainFit)) {
        (flex, fit) = (flexValue, mainFit == SizeFit.flexible || mainMax != null ? FlexFit.loose : FlexFit.tight);
      }
      if (mainFit == SizeFit.hug && n.layout.squeezable && !parentNode.wraps) (flex, fit) = (flexValue, FlexFit.loose);
      // Collapsed: no flex, no gaps (flex 0).
      if (_collapsed) (flex, fit) = (null, null);
      if (pd.flex != flex || pd.fit != fit || pd.collapsed != _collapsed) {
        pd
          ..flex = flex
          ..fit = fit
          ..collapsed = _collapsed;
        p?.markNeedsLayout();
      }
    } else if (pd is FreeformParentData && parentNode != null) {
      final placement = placementFor(n, parentNode, scrollAxis: _scrollAxisFor(parentNode));
      if (pd.placement != placement) {
        pd.placement = placement;
        p?.markNeedsLayout();
      }
    }
  }

  /// The axis [node]'s children scroll along, if any.
  Axis? _scrollAxisFor(Node node) {
    if (node.scrolls) return node.scrollDirection == api.Axis.vertical ? Axis.vertical : Axis.horizontal;
    final pid = tree.source.parentOf(node.id);
    final p = pid == null ? null : tree.source.node(pid);
    if (p != null && p.type == 'canvas' && p.slots['body'] == node.id && p.scrolls) {
      return p.scrollDirection == api.Axis.vertical ? Axis.vertical : Axis.horizontal;
    }
    return null;
  }

  /// Where a freeform child sits, from its v2 position (DESIGN.md §3).
  static FreeformPlacement placementFor(Node n, Node parent, {Axis? scrollAxis}) {
    FreeformAxisPlacement axis(bool horizontal) {
      final pos = horizontal ? n.layout.x : n.layout.y;
      final extent = horizontal ? n.outerWidth : n.outerHeight;
      final inner = parent.innerSize;
      final parentExtent = horizontal ? inner.width : inner.height;
      final fit = horizontal ? n.hFit : n.vFit;
      final c = n.layout.constraints;
      final expands = fit == SizeFit.fill && (horizontal ? c.maxWidth : c.maxHeight) == null;
      final wraps = fit == SizeFit.hug;
      final isScrollAxis = scrollAxis != null && (scrollAxis == Axis.horizontal) == horizontal;
      final start = pos.start ?? pos.relative ?? (pos.end != null ? parentExtent - pos.end! - extent : 0.0);
      final grows = n.type == 'text';
      FreeformAxisPlacement at(FreeformAxisMode mode, {double alignment = 0}) => FreeformAxisPlacement(
            mode: mode,
            start: start,
            extent: extent,
            parentExtent: parentExtent,
            size: wraps || expands ? null : extent,
            alignment: alignment,
            clamp: !isScrollAxis,
            expands: expands,
            growsWithContent: grows,
          );
      if (pos.align case final double a) return at(FreeformAxisMode.align, alignment: a);
      final relative = pos.relative;
      if (expands) return at(FreeformAxisMode.fill);
      if (isScrollAxis) return at(FreeformAxisMode.start);
      if (pos.isStretch && !wraps) {
        final min = horizontal ? c.minWidth : c.minHeight;
        return FreeformAxisPlacement(
          mode: FreeformAxisMode.stretch,
          start: pos.start!,
          extent: parentExtent - pos.start! - pos.end!,
          parentExtent: parentExtent,
          clamp: !isScrollAxis,
          growsWithContent: grows,
          minSize: min == null ? 0 : min + (horizontal ? n.layout.margin.horizontal : n.layout.margin.vertical),
        );
      }
      if (pos.end != null && pos.start == null) return at(FreeformAxisMode.end);
      if (relative != null) return at(FreeformAxisMode.relative);
      return at(FreeformAxisMode.start);
    }

    return FreeformPlacement(horizontal: axis(true), vertical: axis(false));
  }

  // --- children & wiring ------------------------------------------------------

  void _syncChildren(_Container container, List<String> ids, Slot childSlot,
      {Object? instance, List<Object?>? instances}) {
    if (!identical(_container, container) && _container != null) _releaseContainerChildren();
    _container = container;
    RenderBox? after;
    final placed = <NodeBox>{};
    for (var i = 0; i < ids.length; i++) {
      final cid = ids[i];
      if (tree.source.node(cid) == null) continue;
      final scope = instances != null && i < instances.length ? instances[i] : null;
      final box = tree.obtain(cid, childSlot, instance: scope ?? instance ?? this.instance);
      if (identical(box, this) || !placed.add(box)) continue;
      if (box.parent != container) {
        if (box.parent != null) box.detachFromParent();
        container.insert(box, after: after);
      } else if (container.childBefore(box) != after) {
        container.move(box, after: after);
      }
      box._applyParentData();
      after = box;
    }
    var extra = after == null ? container.firstChild : container.childAfter(after);
    while (extra != null) {
      final next = container.childAfter(extra);
      container.remove(extra);
      if (extra is NodeBox) tree.orphan(extra);
      extra = next;
    }
  }

  void _releaseContainerChildren() {
    final c = _container;
    if (c == null) return;
    var child = c.firstChild;
    while (child != null) {
      final next = c.childAfter(child);
      c.remove(child);
      if (child is NodeBox) tree.orphan(child);
      child = next;
    }
    _container = null;
  }

  /// Links [next] under this box; a shell stack's single child is the chain
  /// recorded for it in [_innerChains], with its paint layers around it.
  void _wire(List<RenderBox> next) {
    final relink = _alreadyWired(next);
    if (relink != null) {
      for (final o in relink) {
        o.markNeedsLayout();
      }
      markNeedsLayout();
      _previousInner = const [];
      _finishWire(next);
      return;
    }
    void unlink(List<RenderBox> chain) {
      for (final o in chain) {
        if (o is IslandHost) {
          // Its child is the island's own widget tree.
        } else if (o is RenderObjectWithChildMixin<RenderBox>) {
          (o as RenderObjectWithChildMixin<RenderBox>).child = null;
        } else if (o is RenderStack && !identical(o, _container)) {
          var c = o.firstChild;
          while (c != null) {
            final n = o.childAfter(c);
            o.remove(c);
            c = n;
          }
        }
      }
    }

    unlink(_chain);
    unlink(_previousInner);
    unlink(next);
    unlink([for (final e in _innerChains.entries) ...e.value]);
    _previousInner = const [];
    child = null;

    void link(List<RenderBox> chain) {
      for (var i = 0; i < chain.length - 1; i++) {
        final o = chain[i];
        final nextObj = chain[i + 1];
        _detachFromAnyParent(nextObj);
        if (o is RenderStack && !identical(o, _container)) {
          o.add(nextObj);
        } else if (o is IslandHost) {
          assert(false, 'An island ends its chain');
        } else if (o is RenderObjectWithChildMixin<RenderBox>) {
          (o as RenderObjectWithChildMixin<RenderBox>).child = nextObj;
        }
      }
    }

    link(next);
    void addPositioned(RenderStack stack, RenderBox box) {
      _detachFromAnyParent(box);
      stack.add(box);
      (box.parentData! as StackParentData)
        ..left = 0
        ..top = 0
        ..right = 0
        ..bottom = 0;
    }

    for (final e in _innerChains.entries) {
      if (!next.contains(e.key)) continue;
      final (under, over) = _stackExtras[e.key] ?? (const <RenderBox>[], const <RenderBox>[]);
      for (final b in under) {
        addPositioned(e.key, b);
      }
      if (e.value.isNotEmpty) {
        _detachFromAnyParent(e.value.first);
        e.key.add(e.value.first);
        link(e.value);
      }
      for (final b in over) {
        addPositioned(e.key, b);
      }
    }
    if (next.isNotEmpty) _detachFromAnyParent(next.first);
    child = next.isEmpty ? null : next.first;
    _finishWire(next);
  }

  void _finishWire(List<RenderBox> next) {
    for (final e in _innerChains.entries) {
      if (!next.contains(e.key) || e.value.isEmpty) continue;
      final pd = e.value.first.parentData;
      if (pd is! StackParentData) continue;
      final double? edge = _filledStacks.contains(e.key) ? 0 : null;
      if (pd.left != edge || pd.top != edge || pd.right != edge || pd.bottom != edge) {
        pd
          ..left = edge
          ..top = edge
          ..right = edge
          ..bottom = edge;
        e.key.markNeedsLayout();
      }
    }
    _filledStacks.removeWhere((stack) => !next.contains(stack));
    final keep = <RenderBox>{
      ...next,
      for (final e in _innerChains.entries)
        if (next.contains(e.key)) ...e.value,
      for (final e in _stackExtras.entries)
        if (next.contains(e.key)) ...[...e.value.$1, ...e.value.$2],
    };
    _stackExtras.removeWhere((stack, _) => !next.contains(stack));
    _objects.removeWhere((k, v) => !keep.contains(v));
    _chain = next;
    _innerChains.removeWhere((stack, _) => !next.contains(stack));
  }

  /// The objects that hold a child, when everything is already linked as
  /// [next] describes; null when relinking is needed.
  List<RenderBox>? _alreadyWired(List<RenderBox> next) {
    if (!identical(child, next.firstOrNull)) return null;
    final expected = <RenderBox, List<RenderBox>>{};
    void chain(List<RenderBox> c) {
      for (var i = 0; i < c.length - 1; i++) {
        (expected[c[i]] ??= []).add(c[i + 1]);
      }
    }

    chain(next);
    for (final e in _innerChains.entries) {
      if (!next.contains(e.key)) continue;
      final (under, over) = _stackExtras[e.key] ?? (const <RenderBox>[], const <RenderBox>[]);
      final kids = expected[e.key] ??= [];
      kids.addAll(under);
      if (e.value.isNotEmpty) kids.add(e.value.first);
      kids.addAll(over);
      chain(e.value);
    }
    final all = <RenderBox>{
      ...next,
      for (final e in _innerChains.entries)
        if (next.contains(e.key)) ...e.value,
    };
    for (final o in all) {
      final want = expected[o] ?? const <RenderBox>[];
      if (o is RenderStack && !identical(o, _container)) {
        var c = o.firstChild;
        for (final w in want) {
          if (!identical(c, w)) return null;
          c = o.childAfter(c!);
        }
        if (c != null) return null;
      } else if (identical(o, _container) || o is IslandHost) {
        if (want.isNotEmpty) return null;
      } else if (o is RenderObjectWithChildMixin<RenderBox>) {
        if (want.length > 1) return null;
        if (!identical((o as RenderObjectWithChildMixin<RenderBox>).child, want.firstOrNull)) return null;
      } else if (want.isNotEmpty) {
        return null;
      }
    }
    return [
      for (final o in all)
        if (expected[o]?.isNotEmpty ?? false) o,
    ];
  }

  static void _detachFromAnyParent(RenderBox o) {
    switch (o.parent) {
      case null:
        return;
      case final _Container c:
        c.remove(o);
      case final RenderObjectWithChildMixin<RenderBox> p:
        p.child = null;
      default:
        break;
    }
  }

  void detachFromParent() {
    switch (parent) {
      case final _Container c:
        c.remove(this);
      case final RenderObjectWithChildMixin<RenderBox> p:
        p.child = null;
      default:
        break;
    }
  }

  void _releaseSubtree() {
    final c = _container;
    if (c != null) {
      var child = c.firstChild;
      while (child != null) {
        final next = c.childAfter(child);
        c.remove(child);
        if (child is NodeBox && identical(tree._boxes[child.key], child)) child._releaseSubtree();
        child = next;
      }
    }
    _unsubscribe();
    tree.interactions?.released(this);
    for (final h in _islands.values) {
      h.release();
    }
    _islands.clear();
    if (identical(tree._boxes[key], this)) tree._boxes.remove(key);
  }
}

/// How a shell paints its fills and strokes: one solid fill and at most one
/// plain solid stroke on every side are the decoration's color and border;
/// anything richer is a [RenderNodePaint] layer.
class _PaintPlan {
  _PaintPlan(this.native, this.fill, this.border, this.foreground);

  final bool native;
  final Color? fill;
  final Border? border;
  final bool foreground;

  static _PaintPlan of(Node n) {
    final d = n.decoration;
    final foreground = d.foregroundFills.any((f) => f.visible);
    // Paints bound per paint id are resolved at runtime by the paint layer.
    if (n.bind.keys.any((k) => k.startsWith('fill-') || k.startsWith('stroke-paint-'))) {
      return _PaintPlan(false, null, null, foreground);
    }
    final fills = d.visibleFills.toList();
    final simpleFill =
        fills.length <= 1 && fills.every((f) => f.type == api.PaintType.solid && f.blendMode == api.BlendMode.srcOver);
    final strokes = d.visibleStrokes.toList();
    final path = n.type == 'box' && n.prop(api.BoxProps.path).isNotEmpty;
    final simpleStroke = strokes.isEmpty ||
        (strokes.length == 1 &&
            strokes.first.type == api.PaintType.solid &&
            d.dashPattern.isEmpty &&
            d.strokeSides == api.StrokeSides.all &&
            !path);
    if (!simpleFill || !simpleStroke) return _PaintPlan(false, null, null, foreground);
    final strokeColor = strokes.isEmpty ? null : strokes.first.effectiveColor?.flutter;
    return _PaintPlan(
      true,
      fills.isEmpty ? null : fills.first.effectiveColor?.flutter,
      strokeColor == null
          ? null
          : Border.all(strokeAlign: d.strokeAlign.value, color: strokeColor, width: d.strokeWidth),
      foreground,
    );
  }
}
