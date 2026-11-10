import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../ui/layout_presentation_route.dart';
import 'action_chain.dart';

/// How a [ConfirmAction]'s dialog closed.
typedef ConfirmOutcome = ({bool confirmed, Map<String, dynamic>? values});

/// The size of a built-in confirm dialog (see [AppConfirmDialog.layoutOf]);
/// a null field takes the default.
typedef ConfirmDialogLayout = ({
  double? width,
  double? maxWidth,
  EdgeInsets? insets,
  EdgeInsets? padding,
  double? buttonHeight,
});

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

  /// The icon [action]'s built-in dialog shows: its `icon` binding naming a
  /// Material icon (`variables: {"icon": "${lamp.icon}"}`), else
  /// [ConfirmAction.icon]. A binding that gives no name keeps the action's.
  static MultiSourceIconModel? iconOf(
    ConfirmAction action,
    ScopedValues scopedValues,
  ) {
    final String? binding = action.variables['icon'];
    if (binding == null) return action.icon;
    final String name = PropertyValueDelegate.substituteVariables(
      binding,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    ).trim();
    if (name.isEmpty) return action.icon;
    final MultiSourceIconModel base =
        action.icon ?? MultiSourceIconModel.icon(size: action.iconSize);
    final MultiSourceIconModel named = iconWithName(base, name);
    return identical(named, base) ? action.icon : named;
  }

  /// The size of [action]'s built-in dialog: its width, max width, insets,
  /// padding and button height, each from its [ConfirmAction.variables]
  /// binding (see [ConfirmAction.bindableSizes]) when that gives a value,
  /// else the action's own field (null for the default).
  static ConfirmDialogLayout layoutOf(
    ConfirmAction action,
    ScopedValues scopedValues,
  ) {
    Object? bound(String key) {
      final String? binding = action.variables[key]?.trim();
      if (binding == null || binding.isEmpty) return null;
      final bool single =
          FormulaEvaluator.exactExpression(binding) != null ||
          RegExp(r'^\$\{[^{}]+\}$').hasMatch(binding);
      final Object? value = single
          ? PropertyValueDelegate.getVariableValueFromPath<Object>(
              binding,
              scopedValues: scopedValues,
            )
          : PropertyValueDelegate.substituteVariables(
              binding,
              scopedValues: scopedValues,
              nullSubstitutionMode: NullSubstitutionMode.emptyString,
            );
      return value is String && value.trim().isEmpty ? null : value;
    }

    double? number(String key, double? own) {
      final Object? value = bound(key);
      final num? n = value is num
          ? value
          : value is String
          ? num.tryParse(value.trim())
          : null;
      return n != null && n.isFinite && n >= 0 ? n.toDouble() : own;
    }

    EdgeInsets? insets(String key, EdgeInsetsModel? own) {
      final Object? value = bound(key);
      final EdgeInsetsModel? model =
          (value is String ? num.tryParse(value.trim()) ?? value : value)
              ?.toEdgeInsetsModel() ??
          own;
      return model?.flutterEdgeInsets;
    }

    return (
      width: number('width', action.width),
      maxWidth: number('maxWidth', action.maxWidth),
      insets: insets('insets', action.insets),
      padding: insets('padding', action.padding),
      buttonHeight: number('buttonHeight', action.buttonHeight),
    );
  }

  /// What a dialog canvas receives as `${route.*}`: the action's own text
  /// (`title`, `caption`, `message`, `confirmLabel`, `cancelLabel`, with
  /// their `${...}` filled in where the action runs), so one Confirm canvas
  /// can ask every question, then [ConfirmAction.params], which win.
  static Map<String, dynamic> dialogParams(
    BuildContext context,
    ConfirmAction action,
  ) {
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    String text(String value) => PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    return {
      for (final (String key, String value) in [
        ('title', action.title),
        ('caption', action.caption),
        ('message', action.message),
        ('confirmLabel', action.confirmLabel),
        ('cancelLabel', action.cancelLabel),
      ])
        if (value.isNotEmpty) key: text(value),
      ...action.params,
    };
  }

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
          params: dialogParams(context, action),
          barrierDismissible: action.barrierDismissible,
          barrierColor: action.barrierColor?.toFlutterColor(),
          presentation: action.presentation,
          sheetWidth: action.sheetWidth,
          maxHeightFactor: action.maxHeightFactor,
          showDragHandle: action.showDragHandle,
          placement: action.placement,
          barrierBlur: action.barrierBlur,
          enterScale: action.enterScale,
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
    final String caption = text(action.caption);
    final String message = text(action.message);
    final String confirmLabel = text(action.confirmLabel);
    final String cancelLabel = text(action.cancelLabel);
    // Read the look where the action runs: the dialog's route sits outside
    // the layout.
    final ResolvedFeedbackTheme theme = FeedbackTheme.of(context);
    // Colors bound in [ConfirmAction.variables] win over the action's own.
    final Map<String, Color> bound = ActionColorBindings.resolve(
      action.variables,
      scopedValues,
      keys: ConfirmAction.bindableColors,
    );
    Color? color(String key, ColorRGBA? own) =>
        bound[key] ?? own?.toFlutterColor();
    TextStyleModel? styled(TextStyleModel? style, String key) {
      final Color? value = bound[key];
      if (value == null) return style;
      return (style ?? const TextStyleModel()).copyWith(
        color: value.toColorRGBA(),
      );
    }

    BorderSide? side(BorderSideModel? model, String key) {
      final BorderSide? own = model == null ? null : borderSideOf(model);
      final Color? value = bound[key];
      if (value == null) return own;
      return own == null || own == BorderSide.none
          ? BorderSide(color: value)
          : own.copyWith(color: value);
    }

    final Color? barrierColor = color('barrierColor', action.barrierColor);
    final ConfirmDialogLayout layout = layoutOf(action, scopedValues);

    Widget buildDialog(BuildContext context) => ThemedConfirmDialog(
      width: layout.width,
      maxWidth: layout.maxWidth,
      insets: layout.insets,
      padding: layout.padding,
      buttonHeight: layout.buttonHeight,
      theme: theme,
      presentation: action.presentation.resolveFor(context),
      title: title,
      caption: caption,
      captionStyle: action.captionStyle,
      message: message,
      confirmLabel: confirmLabel.isEmpty ? 'OK' : confirmLabel,
      cancelLabel: cancelLabel.isEmpty ? 'Cancel' : cancelLabel,
      destructive: action.destructive,
      backgroundColor: color('backgroundColor', action.backgroundColor),
      textColor: color('textColor', action.textColor),
      confirmColor: color('confirmColor', action.confirmColor),
      cornerRadius: action.cornerRadius,
      border: side(action.border, 'borderColor'),
      shadows: action.shadows == null ? null : boxShadowsOf(action.shadows),
      titleStyle: styled(action.titleStyle, 'titleColor'),
      messageStyle: styled(action.messageStyle, 'messageColor'),
      buttonStyle: action.buttonStyle,
      buttonRadius: action.buttonRadius,
      buttonBorder: side(action.buttonBorder, 'buttonBorderColor'),
      buttonShadows: action.buttonShadows == null
          ? null
          : boxShadowsOf(action.buttonShadows),
      confirmTextColor: color('confirmTextColor', action.confirmTextColor),
      cancelColor: color('cancelColor', action.cancelColor),
      cancelTextColor: color('cancelTextColor', action.cancelTextColor),
      confirmBorder: side(action.confirmBorder, 'confirmBorderColor'),
      cancelBorder: side(action.cancelBorder, 'cancelBorderColor'),
      icon: iconOf(action, scopedValues),
      iconSize: action.iconSize,
      iconColor: color('iconColor', action.iconColor),
      iconDiscColor: color('iconDiscColor', action.iconDiscColor),
      iconDiscSize: action.iconDiscSize,
      iconDiscBorder: side(action.iconDiscBorder, 'iconDiscBorderColor'),
      centered: action.centered,
      expandButtons: action.expandButtons,
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
              barrierColor ??
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
      barrierColor: barrierColor,
      builder: buildDialog,
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
    this.caption = '',
    this.captionStyle,
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
    this.confirmBorder,
    this.cancelBorder,
    this.icon,
    this.iconSize = 24,
    this.iconColor,
    this.iconDiscColor,
    this.iconDiscSize = 52,
    this.iconDiscBorder,
    this.centered = false,
    this.expandButtons = false,
    this.width,
    this.maxWidth,
    this.insets,
    this.padding,
    this.buttonHeight,
  });

  /// Width of a centered dialog, within [maxWidth] and the screen less
  /// [insets]; null hugs the content.
  final double? width;

  /// The widest a centered dialog gets; null is 400.
  final double? maxWidth;

  /// Space between a centered dialog and the screen's edges; null is 24.
  final EdgeInsets? insets;

  /// Space between the dialog's edge and its content; null is 24 on top
  /// and the sides, 16 at the bottom.
  final EdgeInsets? padding;

  /// Height of the buttons; null is 44.
  final double? buttonHeight;

  /// Outline of the confirm button, over [buttonBorder].
  final BorderSide? confirmBorder;

  /// Outline of the cancel button, over [buttonBorder].
  final BorderSide? cancelBorder;

  /// An icon over the title.
  final MultiSourceIconModel? icon;

  /// Size of [icon].
  final double iconSize;

  /// Color of [icon]; null keeps its own, else the text color.
  final Color? iconColor;

  /// Fill of a circle behind [icon] (a dot on its own without one).
  final Color? iconDiscColor;

  /// Diameter of the [iconDiscColor] circle.
  final double iconDiscSize;

  /// Outline of the [iconDiscColor] circle.
  final BorderSide? iconDiscBorder;

  /// Whether the icon, title and message are centered.
  final bool centered;

  /// Whether the buttons share the dialog's width equally.
  final bool expandButtons;

  /// The app's look.
  final ResolvedFeedbackTheme theme;

  /// Whether it is a centered dialog or fills a bottom or side sheet. A
  /// sheet's route ([LayoutPresentationRoute]) places and clips it.
  final DialogPresentation presentation;

  /// Title; hidden when empty.
  final String title;

  /// A small line above the [title], or empty for none.
  final String caption;

  /// Style of the [caption], over the built-in small caps.
  final TextStyleModel? captionStyle;

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
    // A set height is the buttons' height exactly, not just their least.
    final Size buttonSize = Size(64, buttonHeight ?? 44);
    final Size? buttonMaxSize = buttonHeight == null
        ? null
        : Size(double.infinity, buttonHeight!);
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
        side: cancelBorder ?? buttonSide,
        minimumSize: buttonSize,
        maximumSize: buttonMaxSize,
        tapTargetSize: buttonHeight == null
            ? null
            : MaterialTapTargetSize.shrinkWrap,
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
        side: confirmBorder ?? buttonSide,
        minimumSize: buttonSize,
        maximumSize: buttonMaxSize,
        tapTargetSize: buttonHeight == null
            ? null
            : MaterialTapTargetSize.shrinkWrap,
        padding: buttonPadding,
      ),
      child: Text(confirmLabel),
    );
    final TextAlign textAlign = centered ? TextAlign.center : TextAlign.start;
    Widget? leading = icon == null
        ? null
        : retrieveIconWidget(
            iconColor == null
                ? icon!
                : icon!.copyWith(color: iconColor!.toColorRGBA()),
            iconSize,
            onSurface,
          );
    if (iconDiscColor != null || iconDiscBorder != null) {
      leading = Container(
        key: const ValueKey('codelessly-confirm-icon-disc'),
        width: iconDiscSize,
        height: iconDiscSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconDiscColor,
          shape: BoxShape.circle,
          border: iconDiscBorder == null
              ? null
              : Border.fromBorderSide(iconDiscBorder!),
        ),
        child: leading,
      );
    }
    final List<Widget> buttons = [
      cancelColor != null ? withShadow(cancel) : cancel,
      withShadow(confirm),
    ];

    final Widget content = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title.isEmpty ? null : title,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centered
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading, const SizedBox(height: 16)],
            if (caption.isNotEmpty) ...[
              Text(
                caption,
                textAlign: textAlign,
                style: captionStyle.applyTo(
                  theme.bodyStyle.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (title.isNotEmpty)
              Text(
                title,
                textAlign: textAlign,
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
                    textAlign: textAlign,
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
            if (expandButtons)
              Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: buttons[1]),
                ],
              )
            else
              OverflowBar(
                alignment: centered
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.end,
                overflowAlignment: centered
                    ? OverflowBarAlignment.center
                    : OverflowBarAlignment.end,
                // Outlined or shadowed buttons need room between them.
                spacing:
                    buttonShadowList.isEmpty &&
                        confirmBorder == null &&
                        cancelBorder == null
                    ? 8
                    : 12,
                overflowSpacing: 8,
                children: buttons,
              ),
          ],
        ),
      ),
    );

    // Shadows of its own replace the dialog's elevation: they are drawn
    // around a box that carries its fill and outline.
    final double widest = maxWidth ?? 400;
    Widget dialogBody = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widest),
      child: width == null
          ? content
          : SizedBox(width: math.min(width!, widest), child: content),
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
        DialogPresentation.dialog ||
        DialogPresentation.popover ||
        DialogPresentation.fullScreen => Dialog(
          backgroundColor: dialogShadows != null ? Colors.transparent : surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: dialogShadows != null ? Colors.transparent : null,
          elevation: dialogShadows != null ? 0 : 8,
          insetPadding:
              insets ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
