// Islands: Flutter widgets for one node, hosted under a render box.
//
// Most nodes are render objects only. A widget that needs an element tree (a
// text field, a slider, a video, a chart) is built as an island: an
// [IslandHost] render box in the node's chain, and under it the render
// objects of the island's widgets.
//
// The island's elements live in the app's element tree. The element of the
// widget that shows the nodes ([NodeView], or a [NodeChild] inside another
// island) is an [IslandOwnerElement]: besides its render object, it owns one
// child element per island under it, with the island's host as the slot, so
// the island inherits from the app (theme, media query, localizations,
// navigator, overlay, focus) like any widget, and is deactivated, reactivated
// and unmounted with it. Its render object, though, sits under the host deep
// in the node tree, as with Overlay or a sliver list: the owner element puts
// it there ([IslandOwnerElement.insertRenderObjectChild]).
//
// Islands build lazily, inside their host's layout (as LayoutBuilder does), so
// a node that's never laid out never builds. The owner is found then: the
// nearest render ancestor that a [IslandOwnerElement] owns. When a node moves
// under another owner (a list item, a node inside an island), its island's
// elements move with it, keeping their state.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// How islands are built in one node tree.
@immutable
class IslandEnvironment {
  const IslandEnvironment({this.wrap, this.interactive = false});

  /// Whether islands take pointer input and focus (a running app) or are
  /// only drawn (a design canvas, the default).
  final bool interactive;

  /// Wraps every island's widget (extra inherited widgets). The app's own
  /// inherited widgets reach islands without it.
  final Widget Function(Widget child)? wrap;

  /// [child] under the environment: a transparent Material (inputs and ink
  /// need one), with the ambient widgets an app normally provides added only
  /// where the app has none; not focusable or tappable unless [interactive].
  Widget apply(Widget child) {
    if (!interactive) child = ExcludeFocus(child: IgnorePointer(child: child));
    // An island's scroll views are its own, not the app's primary one.
    child = PrimaryScrollController.none(
      child: Material(type: MaterialType.transparency, child: child),
    );
    child = _Ambient(child: child);
    return wrap?.call(child) ?? child;
  }

  @override
  bool operator ==(Object other) =>
      other is IslandEnvironment && other.interactive == interactive && other.wrap == wrap;

  @override
  int get hashCode => Object.hash(interactive, wrap);
}

/// Media query, directionality and overlay for islands shown outside an app.
class _Ambient extends StatelessWidget {
  const _Ambient({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var w = child;
    if (Overlay.maybeOf(context) == null) {
      w = Overlay.wrap(alwaysSizeToContent: true, clipBehavior: Clip.none, child: w);
    }
    if (Directionality.maybeOf(context) == null) w = Directionality(textDirection: TextDirection.ltr, child: w);
    if (MediaQuery.maybeOf(context) == null) w = MediaQuery(data: const MediaQueryData(), child: w);
    return w;
  }
}

/// The islands of one node tree.
class IslandManager {
  IslandManager([this._environment = const IslandEnvironment()]);

  IslandEnvironment _environment;
  IslandEnvironment get environment => _environment;

  /// Setting another environment rebuilds every island.
  set environment(IslandEnvironment e) {
    if (e == _environment) return;
    _environment = e;
    rebuildAll();
  }

  final Set<IslandHost> _hosts = {};
  Iterable<IslandHost> get hosts => _hosts;

  IslandHost host(String debugLabel, WidgetBuilder builder) {
    final h = IslandHost._(this, debugLabel).._builder = builder;
    _hosts.add(h);
    return h;
  }

  /// Rebuilds every island on its next layout.
  void rebuildAll() {
    for (final h in _hosts) {
      h.markRebuild();
    }
  }

  void dispose() {
    for (final h in _hosts.toList()) {
      h.release();
    }
  }
}

/// Schedules [callback] for the layout phase: now during a frame, else from
/// the next frame's start (the render tree stays clean between frames), as
/// LayoutBuilder does.
void _whenLaidOut(VoidCallback callback) {
  switch (SchedulerBinding.instance.schedulerPhase) {
    case SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks:
      SchedulerBinding.instance.scheduleFrameCallback((_) => callback());
      SchedulerBinding.instance.ensureVisualUpdate();
    case SchedulerPhase.transientCallbacks || SchedulerPhase.midFrameMicrotasks || SchedulerPhase.persistentCallbacks:
      callback();
  }
}

/// A render object that can deliberately skip laying out its children.
abstract interface class SkippedChildLayout {
  bool get skipsChildLayout;
}

/// Repairs the dirty path left by a skipped child layout before mutating it.
/// A skipped descendant may stay dirty while its ancestor becomes clean;
/// invalidating from the outermost skipped ancestor down restores the normal
/// relayout-boundary invariant, including cached wrappers between node boxes.
void prepareSkippedLayoutChange(RenderObject object, {bool markWhenExpanded = true}) {
  final path = <RenderObject>[];
  var skippedAt = -1;
  for (RenderObject? current = object; current != null; current = current.parent) {
    path.add(current);
    final ancestor = current;
    if (ancestor is SkippedChildLayout && (ancestor as SkippedChildLayout).skipsChildLayout) skippedAt = path.length - 1;
  }
  if (skippedAt < 0) {
    if (markWhenExpanded) object.markNeedsLayout();
    return;
  }
  for (var i = skippedAt; i >= 0; i--) {
    path[i].markNeedsLayout();
  }
}

/// A render box hosting one island's widget.
class IslandHost extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin {
  IslandHost._(this.manager, this.debugLabel);

  @override
  set child(RenderBox? value) {
    if (identical(super.child, value)) return;
    // Flutter can remove an island while its node is collapsed,
    // outside NodeBox's normal property-update path (owner deactivation,
    // transfer, or release). Repair the entire path before dropChild.
    // Inserting into an empty host does not drop a dirty child and can happen
    // in that host's own layout callback, where its ancestors must stay clean.
    if (super.child != null) prepareSkippedLayoutChange(this, markWhenExpanded: false);
    super.child = value;
  }

  final IslandManager manager;
  final String debugLabel;
  bool _disposed = false;
  bool _renderDisposed = false;
  bool get disposed => _disposed;

  /// The island's root element (null until built, or once unmounted).
  _IslandScopeElement? _scope;

  /// The element that owns [_scope].
  IslandOwnerElement? _owner;

  /// The island's root element, for tools and tests.
  @visibleForTesting
  Element? get element => _scope;

  /// Keeps the island's elements (and their state) when its node moves under
  /// another owner.
  late final GlobalKey _key = GlobalObjectKey(this);

  bool _dirty = true;

  WidgetBuilder _builder = _empty;
  static Widget _empty(BuildContext _) => const SizedBox.shrink();

  /// Builds the island's widget. Setting it rebuilds the island.
  WidgetBuilder get builder => _builder;
  set builder(WidgetBuilder b) {
    _builder = b;
    markRebuild();
  }

  /// Islands whose widgets rebuild themselves (spinners, streams) become
  /// their own layer, so their frames don't repaint around them.
  bool _animates = false;

  @override
  bool get isRepaintBoundary => _animates;

  /// Times this island was built (tests, profiling).
  int debugBuilds = 0;

  /// Rebuilds the island on its next layout.
  void markRebuild() {
    if (_disposed) return;
    _dirty = true;
    if (attached) {
      scheduleLayoutCallback();
    } else {
      markNeedsLayout();
    }
  }

  bool _rebuildScheduled = false;
  int _ownRebuilds = 0;

  /// A widget inside the island needs building: flushed in the next layout.
  void _scheduleDescendantRebuild() {
    if (_disposed || _building || _rebuildScheduled) return;
    _rebuildScheduled = true;
    _whenLaidOut(() {
      _rebuildScheduled = false;
      if (_disposed) return;
      // An inherited change rebuilds an island once; a widget that keeps
      // rebuilding itself animates.
      if (!_animates && ++_ownRebuilds >= 2) {
        _animates = true;
        markNeedsCompositingBitsUpdate();
        markNeedsPaint();
      }
      if (attached) scheduleLayoutCallback();
    });
  }

  /// The element owning the islands at this point of the render tree.
  IslandOwnerElement? _findOwner() {
    for (RenderObject? p = parent; p != null; p = p.parent) {
      if (p is IslandParent) return p._islandOwner;
    }
    return null;
  }

  @override
  void performLayout() {
    runLayoutCallback();
    super.performLayout();
  }

  @override
  void layoutCallback() {
    if (_disposed) return;
    final owner = _findOwner();
    // Shown without a NodeView or NodeChild above: nothing to build under.
    if (owner == null || !owner.mounted) return;
    final scope = _scope;
    _building = true;
    try {
      if (_dirty || scope == null || !identical(owner, _owner)) {
        _dirty = false;
        debugBuilds++;
        owner._buildIsland(this, _IslandScope(key: _key, host: this, child: manager.environment.apply(Builder(builder: _builder))));
      }
      // Always flush the island's own scope, also after rebuilding it from
      // the top: a widget that marked itself dirty (a ticking spinner) and
      // was then rebuilt by its parent is clean but still in the scope's
      // dirty list, and its next setState would assert in
      // BuildOwner.scheduleBuildFor. Flushing clears the list (and builds
      // what is still dirty).
      final built = _scope;
      if (built != null) owner.owner!.buildScope(built);
    } finally {
      _building = false;
    }
  }

  bool _building = false;

  /// Unmounts the island's widgets; the host can't be used again.
  void release() {
    if (_disposed) return;
    _disposed = true;
    manager._hosts.remove(this);
    final owner = _owner;
    if (owner != null && owner.mounted) owner._drop(this);
    // The host has no RenderObjectElement. Its island's elements own the
    // child, so release the host's layers only after they finish unmounting.
    SchedulerBinding.instance.addPostFrameCallback((_) => _disposeReleasedHost());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _disposeReleasedHost() {
    if (_renderDisposed || !_disposed || attached || child != null) return;
    _renderDisposed = true;
    super.dispose();
  }

  @override
  void detach() {
    super.detach();
    if (_disposed) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _disposeReleasedHost());
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  void _unmounted(_IslandScopeElement scope) {
    if (!identical(_scope, scope)) return;
    _scope = null;
    _owner = null;
    _dirty = true;
    // The island's render objects are disposed with its elements.
    child = null;
    _disposeReleasedHost();
  }
}

/// A render object whose element ([IslandOwnerElement]) owns the islands
/// under it.
mixin IslandParent on RenderBox, RenderObjectWithLayoutCallbackMixin {
  IslandOwnerElement? _islandOwner;

  /// The element that shows this render object (in the app's element tree),
  /// or null while none does.
  BuildContext? get islandOwnerContext => _islandOwner;

  /// The element showing this render object's node boxes (a [NodeView]'s
  /// or a [NodeChild]'s), for what needs a place in the element tree (a
  /// drag track's focus node); null before it's mounted.
  BuildContext? get islandContext => _islandOwner;

  @override
  void performLayout() {
    runLayoutCallback();
    super.performLayout();
  }

  /// Unmounts the islands released since the last layout.
  @override
  void layoutCallback() => _islandOwner?._flushDrops();
}

/// The element showing the node boxes [object] is in (a [NodeView]'s, or a
/// [NodeChild]'s inside an island): a context in the app's element tree,
/// for what a render object shows in the app's overlay. Null outside one.
BuildContext? islandContextOf(RenderObject object) {
  for (RenderObject? p = object; p != null; p = p.parent) {
    if (p is IslandParent) return p._islandOwner;
  }
  return null;
}

/// The element of a widget that shows node boxes ([NodeView], [NodeChild]):
/// it owns the islands under its render object as its children, one per
/// island, each in the slot of its [IslandHost].
class IslandOwnerElement extends RenderObjectElement {
  IslandOwnerElement(super.widget);

  @override
  IslandParent get renderObject => super.renderObject as IslandParent;

  final Map<IslandHost, Element> _islands = {};
  final Set<IslandHost> _drops = {};

  /// Islands build during layout, in this scope: building them never flushes
  /// the app's dirty widgets.
  @override
  BuildScope get buildScope => _buildScope;
  late final BuildScope _buildScope = BuildScope(
    scheduleRebuild: () => _whenLaidOut(() {
      if (mounted) renderObject.scheduleLayoutCallback();
    }),
  );

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._islandOwner = this;
  }

  /// Going inactive, the islands' render objects leave their hosts (as an
  /// element's render object leaves its parent): a host may have moved on
  /// under another owner, which then takes the island over.
  @override
  void deactivate() {
    for (final e in _islands.entries) {
      final ro = e.value.renderObject;
      if (ro != null && identical(e.key.child, ro)) e.key.child = null;
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    for (final e in _islands.entries) {
      final ro = e.value.renderObject;
      if (ro is RenderBox && e.key.child == null && ro.parent == null) e.key.child = ro;
    }
  }

  @override
  void unmount() {
    // The islands are unmounted already (children first).
    final ro = renderObject;
    if (identical(ro._islandOwner, this)) ro._islandOwner = null;
    super.unmount();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final e in _islands.values.toList()) {
      visitor(e);
    }
  }

  @override
  void forgetChild(Element child) {
    final host = child.slot! as IslandHost;
    if (identical(_islands[host], child)) {
      _islands.remove(host);
      if (identical(host._owner, this)) host._owner = null;
    }
    super.forgetChild(child);
  }

  /// Builds (or updates) [host]'s island as [widget]. Called in the host's
  /// layout callback.
  void _buildIsland(IslandHost host, Widget widget) {
    owner!.buildScope(this, () {
      final previous = host._owner;
      if (previous != null && !identical(previous, this)) previous._release(host);
      host._owner = this;
      final e = updateChild(_islands[host], widget, host);
      if (e != null) _islands[host] = e;
    });
  }

  /// Lets go of [host]'s island so another owner takes it (with its state,
  /// by its global key).
  void _release(IslandHost host) {
    final e = _islands.remove(host);
    if (e == null) return;
    forgetChild(e);
    deactivateChild(e);
  }

  /// Unmounts [host]'s island at the next layout.
  void _drop(IslandHost host) {
    _drops.add(host);
    _whenLaidOut(() {
      if (mounted && _drops.isNotEmpty) renderObject.scheduleLayoutCallback();
    });
  }

  void _flushDrops() {
    if (_drops.isEmpty) return;
    owner!.buildScope(this, () {
      final drops = _drops.toList();
      _drops.clear();
      for (final h in drops) {
        final e = _islands.remove(h);
        if (identical(h._owner, this)) h._owner = null;
        if (e != null) updateChild(e, null, h);
      }
    });
  }

  @override
  void insertRenderObjectChild(RenderObject child, IslandHost slot) {
    slot.child = child as RenderBox;
  }

  @override
  void moveRenderObjectChild(RenderObject child, IslandHost oldSlot, IslandHost newSlot) {
    assert(false, 'An island stays in its host');
  }

  @override
  void removeRenderObjectChild(RenderObject child, IslandHost slot) {
    if (identical(slot.child, child)) slot.child = null;
  }
}

/// The root of an island's widgets: its descendants rebuild in their own
/// build scope, flushed during the host's layout.
class _IslandScope extends ProxyWidget {
  const _IslandScope({super.key, required this.host, required super.child});
  final IslandHost host;

  @override
  Element createElement() => _IslandScopeElement(this);
}

class _IslandScopeElement extends ProxyElement {
  _IslandScopeElement(_IslandScope super.widget);

  IslandHost get host => (widget as _IslandScope).host;

  late final BuildScope _buildScope = BuildScope(scheduleRebuild: () => host._scheduleDescendantRebuild());

  @override
  BuildScope get buildScope => _buildScope;

  @override
  void mount(Element? parent, Object? newSlot) {
    host._scope = this;
    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    final host = this.host;
    super.unmount();
    host._unmounted(this);
  }

  @override
  void notifyClients(ProxyWidget oldWidget) {}
}
