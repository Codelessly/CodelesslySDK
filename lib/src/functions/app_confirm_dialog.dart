import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'action_chain.dart';

/// How a [ConfirmAction]'s dialog closed.
typedef ConfirmOutcome = ({bool confirmed, Map<String, dynamic>? values});

/// Shows a [ConfirmAction]'s dialog.
///
/// Without a [ConfirmAction.dialogId] the dialog is built here and takes the
/// look of the layout that shows it ([FeedbackTheme.of]): its font, surface,
/// text and primary colors and its buttons' corner radius. The action's own
/// colors and radius override that look.
///
/// With a [ConfirmAction.dialogId] the dialog is that canvas. A button in it
/// answers with a "Navigate back" action whose params hold
/// [ConfirmAction.resultKey] (see [ConfirmAction.isConfirmResult]).
class AppConfirmDialog {
  AppConfirmDialog._();

  /// Shows [action]'s dialog and completes with whether the user confirmed.
  /// Dismissing the dialog counts as cancelling.
  static Future<bool> show(BuildContext context, ConfirmAction action) async =>
      (await ask(context, action)).confirmed;

  /// Shows [action]'s dialog and completes with whether the user confirmed
  /// and, for a canvas dialog, the other params its "Navigate back" passed.
  static Future<ConfirmOutcome> ask(
    BuildContext context,
    ConfirmAction action,
  ) async {
    final String? dialogId = action.dialogId;
    if (dialogId != null && dialogId.isNotEmpty) {
      if (FunctionsRepository.layoutIdForCanvas(
            context.read<Codelessly>(),
            dialogId,
          ) !=
          null) {
        final Object? result = await FunctionsRepository.showLayoutDialog(
          context,
          canvasId: dialogId,
          params: action.params,
          barrierDismissible: action.barrierDismissible,
          barrierColor: action.barrierColor?.toFlutterColor(),
          placement: action.placement,
        );
        final bool confirmed = ConfirmAction.isConfirmResult(result);
        return (
          confirmed: confirmed,
          values: confirmed && result is Map
              ? {
                  for (final MapEntry entry in result.entries)
                    if (entry.key != ConfirmAction.resultKey)
                      '${entry.key}': entry.value,
                }
              : null,
        );
      }
      DebugLogger.instance.printInfo(
        'Confirm dialog canvas [$dialogId] was not found. Showing the '
        'built-in dialog.',
        name: 'AppConfirmDialog',
      );
    }

    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    String text(String value) => PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    final String title = text(action.title);
    final String message = text(action.message);
    final String confirmLabel = text(action.confirmLabel);
    final String cancelLabel = text(action.cancelLabel);
    // Read the look where the action runs: the dialog's route sits outside
    // the layout.
    final ResolvedFeedbackTheme theme = FeedbackTheme.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: action.barrierDismissible,
      barrierColor: action.barrierColor?.toFlutterColor(),
      builder: (context) => ThemedConfirmDialog(
        theme: theme,
        title: title,
        message: message,
        confirmLabel: confirmLabel.isEmpty ? 'OK' : confirmLabel,
        cancelLabel: cancelLabel.isEmpty ? 'Cancel' : cancelLabel,
        destructive: action.destructive,
        backgroundColor: action.backgroundColor?.toFlutterColor(),
        textColor: action.textColor?.toFlutterColor(),
        confirmColor: action.confirmColor?.toFlutterColor(),
        cornerRadius: action.cornerRadius,
      ),
    );
    return (confirmed: confirmed ?? false, values: null);
  }
}

/// The built-in confirm dialog, in the app's look. Pops true when confirmed
/// and false when cancelled.
class ThemedConfirmDialog extends StatelessWidget {
  /// Creates a [ThemedConfirmDialog].
  const ThemedConfirmDialog({
    super.key,
    required this.theme,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = false,
    this.backgroundColor,
    this.textColor,
    this.confirmColor,
    this.cornerRadius,
  });

  /// The app's look.
  final ResolvedFeedbackTheme theme;

  /// Title; hidden when empty.
  final String title;

  /// Text under the title; hidden when empty.
  final String message;

  /// Label of the confirm button.
  final String confirmLabel;

  /// Label of the cancel button.
  final String cancelLabel;

  /// Whether the confirm button takes the error color.
  final bool destructive;

  /// Overrides the theme's surface.
  final Color? backgroundColor;

  /// Overrides the theme's text color.
  final Color? textColor;

  /// Overrides the confirm button's fill.
  final Color? confirmColor;

  /// Overrides the dialog's corner radius.
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final Color surface = backgroundColor ?? theme.surface;
    final Color onSurface =
        textColor ??
        (backgroundColor == null
            ? theme.onSurface
            : ResolvedFeedbackTheme.onColor(surface));
    final Color confirmFill =
        confirmColor ?? (destructive ? theme.error : theme.primary);
    final Color onConfirm = ResolvedFeedbackTheme.onColor(confirmFill);
    final double radius = cornerRadius ?? theme.radius;
    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(theme.buttonRadius),
    );
    final TextStyle buttonText = theme.buttonStyle.copyWith(
      fontSize: 15,
      height: 1.2,
    );
    const Size buttonSize = Size(64, 44);
    const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 18);

    return Theme(
      data: theme.apply(Theme.of(context)),
      child: Dialog(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: title.isEmpty ? null : title,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: theme.titleStyle.copyWith(
                        fontSize: 18,
                        height: 1.3,
                        color: onSurface,
                      ),
                    ),
                  if (title.isNotEmpty && message.isNotEmpty)
                    const SizedBox(height: 8),
                  if (message.isNotEmpty)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          message,
                          style: theme.bodyStyle.copyWith(
                            fontSize: 15,
                            height: 1.45,
                            color: onSurface.withValues(alpha: 0.74),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: [
                      TextButton(
                        key: const ValueKey('codelessly-confirm-cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: onSurface,
                          textStyle: buttonText,
                          shape: buttonShape,
                          minimumSize: buttonSize,
                          padding: buttonPadding,
                        ),
                        child: Text(cancelLabel),
                      ),
                      FilledButton(
                        key: const ValueKey('codelessly-confirm-ok'),
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: confirmFill,
                          foregroundColor: onConfirm,
                          textStyle: buttonText,
                          shape: buttonShape,
                          minimumSize: buttonSize,
                          padding: buttonPadding,
                        ),
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
