// What actions show and where they go: screens, modals, toasts, confirm
// dialogs, file pickers. Handlers never hold a BuildContext; they ask an
// [ActionUi], which the app shell implements (or [NavigatorActionUi], a
// Navigator-based default any NodeView can use).
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show
        CloseModalAction,
        ConfirmAction,
        Json,
        ModalPresentation,
        NavigateAction,
        OpenModalAction,
        RouteTransition,
        ShowToastAction;
import 'package:flutter/material.dart' hide NavigationMode;
import 'package:codelessly_api/core.dart' show NavigationMode;

import '../../app/viewport.dart' show CanvasSizing, CanvasSizingScope;
import 'confirm_dialog.dart';
import 'feedback_theme.dart';
import 'presentation_route.dart';
import 'presentation_scope.dart';
import 'route_transition.dart';
import 'toast.dart';

/// What a confirm dialog answered: whether the user confirmed, and what a
/// screen used as the dialog gave back (its close modal action's result).
@immutable
class ConfirmOutcome {
  const ConfirmOutcome(this.confirmed, [this.values]);

  final bool confirmed;
  final Object? values;
}

/// A file the user picked for an upload.
@immutable
class PickedFile {
  const PickedFile({required this.name, required this.bytes, this.contentType});

  final String name;
  final Uint8List bytes;
  final String? contentType;
}

/// The site's light or dark choice (`setThemeMode`), implemented by a UI
/// that shows a project's screens: every screen of the project redraws in
/// [mode] at once. Without one (a headless runtime) the action does nothing.
abstract interface class ThemeModeUi {
  /// Sets the project's theme mode; with [persist] it is kept in local
  /// storage for the next visit.
  void setThemeMode(api.ThemeMode mode, {bool persist = true});
}

/// The UI effects of actions, implemented by the app shell.
abstract interface class ActionUi {
  /// Moves between screens as [action] says ([NavigateAction.mode]), with
  /// its params and base params evaluated.
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}});

  /// Shows screen [OpenModalAction.to] as a modal; completes with what
  /// closed it (a [CloseModalAction]'s result), null when dismissed.
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}});

  /// Closes the modal the action runs in with [result]; false when it
  /// doesn't run in one.
  bool closeModal(Object? result);

  /// Shows a toast. [onAction] runs when its button ([actionLabel]) is
  /// pressed. Text and [bound] (the action's `variables` and the look's
  /// `offset`, evaluated) are read where the action ran.
  void showToast(ShowToastAction action,
      {required String message,
      String title = '',
      String actionLabel = '',
      Map<String, Object?> bound = const {},
      VoidCallback? onAction});

  /// Asks to confirm; text, [params] and [bound] (the action's `variables`)
  /// evaluated.
  Future<ConfirmOutcome> confirm(ConfirmAction action,
      {required String title,
      String message = '',
      String caption = '',
      String confirmLabel = 'OK',
      String cancelLabel = 'Cancel',
      Map<String, Object?> bound = const {},
      Json params = const {}});

  /// Lets the user pick files for an upload (none: canceled).
  Future<List<PickedFile>> pickFiles({bool images = true, bool multiple = true});
}

/// An [ActionUi] that shows nothing and goes nowhere (a headless runtime,
/// a design canvas).
class NoActionUi implements ActionUi {
  const NoActionUi();

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async {}

  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) async => null;

  @override
  bool closeModal(Object? result) => false;

  @override
  void showToast(ShowToastAction action,
      {required String message,
      String title = '',
      String actionLabel = '',
      Map<String, Object?> bound = const {},
      VoidCallback? onAction}) {}

  @override
  Future<ConfirmOutcome> confirm(ConfirmAction action,
          {required String title,
          String message = '',
          String caption = '',
          String confirmLabel = 'OK',
          String cancelLabel = 'Cancel',
          Map<String, Object?> bound = const {},
          Json params = const {}}) async =>
      const ConfirmOutcome(false);

  @override
  Future<List<PickedFile>> pickFiles({bool images = true, bool multiple = true}) async => const [];
}

/// Builds the route that shows screen [destination] (a canvas or layout id)
/// opened with [params]; null for a screen that doesn't exist.
typedef ScreenRouteBuilder = Route<Object?>? Function(String destination, Json params);

/// Builds the widget showing screen [destination] in a modal; null for a
/// screen that doesn't exist.
typedef ScreenBuilder = Widget? Function(String destination, Json params);

/// An [ActionUi] on the nearest [Navigator] of [context]: navigation pushes
/// [route]s, modals show [modal] screens as Material dialogs and sheets,
/// toasts are snack bars, confirms an [AlertDialog] (or the screen they name).
///
/// [context] gives the context the actions run near (a NodeView's, a
/// screen's); it's read when an action runs, so it can be any later one.
class NavigatorActionUi implements ActionUi {
  NavigatorActionUi({required this.context, this.route, this.modal, this.sheetModal, this.files, this.breakpoints});

  final BuildContext? Function() context;

  /// The project's breakpoints (per-breakpoint toast looks); null: the
  /// defaults.
  final api.Breakpoints? Function()? breakpoints;

  /// The project's breakpoints now ([breakpoints], else the defaults).
  api.Breakpoints get _breakpoints => breakpoints?.call() ?? api.Breakpoints.defaults;
  final ScreenRouteBuilder? route;
  final ScreenBuilder? modal;

  /// A modal screen shown as a bottom sheet: as wide as the sheet (a dialog
  /// keeps its design width). Null: [modal].
  final ScreenBuilder? sheetModal;

  /// Picks files for uploads; none by default.
  final Future<List<PickedFile>> Function({bool images, bool multiple})? files;

  BuildContext? get _context {
    final c = context();
    return c != null && c.mounted ? c : null;
  }

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async {
    final c = _context;
    final navigator = c == null ? null : Navigator.maybeOf(c);
    if (navigator == null) return;
    var mode = action.mode;
    if (mode == NavigationMode.pop) {
      if (navigator.canPop()) {
        navigator.pop(params.isEmpty ? null : params);
        return;
      }
      if (action.to.isEmpty) return;
      mode = NavigationMode.replace;
    }
    final next = route?.call(action.to, params);
    if (next == null) return;
    switch (mode) {
      case NavigationMode.push:
        await navigator.push(next);
      case NavigationMode.replace || NavigationMode.pop:
        unawaited(navigator.pushReplacement(next));
      case NavigationMode.reset:
        final base = action.base.isEmpty ? null : route?.call(action.base, baseParams);
        unawaited(navigator.pushAndRemoveUntil(base ?? next, (_) => false));
        if (base != null) unawaited(navigator.push(next));
    }
  }

  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) async {
    final c = _context;
    if (c == null) return null;
    final sheetBelowWidth = action.sheetBelowWidthIn(_breakpoints);
    final width = MediaQuery.maybeSizeOf(c)?.width;
    final sheet = action.presentation == ModalPresentation.bottomSheet ||
        (action.presentation == ModalPresentation.adaptive && (width == null || width < sheetBelowWidth));
    final content = ((sheet ? sheetModal : null) ?? modal)?.call(action.to, params);
    if (content == null) return null;
    // Preserve inherited localizations and themes across both modal routes.
    final inherited = InheritedTheme.captureAll(c, Localizations.override(context: c, child: content));
    // Insets keep space around a dialog; a bottom sheet sits on the screen's
    // edge (an adaptive modal used both ways keeps its sheet flush).
    final modalContent = sheet
        ? inherited
        : Padding(
            padding: EdgeInsets.fromLTRB(action.insets[0], action.insets[1], action.insets[2], action.insets[3]),
            child: inherited,
          );
    final pointer = RevealAnchor.lastTap == null ? null : RevealAnchor.lastTap! & Size.zero;
    final anchor = switch (action.anchor) {
      api.ModalAnchor.trigger => RevealAnchor.lastTrigger,
      api.ModalAnchor.pointer => pointer,
      api.ModalAnchor.node => RevealAnchor.named,
      // A popover sits by the node that opened it (or the pointer) even
      // when no anchor is named.
      api.ModalAnchor.none => action.presentation == ModalPresentation.popover ? RevealAnchor.lastTrigger ?? pointer : null,
    };
    // A popover: by the node that opened it, or the pointer.
    if (anchor != null &&
        action.routeTransition == null &&
        !sheet &&
        (action.presentation == ModalPresentation.popover ||
            action.presentation == ModalPresentation.dialog ||
            action.presentation == ModalPresentation.adaptive)) {
      return showAnchoredModal(c, modalContent,
          anchor: anchor,
          placement: action.placement,
          gap: action.anchorGap,
          offset: action.anchorOffset,
          reserve: action.anchorReserve,
          barrierDismissible: action.barrierDismissible,
          barrierColor: action.barrierColor);
    }
    return showScreenModal(c, modalContent,

        presentation: action.presentation,
        barrierDismissible: action.barrierDismissible,
        barrierColor: action.barrierColor,
        showDragHandle: action.showDragHandle,
        alignment: Alignment(action.alignment[0], action.alignment[1]),
        sheetWidth: action.sheetWidth,
        sheetRadius: action.sheetRadius,
        maxHeightFactor: action.maxHeightFactor == 1 ? null : action.maxHeightFactor,
        barrierBlur: action.barrierBlur,
        enterScale: action.enterScale,
        sheetBelowWidth: sheetBelowWidth,
        cover: action.cover,
        routeTransition: action.routeTransition);
  }

  @override
  bool closeModal(Object? result) {
    final c = _context;
    if (c == null) return false;
    // A presented banner or full-screen layout closes the way it was shown.
    if (CodelesslyPresentation.maybeOf(c)?.close case final close?) {
      close(result);
      return true;
    }
    final route = ModalRoute.of(c);
    final modal = route is PopupRoute || (route is CodelesslyRouteTransitionRoute && route.modal);
    if (route == null || !modal || !route.isCurrent) return false;
    Navigator.of(c).pop(result);
    return true;
  }

  @override
  void showToast(ShowToastAction action,
      {required String message,
      String title = '',
      String actionLabel = '',
      Map<String, Object?> bound = const {},
      VoidCallback? onAction}) {
    final c = _context;
    if (c == null) return;
    CodelesslyToast.show(
      c,
      ToastRequest(action,
          message: message,
          title: title,
          actionLabel: actionLabel,
          bound: bound,
          onAction: onAction,
          breakpoints: breakpoints?.call()),
    );
  }

  @override
  Future<ConfirmOutcome> confirm(ConfirmAction action,
      {required String title,
      String message = '',
      String caption = '',
      String confirmLabel = 'OK',
      String cancelLabel = 'Cancel',
      Map<String, Object?> bound = const {},
      Json params = const {}}) async {
    final c = _context;
    if (c == null) return const ConfirmOutcome(false);
    final request = ConfirmRequest(
      action,
      title: title,
      caption: caption,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      bound: bound,
      params: params,
    );
    if (action.dialog.isNotEmpty) {
      final content = modal?.call(action.dialog, request.dialogParams);
      if (content != null) {
        final look = Look(action.style);
        final barrier = colorValue(bound['barrierColor']) ?? look.color('barrierColor');
        final result = await showScreenModal(
          c,
          content,
          presentation: action.presentation,
          barrierDismissible: action.barrierDismissible,
          barrierColor: barrier == null ? null : api.Color(barrier.toARGB32()),
          showDragHandle: look.flag('showDragHandle'),
          sheetBelowWidth: defaultSheetBelowWidth(_breakpoints),
          sheetWidth: look.number('sheetWidth'),
          sheetMargin: look.numberOr('sheetMargin', 0),
          maxHeightFactor: look.number('maxHeightFactor'),
          barrierBlur: look.numberOr('barrierBlur', 0),
          enterScale: look.numberOr('enterScale', 1),
        );
        return ConfirmOutcome(isConfirmResult(result), confirmValues(result));
      }
      debugPrint('Confirm dialog screen [${action.dialog}] was not found. Showing the built-in dialog.');
    }
    return ConfirmOutcome(await showConfirmDialog(c, request, sheetBelowWidth: defaultSheetBelowWidth(_breakpoints)));
  }

  @override
  Future<List<PickedFile>> pickFiles({bool images = true, bool multiple = true}) =>
      files?.call(images: images, multiple: multiple) ?? Future.value(const []);
}

/// Shows [content] (a screen) over [context]'s navigator as [presentation]
/// says; completes with what popped it. With [routeTransition] it opens in
/// a page route playing that transition (the screen behind can move, a
/// drag can dismiss it), placed as [presentation] says.
Future<Object?> showScreenModal(
  BuildContext context,
  Widget content, {
  ModalPresentation presentation = ModalPresentation.dialog,
  bool barrierDismissible = true,
  api.Color? barrierColor,
  bool showDragHandle = false,
  Alignment alignment = Alignment.center,
  required double sheetBelowWidth,
  RouteTransition? routeTransition,
  double? sheetWidth,
  double sheetMargin = 0,
  double? sheetRadius,
  double? maxHeightFactor,
  double barrierBlur = 0,
  double enterScale = 1,
  bool cover = false,
}) {
  final scrim = barrierColor == null ? null : Color(barrierColor.value);
  // A toast on screen goes under the modal's barrier.
  content = ToastBelowRoute(child: content);
  final width = MediaQuery.maybeSizeOf(context)?.width;
  final narrow = width == null || width < sheetBelowWidth;
  final sheet = presentation == ModalPresentation.bottomSheet || (presentation == ModalPresentation.adaptive && narrow);
  if (routeTransition != null) {
    final fullScreen = presentation == ModalPresentation.fullScreen;
    return Navigator.of(context).push<Object?>(CodelesslyRouteTransitionRoute<Object?>(
      modal: true,
      transition: routeTransition,
      anchor: RevealAnchor(tap: RevealAnchor.lastTap),
      dismissibleBarrier: barrierDismissible,
      fallbackBarrierColor: scrim ?? (fullScreen ? Colors.black : Colors.black54),
      builder: (_) {
        if (sheet) return Align(alignment: Alignment.bottomCenter, child: content);
        if (fullScreen) return content;
        return SafeArea(child: Align(alignment: alignment, child: Material(type: MaterialType.transparency, child: content)));
      },
    ));
  }
  // Side sheets, sized or rounded bottom sheets, sheets with a drag handle
  // and frosted or scaled dialogs. (Material's sheet put the handle above
  // the screen, on its transparent background: invisible over the scrim,
  // and a gap over the screen's own surface.)
  final presented = presentation == ModalPresentation.sideSheet ||
      (sheet && (maxHeightFactor != null || sheetRadius != null || showDragHandle || sheetMargin > 0)) ||
      (!sheet && presentation == ModalPresentation.dialog && (barrierBlur > 0 || enterScale != 1));
  if (presented) {
    return Navigator.of(context).push<Object?>(PresentationRoute<Object?>(
      context: context,
      presentation: sheet ? ModalPresentation.bottomSheet : presentation,
      barrierDismissible: barrierDismissible,
      barrierColor: scrim ?? Colors.black54,
      sheetWidth: sheetWidth,
      sheetMargin: sheetMargin,
      cornerRadius: sheetRadius,
      maxHeightFactor: maxHeightFactor ?? 1,
      showDragHandle: showDragHandle,
      barrierBlur: barrierBlur,
      enterScale: enterScale,
      builder: (_) => sheet || presentation == ModalPresentation.sideSheet
          ? content
          : Align(alignment: alignment, child: Material(type: MaterialType.transparency, child: content)),
    ));
  }
  if (sheet) {
    return showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      showDragHandle: showDragHandle,
      barrierColor: scrim,
      // The screen draws its own surface (its fills, radius and shadow): a
      // tinted Material sheet behind it showed above a screen whose content
      // sits at the bottom of its canvas.
      backgroundColor: Colors.transparent,
      elevation: 0,
      // The keyboard pushes the sheet up (a composer at its bottom).
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: content,
      ),
    );
  }
  if (presentation == ModalPresentation.fullScreen) {
    return Navigator.of(context).push<Object?>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => content));
  }
  if (cover && !sheet) {
    // Covers the screen: the screen it shows fills it, at the device size.
    return showDialog<Object?>(
      context: context,
      useRootNavigator: false,
      useSafeArea: false,
      barrierDismissible: barrierDismissible,
      barrierColor: scrim,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: CanvasSizingScope(sizing: CanvasSizing.fill, child: SizedBox.expand(child: content)),
      ),
    );
  }
  return showDialog<Object?>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: barrierDismissible,
    barrierColor: scrim,
    builder: (_) => Align(alignment: alignment, child: Material(type: MaterialType.transparency, child: content)),
  );
}

/// Shows [content] as a popover by [anchor] (a global rect: the node that
/// opened it, or the pointer as an empty rect) at [placement], [gap] away
/// from it and shifted [offset] along it.
/// It flips to the other side when it doesn't fit and stays on screen. Below
/// its anchor with a [reserve], it doesn't flip: it keeps that much room
/// under its top, moving up when that would pass the screen's bottom margin
/// (a menu that may grow keeps its place; a tall card overlaps its anchor).
Future<Object?> showAnchoredModal(
  BuildContext context,
  Widget content, {
  required Rect anchor,
  api.PopoverPlacement placement = api.PopoverPlacement.belowStart,
  double gap = 4,
  double offset = 0,
  double reserve = 0,
  bool barrierDismissible = true,
  api.Color? barrierColor,
}) {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay?.context.findRenderObject();
  final local = overlay is RenderBox && overlay.attached
      ? Rect.fromPoints(overlay.globalToLocal(anchor.topLeft), overlay.globalToLocal(anchor.bottomRight))
      : anchor;
  return showDialog<Object?>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor == null ? Colors.transparent : Color(barrierColor.value),
    useSafeArea: false,
    builder: (_) => CustomSingleChildLayout(
      delegate: PopoverLayout(anchor: local, placement: placement, gap: gap, offset: offset, reserve: reserve),
      child: Material(type: MaterialType.transparency, child: content),
    ),
  );
}

/// Lays a popover out by its anchor (see [showAnchoredModal]).
class PopoverLayout extends SingleChildLayoutDelegate {
  PopoverLayout(
      {required this.anchor, required this.placement, this.gap = 4, this.offset = 0, this.margin = 8, this.reserve = 0});

  final Rect anchor;
  final api.PopoverPlacement placement;
  final double gap, offset, margin;

  /// Room kept under the popover's top when it opens below its anchor
  /// (`OpenModalAction.anchorReserve`).
  final double reserve;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(EdgeInsets.all(margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final name = placement.name;
    final vertical = name.startsWith('below') || name.startsWith('above');
    final side = name.startsWith('below')
        ? 'below'
        : name.startsWith('above')
            ? 'above'
            : name.startsWith('right')
                ? 'right'
                : name.startsWith('left')
                    ? 'left'
                    : 'center';
    final along = name.endsWith('Start')
        ? -1
        : name.endsWith('End')
            ? 1
            : 0;
    double x, y;
    if (side == 'center') {
      x = anchor.center.dx - childSize.width / 2;
      y = anchor.center.dy - childSize.height / 2;
    } else if (vertical) {
      // Below unless it only fits above (and the other way round).
      var below = side == 'below';
      final roomBelow = size.height - margin - (anchor.bottom + gap);
      final roomAbove = anchor.top - gap - margin;
      // A popover that reserves room stays below and moves up instead.
      final flips = !(below && reserve > 0);
      if (flips && below && childSize.height > roomBelow && roomAbove > roomBelow) below = false;
      if (flips && !below && childSize.height > roomAbove && roomBelow > roomAbove) below = true;
      y = below ? anchor.bottom + gap : anchor.top - gap - childSize.height;
      if (below && reserve > 0 && y + reserve > size.height - margin) {
        y = math.max(margin, size.height - margin - reserve);
      }
      x = switch (along) {
        -1 => anchor.left + offset,
        1 => anchor.right - childSize.width - offset,
        _ => anchor.center.dx - childSize.width / 2 + offset,
      };
    } else {
      var right = side == 'right';
      final roomRight = size.width - margin - (anchor.right + gap);
      final roomLeft = anchor.left - gap - margin;
      if (right && childSize.width > roomRight && roomLeft > roomRight) right = false;
      if (!right && childSize.width > roomLeft && roomRight > roomLeft) right = true;
      x = right ? anchor.right + gap : anchor.left - gap - childSize.width;
      y = switch (along) {
        -1 => anchor.top + offset,
        1 => anchor.bottom - childSize.height - offset,
        _ => anchor.center.dy - childSize.height / 2 + offset,
      };
    }
    double clampTo(double v, double extent, double total) =>
        v.clamp(margin, (total - margin - extent).clamp(margin, double.infinity)).toDouble();
    return Offset(clampTo(x, childSize.width, size.width), clampTo(y, childSize.height, size.height));
  }

  @override
  bool shouldRelayout(PopoverLayout old) =>
      old.anchor != anchor ||
      old.placement != placement ||
      old.gap != gap ||
      old.offset != offset ||
      old.margin != margin ||
      old.reserve != reserve;
}

