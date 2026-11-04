// Islands: Flutter widgets for one node, hosted under a render box.
//
// Most nodes are render objects only. A widget that needs an element tree —
// a text field, a slider, a video, a chart — is built as an island: its
// widget is mounted under an [IslandHost] with the app's [BuildOwner]. No
// widget or element exists above the island; the host is an ordinary render
// box in the node tree. Islands build lazily, inside the host's layout (as
// LayoutBuilder does), so a node that's never laid out never builds.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// The ambient widgets islands are built under (theme, media query,
/// localizations), captured from where the tree is shown.
@immutable
class IslandEnvironment {
  const IslandEnvironment({this.wrap, this.interactive = false});

  /// Whether islands take pointer input and focus (a running app) or are
  /// only drawn (a design canvas, the default).
  final bool interactive;

  /// Wraps an island's widget in inherited widgets.
  final Widget Function(Widget child)? wrap;

  /// Captures the inherited widgets above [context].
  factory IslandEnvironment.capture(BuildContext context, {bool interactive = false}) {
    final mq = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final hasLocalizations = Localizations.maybeLocaleOf(context) != null;
    return IslandEnvironment(
      interactive: interactive,
      wrap: (child) {
        Widget w = InheritedTheme.captureAll(context, child);
        if (hasLocalizations) w = Localizations.override(context: context, child: w);
        return MediaQuery(data: mq, child: Directionality(textDirection: dir, child: w));
      },
    );
  }

  /// [child] under the environment: a transparent Material (inputs and ink
  /// need one) with an overlay (menus, tooltips); not focusable or tappable
  /// unless [interactive].
  Widget apply(Widget child) {
    if (!interactive) child = ExcludeFocus(child: IgnorePointer(child: child));
    final material = Material(
      type: MaterialType.transparency,
      child: Overlay.wrap(alwaysSizeToContent: true, clipBehavior: Clip.none, child: child),
    );
    return wrap?.call(material) ??
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(textDirection: TextDirection.ltr, child: material),
        );
  }
}

/// Builds and owns the islands of one node tree.
class IslandManager {
  IslandManager([this.environment = const IslandEnvironment()]);

  IslandEnvironment environment;

  /// Islands share the app's build owner: GlobalKeys and focus resolve
  /// through it.
  BuildOwner get buildOwner => WidgetsBinding.instance.buildOwner!;
  final Set<IslandHost> _hosts = {};
  Iterable<IslandHost> get hosts => _hosts;

  IslandHost host(String debugLabel, WidgetBuilder builder) {
    final h = IslandHost._(this, debugLabel)..builder = builder;
    _hosts.add(h);
    _markDirty(h);
    return h;
  }

  final Set<IslandHost> _dirty = {};
  bool _flushing = false;

  /// Called when an island needs building; the view then flushes islands
  /// before laying out ([flush]).
  VoidCallback? onNeedsFlush;

  void _markDirty(IslandHost h) {
    _dirty.add(h);
    if (!_flushing) onNeedsFlush?.call();
  }

  /// Rebuilds every island (the environment changed).
  void rebuildAll() {
    for (final h in _hosts) {
      h.markRebuild();
    }
  }

  /// Builds every island that needs it. Called by the view inside its own
  /// layout callback, so an island is built before a parent measures it.
  void flush() {
    if (_dirty.isEmpty) return;
    _flushing = true;
    try {
      while (_dirty.isNotEmpty) {
        final batch = _dirty.toList();
        _dirty.clear();
        for (final h in batch) {
          if (h.attached) h._buildNow();
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    for (final h in _hosts.toList()) {
      h.release();
    }
  }
}

/// A render box hosting one island's widget.
class IslandHost extends RenderProxyBox {
  IslandHost._(this.manager, this.debugLabel);

  final IslandManager manager;
  final String debugLabel;
  RenderObjectToWidgetElement<RenderBox>? _element;
  _IslandScopeElement? _scope;
  bool _dirty = true;
  bool _descendantsDirty = false;
  bool _disposed = false;
  bool get disposed => _disposed;

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

  /// Rebuilds the island on its next layout.
  void markRebuild() {
    if (_disposed) return;
    if (!_dirty) {
      _dirty = true;
      manager._markDirty(this);
    }
    markNeedsLayout();
  }

  void _buildNow() {
    if (_disposed) return;
    if (_dirty) {
      _rebuild();
    } else if (_descendantsDirty && _scope != null) {
      _descendantsDirty = false;
      if (!_animates) {
        _animates = true;
        markNeedsCompositingBitsUpdate();
        markNeedsPaint();
      }
      _building = true;
      try {
        manager.buildOwner.buildScope(_scope!);
      } finally {
        _building = false;
      }
    }
  }

  bool _building = false;

  /// Times this island was built (tests, profiling).
  int debugBuilds = 0;

  void _rebuild() {
    _building = true;
    try {
      debugBuilds++;
      _dirty = false;
      _descendantsDirty = false;
      final adapter = RenderObjectToWidgetAdapter<RenderBox>(
        container: this,
        debugShortDescription: '[island $debugLabel]',
        child: _IslandScope(host: this, child: manager.environment.apply(Builder(builder: _builder))),
      );
      final owner = manager.buildOwner;
      final existing = _element;
      if (existing == null) {
        _element = adapter.attachToRenderTree(owner);
      } else {
        owner.buildScope(existing, () => existing.update(adapter));
      }
      final scope = _scope;
      if (scope != null) owner.buildScope(scope);
    } finally {
      _building = false;
    }
  }

  void _scheduleDescendantRebuild() {
    if (_disposed || _building) return;
    _descendantsDirty = true;
    manager._markDirty(this);
  }

  @override
  void performLayout() {
    if (!_disposed) {
      if (_dirty) {
        invokeLayoutCallback<BoxConstraints>((_) => _rebuild());
      } else if (_descendantsDirty && _scope != null) {
        invokeLayoutCallback<BoxConstraints>((_) => _buildNow());
      }
    }
    super.performLayout();
  }

  /// Unmounts the island's widgets; the host can't be used again.
  void release() {
    if (_disposed) return;
    _disposed = true;
    manager._hosts.remove(this);
    manager._dirty.remove(this);
    final e = _element;
    if (e == null) return;
    final adapter = RenderObjectToWidgetAdapter<RenderBox>(container: this, child: null);
    final owner = manager.buildOwner;
    _element = null;
    _scope = null;
    void deactivate() => owner.buildScope(e, () => e.update(adapter));
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(deactivate);
    } else {
      deactivate();
    }
  }
}

/// The root of an island's widgets: its descendants rebuild in their own
/// build scope, flushed during the host's layout.
class _IslandScope extends ProxyWidget {
  const _IslandScope({required this.host, required super.child});
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
    if (identical(host._scope, this)) host._scope = null;
    super.unmount();
  }

  @override
  void notifyClients(ProxyWidget oldWidget) {}
}
