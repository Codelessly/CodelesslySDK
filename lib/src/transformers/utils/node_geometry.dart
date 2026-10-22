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
  bool _hitTesting = false;
  bool _notified = false;

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

  /// The node instances under [position], in scope coordinates, deepest
  /// first. Uses Flutter's hit testing, so clips, scroll offsets,
  /// transforms, offstage subtrees and paint order are respected. A node is
  /// hit anywhere inside its own box, whether or not it paints there.
  List<NodeHit> hitTest(Offset position) {
    final RenderGeometryRoot? root = _root;
    if (root == null || !root.attached || !root.hasSize) return const [];
    final BoxHitTestResult result = BoxHitTestResult();
    _hitTesting = true;
    try {
      root.hitTest(result, position: position);
    } finally {
      _hitTesting = false;
    }
    return [
      for (final HitTestEntry entry in result.path)
        if (entry is _GeometryHitEntry) entry.hit,
    ];
  }

  @override
  void dispose() {
    _probes.clear();
    _root = null;
    super.dispose();
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

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_registry._hitTesting) {
      return super.hitTest(result, position: position);
    }
    if (!size.contains(position)) return false;
    // A margin probe is transparent: the node is hit only inside its own
    // box, which its content probe reports.
    final bool childHit = hitTestChildren(result, position: position);
    if (_buildLayer == NodeBuildLayer.margin || !_visible) return childHit;
    result.add(_GeometryHitEntry(this, position, NodeHit(_nodeId, _instance)));
    return true;
  }
}

class _GeometryHitEntry extends BoxHitTestEntry {
  final NodeHit hit;

  _GeometryHitEntry(super.target, super.localPosition, this.hit);
}
