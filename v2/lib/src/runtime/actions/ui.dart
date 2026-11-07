// What actions show and where they go: screens, modals, toasts, confirm
// dialogs, file pickers. Handlers never hold a BuildContext; they ask an
// [ActionUi], which the app shell implements (or [NavigatorActionUi], a
// Navigator-based default any NodeView can use).
import 'dart:async';
import 'dart:typed_data';

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart'
    show
        CloseModalAction,
        ConfirmAction,
        Json,
        ModalPresentation,
        NavigateAction,
        OpenModalAction,
        RouteTransition,
        ShowToastAction,
        ToastPosition,
        ToastStyle;
import 'package:flutter/material.dart' hide NavigationMode;
import 'package:codelessly_api_v2/codelessly_api.dart' show NavigationMode;

import 'route_transition.dart';

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

  /// Shows a toast. [onAction] runs when its button is pressed.
  void showToast(ShowToastAction action, {required String message, String title = '', VoidCallback? onAction});

  /// Asks to confirm; [title] and [message] evaluated.
  Future<ConfirmOutcome> confirm(ConfirmAction action, {required String title, String message = '', Json params = const {}});

  /// Lets the user pick files for an upload (none: cancelled).
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
  void showToast(ShowToastAction action, {required String message, String title = '', VoidCallback? onAction}) {}

  @override
  Future<ConfirmOutcome> confirm(ConfirmAction action, {required String title, String message = '', Json params = const {}}) async =>
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
  NavigatorActionUi({required this.context, this.route, this.modal, this.files});

  final BuildContext? Function() context;
  final ScreenRouteBuilder? route;
  final ScreenBuilder? modal;

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
    final content = modal?.call(action.to, params);
    if (c == null || content == null) return null;
    return showScreenModal(c, content,
        presentation: action.presentation,
        barrierDismissible: action.barrierDismissible,
        barrierColor: action.barrierColor,
        showDragHandle: action.showDragHandle,
        alignment: Alignment(action.alignment[0], action.alignment[1]),
        sheetBelowWidth: action.sheetBelowWidth,
        routeTransition: action.routeTransition);
  }

  @override
  bool closeModal(Object? result) {
    final c = _context;
    if (c == null) return false;
    final route = ModalRoute.of(c);
    final modal = route is PopupRoute || (route is CodelesslyRouteTransitionRoute && route.modal);
    if (route == null || !modal || !route.isCurrent) return false;
    Navigator.of(c).pop(result);
    return true;
  }

  @override
  void showToast(ShowToastAction action, {required String message, String title = '', VoidCallback? onAction}) {
    final c = _context;
    final messenger = c == null ? null : ScaffoldMessenger.maybeOf(c);
    if (messenger == null) return;
    final text = title.isEmpty ? message : '$title\n$message';
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      duration: Duration(milliseconds: action.durationMs),
      backgroundColor: switch (action.toastStyle) {
        ToastStyle.success => Colors.green.shade700,
        ToastStyle.warning => Colors.orange.shade800,
        ToastStyle.error => Colors.red.shade700,
        ToastStyle.info => Colors.blue.shade700,
        ToastStyle.neutral => null,
      },
      behavior: action.position == ToastPosition.top ? SnackBarBehavior.floating : null,
      showCloseIcon: action.showClose,
      action: action.actionLabel.isEmpty || onAction == null
          ? null
          : SnackBarAction(label: action.actionLabel, onPressed: onAction),
    ));
  }

  @override
  Future<ConfirmOutcome> confirm(ConfirmAction action, {required String title, String message = '', Json params = const {}}) async {
    final c = _context;
    if (c == null) return const ConfirmOutcome(false);
    if (action.dialog.isNotEmpty) {
      final content = modal?.call(action.dialog, params);
      if (content != null) {
        final result = await showScreenModal(c, content,
            presentation: action.presentation, barrierDismissible: action.barrierDismissible);
        return ConfirmOutcome(result != null && result != false, result);
      }
    }
    final ok = await showDialog<bool>(
      context: c,
      barrierDismissible: action.barrierDismissible,
      builder: (context) => AlertDialog(
        title: title.isEmpty ? null : Text(title),
        content: message.isEmpty ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(action.cancelLabel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: action.destructive ? TextButton.styleFrom(foregroundColor: Colors.red) : null,
            child: Text(action.confirmLabel),
          ),
        ],
      ),
    );
    return ConfirmOutcome(ok ?? false);
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
  double sheetBelowWidth = 600,
  RouteTransition? routeTransition,
}) {
  final scrim = barrierColor == null ? null : Color(barrierColor.value);
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
  if (sheet) {
    return showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      showDragHandle: showDragHandle,
      barrierColor: scrim,
      builder: (_) => content,
    );
  }
  if (presentation == ModalPresentation.fullScreen) {
    return Navigator.of(context).push<Object?>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => content));
  }
  return showDialog<Object?>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: scrim,
    builder: (_) => Align(alignment: alignment, child: Material(type: MaterialType.transparency, child: content)),
  );
}
