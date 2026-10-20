import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// Shows a [ConfirmAction]'s dialog.
class AppConfirmDialog {
  AppConfirmDialog._();

  /// Shows [action]'s dialog and completes with whether the user confirmed.
  /// Dismissing the dialog counts as cancelling.
  static Future<bool> show(BuildContext context, ConfirmAction action) async {
    final ScopedValues scopedValues = ScopedValues.of(context);
    String text(String value) => PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    final String title = text(action.title);
    final String message = text(action.message);
    final String confirmLabel = text(action.confirmLabel);
    final String cancelLabel = text(action.cancelLabel);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: title.isEmpty ? null : Text(title),
        content: message.isEmpty ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel.isEmpty ? 'Cancel' : cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: action.destructive
                ? TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel.isEmpty ? 'OK' : confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
