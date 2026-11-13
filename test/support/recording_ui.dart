import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';

/// Records what the actions ask of the UI.
class RecordingUi implements ActionUi {
  final List<String> log = [];
  bool confirmAnswer = false;
  Object? modalResult;

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async =>
      log.add('navigate ${action.mode.name} ${action.to} $params');

  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) async {
    log.add('modal ${action.to} ${action.presentation.name}');
    return modalResult;
  }

  @override
  bool closeModal(Object? result) {
    log.add('close $result');
    return true;
  }

  @override
  void showToast(ShowToastAction action,
          {required String message,
          String title = '',
          String actionLabel = '',
          Map<String, Object?> bound = const {},
          VoidCallback? onAction}) =>
      log.add('toast $message');

  @override
  Future<ConfirmOutcome> confirm(ConfirmAction action,
      {required String title,
      String message = '',
      String caption = '',
      String confirmLabel = 'OK',
      String cancelLabel = 'Cancel',
      Map<String, Object?> bound = const {},
      Json params = const {}}) async {
    log.add('confirm $title');
    return ConfirmOutcome(confirmAnswer);
  }

  @override
  Future<List<PickedFile>> pickFiles({bool images = true, bool multiple = true}) async => const [];
}
