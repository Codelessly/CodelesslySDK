import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../ui/layout_presentation_route.dart';
import 'action_chain.dart';

/// How a [ConfirmAction]'s dialog closed.
typedef ConfirmOutcome = ({bool confirmed, Map<String, dynamic>? values});

/// Shows a [ConfirmAction]'s dialog.
///
/// Without a [ConfirmAction.dialogId] the dialog is built here and takes the
/// look of the layout that shows it ([FeedbackTheme.of]): its font, surface,
/// text and primary colors and its buttons' corner radius, outline and
/// shadows. The action's own colors, radii, borders, shadows and text styles
/// override that look.
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
          presentation: action.presentation,
          sheetWidth: action.sheetWidth,
          maxHeightFactor: action.maxHeightFactor,
          showDragHandle: action.showDragHandle,
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

    Widget buildDialog(BuildContext context) => ThemedConfirmDialog(
      theme: theme,
      presentation: action.presentation.resolveFor(context),
      title: title,
      message: message,
      confirmLabel: confirmLabel.isEmpty ? 'OK' : confirmLabel,
      cancelLabel: cancelLabel.isEmpty ? 'Cancel' : cancelLabel,
      destructive: action.destructive,
      backgroundColor: action.backgroundColor?.toFlutterColor(),
      textColor: action.textColor?.toFlutterColor(),
      confirmColor: action.confirmColor?.toFlutterColor(),
      cornerRadius: action.cornerRadius,
    );

    final DialogPresentation presentation = action.presentation.resolveFor(
      context,
    );
    if (presentation != DialogPresentation.dialog) {
      final Object? answer = await Navigator.of(context).push<Object?>(
        LayoutPresentationRoute<Object?>(
          context: context,
          presentation: presentation,
          barrierDismissible: action.barrierDismissible,
          barrierColor:
              action.barrierColor?.toFlutterColor() ??
              Theme.of(context).dialogTheme.barrierColor ??
              Colors.black54,
          sheetWidth: action.sheetWidth,
          maxHeightFactor: action.maxHeightFactor,
          showDragHandle: action.showDragHandle,
          builder: buildDialog,
        ),
      );
      return (confirmed: answer == true, values: null);
    }

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
        border: action.border == null ? null : borderSideOf(action.border!),
        shadows: action.shadows == null ? null : boxShadowsOf(action.shadows),
        titleStyle: action.titleStyle,
        messageStyle: action.messageStyle,
        buttonStyle: action.buttonStyle,
        buttonRadius: action.buttonRadius,
        buttonBorder: action.buttonBorder == null
            ? null
            : borderSideOf(action.buttonBorder!),
        buttonShadows: action.buttonShadows == null
            ? null
            : boxShadowsOf(action.buttonShadows),
        confirmTextColor: action.confirmTextColor?.toFlutterColor(),
        cancelColor: action.cancelColor?.toFlutterColor(),
        cancelTextColor: action.cancelTextColor?.toFlutterColor(),
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
    this.presentation = DialogPresentation.dialog,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = false,
    this.backgroundColor,
    this.textColor,
    this.confirmColor,
    this.cornerRadius,
    this.border,
    this.shadows,
    this.titleStyle,
    this.messageStyle,
    this.buttonStyle,
    this.buttonRadius,
    this.buttonBorder,
    this.buttonShadows,
    this.confirmTextColor,
    this.cancelColor,
    this.cancelTextColor,
  });

  /// The app's look.
  final ResolvedFeedbackTheme theme;

  /// Whether it is a centered dialog or fills a bottom or side sheet. A
  /// sheet's route ([LayoutPresentationRoute]) places and clips it.
  final DialogPresentation presentation;

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

  /// Overrides the theme's dialog outline.
  final BorderSide? border;

  /// Overrides the theme's dialog shadows; set, they replace the elevation.
  final List<BoxShadow>? shadows;

  /// Changes to the title's font, size and color.
  final TextStyleModel? titleStyle;

  /// Changes to the message's font, size and color.
  final TextStyleModel? messageStyle;

  /// Changes to the buttons' font, size and label color.
  final TextStyleModel? buttonStyle;

  /// Overrides the theme's button corner radius.
  final double? buttonRadius;

  /// Overrides the theme's button outline.
  final BorderSide? buttonBorder;

  /// Overrides the theme's button shadows. The cancel button takes them only
  /// when it has a [cancelColor].
  final List<BoxShadow>? buttonShadows;

  /// Label color of the confirm button.
  final Color? confirmTextColor;

  /// Fill of the cancel button; null leaves it a text button.
  final Color? cancelColor;

  /// Label color of the cancel button.
  final Color? cancelTextColor;

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
    final double radius = cornerRadius ?? theme.radius;
    final double buttonCorner = buttonRadius ?? theme.buttonRadius;
    final BorderSide buttonSide =
        buttonBorder ?? theme.buttonBorder ?? BorderSide.none;
    final List<BoxShadow> buttonShadowList =
        buttonShadows ?? theme.buttonShadows ?? const [];
    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonCorner),
    );
    final TextStyle buttonText = buttonStyle.applyTo(
      theme.buttonStyle.copyWith(fontSize: 15, height: 1.2),
    );
    final Color onConfirm =
        buttonStyle?.color?.toFlutterColor() ??
        confirmTextColor ??
        ResolvedFeedbackTheme.onColor(confirmFill);
    final Color onCancel =
        buttonStyle?.color?.toFlutterColor() ?? cancelTextColor ?? onSurface;
    const Size buttonSize = Size(64, 44);
    const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 18);
    final BorderSide? dialogSide = border ?? theme.border;
    final List<BoxShadow>? dialogShadows = shadows ?? theme.shadows;

    Widget withShadow(Widget button) => buttonShadowList.isEmpty
        ? button
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(buttonCorner),
              boxShadow: buttonShadowList,
            ),
            child: button,
          );

    final Widget cancel = TextButton(
      key: const ValueKey('codelessly-confirm-cancel'),
      onPressed: () => Navigator.of(context).pop(false),
      style: TextButton.styleFrom(
        foregroundColor: onCancel,
        backgroundColor: cancelColor,
        textStyle: buttonText,
        shape: buttonShape,
        side: buttonSide,
        minimumSize: buttonSize,
        padding: buttonPadding,
      ),
      child: Text(cancelLabel),
    );
    final Widget confirm = FilledButton(
      key: const ValueKey('codelessly-confirm-ok'),
      onPressed: () => Navigator.of(context).pop(true),
      style: FilledButton.styleFrom(
        backgroundColor: confirmFill,
        foregroundColor: onConfirm,
        textStyle: buttonText,
        shape: buttonShape,
        side: buttonSide,
        minimumSize: buttonSize,
        padding: buttonPadding,
      ),
      child: Text(confirmLabel),
    );

    final Widget content = Semantics(
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
                style: titleStyle.applyTo(
                  theme.titleStyle.copyWith(
                    fontSize: 18,
                    height: 1.3,
                    color: onSurface,
                  ),
                ),
              ),
            if (title.isNotEmpty && message.isNotEmpty)
              const SizedBox(height: 8),
            if (message.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: messageStyle.applyTo(
                      theme.bodyStyle.copyWith(
                        fontSize: 15,
                        height: 1.45,
                        color: onSurface.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              // Outlined or shadowed buttons need room between them.
              spacing: buttonShadowList.isEmpty ? 8 : 12,
              overflowSpacing: 8,
              children: [
                cancelColor != null ? withShadow(cancel) : cancel,
                withShadow(confirm),
              ],
            ),
          ],
        ),
      ),
    );

    // Shadows of its own replace the dialog's elevation: they are drawn
    // around a box that carries its fill and outline.
    Widget dialogBody = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: content,
    );
    if (dialogShadows != null) {
      dialogBody = DecoratedBox(
        key: const ValueKey('codelessly-confirm-surface'),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radius),
          border: dialogSide == null ? null : Border.fromBorderSide(dialogSide),
          boxShadow: dialogShadows,
        ),
        child: dialogBody,
      );
    }

    return Theme(
      data: theme.apply(Theme.of(context)),
      child: switch (presentation) {
        DialogPresentation.dialog => Dialog(
          backgroundColor: dialogShadows != null ? Colors.transparent : surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: dialogShadows != null ? Colors.transparent : null,
          elevation: dialogShadows != null ? 0 : 8,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: dialogShadows == null
                ? dialogSide ?? BorderSide.none
                : BorderSide.none,
          ),
          child: dialogBody,
        ),
        // A sheet is as wide as its route makes it; its content keeps clear
        // of the home indicator and the bottom sheet's grab handle.
        DialogPresentation.bottomSheet ||
        DialogPresentation.adaptive => SizedBox(
          width: double.infinity,
          child: Material(
            color: surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: content,
              ),
            ),
          ),
        ),
        DialogPresentation.sideSheet => Material(
          color: surface,
          child: SafeArea(
            left: false,
            child: Align(alignment: Alignment.topLeft, child: content),
          ),
        ),
      },
    );
  }
}
