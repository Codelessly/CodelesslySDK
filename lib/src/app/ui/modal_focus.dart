// The keyboard in a modal overlay: every dialog, sheet, side sheet, popover,
// menu and full-screen cover the runtime opens (an openModal action's
// screen, the built-in confirm, a presented layout) is wrapped in a
// [ModalFocus], which gives it what a web dialog has:
//
// - the focus moves into it as it opens: onto its first focusable when the
//   keyboard opened it (in a group of items, a menu, the selected one),
//   else onto the overlay itself, nothing focused and no ring, until a key
//   is pressed;
// - Tab and Shift+Tab stay inside it while it is the top overlay;
// - Escape closes the top overlay, unless the document blocks dismissal
//   (`barrierDismissible: false` on the action; a canvas whose `blockBack`
//   holds keeps it open and runs its `backPressed` reactions instead);
// - closing it gives the focus back to the control that opened it, and
//   nested overlays unwind to the nearest opener still on screen;
// - assistive technology hears its name as it opens: the canvas's
//   `semanticLabel`, else for a popover the label of what opened it, else
//   the first text it shows.
//
// The mechanism is the controls' own (render/controls/focus.dart's
// ControlFocusLayer); this is its widget host.
import 'package:codelessly_api/core.dart' show CanvasProps;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../render/controls/focus.dart';
import '../../render/controls/kit.dart' show firstTextUnder;
import '../../render/node_view.dart';

/// Wraps the content of a modal route: see the head of this file.
class ModalFocus extends StatefulWidget {
  const ModalFocus({super.key, required this.child, this.dismissible = true, this.popover = false, this.label});

  final Widget child;

  /// Whether Escape closes it (the action's `barrierDismissible`).
  final bool dismissible;

  /// A popover (a menu, a bubble by its button): named after what opened
  /// it when its canvas gives no name.
  final bool popover;

  /// Its name for assistive technology; null: worked out from its content.
  final String? label;

  /// The overlay [context] is in; null outside one.
  static ControlFocusLayer? layerOf(BuildContext context) => ControlFocusLayerScope.maybeOf(context);

  @override
  State<ModalFocus> createState() => _ModalFocusState();
}

class _ModalFocusState extends State<ModalFocus> {
  late final ControlFocusLayer _layer;
  final FocusManagerKeyboard _keys = FocusManagerKeyboard();
  ModalRoute<Object?>? _route;
  String? _name;
  int _naming = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _layer = ControlFocusLayer(onDismiss: _dismiss, isCurrent: () => _route?.isCurrent ?? true)..open();
    _keys.attach(_onKey);
    _scheduleNaming();
    // An overlay of the host's own widgets (the built-in confirm) opened
    // from the keyboard: Flutter's focus goes to its first button.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_layer.isOpen || !_layer.usedKeyboard || _layer.hasScopes) return;
      final scope = FocusScope.of(context);
      if (scope.focusedChild == null) scope.nextFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _route = route;
    // It lets go as it starts to leave, not when its exit has played.
    route?.popped.whenComplete(() {
      if (identical(_route, route)) _layer.close();
    });
  }

  @override
  void dispose() {
    _keys.detach(_onKey);
    _layer.close();
    super.dispose();
  }

  // Escape while nothing of the overlay has the focus (a control that has
  // it is asked first: an open dropdown closes itself, and its scope then
  // asks the layer).
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!identical(ControlFocusLayer.top, _layer) || _layer.hasFocus) return false;
    return _layer.dismiss();
  }

  bool _dismiss() {
    if (!widget.dismissible || !mounted) return false;
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isCurrent) return false;
    if (_dismissing) return true;
    _dismissing = true;
    // As the back button: a canvas that blocks back stays and is told.
    navigator.maybePop().whenComplete(() => _dismissing = false);
    return true;
  }

  // --- its name ----------------------------------------------------------------

  void _scheduleNaming() {
    if (widget.label != null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = _findName();
      if (name != null && name != _name) {
        setState(() => _name = name);
        return;
      }
      // Its screen may still be loading: look again for a while.
      if (name == null && _naming++ < 30) _scheduleNaming();
    });
  }

  String? _findName() {
    final root = context.findRenderObject();
    if (root == null) return null;
    RenderNodeView? view;
    void visit(RenderObject o) {
      if (view != null) return;
      if (o is RenderNodeView) {
        view = o;
        return;
      }
      o.visitChildren(visit);
    }

    visit(root);
    final v = view;
    final id = v?.rootId;
    if (v != null && id != null) {
      final canvas = v.tree?.resolve(id);
      if (canvas != null && canvas.type == CanvasProps.spec.type) {
        final given = canvas.props.get(CanvasProps.semanticLabel).trim();
        if (given.isNotEmpty) return given;
      }
    }
    if (widget.popover) {
      final opener = _layer.openerLabel?.trim();
      if (opener != null && opener.isNotEmpty) return _short(opener);
    }
    final text = firstTextUnder(root);
    return text == null ? null : _short(text);
  }

  static String _short(String s) {
    final line = s.split('\n').first.trim();
    return line.length <= 80 ? line : '${line.substring(0, 79)}…';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.label ?? _name;
    final named = name != null && name.isNotEmpty;
    return Semantics(
      scopesRoute: named ? true : null,
      namesRoute: named ? true : null,
      label: named ? name : null,
      explicitChildNodes: true,
      child: ControlFocusLayerScope(layer: _layer, child: widget.child),
    );
  }
}
