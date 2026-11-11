// Nodes → render objects, without a widget or element per node.
//
// Each node is one [NodeBox]. Its chain of render objects is, layer by layer,
// outer decorations, the shell's size, decoration and clip, padding, then the
// content, configured directly. The layout render objects are in
// render/layout. Parity: test/parity_test.dart compares every node's rect
// with stored goldens of real projects.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Json, Node, SizeFit, FlexProps, ScrollProps, TextProps, IconProps;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show WidgetBuilder;

import 'behaviors.dart';
import 'typewriter.dart';
import 'hero.dart';
import 'play.dart';
import '../runtime/gestures/drag_and_drop.dart' show dragAndDropLayers;
import '../runtime/gestures/drag_motion.dart' show RenderDragMotion, dragMotionLayers;
import 'convert.dart';
import 'count_up.dart';
import 'layout/margin_box.dart';
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
import 'reveal.dart';
import 'view_scroll.dart';
import 'source.dart';
import '../runtime/expressions/bindings.dart' show BoundNode, NodeBinder;
import '../widgets/collections.dart' show listBuildsAllItems;
import '../widgets/registry.dart';
import '../widgets/inputs.dart' show inputsRecipes;

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

class _TreeIslands extends IslandManager {
  _TreeIslands(super.environment);
  VoidCallback? onEnvironment;
  @override
  set environment(IslandEnvironment value) {
    if (value == environment) return;
    super.environment = value;
    onEnvironment?.call();
  }
}

/// Owns the boxes built from one [NodeSource].
class NodeTree {
  bool _preservingActions = false;

  /// Conditional hiding retains the node: pause its screen triggers, but
  /// let the reaction that hid it finish. Removing a view still cancels it.
  bool get preservingActions => _preservingActions;
  NodeTree(this.source,
      {this.observer, IslandEnvironment environment = const IslandEnvironment(), NodeBinder? binder, NodeInteractions? interactions})
      : islands = _TreeIslands(environment) {
    (islands as _TreeIslands).onEnvironment = () {
      for (final box in _boxes.values.toList()) {
        box._applied = null;
        box._apply();
      }
    };
    _binder = binder;
    _interactions = interactions;
  }

  // Font loading defers RenderParagraph's relayout to the next frame. Flutter
  // forbids detaching it before that callback drains. Source edits normally
  // apply synchronously; hold only those arriving during a font notification.
  Listenable? _fontNotifications;
  bool _fontsPending = false;
  int _fontGeneration = 0;
  bool _disposed = false;
  bool get isDisposed => _disposed;
  final Set<NodeBox> _afterFonts = {};

  void _listenForFonts() {
    if (_fontNotifications != null || _disposed) return;
    _fontNotifications = PaintingBinding.instance.systemFonts;
    _fontNotifications!.addListener(_fontsChanged);
  }

  void _fontsChanged() {
    if (_disposed) return;
    _fontsPending = true;
    final generation = ++_fontGeneration;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      // Our listener precedes paragraphs' listeners. Wait until all of their
      // transient callbacks have run, including callbacks registered later
      // in the font notification. A newer font event restarts this wait.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed || generation != _fontGeneration) return;
        _fontsPending = false;
        final pending = _afterFonts.toList();
        _afterFonts.clear();
        for (final box in pending) {
          if (identical(_boxes[box.key], box)) box._apply();
        }
        remeasure();
      });
    });
  }

  /// Lays every box out again from scratch, as after an edit: what fonts
  /// changed (a family that loaded after the first layout) is measured
  /// again. Paragraphs inside stretched children of a hugging row/column
  /// sit behind relayout boundaries, and islands (chips, buttons) cache the
  /// intrinsic sizes they measured, so every render object below each box
  /// is marked, then the hugging layouts above it.
  void remeasure() {
    void markAll(RenderObject o) {
      o.markNeedsLayout();
      o.visitChildren(markAll);
    }

    for (final box in _boxes.values.toList()) {
      if (!box.attached) continue;
      // Applied again as after an edit: islands rebuild their widgets
      // (a chip measures its label anew).
      box._apply();
      markAll(box);
      box._relayoutHuggingAncestors();
    }
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

  /// Whether behaviors play (a running app: entrances, loops, spins) or
  /// rest (a design canvas).
  /// Whether the hosting route enables tickers (covered routes do not tick).
  bool Function()? runtimeVisibility;
  bool get runtimeVisible => runtimeVisibility?.call() ?? true;

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
    final affected = {id, ...?source.node(id)?.behaviors.states.targets};
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
    var n = _patched(id, instance);
    if (n == null) return null;
    final binder = _binder;
    if (binder == null) return BoundNode(n);
    var bound = binder.bind(source, n, instance);
    // States driven by data (`selected`, `disabled`): held like hover, so
    // the node's state styles patch it (bind it again) and its targets.
    if (bound.states.isNotEmpty && _syncBoundStates(id, instance, bound.states)) {
      n = _patched(id, instance)!;
      bound = binder.bind(source, n, instance);
    }
    return bound;
  }

  /// Turns node [id]'s bound [states] on or off without re-applying it
  /// (it is being resolved); the other nodes its state styles patch
  /// re-apply right after. Whether anything changed.
  bool _syncBoundStates(String id, Object? instance, Map<api.WidgetState, bool> states) {
    final key = (id, instance);
    final current = _states[key] ?? const <api.WidgetState>{};
    final next = {...current};
    for (final e in states.entries) {
      e.value ? next.add(e.key) : next.remove(e.key);
    }
    if (setEquals(next, current)) return false;
    next.isEmpty ? _states.remove(key) : _states[key] = next;
    final targets = {...?source.node(id)?.behaviors.states.targets}..remove(id);
    if (targets.isNotEmpty) {
      _pendingStateTargets.add((targets, instance));
      if (!_stateFlushScheduled) {
        _stateFlushScheduled = true;
        scheduleMicrotask(_flushStateTargets);
      }
    }
    return true;
  }

  final List<(Set<String>, Object?)> _pendingStateTargets = [];
  bool _stateFlushScheduled = false;

  void _flushStateTargets() {
    _stateFlushScheduled = false;
    final pending = _pendingStateTargets.toList();
    _pendingStateTargets.clear();
    for (final (ids, instance) in pending) {
      for (final b in _boxes.values.toList()) {
        if (b.instance == instance && ids.contains(b.id)) b._apply();
      }
    }
  }

  Node? _patched(String id, Object? instance) {
    final n = source.node(id);
    if (n == null || _states.isEmpty) return n;
    var out = n;
    for (final e in _states.entries) {
      if (e.key.$2 != instance) continue;
      final patch = source.node(e.key.$1)?.behaviors.states.patchFor(id, e.value);
      if (patch != null) out = withoutBindsUnder(out.patched(patch), patch);
    }
    return out;
  }

  /// [n] without the bindings [patch] (an active state's) sets: a hovered
  /// fill wins over the bound one while it's hovered, as a state's style
  /// overrides the node's.
  @visibleForTesting
  static Node withoutBindsUnder(Node n, Map<String, Object?> patch) {
    if (n.bind.isEmpty) return n;
    final set = <String>[];
    void walk(Object? v, String path) {
      if (v is Map && v.isNotEmpty) {
        for (final e in v.entries) {
          if (path.isEmpty && (e.key == 'bind' || e.key == 'id')) continue;
          walk(e.value, path.isEmpty ? '${e.key}' : '$path.${e.key}');
        }
      } else if (path.isNotEmpty) {
        set.add(path);
      }
    }

    walk(patch, '');
    bool overridden(String key) =>
        set.any((p) => key == p || key.startsWith('$p.') || key.startsWith('$p['));
    final kept = {
      for (final e in n.bind.entries)
        if (!overridden(e.key)) e.key: e.value,
    };
    return kept.length == n.bind.length ? n : n.copyWith(bind: kept);
  }

  /// The key of node [id]'s box in [instance] (null: outside repeats).
  static String keyOf(String id, Object? instance) => instance == null ? id : '$instance/$id';

  final Map<String, NodeBox> _boxes = {};
  final Set<NodeBox> _orphans = {};
  bool _sweepScheduled = false;

  NodeBox? boxOf(String id, {Object? instance}) => _boxes[keyOf(id, instance)];

  /// Every box of node [id]: one per copy a list (or grid, page view...)
  /// repeats it in, and the single one of a node that doesn't repeat.
  Iterable<NodeBox> boxesOf(String id) => _boxes.values.where((b) => b.id == id);
  int get length => _boxes.length;

  NodeBox obtain(String id, Slot slot, {Object? instance}) {
    _listenForFonts();
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
    _disposed = true;
    _fontNotifications?.removeListener(_fontsChanged);
    _afterFonts.clear();
    for (final b in _boxes.values.toList()) {
      if (identical(_boxes[b.key], b)) release(b);
    }
    _boxes.clear();
    _orphans.clear();
    _states.clear();
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
class NodeBox extends RenderProxyBox implements NodeBuilder, SkippedChildLayout {
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

  // ---- adaptive repaint boundaries -------------------------------------------
  //
  // A running app's box that its data keeps changing (a readout ticking with
  // a simulation, a live chart, a clock) gets a layer of its own after three
  // changes within two seconds: its repaints then stay in that layer instead
  // of repainting what's around it (shadows, gradients, big lists), as a
  // Flutter author would place a RepaintBoundary. Items of a list don't: the
  // list is the boundary (RenderCollection).
  bool _ownLayer = false;
  int _recentChanges = 0, _windowStartMs = 0;
  static final Stopwatch _clock = Stopwatch()..start();
  static const _repeaters = {'listView', 'gridView', 'pageView', 'tableView'};

  /// Some boxes are worth a layer from the start: one whose content moves
  /// on its own (a transform gesture: pinch, pan) and one that's expensive
  /// to paint again (a large blurred shadow), so a change elsewhere on the
  /// screen doesn't repaint them.
  bool _heavy = false;

  static bool _isHeavy(Node n) =>
      n.behaviors.transformGesture != null ||
      n.decoration.effects.any((e) => e.visible && e.type == api.EffectType.dropShadow && e.blurRadius >= 16);

  void _updateHeavy(Node n) {
    final heavy = tree.animates && _isHeavy(n);
    if (heavy == _heavy) return;
    _heavy = heavy;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => _ownLayer || _heavy;

  /// Whether this box paints in a layer of its own (it changed often).
  bool get hasOwnLayer => _ownLayer;

  void _noteDataChange() {
    if (_ownLayer || !tree.animates || _repeaters.contains(_slot.parent?.type)) return;
    final now = _clock.elapsedMilliseconds;
    if (now - _windowStartMs > 2000) {
      _windowStartMs = now;
      _recentChanges = 0;
    }
    if (++_recentChanges < 3) return;
    _ownLayer = true;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }
  Node? _node;

  /// The node as rendered.
  Node? get node => _node;
  ValueListenable<Node?>? _listenable;

  static final Map<String, int> debugApplyCounts = {};

  /// Nodes whose bound change was drawn in place, without a re-apply (a
  /// text's new text, a fill's new colour), while [debugCountApplies].
  static final Map<String, int> debugInPlaceCounts = {};
  static bool debugCountApplies = false;

  /// Paints per node id while [debugCountPaints] is on (tools, tests).
  static final Map<String, int> debugPaintCounts = {};
  static bool debugCountPaints = false;

  /// The node's own box (margin excluded).
  RenderBox? contentBox;

  List<RenderBox> _chain = const [];
  final Map<String, RenderBox> _objects = {};
  final Set<RenderBox> _retiredObjects = {};
  bool _released = false;
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
  /// no space, as Flutter's `Visibility` without `maintainSize`.
  bool get collapsed => _collapsed;

  @override
  bool get skipsChildLayout => _collapsed;
  bool _collapsed = false;
  List<Listenable> _bindingWatch = const [];
  Listenable? _bindingListenable;

  void _watchBindings(List<Listenable> watch) {
    if (listEquals(watch, _bindingWatch)) return;
    _bindingListenable?.removeListener(_bindingsChanged);
    _bindingWatch = watch;
    _bindingListenable = watch.isEmpty ? null : (Listenable.merge(watch)..addListener(_bindingsChanged));
  }

  // Font notifications are deferred by _apply's shared tree guard. Keep
  // ordinary bindings synchronous so motion observes a change this frame.
  //
  // A binding change that leaves the node as it was (a list whose items
  // moved but whose count didn't: its item scopes were updated while it
  // resolved) re-applies nothing, and one that only changes a solid fill or
  // stroke repaints without relayout (render-object boxes only). A grid of thousands of bound cells
  // then costs what its changed cells cost, not a rebuild of the grid.
  void _bindingsChanged() {
    final old = _applied;
    // A box hosting islands (a table, a paged or reordering list, an input,
    // a chart) hands its widgets what they read when it applies: always
    // re-apply it.
    if (tree._fontsPending || old == null || _islands.isNotEmpty) {
      _apply();
      if (old != null) _noteDataChange();
      return;
    }
    final bound = tree.resolveBound(id, instance: instance);
    final n = bound?.node;
    if (bound != null && n != null && bound.collapsed == _collapsed) {
      if (n == old) {
        _watchBindings(bound.watch);
        return;
      }
      if (_repaintOnly(old, n) || _retextOnly(old, n)) {
        // Updated in place (no re-apply): counted apart.
        if (debugCountApplies) debugInPlaceCounts.update(id, (v) => v + 1, ifAbsent: () => 1);
        _watchBindings(bound.watch);
        _noteDataChange();
        return;
      }
    }
    _apply(given: (bound,));
    _noteDataChange();
  }

  /// Applies [n] when it is a text that differs from [old] only in its
  /// characters, runs or style (a readout ticking every frame): sets the
  /// paragraph's text in place. Its layout, if it changes, propagates as any
  /// Flutter text's does; nothing around it re-applies. False (nothing done)
  /// for any other change.
  bool _retextOnly(Node old, Node n) {
    if (n.type != 'text' || old.type != 'text') return false;
    if (old.copyWith(props: n.props) != n) return false;
    final sameOtherwise = old.props
        .set<Object?>(TextProps.text, n.prop(TextProps.text))
        .set<Object?>(TextProps.runs, n.prop(TextProps.runs))
        .set<Object?>(TextProps.style, n.prop(TextProps.style));
    if (sameOtherwise != n.props) return false;
    final paragraph = _objects['paragraph'];
    // A count-up text counts to its new value: the recipe re-applies it.
    if (paragraph is! RenderParagraph || paragraph is RenderCountUpParagraph) return false;
    paragraph.text = _textSpan(n);
    _node = n;
    _applied = n;
    return true;
  }

  /// Applies [n] when it differs from [old] only in the colors of a native
  /// (solid) fill or stroke: sets the decoration's colors and repaints.
  /// False (nothing done) for any other change.
  bool _repaintOnly(Node old, Node n) {
    final od = old.decoration, nd = n.decoration;
    if (identical(od, nd) || od.copyWith(fills: nd.fills, strokes: nd.strokes) != nd) return false;
    if (old.copyWith(decoration: nd) != n) return false;
    final before = _PaintPlan.of(old), after = _PaintPlan.of(n);
    if (!before.native || !after.native || before.foreground || after.foreground) return false;
    if ((before.border == null) != (after.border == null)) return false;
    final deco = _objects['decoration'];
    if (deco is! RenderDecoratedBox) return false;
    final current = deco.decoration;
    if (current is! BoxDecoration) return false;
    final stroke = _objects['stroke'];
    if (after.border != null && stroke is! RenderDecoratedBox) return false;
    deco.decoration = BoxDecoration(
      boxShadow: current.boxShadow,
      borderRadius: current.borderRadius,
      color: after.fill,
    );
    if (after.border != null) {
      (stroke! as RenderDecoratedBox).decoration = BoxDecoration(borderRadius: current.borderRadius, border: after.border);
    }
    _node = n;
    _applied = n;
    return true;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (_collapsed) {
      // Like RenderOffstage, keep descendant layout boundaries clean even
      // though this node takes no space and is not painted or hit tested.
      // Widget islands can still rebuild while the node is collapsed.
      child?.layout(constraints);
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
    if (debugCountPaints) debugPaintCounts.update(id, (v) => v + 1, ifAbsent: () => 1);
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
    // A chain rebuilt after this frame's layout (a font arriving in a
    // post-frame callback) hasn't been laid out yet, and the mouse tracker
    // hit tests after frames: there's nothing drawn to hit. (Hit testing it
    // threw in debug builds, inside the mouse tracker, which then refused
    // every later pointer event.)
    final c = child;
    if (c != null && !c.hasSize) return false;
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
    if (existing != null) _retiredObjects.add(existing);
    _objects[key] = made;
    return made;
  }

  Node? _applied;

  void _apply({(BoundNode?,)? given}) {
    if (tree._fontsPending) {
      tree._afterFonts.add(this);
      return;
    }
    if (debugCountApplies) debugApplyCounts.update(id, (v) => v + 1, ifAbsent: () => 1);
    final bound = given != null ? given.$1 : tree.resolveBound(id, instance: instance);
    final resolved = bound?.node;
    // Bindings give a new node each time: the same one keeps its identity,
    // which the children's slots compare (else re-applying a row whose
    // structure depends on its children re-applies them, and so on).
    final n = resolved != null && _applied != null && resolved == _applied ? _applied : resolved;
    _watchBindings(bound?.watch ?? const []);
    final collapsed = bound?.collapsed ?? false;
    // A top-level node that only moved: its content doesn't depend on where
    // it sits (the host offsets it), so nothing re-applies or repaints.
    if (collapsed == _collapsed && _slot.kind == SlotKind.root && n != null && _applied != null && _onlyMoved(_applied!, n)) {
      _node = n;
      _applied = n;
      return;
    }
    _prepareLayoutChanges();
    if (collapsed != _collapsed) {
      _collapsed = collapsed;
      // Runtime hiding detaches timers and islands. Design previews retain
      // their placeholder subtree so tooling can inspect its default text.
      if (_collapsed && tree.animates) {
        final previous = tree._preservingActions;
        tree._preservingActions = true;
        try { child = null; } finally { tree._preservingActions = previous; }
      }
      _applyParentData();
    }
    _node = n;
    _applied = n;
    contentBox = null;
    if (n != null) _updateHeavy(n);
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
    // Pinned while its parent is in view (render/view_scroll.dart): the
    // whole node, margin included, moves.
    if (n.behaviors.sticky case final api.Sticky sticky) {
      chain.add(_obtain<RenderSticky>('sticky', RenderSticky.new)
        ..onStuck = ((stuck) => tree.binder?.nodeScope(tree.source, id, instance: instance)?.update('sticky', {'stuck': stuck}))
        ..configure(sticky, interactive: tree.animates));
    }

    // Outer layers, outermost first: margin, constraints, motion and scale
    // (render/behaviors.dart), rotation, loops, opacity, blurs and stroke
    // path.
    // Not `.flutter`, which reads a negative side as 0: a margin may be
    // negative (RenderMargin).
    final m0 = n.layout.margin;
    final margin = EdgeInsets.fromLTRB(m0.left, m0.top, m0.right, m0.bottom);
    if (margin != EdgeInsets.zero) {
      if (margin.isNonNegative) {
        chain.add(_obtain<RenderPadding>('margin', () => RenderPadding(padding: margin, textDirection: TextDirection.ltr))
          ..padding = margin);
      } else {
        // A negative side reaches past the node's box (RenderPadding takes
        // none, and ignored it).
        chain.add(_obtain<RenderMargin>('negativeMargin', () => RenderMargin(margin: margin))..margin = margin);
      }
    }
    if (!n.layout.constraints.isEmpty) {
      final c = n.layout.constraints.flutter;
      chain.add(_obtain<RenderConstrainedBox>('constraints', () => RenderConstrainedBox(additionalConstraints: c))
        ..additionalConstraints = c);
    }
    final reveal = n.behaviors.reveal;
    if (tree.animates && reveal != null) {
      chain.add(_obtain<RenderReveal>('reveal', RenderReveal.new)..configure(reveal, n.visible));
    }
    // `${view.progress}` as it scrolls through its view.
    if (n.behaviors.viewProgress case final api.ViewProgress progress) {
      chain.add(_obtain<RenderViewProgress>('viewProgress', RenderViewProgress.new)
        ..onValues = ((values) => tree.binder?.nodeScope(tree.source, id, instance: instance)?.update('view', values))
        ..configure(this, progress, interactive: tree.animates));
    }
    // Its laid-out box, written to a variable.
    if (n.behaviors.measure case final api.Measure measure) {
      chain.add(_obtain<RenderMeasure>('measure', RenderMeasure.new)..configure(this, measure));
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

  /// A collapsed box skips its children's layout. Its cached inner boxes
  /// can therefore stay dirty after the collapsed box itself becomes clean.
  /// Before updating those boxes, invalidate the path from the outermost
  /// collapsed ancestor down: a dirty child must never have a clean parent
  /// between it and its relayout boundary. Do this before property setters
  /// too, since a changed paragraph can invalidate layout before `_wire`.
  void _prepareLayoutChanges() => prepareSkippedLayoutChange(this);

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
        if (recipe != null && _inputInShell(n)) {
          // An input with its own fill, border, shadow or padding: the node's
          // shell around it, the widget filling (or hugging) the padded box.
          _shell(n, chain, content: (inner) => recipe(this, _shellContent(n), inner));
        } else if (recipe != null) {
          recipe(this, n, chain);
        } else {
          // A type this SDK doesn't render yet: its box, at its size.
          chain.add(_fitBox('placeholder', n.hFit, n.vFit, n.designSize));
        }
    }
  }

  /// Whether input [n] draws the node shell around its widget: a decorated
  /// input (dropdown, date/time input) with a visible fill, stroke or
  /// shadow, or padding.
  static bool _inputInShell(Node n) {
    if (!inputsRecipes.containsKey(n.type) || !(n.spec?.decorated ?? false)) return false;
    final d = n.decoration;
    return d.fills.any((f) => f.visible) ||
        d.strokes.any((s) => s.visible) ||
        d.effects.any((e) => e.visible) ||
        n.layout.padding != api.EdgeInsets.zero;
  }

  /// [n] as the widget inside its shell: filling the padded box (hugging
  /// where the node hugs), without the shell's padding, margin or decoration.
  static Node _shellContent(Node n) {
    final l = n.layout;
    final p = l.padding;
    api.AxisSize inner(api.AxisSize s, double pad) =>
        s.fit == SizeFit.hug ? api.AxisSize.hug(math.max(0, s.value - pad)) : api.AxisSize.fill(math.max(0, s.value - pad));
    return n.copyWith(
      layout: l.copyWith(
        width: inner(l.width, p.horizontal),
        height: inner(l.height, p.vertical),
        padding: api.EdgeInsets.zero,
        margin: api.EdgeInsets.zero,
      ),
      decoration: api.Decoration.none,
    );
  }

  bool get _isPlaceholder {
    final parent = _slot.parent;
    return parent != null && parent.type == 'canvas' && parent.slots['body'] == id;
  }

  /// The shell (PassiveRectangleWidget): fit box → shadows → decoration →
  /// stroke → clip → stack [paint layers, (padding) content].
  void _shell(Node n, List<RenderBox> chain, {void Function(List<RenderBox> inner)? content, bool padded = true}) {
    // A canvas body hugs its content; one without content (a plain box)
    // keeps its own size, else it would have none: nothing to paint or tap.
    final isPlaceholder = _isPlaceholder && content != null;
    final contentSized = _scrollsFlexiblyOnMainAxis(n);
    final hFit = isPlaceholder || (contentSized && n.isRow) ? SizeFit.hug : n.hFit;
    final vFit = isPlaceholder || (contentSized && !n.isRow) ? SizeFit.hug : n.vFit;
    chain.add(_fitBox('shellFit', hFit, vFit, n.designSize)
      ..widthFactor = n.layout.widthFactor
      ..heightFactor = n.layout.heightFactor);

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
    chain.add(_obtain<RenderNodeDecoration>('decoration', () => RenderNodeDecoration(decoration: const BoxDecoration()))
      ..decoration = BoxDecoration(
        boxShadow: [for (final sh in shadows) if (!spread.contains(sh)) sh],
        borderRadius: radius,
        color: plan.native ? plan.fill : null,
      )
      // A node that paints a fill is opaque to pointers, as Flutter's
      // Container(color:) is; one without lets them through its gaps to what
      // lies under it (a row of black keys over the white ones).
      ..opaque = d.fills.any((f) => f.visible));
    if (plan.native && plan.border != null) {
      chain.add(_obtain<RenderNodeDecoration>('stroke', () => RenderNodeDecoration(decoration: const BoxDecoration()))
        ..decoration = BoxDecoration(borderRadius: radius, border: plan.border)
        ..opaque = false);
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
      under.add(
        _obtain<RenderNodePaint>('under', RenderNodePaint.new)
          ..onImageState = tree.animates
              ? (status, url) {
                  final trigger = switch (status) {
                    'loaded' => 'imageLoaded',
                    'error' => 'imageError',
                    _ => 'imageLoading',
                  };
                  tree.interactions?.fire(
                    this,
                    trigger,
                    event: {
                      'result': {'status': status, 'url': url},
                    },
                  );
                }
              : null
          ..decoration = d
          ..foreground = false,
      );
    }
    if (canStack && plan.foreground) {
      over.add(_obtain<RenderNodePaint>('over', RenderNodePaint.new)
        ..decoration = d
        ..foreground = true);
    }
    if (canStack && tree.animates && n.behaviors.inkWell != null) under.add(inkOverlay(this, n, radius));
    if (content == null && under.isEmpty && over.isEmpty) return;
    // Passthrough: the content gets the shell's own constraints, as it
    // would with no decoration, so a size the parent forces (a fixed child
    // stretched between two pins) reaches it instead of its design size.
    final stack = _obtain<RenderStack>('shellStack',
        () => RenderStack(alignment: AlignmentDirectional.topStart, textDirection: TextDirection.ltr, clipBehavior: Clip.none, fit: StackFit.passthrough));
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
    // The content of a shell with ink goes in its InkWell, filling
    // the shell (Positioned.fill) when the shell has a size on both axes:
    // its content then sizes nothing (no intrinsic size either).
    if (n.behaviors.inkWell != null && n.hFit != SizeFit.hug && n.vFit != SizeFit.hug) _filledStacks.add(stack);
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
    bool Function(RenderBox)? fillsAcross;
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
      // Its other children set its thickness. When every child fills
      // across, their content does (at least), as under IntrinsicHeight /
      // IntrinsicWidth, rather than their design sizes alone (unless
      // intrinsics can't see into a child: scrolling content).
      bool fills(Node c) => (isRow ? c.vFit : c.hFit) == SizeFit.fill;
      final shown = children.where((c) => c.type != 'spacer');
      final measureFills = shown.isNotEmpty && shown.every(fills) && !children.any(_subtreeBlocksIntrinsics);
      chain.add(_obtain<RenderHugCross>('hugCross', RenderHugCross.new));
      fillsAcross = measureFills ? _fillsAcross(isRow) : null;
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
      ..squeeze = n.prop(FlexProps.squeezeChildren)
      ..fillsAcross = fillsAcross;
    _syncChildren(flex, n.children, Slot(SlotKind.flex, n));
    chain.add(flex);
  }

  /// A row/column whose children flow onto new runs: main-axis alignment within each run, cross-axis
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

  /// Whether a laid-out flex child is a drawn node that fills the flex's
  /// cross axis.
  static bool Function(RenderBox) _fillsAcross(bool isRow) => isRow ? _fillsHeight : _fillsWidth;
  static bool _fillsHeight(RenderBox b) =>
      b is NodeBox && b.drawn && b.node?.type != 'spacer' && b.node?.vFit == SizeFit.fill;
  static bool _fillsWidth(RenderBox b) =>
      b is NodeBox && b.drawn && b.node?.type != 'spacer' && b.node?.hFit == SizeFit.fill;

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
      ..interactive = tree.animates
      ..userScrollable = n.prop(ScrollProps.physics) != api.ScrollPhysicsType.never
      ..onScroll = (event) { tree.interactions?.fire(this, 'scroll', event: event); }
      ..onScrollEnd = (event) { tree.interactions?.fire(this, 'scrollEnd', event: event); }
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
    // A fitted board: laid out at its design size, then scaled into the box.
    final fit = n.type == 'stack' ? n.prop(api.StackProps.fit) : null;
    if (fit != null) {
      chain.add(_obtain<RenderFillBounds>('boardFill', RenderFillBounds.new)..fallback = n.innerSize);
      chain.add(_obtain<RenderFittedBox>('boardFit', () => RenderFittedBox(textDirection: TextDirection.ltr, clipBehavior: Clip.hardEdge))
        ..fit = BoxFit.values.byName(fit.name)
        ..alignment = n.prop(api.StackProps.fitAlignment).flutter);
      final board = BoxConstraints.tight(n.innerSize);
      chain.add(_obtain<RenderConstrainedBox>('boardSize', () => RenderConstrainedBox(additionalConstraints: board))
        ..additionalConstraints = board);
    }
    final layout = _obtain<RenderFreeformLayout>(
        'freeform', () => RenderFreeformLayout(wrapsWidth: false, wrapsHeight: false, designSize: Size.zero))
      ..wrapsWidth = fit == null && n.hFit == SizeFit.hug
      ..wrapsHeight = fit == null && n.vFit == SizeFit.hug
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
  ///
  /// A fixed height is the text's height, as `SizedBox(height:)` around a
  /// `Text`: the paragraph is laid out within it and clips the lines that
  /// don't fit (by its overflow). A flexible height is the least it takes.
  void _text(Node n, List<RenderBox> chain) {
    final hFit = n.hFit, vFit = n.vFit;
    final hugsWidth = hFit == SizeFit.hug || hFit == SizeFit.flexible;
    final minHeight = vFit == SizeFit.flexible;
    // A filling axis takes the room offered, or hugs the text where that
    // room is unbounded (a hugging parent measuring its children).
    if (hFit == SizeFit.fill || vFit == SizeFit.fill) {
      chain.add(_obtain<RenderFitBox>('textFill', RenderFitBox.new)
        ..width = null
        ..height = null
        ..fillWidth = hFit == SizeFit.fill
        ..fillHeight = vFit == SizeFit.fill
        ..aspectRatio = null);
    }
    final c = BoxConstraints.tightFor(
      width: hFit == SizeFit.fixed ? n.layout.width.value : null,
      height: vFit == SizeFit.fixed ? n.layout.height.value : null,
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
      ..heightFactor = vFit == SizeFit.fill || vFit == SizeFit.fixed ? null : 1);
    final countUp = n.prop(TextProps.countUp);
    final RenderParagraph paragraph;
    final span = _textSpan(n);
    if (countUp) {
      paragraph = _obtain<RenderCountUpParagraph>('paragraph', RenderCountUpParagraph.new);
    } else {
      paragraph = _obtain<RenderParagraph>('paragraph', () => RenderParagraph(span, textDirection: TextDirection.ltr))
        ..text = span;
    }
    if (paragraph is RenderCountUpParagraph) {
      // Counts in a running app; a design canvas (or TickerMode off) and a
      // text without countUp show the final text.
      paragraph.count(
        n.prop(TextProps.text),
        (text) => _textSpan(n.withProp(TextProps.text, text)),
        animates: countUp && tree.animates && tree.runtimeVisible,
        durationMs: n.prop(TextProps.countUpDuration),
        curve: n.prop(TextProps.countUpCurve),
        onShow: n.prop(TextProps.countUpOnShow),
        visible: () => tree.runtimeVisible,
      );
    }
    paragraph
      ..textAlign = flutterTextAlign(textAlign)
      ..maxLines = n.prop(TextProps.maxLines)
      ..overflow = textOverflow(n.prop(TextProps.overflow));
    if (n.prop(TextProps.scaleDown)) {
      chain.add(_obtain<RenderFittedBox>('textScale', () => RenderFittedBox(fit: BoxFit.scaleDown, textDirection: TextDirection.ltr))
        ..alignment = Alignment(x, y));
    }
    if (n.behaviors.typewriter case final api.Typewriter tw) {
      chain.add(_obtain<RenderTypewriter>('typewriter', RenderTypewriter.new)
        ..configure(tw, plainText(span), animates: tree.animates));
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
    // Runs style ranges; they do not replace the unstyled characters.
    // Split at each boundary so gaps and overlapping styles retain text once.
    final bounds = <int>{0, text.length,
      for (final r in runs) ...[r.start.clamp(0, text.length), r.end.clamp(0, text.length)]}.toList()..sort();
    return TextSpan(children: [
      for (var i = 0; i + 1 < bounds.length; i++)
        TextSpan(
          text: text.substring(bounds[i], bounds[i + 1]),
          style: textStyle(runs.where((r) => r.start <= bounds[i] && r.end >= bounds[i + 1])
              .fold(base, (style, run) => style.merge(run.style))),
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
    // A bare box filling across a row/column that hugs that axis and
    // stretches: its siblings set the thickness (RenderStretchFiller).
    if (cross == api.CrossAxisAlignment.stretch && parentHugsCross && crossFit == SizeFit.fill &&
        n.type == 'box' && n.children.isEmpty) {
      chain.add(_obtain<RenderStretchFiller>('stretchFill', RenderStretchFiller.new)
        ..cross = isRow ? Axis.vertical : Axis.horizontal);
    }
    if (align != null) {
      chain.add(_obtain<RenderPositionedBox>('slotAlign', () => RenderPositionedBox(alignment: align, textDirection: TextDirection.ltr))
        ..alignment = align);
    }
  }

  /// A child of a wrapping row/column: fills
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

  /// Where a freeform child sits, from its position (DESIGN.md §3).
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
            preserveDesignOverflow: fit != SizeFit.fill,
            growsWithContent: grows,
          );
      if (pos.align case final double a) return at(FreeformAxisMode.align, alignment: a);
      final relative = pos.relative;
      // A fill child pinned to both edges fills the space between its
      // insets; pinned to one edge (or none) it fills the container.
      if (expands && !(pos.isStretch && !isScrollAxis)) return at(FreeformAxisMode.fill);
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

    // A share of the container on an axis (Layout.widthFactor/heightFactor).
    FreeformAxisPlacement sized(bool horizontal) {
      final p = axis(horizontal);
      final f = horizontal ? n.layout.widthFactor : n.layout.heightFactor;
      return f == null ? p : p.withSizeFactor(f, horizontal ? n.layout.margin.horizontal : n.layout.margin.vertical);
    }

    return FreeformPlacement(horizontal: sized(true), vertical: sized(false));
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
    markNeedsLayout();
    final relink = _alreadyWired(next);
    if (relink != null) {
      // Dirty the owner before invalidating reused inner layers.
      markNeedsLayout();
      for (final o in relink) {
        o.markNeedsLayout();
      }
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
    child = (_collapsed && tree.animates) || next.isEmpty ? null : next.first;
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
    final retired = {..._retiredObjects, for (final o in _objects.values) if (!keep.contains(o)) o};
    _retiredObjects.clear();
    _disposeObjects(retired);
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
    if (_released) return;
    _released = true;
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
    child = null;
    _disposeObjects({..._objects.values, ..._retiredObjects});
    _objects.clear();
    _retiredObjects.clear();
    _chain = const [];
    _innerChains.clear();
    _stackExtras.clear();
    _container = null;
    super.dispose();
  }

  // These objects were constructed by recipes, without RenderObjectElements.
  // Dropping Dart references alone does not release their layers, paragraph
  // caches, image listeners or animation controllers.
  void _disposeObjects(Set<RenderBox> objects) {
    for (final o in objects) {
      _detachFromAnyParent(o);
      if (o is _Container) {
        final container = o as _Container;
        var c = container.firstChild;
        while (c != null) {
          final next = container.childAfter(c);
          container.remove(c);
          if (c is NodeBox) tree.orphan(c);
          c = next;
        }
      } else if (o is RenderObjectWithChildMixin<RenderBox>) {
        (o as RenderObjectWithChildMixin<RenderBox>).child = null;
      }
    }
    for (final o in objects) {
      // Flutter's current paint queue asserts the retained layer exists even
      // for a detached object. Release that layer only after this frame drains.
      // ignore: invalid_use_of_protected_member
      final hasLayer = o.layer != null;
      if (hasLayer && SchedulerBinding.instance.schedulerPhase != SchedulerPhase.postFrameCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) => o.dispose(), debugLabel: 'NodeTree.disposeLayer');
        SchedulerBinding.instance.ensureVisualUpdate();
      } else {
        o.dispose();
      }
    }
  }
}

/// How a shell paints its fills and strokes: one solid fill and at most one
/// plain solid stroke on every side are the decoration's color and border;
/// anything richer is a [RenderNodePaint] layer.
Color? _visible(Color? c) => c == null || c.a == 0 ? null : c;

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
      // A transparent fill draws nothing: leave it out (most cells of a
      // sparse board are empty).
      fills.isEmpty ? null : _visible(fills.first.effectiveColor?.flutter),
      strokeColor == null
          ? null
          : Border.all(strokeAlign: d.strokeAlign.value, color: strokeColor, width: d.strokeWidth),
      foreground,
    );
  }
}

/// Takes all the room it's given (its constraints' bounded maximum; on an
/// unbounded axis, [fallback]): the box a fitted board scales into.
class RenderFillBounds extends RenderProxyBox {
  Size _fallback = Size.zero;
  set fallback(Size v) {
    if (v == _fallback) return;
    _fallback = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = constraints;
    final w = c.hasBoundedWidth ? c.maxWidth : c.constrainWidth(_fallback.width);
    final h = c.hasBoundedHeight ? c.maxHeight : c.constrainHeight(_fallback.height);
    child?.layout(BoxConstraints.tight(Size(w, h)));
    size = Size(w, h);
  }
}

/// A node's box decoration (color, shadows; or its stroke), taking pointers
/// on its own only while [opaque]: a box with no fill paints nothing there,
/// so pointers pass to its children, or else to what lies under it.
class RenderNodeDecoration extends RenderDecoratedBox {
  RenderNodeDecoration({required super.decoration});

  bool opaque = true;

  @override
  bool hitTestSelf(Offset position) => opaque && super.hitTestSelf(position);
}
