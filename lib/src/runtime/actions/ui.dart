// What actions show and where they go: screens, modals, toasts, confirm
// dialogs, file pickers. Handlers never hold a BuildContext; they ask an
// [ActionUi], which whatever shows the UI implements: the app shell's
// Navigator-based one (lib/src/app/navigator_ui.dart) in a Flutter widget
// app, a recording one in a test. No widget library is needed to ask.
import 'dart:async';
import 'dart:typed_data';

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show ConfirmAction, Json, NavigateAction, OpenModalAction, ShowToastAction;
import 'package:flutter/foundation.dart';

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

/// An [ActionUi] that may come without a file picker of its own: the
/// services' picker (the platform's file dialog) is used then.
abstract interface class OptionalFilePicker {
  /// Whether it picks files itself.
  bool get picksFiles;
}
