import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/widgets.dart';

import 'controls/buttons.dart';
import 'controls/focus.dart';
import 'controls/root.dart';
import 'controls/slider.dart';
import 'controls/spinner.dart';
import 'controls/tokens.dart';
import 'islands.dart';
import 'labels.dart';
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
    return RenderNodeView(tree, rootId, keyboard: interactive ? FocusManagerKeyboard() : null)
      ..focus.layer = interactive ? ControlFocusLayerScope.maybeOf(context) : null;
  }

  @override
  void updateRenderObject(BuildContext context, RenderNodeView renderObject) {
    _configure(context);
    renderObject.setRoot(tree, rootId);
    renderObject.focus.layer = interactive ? ControlFocusLayerScope.maybeOf(context) : null;
    if (interactive != (renderObject.keyboard != null)) renderObject.keyboard = interactive ? FocusManagerKeyboard() : null;
  }
}

/// The modal overlay (a dialog, a sheet, a popover) the screens under it are
/// shown in: each [NodeView] below puts its focus scope in [layer], so the
/// keyboard stays in the overlay while it is the top one
/// (render/controls/focus.dart's [ControlFocusLayer]). The host that opens
/// the overlay's route puts it there (ModalFocus, app/ui/presentation_route.dart).
class ControlFocusLayerScope extends InheritedWidget {
  const ControlFocusLayerScope({super.key, required this.layer, required super.child});

  final ControlFocusLayer layer;

  /// The overlay [context] is shown in; null: none (a page).
  static ControlFocusLayer? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ControlFocusLayerScope>()?.layer;

  @override
  bool updateShouldNotify(ControlFocusLayerScope oldWidget) => !identical(oldWidget.layer, layer);
}

/// The words a screen reader hears for the runtime's own chrome under it
/// ([CodelesslyLabels]): a layout's host puts the project's there.
class CodelesslyLabelsScope extends InheritedWidget {
  const CodelesslyLabelsScope({super.key, required this.labels, required super.child});

  final CodelesslyLabels labels;

  /// The labels at [context]: the nearest scope's, else English.
  static CodelesslyLabels of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CodelesslyLabelsScope>()?.labels ?? const CodelesslyLabels();

  @override
  bool updateShouldNotify(CodelesslyLabelsScope oldWidget) => labels != oldWidget.labels;
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

  /// The tree it shows, and the node of it that is its root.
  RenderTree? get tree => _tree;
  String? get rootId => _rootId;

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

/// The SDK's spinner ([RenderSpinner]) where the surroundings are still
/// widgets (a loading screen, a list's loading footer, a player getting
/// ready): an arc in [color] turning in a square of [diameter], or of the
/// size it is given.
class SpinnerView extends LeafRenderObjectWidget {
  const SpinnerView({super.key, required this.color, this.diameter = 36, this.strokeWidth = 4, this.value});

  final Color color;
  final double diameter;
  final double strokeWidth;

  /// The part of the ring that is drawn, from the top (0–1), standing
  /// still; null: the arc turns.
  final double? value;

  @override
  RenderSpinner createRenderObject(BuildContext context) => RenderSpinner()
    ..color = color
    ..diameter = diameter
    ..strokeWidth = strokeWidth
    ..strokeAlign = 0
    ..strokeCap = StrokeCap.square
    ..value = value
    ..animating = TickerMode.valuesOf(context).enabled;

  @override
  void updateRenderObject(BuildContext context, RenderSpinner renderObject) => renderObject
    ..color = color
    ..diameter = diameter
    ..strokeWidth = strokeWidth
    ..value = value
    ..animating = TickerMode.valuesOf(context).enabled;
}

/// A root for the SDK's controls where the surroundings are widgets and no
/// [NodeView] is above them (a toast in the app's overlay, the confirm
/// dialog in its route): the controls under it ([ControlButton],
/// [ControlSlider]) share its focus order and take keys as a screen's do.
/// Inside a modal route it joins the route's [ControlFocusLayerScope], so
/// the keyboard stays in the dialog.
class ControlHost extends SingleChildRenderObjectWidget {
  const ControlHost({super.key, required super.child});

  @override
  RenderControlRoot createRenderObject(BuildContext context) {
    final keyboard = FocusManagerKeyboard();
    final root = RenderControlRoot(keyboard: keyboard);
    keyboard.scope = root.focus;
    return root..focus.layer = ControlFocusLayerScope.maybeOf(context);
  }

  @override
  void updateRenderObject(BuildContext context, RenderControlRoot renderObject) =>
      renderObject.focus.layer = ControlFocusLayerScope.maybeOf(context);
}

/// One of the SDK's buttons ([RenderButton]) as a widget: [spec] is what it
/// shows, [onPressed] what a press does (null: it draws and takes no press).
/// It needs a root above it: a [NodeView] (a list's row, a player) or a
/// [ControlHost].
class ControlButton extends LeafRenderObjectWidget {
  const ControlButton({
    super.key,
    required this.spec,
    this.onPressed,
    this.semanticsLabel,
    this.focusWhenShown = false,
    this.interactive = true,
    this.focusable = true,
  });

  final ButtonSpec spec;
  final VoidCallback? onPressed;

  /// What a screen reader says (else the label).
  final String? semanticsLabel;

  /// Whether the focus starts on it when it is first shown (a dialog's
  /// default answer: Enter presses it). It shows as focused only when the
  /// keyboard is what the user is on.
  final bool focusWhenShown;

  /// Whether it takes pointers and the focus; else it only draws (a
  /// player's button on a design canvas).
  final bool interactive;

  /// Whether Tab stops on it (false: what is around it is the stop, and
  /// presses it).
  final bool focusable;

  @override
  RenderButton createRenderObject(BuildContext context) {
    final button = RenderButton().._apply(this, context);
    if (focusWhenShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!button.attached) return;
        final keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional ||
            (button.focusNode.scope?.layer?.usedKeyboard ?? false);
        button.focusNode.requestFocus(highlight: keyboard);
      });
    }
    return button;
  }

  @override
  void updateRenderObject(BuildContext context, RenderButton renderObject) => renderObject._apply(this, context);
}

extension on RenderButton {
  void _apply(ControlButton w, BuildContext context) {
    this
      ..interactive = w.interactive
      ..spec = w.spec
      ..enabled = w.spec.enabled
      ..busy = w.spec.loading
      ..autofocus = w.spec.autofocus
      ..onPressed = w.onPressed
      ..semanticsLabel = w.semanticsLabel
      ..semanticsDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    focusNode.canRequestFocus = w.interactive && w.spec.enabled && w.focusable;
  }
}

/// The SDK's slider ([RenderSlider]) as a widget: [node] is a `slider`
/// node's props (its value, range, sizes and colors), [onChanged] is told
/// each value a drag, a tap or a key gives. [seekBar] draws a player's seek
/// bar ([RenderSeekBar]). Not [interactive], it draws and takes no input.
/// It needs a root above it, as [ControlButton] does.
class ControlSlider extends LeafRenderObjectWidget {
  const ControlSlider({
    super.key,
    required this.node,
    required this.tokens,
    this.onChanged,
    this.seekBar = false,
    this.seekColors,
    this.interactive = true,
    this.semanticsLabel,
  });

  final Node node;
  final ControlTokens tokens;
  final ValueChanged<double>? onChanged;
  final bool seekBar;

  /// A seek bar's played part, rail and thumb, over the node's colors.
  final ({Color active, Color rail, Color thumb})? seekColors;
  final bool interactive;
  final String? semanticsLabel;

  @override
  RenderSlider createRenderObject(BuildContext context) =>
      (seekBar ? RenderSeekBar() : RenderSlider()).._apply(this, context);

  @override
  void updateRenderObject(BuildContext context, RenderSlider renderObject) => renderObject._apply(this, context);
}

extension on RenderSlider {
  void _apply(ControlSlider w, BuildContext context) {
    this
      ..interactive = w.interactive
      ..configure(w.node, w.tokens, Size.zero)
      ..semanticsLabel = w.semanticsLabel
      ..onChanged = w.interactive ? w.onChanged : null;
    focusNode.canRequestFocus = w.interactive;
    if (this case final RenderSeekBar bar) bar.colors = w.seekColors;
  }
}
