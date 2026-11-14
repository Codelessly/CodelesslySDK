import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';

import 'controls/focus.dart';
import 'controls/root.dart';
import 'islands.dart';
import 'node_tree.dart';

/// Hosts the render tree of one node of a [RenderTree] (a screen, or any
/// node). No widget or element exists per node below it; its element owns
/// the islands (widget-built nodes) of the boxes it shows, so they live
/// under the app's element tree (see islands.dart).
///
/// It is the renderer's widget adapter: its render object is the root
/// ([RenderControlRoot]: the overlay layer and the controls' focus scope),
/// fed key events from `FocusManager`'s early handlers. Nothing above it is
/// needed: no `MaterialApp`, `WidgetsApp`, `Theme` or `Overlay`.
class NodeView extends RenderObjectWidget {
  const NodeView({super.key, required this.tree, required this.rootId, this.interactive = false});

  final RenderTree tree;
  final String rootId;

  /// Islands (inputs, embeds) take pointer input and focus: a running app.
  /// False on a design canvas.
  final bool interactive;

  @override
  IslandOwnerElement createElement() => IslandOwnerElement(this);

  void _configure(BuildContext context) {
    final visibility = TickerMode.getValuesNotifier(context);
    tree.runtimeVisibility = () => visibility.value.enabled;
    final env = tree.islands.environment;
    if (env.interactive != interactive) {
      tree.islands.environment = IslandEnvironment(interactive: interactive, wrap: env.wrap);
    }
  }

  @override
  RenderNodeView createRenderObject(BuildContext context) {
    _configure(context);
    return RenderNodeView(tree, rootId, keyboard: interactive ? FocusManagerKeyboard() : null);
  }

  @override
  void updateRenderObject(BuildContext context, RenderNodeView renderObject) {
    _configure(context);
    renderObject.setRoot(tree, rootId);
    if (interactive != (renderObject.keyboard != null)) renderObject.keyboard = interactive ? FocusManagerKeyboard() : null;
  }
}

/// Key events for a root from Flutter's `FocusManager` (its early handlers,
/// so a key a control handles never reaches Flutter's own traversal), and
/// the bridge between the two focuses: a control taking the focus unfocuses
/// the app's focused widget; the app focusing one of its widgets (an
/// island's text field) takes the focus from the controls.
class FocusManagerKeyboard implements ControlKeyboard {
  FocusManagerKeyboard();

  bool Function(KeyEvent event)? _handler;
  ControlFocusScope? scope;

  KeyEventResult _early(KeyEvent event) =>
      (_handler?.call(event) ?? false) ? KeyEventResult.handled : KeyEventResult.ignored;

  void _focusChanged() {
    if (hostHasFocus) scope?.hostTookFocus();
  }

  // FocusManager asks no handler while nothing has its focus: the keys
  // come from HardwareKeyboard then.
  bool _unfocused(KeyEvent event) => FocusManager.instance.primaryFocus == null && (_handler?.call(event) ?? false);

  @override
  void attach(bool Function(KeyEvent event) handler) {
    _handler = handler;
    FocusManager.instance.addEarlyKeyEventHandler(_early);
    FocusManager.instance.addListener(_focusChanged);
    HardwareKeyboard.instance.addHandler(_unfocused);
  }

  @override
  void detach(bool Function(KeyEvent event) handler) {
    FocusManager.instance.removeEarlyKeyEventHandler(_early);
    FocusManager.instance.removeListener(_focusChanged);
    HardwareKeyboard.instance.removeHandler(_unfocused);
    _handler = null;
  }

  @override
  bool get hostHasFocus {
    final f = FocusManager.instance.primaryFocus;
    return f != null && f is! FocusScopeNode;
  }

  @override
  void yieldHostFocus() {
    if (hostHasFocus) FocusManager.instance.primaryFocus?.unfocus();
  }
}

class RenderNodeView extends RenderControlRoot with RenderObjectWithLayoutCallbackMixin, IslandParent {
  RenderNodeView(RenderTree tree, String rootId, {super.keyboard}) {
    if (keyboard case final FocusManagerKeyboard k) k.scope = focus;
    setRoot(tree, rootId);
  }

  @override
  set keyboard(ControlKeyboard? value) {
    if (value case final FocusManagerKeyboard k) k.scope = focus;
    super.keyboard = value;
  }

  RenderTree? _tree;
  String? _rootId;

  void setRoot(RenderTree tree, String rootId) {
    if (identical(tree, _tree) && rootId == _rootId) return;
    final old = child;
    if (old is NodeBox) {
      child = null;
      old.tree.release(old);
    }
    _tree = tree;
    _rootId = rootId;
    final box = tree.obtain(rootId, tree.rootSlot(rootId));
    // Another view showed it (a view rebuilt elsewhere in the app): it's
    // this one's now.
    if (box.parent != null) box.detachFromParent();
    child = box;
  }

  /// The root box belongs to the tree, not to this view: let go of it.
  @override
  void dispose() {
    child = null;
    super.dispose();
  }
}
