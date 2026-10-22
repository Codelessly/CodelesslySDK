import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'indexed_item_provider.dart';

/// Where a [NodeBuildDecorator] wraps a node's widget.
enum NodeBuildLayer {
  /// The node's own box: the transformer's widget, inside opacity, rotation,
  /// constraints and margin. Its transform includes the node's rotation.
  content,

  /// The node's outer box: the whole wrapper stack including margin and
  /// visibility. This is the widget the parent lays out.
  margin,
}

/// Lets a host wrap every node instance that a transformer manager builds.
///
/// The editor uses this to put [GeometryProbe]s and its own chrome around
/// nodes without replacing the SDK's transformers. A published app installs
/// no decorator, so it costs nothing at runtime.
abstract class NodeBuildDecorator {
  const NodeBuildDecorator();

  /// Returns [child], the widget of [node] at [layer], wrapped as needed.
  Widget decorate(
    BuildContext context,
    BaseNode node,
    Widget child,
    NodeBuildLayer layer,
  );
}

/// A [NodeBuildDecorator] that adds a [GeometryProbe] at both layers.
class GeometryProbeDecorator extends NodeBuildDecorator {
  const GeometryProbeDecorator();

  @override
  Widget decorate(
    BuildContext context,
    BaseNode node,
    Widget child,
    NodeBuildLayer layer,
  ) => GeometryProbe(nodeId: node.id, layer: layer, child: child);
}

/// One node instance hit by [NodeGeometryRegistry.hitTest].
class NodeHit {
  final String nodeId;

  /// The list, grid or page item indices that lead to this instance,
  /// outermost first. Empty for a node outside any repeated item.
  final List<int> instance;

  const NodeHit(this.nodeId, this.instance);

  @override
  bool operator ==(Object other) =>
      other is NodeHit &&
      other.nodeId == nodeId &&
      listEquals(other.instance, instance);

  @override
  int get hashCode => Object.hash(nodeId, Object.hashAll(instance));

  @override
  String toString() =>
      instance.isEmpty ? 'NodeHit($nodeId)' : 'NodeHit($nodeId $instance)';
}

/// Where one node instance was laid out and painted, in the coordinate space
/// of the [NodeGeometryScope] that holds it.
class NodeGeometry {
  final String nodeId;
  final NodeBuildLayer layer;
  final List<int> instance;

  /// Maps the probe's local coordinates to the scope's. Includes scroll
  /// offsets, scales and the node's rotation (for [NodeBuildLayer.content]).
  final Matrix4 transform;

  /// The laid out size of the box.
  final Size size;

  /// The intersection of the paint clips of the box's ancestors, in scope
  /// coordinates, or null when nothing clips it.
  final Rect? clip;

  /// False when an ancestor laid the box out but does not paint it, for
  /// example an [Offstage] or a viewport child outside the cache extent.
  final bool painted;

  const NodeGeometry({
    required this.nodeId,
    required this.layer,
    required this.instance,
    required this.transform,
    required this.size,
    required this.clip,
    required this.painted,
  });

  /// The four corners of the box in scope coordinates, clockwise from the
  /// top left. Not axis aligned when the node or an ancestor is rotated.
  List<Offset> get quad => [
    MatrixUtils.transformPoint(transform, Offset.zero),
    MatrixUtils.transformPoint(transform, Offset(size.width, 0)),
    MatrixUtils.transformPoint(transform, Offset(size.width, size.height)),
    MatrixUtils.transformPoint(transform, Offset(0, size.height)),
  ];

  /// The axis aligned bounds of [quad].
  Rect get bounds => MatrixUtils.transformRect(transform, Offset.zero & size);

  /// The part of [bounds] that its ancestors let paint. Empty when clipped
  /// away entirely or not painted.
  Rect get visibleBounds {
    if (!painted) return Rect.zero;
    final Rect box = bounds;
    final Rect? clip = this.clip;
    if (clip == null) return box;
    final Rect visible = box.intersect(clip);
    return visible.width <= 0 || visible.height <= 0 ? Rect.zero : visible;
  }

  /// Whether the box has no area, like a runtime-hidden flex child.
  bool get collapsed => size.isEmpty;

  @override
  String toString() =>
      'NodeGeometry($nodeId ${layer.name}'
      '${instance.isEmpty ? '' : ' $instance'} $bounds)';
}

/// Holds the render boxes of every node instance built under a
/// [NodeGeometryScope], and answers where each one is.
///
/// Geometry is read from the render objects that paint, so it can't
/// disagree with what is on screen. It is computed on demand. Read it during
/// paint, or after a frame, so that layout has run.
///
/// Listeners are notified at most once per frame when any probe lays out,
/// attaches, detaches or rebuilds, or a scrollable in the scope scrolls. The
/// notification can come during the build or layout phase, so listeners
/// should only mark render objects as needing paint (as a
/// [CustomPainter.repaint] does) or schedule work for later.
class NodeGeometryRegistry extends ChangeNotifier {
  RenderGeometryRoot? _root;
  final Map<String, Map<String, RenderGeometryProbe>> _probes = {};
  bool _notified = false;

  /// Every painted probe in paint order, with what hit testing needs,
  /// collected once after geometry changes rather than on every test.
  List<_HitEntry>? _hitIndex;

  /// Probes whose paint offset changed since [_hitIndex] was collected. Only
  /// their subtrees are collected again, so a drag doesn't walk the tree on
  /// every move.
  final Set<RenderGeometryProbe> _movedProbes = {};

  /// The render box that geometry is measured relative to, if mounted.
  RenderBox? get root => _root;

  /// The ids of every node with at least one probe attached.
  Iterable<String> get nodeIds => _probes.keys;

  /// Completes after the next frame has laid out and painted.
  Future<void> get settled => SchedulerBinding.instance.endOfFrame;

  static String _key(NodeBuildLayer layer, List<int> instance) =>
      '${layer.name}|${instance.join(',')}';

  /// Records that geometry may have changed and notifies listeners. During
  /// a frame's build, layout and paint, listeners are notified once.
  void markChanged() {
    _hitIndex = null;
    _movedProbes.clear();
    _notify();
  }

  /// Records that [probe] paints at a new offset. Nothing lays out again, so
  /// only its own subtree of the hit index is stale.
  void _paintOffsetChanged(RenderGeometryProbe probe) {
    if (_hitIndex != null) _movedProbes.add(probe);
    _notify();
  }

  void _notify() {
    final SchedulerBinding scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notified) return;
    _notified = true;
    scheduler.addPostFrameCallback((_) => _notified = false);
    notifyListeners();
  }

  void _register(RenderGeometryProbe probe) {
    (_probes[probe.nodeId] ??= {})[_key(probe.buildLayer, probe.instance)] =
        probe;
    markChanged();
  }

  void _unregister(RenderGeometryProbe probe) {
    final Map<String, RenderGeometryProbe>? byKey = _probes[probe.nodeId];
    if (byKey == null) return;
    final String key = _key(probe.buildLayer, probe.instance);
    if (!identical(byKey[key], probe)) return;
    byKey.remove(key);
    if (byKey.isEmpty) _probes.remove(probe.nodeId);
    markChanged();
  }

  /// Paints the instance [instance] of [nodeId] shifted by [offset], without
  /// laying anything out again: the node follows a drag while its parent
  /// keeps its place. [Offset.zero] puts it back. Geometry, hit testing and
  /// paint all include the offset. Returns false when the node isn't built.
  bool setPaintOffset(
    String nodeId,
    Offset offset, {
    List<int> instance = const [],
  }) {
    final RenderGeometryProbe? probe =
        _probes[nodeId]?[_key(NodeBuildLayer.margin, instance)];
    if (probe == null) return false;
    probe.paintOffset = offset;
    return true;
  }

  /// Stops painting the instance [instance] of [nodeId] in place, so it can
  /// be drawn above everything else, unclipped by its ancestors, while it is
  /// dragged. Its geometry, paint offset included, stays where it would
  /// paint. Returns false when the node isn't built.
  bool setLifted(String nodeId, bool lifted, {List<int> instance = const []}) {
    final RenderGeometryProbe? probe =
        _probes[nodeId]?[_key(NodeBuildLayer.margin, instance)];
    if (probe == null) return false;
    probe.lifted = lifted;
    return true;
  }

  /// The geometry of one instance of [nodeId], or null when it isn't laid
  /// out under this scope (not built, hidden, disabled, or a list item that
  /// isn't built).
  NodeGeometry? geometryOf(
    String nodeId, {
    NodeBuildLayer layer = NodeBuildLayer.content,
    List<int> instance = const [],
  }) {
    final RenderGeometryProbe? probe = _probes[nodeId]?[_key(layer, instance)];
    return probe == null ? null : _measure(probe);
  }

  /// The geometry of every built instance of [nodeId], ordered by instance.
  List<NodeGeometry> instancesOf(
    String nodeId, {
    NodeBuildLayer layer = NodeBuildLayer.content,
  }) {
    final Iterable<RenderGeometryProbe> probes =
        _probes[nodeId]?.values.where((probe) => probe.buildLayer == layer) ??
        const [];
    final List<NodeGeometry> result = [
      for (final probe in probes) ?_measure(probe),
    ];
    result.sort((a, b) => _compareInstances(a.instance, b.instance));
    return result;
  }

  /// The first built instance of [nodeId]: the one outside any repeated
  /// item, or the lowest item index.
  NodeGeometry? primaryOf(
    String nodeId, {
    NodeBuildLayer layer = NodeBuildLayer.content,
  }) =>
      geometryOf(nodeId, layer: layer) ??
      instancesOf(nodeId, layer: layer).firstOrNull;

  static int _compareInstances(List<int> a, List<int> b) {
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return a.length.compareTo(b.length);
  }

  NodeGeometry? _measure(RenderGeometryProbe probe) {
    final RenderGeometryRoot? root = _root;
    if (root == null || !root.attached || !probe.attached || !probe.hasSize) {
      return null;
    }
    final List<RenderObject> chain = [];
    RenderObject? current = probe;
    while (current != null && !identical(current, root)) {
      chain.add(current);
      current = current.parent;
    }
    if (current == null) return null;
    chain.add(root);

    // Walk down from the root so that each ancestor's clip, which is in its
    // own coordinates, is mapped with the transform accumulated so far.
    final Matrix4 transform = Matrix4.identity();
    Rect? clip;
    bool painted = true;
    for (int i = chain.length - 1; i > 0; i--) {
      final RenderObject parent = chain[i];
      final RenderObject child = chain[i - 1];
      if (!parent.paintsChild(child)) painted = false;
      final Rect? childClip = parent.describeApproximatePaintClip(child);
      if (childClip != null) {
        final Rect mapped = MatrixUtils.transformRect(transform, childClip);
        clip = clip == null ? mapped : clip.intersect(mapped);
      }
      parent.applyPaintTransform(child, transform);
    }
    // A margin probe paints its child shifted by its paint offset; its own
    // box moves with it.
    final Offset shift = probe.paintOffset;
    if (shift != Offset.zero) {
      transform.translateByDouble(shift.dx, shift.dy, 0, 1);
    }
    final RenderGeometryProbe? content =
        probe.buildLayer == NodeBuildLayer.content
        ? probe
        : _probes[probe.nodeId]?[_key(NodeBuildLayer.content, probe.instance)];
    if (content != null && !content.visible) painted = false;
    return NodeGeometry(
      nodeId: probe.nodeId,
      layer: probe.buildLayer,
      instance: probe.instance,
      transform: transform,
      size: probe.size,
      clip: clip,
      painted: painted,
    );
  }

  /// The node instances under [position], in scope coordinates, topmost
  /// first: a node comes before its ancestors and before the siblings it
  /// paints over.
  ///
  /// This is a geometric test over the painted boxes, not Flutter's pointer
  /// hit testing: a node is hit anywhere inside its own box, whether or not
  /// it paints there, and children that overflow a parent that doesn't clip
  /// are still hit. Clips, scroll offsets, transforms and rotation are
  /// respected, and nodes that are hidden or not painted are never hit.
  ///
  /// [layer] picks which box of each node must contain [position]: its own
  /// box, or its margin box.
  ///
  /// When [skip] returns true for a node, neither it nor its subtree is hit,
  /// so nodes under it can be (for example the nodes being dragged).
  List<NodeHit> hitTest(
    Offset position, {
    NodeBuildLayer layer = NodeBuildLayer.content,
    bool Function(NodeHit hit)? skip,
  }) {
    final List<_HitEntry> index = _hitIndex ??= _collectHitIndex();
    if (_movedProbes.isNotEmpty) {
      for (final probe in _movedProbes) {
        _recollect(index, probe);
      }
      _movedProbes.clear();
    }
    // Entries are in paint order, so a parent comes before its subtree and
    // a skipped parent can skip its subtree.
    final Set<_HitEntry> skipped = {};
    final List<NodeHit> hits = [];
    for (final entry in index) {
      final _HitEntry? parent = entry.parent;
      if (parent != null && skipped.contains(parent)) {
        skipped.add(entry);
        continue;
      }
      if (skip != null && skip(entry.hit)) {
        skipped.add(entry);
        continue;
      }
      if (entry.layer != layer || !entry.contentVisible) continue;
      if (!entry.clips.contains(position)) continue;
      final Offset local = MatrixUtils.transformPoint(entry.inverse, position);
      if ((Offset.zero & entry.size).contains(local)) hits.add(entry.hit);
    }
    return hits.reversed.toList(growable: false);
  }

  /// Walks the render tree once, in paint order, recording each painted,
  /// visible probe with its inverse transform and the clips above it.
  List<_HitEntry> _collectHitIndex() {
    final RenderGeometryRoot? root = _root;
    if (root == null || !root.attached || !root.hasSize) return const [];
    final List<_HitEntry> entries = [];
    _visit(root, Matrix4.identity(), const _ClipChain.none(), null, entries);
    return entries;
  }

  /// Replaces the entries of [probe] and its subtree in [index] with fresh
  /// ones, keeping the transform and clips above it.
  void _recollect(List<_HitEntry> index, RenderGeometryProbe probe) {
    final int start = index.indexWhere(
      (entry) => identical(entry.probe, probe),
    );
    if (start < 0) return;
    final _HitEntry old = index[start];
    // Entries are in paint order, so the subtree follows its root.
    int end = start + 1;
    while (end < index.length && _descends(index[end], old)) {
      end++;
    }
    final List<_HitEntry> fresh = [];
    if (probe.attached) {
      _visit(probe, old.transform, old.clips, old.parent, fresh);
    }
    index.replaceRange(start, end, fresh);
  }

  static bool _descends(_HitEntry entry, _HitEntry ancestor) {
    for (
      _HitEntry? parent = entry.parent;
      parent != null;
      parent = parent.parent
    ) {
      if (identical(parent, ancestor)) return true;
    }
    return false;
  }

  /// Records [object] and its painted subtree into [entries]. [transform]
  /// maps [object]'s coordinates to scope coordinates.
  void _visit(
    RenderObject object,
    Matrix4 transform,
    _ClipChain clips,
    _HitEntry? parent,
    List<_HitEntry> entries,
  ) {
    if (object is RenderGeometryProbe) {
      if (!object.visible || !object.hasSize) return;
      // A probe's own box moves with its paint offset, as in [_measure].
      final Matrix4 shifted = transform.clone();
      final Offset shift = object.paintOffset;
      if (shift != Offset.zero) {
        shifted.translateByDouble(shift.dx, shift.dy, 0, 1);
      }
      final Matrix4 inverse = Matrix4.zero();
      if (inverse.copyInverse(shifted) == 0) return;
      final _HitEntry entry = _HitEntry(
        probe: object,
        hit: NodeHit(object.nodeId, object.instance),
        layer: object.buildLayer,
        contentVisible: _contentVisible(object),
        transform: transform,
        inverse: inverse,
        size: object.size,
        clips: clips,
        parent: parent,
      );
      entries.add(entry);
      parent = entry;
    }
    object.visitChildren((child) {
      if (!object.paintsChild(child)) return;
      _ClipChain childClips = clips;
      final Rect? clip = object.describeApproximatePaintClip(child);
      if (clip != null) {
        final Matrix4 inverse = Matrix4.zero();
        if (inverse.copyInverse(transform) == 0) return;
        childClips = _ClipChain(inverse, clip, clips);
      }
      final Matrix4 childTransform = transform.clone();
      object.applyPaintTransform(child, childTransform);
      _visit(child, childTransform, childClips, parent, entries);
    });
  }

  /// Whether the node of [probe] is visible. A margin probe sits outside the
  /// node's [Visibility], so it asks the node's content probe.
  bool _contentVisible(RenderGeometryProbe probe) {
    if (probe.buildLayer == NodeBuildLayer.content) return probe.visible;
    return _probes[probe.nodeId]?[_key(NodeBuildLayer.content, probe.instance)]
            ?.visible ??
        false;
  }

  @override
  void dispose() {
    _probes.clear();
    _root = null;
    super.dispose();
  }
}

/// A probe recorded for hit testing.
class _HitEntry {
  final RenderGeometryProbe probe;
  final NodeHit hit;
  final NodeBuildLayer layer;
  final bool contentVisible;

  /// Maps the probe's coordinates, before its paint offset, to scope
  /// coordinates.
  final Matrix4 transform;

  /// Maps scope coordinates into the probe's own, paint offset included.
  final Matrix4 inverse;
  final Size size;
  final _ClipChain clips;

  /// The nearest probe above this one.
  final _HitEntry? parent;

  _HitEntry({
    required this.probe,
    required this.hit,
    required this.layer,
    required this.contentVisible,
    required this.transform,
    required this.inverse,
    required this.size,
    required this.clips,
    required this.parent,
  });
}

/// The clips above a render object, innermost first, each in the space of
/// the object that clips.
class _ClipChain {
  final Matrix4? _inverse;
  final Rect? _clip;
  final _ClipChain? _outer;

  const _ClipChain(Matrix4 inverse, Rect clip, _ClipChain outer)
    : _inverse = inverse,
      _clip = clip,
      _outer = outer;

  const _ClipChain.none() : _inverse = null, _clip = null, _outer = null;

  /// Whether [position], in scope coordinates, is inside every clip.
  bool contains(Offset position) {
    for (_ClipChain? chain = this; chain != null; chain = chain._outer) {
      final Rect? clip = chain._clip;
      if (clip == null) continue;
      if (!clip.contains(
        MatrixUtils.transformPoint(chain._inverse!, position),
      )) {
        return false;
      }
    }
    return true;
  }
}

/// Makes [registry] collect the geometry of every [GeometryProbe] below, in
/// this widget's coordinate space.
class NodeGeometryScope extends StatelessWidget {
  final NodeGeometryRegistry registry;
  final Widget child;

  const NodeGeometryScope({
    super.key,
    required this.registry,
    required this.child,
  });

  /// The registry of the nearest scope, if any.
  static NodeGeometryRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GeometryScopeData>()
      ?.registry;

  @override
  Widget build(BuildContext context) => _GeometryScopeData(
    registry: registry,
    child: NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is ScrollNotification ||
            notification is ScrollMetricsNotification) {
          registry.markChanged();
        }
        return false;
      },
      child: _GeometryRootWidget(registry: registry, child: child),
    ),
  );
}

class _GeometryScopeData extends InheritedWidget {
  final NodeGeometryRegistry registry;

  const _GeometryScopeData({required this.registry, required super.child});

  @override
  bool updateShouldNotify(_GeometryScopeData oldWidget) =>
      !identical(oldWidget.registry, registry);
}

class _GeometryRootWidget extends SingleChildRenderObjectWidget {
  final NodeGeometryRegistry registry;

  const _GeometryRootWidget({required this.registry, super.child});

  @override
  RenderGeometryRoot createRenderObject(BuildContext context) =>
      RenderGeometryRoot(registry);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGeometryRoot renderObject,
  ) => renderObject.registry = registry;
}

/// The coordinate origin of a [NodeGeometryScope].
class RenderGeometryRoot extends RenderProxyBox {
  NodeGeometryRegistry _registry;

  RenderGeometryRoot(this._registry);

  NodeGeometryRegistry get registry => _registry;

  set registry(NodeGeometryRegistry value) {
    if (identical(value, _registry)) return;
    if (attached && identical(_registry._root, this)) _registry._root = null;
    _registry = value;
    if (attached) _registry._root = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry._root = this;
  }

  @override
  void detach() {
    if (identical(_registry._root, this)) _registry._root = null;
    super.detach();
  }
}

/// Registers the render box of one node instance with the nearest
/// [NodeGeometryScope]. Lays out and paints exactly like its child. Without
/// a scope above it, it builds [child] alone.
class GeometryProbe extends StatelessWidget {
  final String nodeId;
  final NodeBuildLayer layer;
  final Widget child;

  const GeometryProbe({
    super.key,
    required this.nodeId,
    required this.layer,
    required this.child,
  });

  /// The item indices of the list, grid and page view items around
  /// [context], outermost first.
  static List<int> instanceOf(BuildContext context) {
    // Depend on the nearest item so that a reused element re-registers when
    // its index changes.
    if (IndexedItemProvider.maybeOf(context) == null) return const [];
    final List<int> indices = [];
    context.visitAncestorElements((element) {
      final Widget widget = element.widget;
      if (widget is IndexedItemProvider) indices.add(widget.item.index);
      return widget is! _GeometryScopeData;
    });
    return indices.reversed.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final NodeGeometryRegistry? registry = NodeGeometryScope.maybeOf(context);
    if (registry == null) return child;
    return _GeometryProbeWidget(
      registry: registry,
      nodeId: nodeId,
      layer: layer,
      instance: instanceOf(context),
      visible: Visibility.of(context),
      child: child,
    );
  }
}

class _GeometryProbeWidget extends SingleChildRenderObjectWidget {
  final NodeGeometryRegistry registry;
  final String nodeId;
  final NodeBuildLayer layer;
  final List<int> instance;
  final bool visible;

  const _GeometryProbeWidget({
    required this.registry,
    required this.nodeId,
    required this.layer,
    required this.instance,
    required this.visible,
    super.child,
  });

  @override
  RenderGeometryProbe createRenderObject(BuildContext context) =>
      RenderGeometryProbe(
        registry: registry,
        nodeId: nodeId,
        layer: layer,
        instance: instance,
        visible: visible,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGeometryProbe renderObject,
  ) {
    renderObject.update(
      registry: registry,
      nodeId: nodeId,
      layer: layer,
      instance: instance,
      visible: visible,
    );
  }
}

/// The render box of one [GeometryProbe].
class RenderGeometryProbe extends RenderProxyBox {
  NodeGeometryRegistry _registry;
  String _nodeId;
  NodeBuildLayer _buildLayer;
  List<int> _instance;

  RenderGeometryProbe({
    required this._registry,
    required this._nodeId,
    required NodeBuildLayer layer,
    required this._instance,
    required this._visible,
  }) : _buildLayer = layer;

  String get nodeId => _nodeId;

  /// Which of the node's boxes this probe is.
  NodeBuildLayer get buildLayer => _buildLayer;

  List<int> get instance => _instance;

  /// False inside a hidden [Visibility], which may still lay the node out.
  bool get visible => _visible;
  bool _visible;

  /// Changes what this probe registers as. Any rebuild of the node can move
  /// paint without relayout (rotation, opacity), so it always notifies.
  void update({
    required NodeGeometryRegistry registry,
    required String nodeId,
    required NodeBuildLayer layer,
    required List<int> instance,
    required bool visible,
  }) {
    _visible = visible;
    final bool rekey =
        !identical(registry, _registry) ||
        nodeId != _nodeId ||
        layer != _buildLayer ||
        !listEquals(instance, _instance);
    if (rekey && attached) _registry._unregister(this);
    _registry = registry;
    _nodeId = nodeId;
    _buildLayer = layer;
    _instance = instance;
    if (rekey && attached) {
      _registry._register(this);
    } else {
      _registry.markChanged();
    }
  }

  /// How far the child is painted from where it was laid out. See
  /// [NodeGeometryRegistry.setPaintOffset].
  Offset get paintOffset => _paintOffset;
  Offset _paintOffset = Offset.zero;

  set paintOffset(Offset value) {
    if (value == _paintOffset) return;
    _paintOffset = value;
    markNeedsPaint();
    _registry._paintOffsetChanged(this);
  }

  /// Whether the node is painted somewhere else instead of here. See
  /// [NodeGeometryRegistry.setLifted].
  bool get lifted => _lifted;
  bool _lifted = false;

  set lifted(bool value) {
    if (value == _lifted) return;
    _lifted = value;
    markNeedsPaint();
    _registry.markChanged();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_lifted) return;
    super.paint(context, offset + _paintOffset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_paintOffset.dx, _paintOffset.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _paintOffset,
        position: position,
        hitTest: (result, transformed) =>
            super.hitTestChildren(result, position: transformed),
      );

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry._register(this);
  }

  @override
  void detach() {
    _registry._unregister(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _registry.markChanged();
  }
}
