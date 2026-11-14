// The root of a rendered screen and the services every control under it
// shares: the overlay layer (tooltips now; menus, pickers, toasts, dialogs
// and drag avatars as the controls move here), the focus scope and its key
// dispatch. What a host app's `MaterialApp` gave islands (an Overlay, a
// FocusScope, Shortcuts), as render objects.
//
// A widget host makes one with `NodeView` (render/node_view.dart: its render
// object is a [RenderControlRoot]); a whole app with no widget attaches one
// to a view with [attachRoot].
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'focus.dart';
import 'overlay.dart';

/// The root render object: a proxy for the screen's box, with an overlay
/// layer above it and the focus scope of the controls under it.
class RenderControlRoot extends RenderProxyBox {
  RenderControlRoot({RenderBox? child, ControlKeyboard? keyboard})
      : focus = ControlFocusScope(keyboard: keyboard),
        super(child) {
    focus.onChange = markNeedsSemanticsUpdate;
  }

  /// The focus order of the controls under this root.
  final ControlFocusScope focus;

  /// Where key events come from (null: none; the root takes no keys).
  ControlKeyboard? get keyboard => focus.keyboard;
  set keyboard(ControlKeyboard? value) {
    if (identical(value, focus.keyboard)) return;
    if (attached) focus.keyboard?.detach(handleKeyEvent);
    focus.keyboard = value;
    if (attached) value?.attach(handleKeyEvent);
  }

  /// The root over [object], or null outside one.
  static RenderControlRoot? of(RenderObject object) {
    for (RenderObject? p = object; p != null; p = p.parent) {
      if (p is RenderControlRoot) return p;
    }
    return null;
  }

  /// A key event from the host; true when a control handled it.
  bool handleKeyEvent(KeyEvent event) => attached && focus.handleKeyEvent(event);

  // --- the overlay layer ----------------------------------------------------

  final List<RenderOverlayEntry> _overlay = [];

  /// Whether the overlay entries are painted. A capture tool turns it off
  /// to take the content alone (the slices of a full-page capture, where a
  /// menu or a tooltip shows once, in the first window).
  bool get paintsOverlay => _paintsOverlay;
  bool _paintsOverlay = true;
  set paintsOverlay(bool value) {
    if (value == _paintsOverlay) return;
    _paintsOverlay = value;
    markNeedsPaint();
  }

  /// The entries shown, bottom first.
  List<RenderOverlayEntry> get overlayEntries => List.unmodifiable(_overlay);

  /// Shows [entry] above the content (and the entries already shown).
  void showOverlay(RenderOverlayEntry entry) {
    if (_overlay.contains(entry)) return;
    _overlay.add(entry);
    adoptChild(entry);
    markNeedsLayout();
  }

  /// Takes [entry] away.
  void hideOverlay(RenderOverlayEntry entry) {
    if (!_overlay.remove(entry)) return;
    dropChild(entry);
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final e in _overlay) {
      e.attach(owner);
    }
    focus.keyboard?.attach(handleKeyEvent);
  }

  @override
  void detach() {
    focus.keyboard?.detach(handleKeyEvent);
    focus.hostTookFocus();
    super.detach();
    for (final e in _overlay) {
      e.detach();
    }
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    _overlay.forEach(redepthChild);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    _overlay.forEach(visitor);
  }

  @override
  void performLayout() {
    super.performLayout();
    for (final e in _overlay) {
      e.layout(BoxConstraints.loose(size), parentUsesSize: true);
      (e.parentData! as BoxParentData).offset = e.placeIn(this, size);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!paintsOverlay) return;
    for (final e in _overlay) {
      context.paintChild(e, offset + (e.parentData! as BoxParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final e in _overlay.reversed) {
      if (!e.hitTestable) continue;
      final o = (e.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(offset: o, position: position, hitTest: (r, p) => e.hitTest(r, position: p));
      if (hit) return true;
    }
    return super.hitTestChildren(result, position: position);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    if (child is RenderOverlayEntry) {
      final o = (child.parentData! as BoxParentData).offset;
      transform.translateByDouble(o.dx, o.dy, 0, 1);
      return;
    }
    super.applyPaintTransform(child, transform);
  }
}

/// A root attached to a view with no widget ([attachRoot]).
class RootAttachment {
  RootAttachment._(this.root, this.renderView, this._owner, this._ownsView, [this._previous]);

  final RenderControlRoot root;
  final RenderView renderView;
  final PipelineOwner? _owner;
  final bool _ownsView;
  final RenderBox? _previous;

  /// Takes the root off the view (and the view off the binding when it was
  /// made for it).
  void detach() {
    root.keyboard = null;
    if (identical(renderView.child, root)) renderView.child = _previous;
    if (_ownsView) RendererBinding.instance.removeRenderView(renderView);
    final owner = _owner;
    if (owner != null) {
      RendererBinding.instance.rootPipelineOwner.dropChild(owner);
      owner.rootNode = null;
    }
  }
}

/// Shows [root] in [view] with no widget: a render view for the view (the
/// binding's [existing] one when given, else a new one added to the
/// binding; an [existing] one's child is put back on [RootAttachment.detach]), key events from `HardwareKeyboard` (unless [keyboard] says
/// otherwise), a frame scheduled. What `runApp` does for a widget, for a
/// render object.
RootAttachment attachRoot(RenderControlRoot root,
    {required ui.FlutterView view, RenderView? existing, ControlKeyboard keyboard = const HardwareKeyboardInput()}) {
  root.keyboard = keyboard;
  final binding = RendererBinding.instance;
  // The view's render view, when the binding made one already (and no
  // widget holds it): the root becomes its child.
  existing ??= binding.renderViews.where((v) => v.flutterView.viewId == view.viewId && v.child == null).firstOrNull;
  if (existing != null) {
    PipelineOwner? made;
    if (existing.owner == null) {
      made = PipelineOwner(onSemanticsUpdate: existing.updateSemantics)..rootNode = existing;
      binding.rootPipelineOwner.adoptChild(made);
      existing.prepareInitialFrame();
    }
    final previous = existing.child;
    existing.child = root;
    binding.scheduleFrame();
    return RootAttachment._(root, existing, made, false, previous);
  }
  final renderView = RenderView(view: view, child: root);
  final owner = PipelineOwner(onSemanticsUpdate: renderView.updateSemantics)..rootNode = renderView;
  binding.rootPipelineOwner.adoptChild(owner);
  binding.addRenderView(renderView);
  renderView.prepareInitialFrame();
  binding.scheduleFrame();
  return RootAttachment._(root, renderView, owner, true);
}
