// The route a dialog or sheet is presented in: a centered dialog, a bottom
// sheet or a side sheet; and [ModalFocus], the keyboard's hold on whatever a
// modal route shows.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' show Breakpoints, CanvasProps, ModalPresentation;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../render/controls/focus.dart';
import '../../render/controls/kit.dart' show firstTextUnder;
import '../../render/node_view.dart';

/// The width below which an adaptive modal with no breakpoint of its own is
/// a bottom sheet: the project's second breakpoint's min width (a sheet on
/// the narrowest breakpoint only; never with one breakpoint). DESIGN.md §5.3.
double defaultSheetBelowWidth(Breakpoints breakpoints) => breakpoints.length > 1 ? breakpoints.list[1].minWidth : 0;

/// [presentation] for a screen [width] wide: adaptive is a bottom sheet
/// below [sheetBelowWidth] (the min width of the breakpoint it switches at;
/// `OpenModalAction.sheetBelowWidthIn`), a dialog otherwise. An unknown
/// width is a dialog.
ModalPresentation resolvePresentation(ModalPresentation presentation, double? width, {required double sheetBelowWidth}) =>
    presentation == ModalPresentation.adaptive
        ? (width != null && width < sheetBelowWidth ? ModalPresentation.bottomSheet : ModalPresentation.dialog)
        : presentation;

/// Presents [builder]'s content as [presentation] says, with a barrier that
/// [barrierDismissible] lets the user tap to close it.
class PresentationRoute<T> extends PopupRoute<T> {
  PresentationRoute({
    required ModalPresentation presentation,
    required this.builder,
    required BuildContext context,
    this.sheetWidth,
    this.sheetMargin = 0,
    this.cornerRadius,
    this.maxHeightFactor = 1,
    this.insets = EdgeInsets.zero,
    this.showDragHandle = false,
    this.barrierDismissible = true,
    this.barrierColor = Colors.black54,
    this.barrierBlur = 0,
    this.enterScale = 0.96,
    double sheetBelowWidth = 0,
    super.settings,
  })  : presentation = resolvePresentation(presentation, MediaQuery.maybeSizeOf(context)?.width, sheetBelowWidth: sheetBelowWidth),
        _barrierLabel = MaterialLocalizations.of(context).modalBarrierDismissLabel,
        _themes = InheritedTheme.capture(from: context, to: Navigator.of(context).context);

  static const enterDuration = Duration(milliseconds: 320);
  static const exitDuration = Duration(milliseconds: 200);
  static const double defaultSheetWidth = 400;
  static const double bottomSheetRadius = 10;
  static const Size dragHandleSize = Size(40, 4);
  static const double dragHandleTop = 8;
  static const Color dragHandleColor = Color(0xFFA9ADA5);

  final ModalPresentation presentation;
  final WidgetBuilder builder;

  /// Width of a side sheet (null: [defaultSheetWidth]); maximum width of
  /// a bottom sheet (null: the screen width). Both stay within the screen.
  final double? sheetWidth;

  /// A bottom sheet narrower than the screen (a tablet, a desktop) floats
  /// this far above the bottom with all its corners rounded; a phone's
  /// full-width sheet stays docked to the bottom edge.
  final double sheetMargin;

  /// Radius of a bottom sheet's top corners. Null preserves
  /// [bottomSheetRadius]; other presentations keep their own shape.
  final double? cornerRadius;

  /// The most of the screen's height a bottom sheet takes.
  final double maxHeightFactor;

  /// Inset of a side sheet from the screen's edges.
  final EdgeInsets insets;
  final bool showDragHandle;

  /// The page behind a dialog blurs up to this (a Gaussian sigma).
  final double barrierBlur;

  /// The scale a dialog grows from.
  final double enterScale;

  final CapturedThemes? _themes;

  @override
  final bool barrierDismissible;

  @override
  final Color? barrierColor;

  final String _barrierLabel;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => enterDuration;

  @override
  Duration get reverseTransitionDuration => exitDuration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final page = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: switch (presentation) {
        ModalPresentation.bottomSheet || ModalPresentation.adaptive => _BottomSheet(
            width: sheetWidth,
            margin: sheetMargin,
            cornerRadius: cornerRadius ?? bottomSheetRadius,
            maxHeightFactor: maxHeightFactor,
            showDragHandle: showDragHandle,
            builder: builder,
          ),
        ModalPresentation.sideSheet => _SideSheet(width: sheetWidth ?? defaultSheetWidth, insets: insets, builder: builder),
        _ => SafeArea(child: Center(child: Builder(builder: builder))),
      },
    );
    return _themes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    switch (presentation) {
      case ModalPresentation.bottomSheet || ModalPresentation.adaptive:
        return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved), child: child);
      case ModalPresentation.sideSheet:
        return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved), child: child);
      default:
        Widget dialog = FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween<double>(begin: enterScale, end: 1).animate(curved), child: child),
        );
        if (barrierBlur > 0) {
          dialog = AnimatedBuilder(
            animation: curved,
            child: dialog,
            builder: (context, child) {
              final sigma = barrierBlur * curved.value;
              return BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: child);
            },
          );
        }
        return dialog;
    }
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({this.width, this.margin = 0, required this.cornerRadius, required this.maxHeightFactor, required this.showDragHandle, required this.builder});

  final double? width;
  final double margin;
  final double cornerRadius;
  final double maxHeightFactor;
  final bool showDragHandle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The keyboard pushes the sheet up.
    final keyboard = media.viewInsets.bottom;
    final sheetWidth = math.min(width ?? media.size.width, media.size.width);
    // Narrower than the screen: it floats [margin] above the bottom, every
    // corner rounded.
    final floating = margin > 0 && sheetWidth < media.size.width;
    final maxHeight = math.max(0.0, media.size.height - keyboard - (floating ? margin : 0)) * maxHeightFactor.clamp(0, 1);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard + (floating ? margin : 0)),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: sheetWidth, maxHeight: maxHeight),
          child: ClipRRect(
            key: const ValueKey('Codelessly bottom sheet'),
            borderRadius: floating ? BorderRadius.circular(cornerRadius) : BorderRadius.vertical(top: Radius.circular(cornerRadius)),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: Stack(
                  children: [
                    Builder(builder: builder),
                    if (showDragHandle)
                      const Positioned(
                        top: PresentationRoute.dragHandleTop,
                        left: 0,
                        right: 0,
                        child: Center(child: _DragHandle()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('Codelessly sheet drag handle'),
        width: PresentationRoute.dragHandleSize.width,
        height: PresentationRoute.dragHandleSize.height,
        decoration: BoxDecoration(color: PresentationRoute.dragHandleColor, borderRadius: BorderRadius.circular(2)),
      );
}

class _SideSheet extends StatelessWidget {
  const _SideSheet({required this.width, required this.insets, required this.builder});

  final double width;
  final EdgeInsets insets;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Padding(
      padding: insets,
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          key: const ValueKey('Codelessly side sheet'),
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(-4, 0))],
          ),
          child: SizedBox(
            width: math.min(width, math.max(0, screen.width - insets.horizontal)),
            height: math.max(0, screen.height - insets.vertical),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}

// --- the keyboard in a modal overlay ---------------------------------------------
//
// Every dialog, sheet, side sheet, popover,
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
