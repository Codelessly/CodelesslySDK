// Confirm actions' built-in dialog, in the app's look, and the answer of a
// designed one (a screen named by the action's `dialog`).
import 'dart:convert';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show ConfirmAction, Json, ModalPresentation;
import 'package:flutter/material.dart';

import '../../render/convert.dart';
import '../../render/paint/icon_names.dart';
import 'feedback_icon.dart';
import 'feedback_theme.dart';
import 'presentation_route.dart';
import 'toast.dart';

/// What a confirm action asks, its text and bindings already evaluated
/// where it ran.
@immutable
class ConfirmRequest {
  const ConfirmRequest(
    this.action, {
    this.title = '',
    this.caption = '',
    this.message = '',
    this.confirmLabel = 'OK',
    this.cancelLabel = 'Cancel',
    this.bound = const {},
    this.params = const {},
  });

  final ConfirmAction action;
  final String title, caption, message, confirmLabel, cancelLabel;

  /// [ConfirmAction.variables] evaluated, by key (colors, sizes, `icon`).
  final Map<String, Object?> bound;

  /// The action's params, evaluated.
  final Json params;

  /// What a dialog screen receives as `${route.*}`: the action's own text
  /// (so one Confirm screen can ask every question), then its params, which
  /// win.
  Json get dialogParams => {
        if (action.title.isNotEmpty) 'title': title,
        if (action.caption.isNotEmpty) 'caption': caption,
        if (action.message.isNotEmpty) 'message': message,
        if (action.confirmLabel.isNotEmpty) 'confirmLabel': confirmLabel,
        if (action.cancelLabel.isNotEmpty) 'cancelLabel': cancelLabel,
        ...params,
      };
}

/// The color fields a confirm's `variables` can bind. `titleColor` and
/// `messageColor` color the title and message over their styles; the
/// `*BorderColor`s color their borders (1px ones when there are none).
const confirmBindableColors = [
  'backgroundColor',
  'textColor',
  'titleColor',
  'messageColor',
  'confirmColor',
  'confirmTextColor',
  'cancelColor',
  'cancelTextColor',
  'barrierColor',
  'borderColor',
  'buttonBorderColor',
  'confirmBorderColor',
  'cancelBorderColor',
  'iconColor',
  'iconDiscColor',
  'iconDiscBorderColor',
];

/// The key of a dialog screen's close result that answers it.
const confirmResultKey = 'confirmed';

/// Whether a dialog that closed with [result] was confirmed: a map whose
/// [confirmResultKey] is true (or `yes`, `1`, `confirm`, a non-zero
/// number), or true itself.
bool isConfirmResult(Object? result) {
  final value = result is Map ? result[confirmResultKey] : result;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    return text == 'true' || text == 'yes' || text == '1' || text == 'confirm';
  }
  return false;
}

/// The values a dialog screen gave back with a confirm (its result less
/// [confirmResultKey]); null when it wasn't confirmed or gave no map.
Json? confirmValues(Object? result) => isConfirmResult(result) && result is Map
    ? {
        for (final e in result.entries)
          if (e.key != confirmResultKey) '${e.key}': e.value,
      }
    : null;

/// The size of a built-in confirm dialog: each from its binding when that
/// gives a value, else the look's (null: the default).
typedef ConfirmDialogLayout = ({double? width, double? maxWidth, EdgeInsets? insets, EdgeInsets? padding, double? buttonHeight});

ConfirmDialogLayout confirmLayoutOf(ConfirmAction action, Map<String, Object?> bound) {
  final look = Look(action.style);
  Object? value(String key) {
    if ((action.variables[key] ?? '').trim().isEmpty) return null;
    final v = bound[key];
    return v is String && v.trim().isEmpty ? null : v;
  }

  double? number(String key) {
    final n = numberValue(value(key));
    return n != null && n.isFinite && n >= 0 ? n : look.number(key);
  }

  EdgeInsets? insets(String key) => insetsValue(value(key)) ?? look.insets(key);

  return (
    width: number('width'),
    maxWidth: number('maxWidth'),
    insets: insets('insets'),
    padding: insets('padding'),
    buttonHeight: number('buttonHeight'),
  );
}

/// [value] (a binding's value) as insets: a number for every side,
/// `[horizontal, vertical]`, `[left, top, right, bottom]`, a map of sides
/// (`left`..., `horizontal`/`vertical`), or such JSON as text.
EdgeInsets? insetsValue(Object? value) {
  double? n(Object? v) => numberValue(v);
  switch (value) {
    case null:
      return null;
    case num():
      return EdgeInsets.all(value.toDouble());
    case [final Object? all] when n(all) != null:
      return EdgeInsets.all(n(all)!);
    case [final Object? h, final Object? v] when n(h) != null && n(v) != null:
      return EdgeInsets.symmetric(horizontal: n(h)!, vertical: n(v)!);
    case [final Object? l, final Object? t, final Object? r, final Object? b]
        when n(l) != null && n(t) != null && n(r) != null && n(b) != null:
      return EdgeInsets.fromLTRB(n(l)!, n(t)!, n(r)!, n(b)!);
    case Map():
      final h = n(value['horizontal']) ?? 0, v = n(value['vertical']) ?? 0;
      return EdgeInsets.fromLTRB(
        n(value['left'] ?? value['l']) ?? h,
        n(value['top'] ?? value['t']) ?? v,
        n(value['right'] ?? value['r']) ?? h,
        n(value['bottom'] ?? value['b']) ?? v,
      );
    case String():
      final text = value.trim();
      final number = num.tryParse(text);
      if (number != null) return EdgeInsets.all(number.toDouble());
      try {
        final parsed = jsonDecode(text);
        return parsed is String ? null : insetsValue(parsed);
      } on FormatException {
        return null;
      }
  }
  return null;
}

/// The icon a confirm's built-in dialog shows: its `icon` binding naming a
/// Material icon, else the look's icon.
Json? confirmIconOf(ConfirmAction action, Map<String, Object?> bound) {
  final look = Look(action.style);
  final own = look.map('icon');
  if (!action.variables.containsKey('icon')) return own;
  final name = '${bound['icon'] ?? ''}'.trim();
  if (name.isEmpty) return own;
  final base = own ?? {'source': 'icon', 'size': look.numberOr('iconSize', 24), 'color': '#FF000000'};
  final named = iconWithName(base, name);
  return identical(named, base) ? own : named;
}

/// Shows [request]'s built-in dialog over [context]; completes with
/// whether the user confirmed (dismissing it cancels).
///
/// An adaptive confirm is a sheet below [sheetBelowWidth] (default: the
/// default breakpoints' [defaultSheetBelowWidth]; the app passes its
/// project's).
Future<bool> showConfirmDialog(BuildContext context, ConfirmRequest request, {double? sheetBelowWidth}) async {
  final action = request.action;
  final look = Look(action.style);
  final bound = request.bound;
  // Read the look where the action runs: the dialog's route sits outside
  // the layout.
  final theme = FeedbackTheme.of(context);
  final colors = boundColors(bound, confirmBindableColors);
  Color? color(String key) => colors[key] ?? look.color(key);
  api.TextStyle? styled(String styleKey, String colorKey) {
    final style = look.textStyle(styleKey);
    final c = colors[colorKey];
    if (c == null) return style;
    return (style ?? api.TextStyle.empty).merge(api.TextStyle(color: api.Color(c.toARGB32())));
  }

  BorderSide? side(String key, String colorKey) {
    final own = look.side(key);
    final c = colors[colorKey];
    if (c == null) return own;
    return own == null || own == BorderSide.none ? BorderSide(color: c) : own.copyWith(color: c);
  }

  double? gap(String key) {
    final value = look.number(key);
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  final barrierColor = color('barrierColor');
  final layout = confirmLayoutOf(action, bound);
  final presentation = resolvePresentation(action.presentation, MediaQuery.maybeSizeOf(context)?.width,
      sheetBelowWidth: sheetBelowWidth ?? defaultSheetBelowWidth(api.Breakpoints.defaults));
  Widget buildDialog(BuildContext context) => ToastBelowRoute(
        child: ThemedConfirmDialog(
          width: layout.width,
          maxWidth: layout.maxWidth,
          insets: layout.insets,
          padding: layout.padding,
          buttonHeight: layout.buttonHeight,
          theme: theme,
          presentation: presentation,
          title: request.title,
          caption: request.caption,
          captionStyle: look.textStyle('captionStyle'),
          message: request.message,
          confirmLabel: request.confirmLabel.isEmpty ? 'OK' : request.confirmLabel,
          cancelLabel: request.cancelLabel.isEmpty ? 'Cancel' : request.cancelLabel,
          destructive: action.destructive,
          backgroundColor: color('backgroundColor'),
          textColor: color('textColor'),
          confirmColor: color('confirmColor'),
          cornerRadius: look.number('radius'),
          border: side('border', 'borderColor'),
          shadows: look.shadows('shadows'),
          titleStyle: styled('titleStyle', 'titleColor'),
          messageStyle: styled('messageStyle', 'messageColor'),
          buttonStyle: look.textStyle('buttonStyle'),
          buttonRadius: look.number('buttonRadius'),
          buttonBorder: side('buttonBorder', 'buttonBorderColor'),
          buttonShadows: look.shadows('buttonShadows'),
          confirmTextColor: color('confirmTextColor'),
          cancelColor: color('cancelColor'),
          cancelTextColor: color('cancelTextColor'),
          confirmBorder: side('confirmBorder', 'confirmBorderColor'),
          cancelBorder: side('cancelBorder', 'cancelBorderColor'),
          icon: confirmIconOf(action, bound),
          iconSize: look.numberOr('iconSize', 24),
          iconColor: color('iconColor'),
          iconDiscColor: color('iconDiscColor'),
          iconDiscSize: look.numberOr('iconDiscSize', 52),
          iconDiscBorder: side('iconDiscBorder', 'iconDiscBorderColor'),
          centered: look.flag('centered'),
          expandButtons: look.flag('expandButtons'),
          stackButtons: look.flag('stackButtons'),
          titleMessageGap: gap('titleMessageGap') ?? 8,
          actionsGap: gap('actionsGap') ?? 20,
          buttonGap: gap('buttonGap'),
        ),
      );

  if (presentation != ModalPresentation.dialog) {
    final answer = await Navigator.of(context).push<Object?>(PresentationRoute<Object?>(
      context: context,
      presentation: presentation,
      barrierDismissible: action.barrierDismissible,
      barrierColor: barrierColor ?? Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
      sheetWidth: look.number('sheetWidth'),
      cornerRadius: look.number('radius'),
      maxHeightFactor: look.numberOr('maxHeightFactor', 1),
      showDragHandle: look.flag('showDragHandle'),
      builder: buildDialog,
    ));
    return answer == true;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: action.barrierDismissible,
    barrierColor: barrierColor,
    builder: buildDialog,
  );
  return confirmed ?? false;
}

/// The built-in confirm dialog, in the app's look. Pops true when confirmed
/// and false when cancelled.
class ThemedConfirmDialog extends StatelessWidget {
  const ThemedConfirmDialog({
    super.key,
    required this.theme,
    this.presentation = ModalPresentation.dialog,
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
    this.stackButtons = false,
    this.titleMessageGap = 8,
    this.actionsGap = 20,
    this.buttonGap,
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

  /// Space inside the dialog's edge; null is 24 on top and the sides, 16
  /// at the bottom.
  final EdgeInsets? padding;

  /// Height of the buttons; null is 44.
  final double? buttonHeight;

  final BorderSide? confirmBorder, cancelBorder;

  /// An icon over the title (an icon glyph's JSON).
  final Json? icon;
  final double iconSize;

  /// Color of [icon]; null keeps its own, else the text color.
  final Color? iconColor;

  /// Fill of a circle behind [icon].
  final Color? iconDiscColor;
  final double iconDiscSize;
  final BorderSide? iconDiscBorder;

  /// Whether the icon, title and message are centered.
  final bool centered;

  /// Whether the buttons share the dialog's width equally.
  final bool expandButtons;

  /// Opt-in full-width vertical actions, confirm first then cancel.
  /// Takes precedence over [expandButtons]; false preserves native layout.
  final bool stackButtons;

  /// Space between title and message, and between content and actions.
  final double titleMessageGap, actionsGap;

  /// Action spacing. Null keeps 8px for stacked/plain actions, and the
  /// existing 12px for expanded rows or bordered/shadowed horizontal actions.
  final double? buttonGap;

  final ResolvedFeedbackTheme theme;

  /// A centered dialog, or the content of a bottom or side sheet (whose
  /// route places and clips it).
  final ModalPresentation presentation;

  final String title, caption, message, confirmLabel, cancelLabel;
  final api.TextStyle? captionStyle, titleStyle, messageStyle, buttonStyle;
  final bool destructive;
  final Color? backgroundColor, textColor, confirmColor;
  final double? cornerRadius;
  final BorderSide? border;
  final List<BoxShadow>? shadows;
  final double? buttonRadius;
  final BorderSide? buttonBorder;

  /// The cancel button takes them only when it has a [cancelColor].
  final List<BoxShadow>? buttonShadows;
  final Color? confirmTextColor, cancelColor, cancelTextColor;

  @override
  Widget build(BuildContext context) {
    final surface = backgroundColor ?? theme.surface;
    final onSurface = textColor ?? (backgroundColor == null ? theme.onSurface : ResolvedFeedbackTheme.onColor(surface));
    final confirmFill = confirmColor ?? (destructive ? theme.error : theme.primary);
    final radius = cornerRadius ?? theme.radius;
    final buttonCorner = buttonRadius ?? theme.buttonRadius;
    final buttonSide = buttonBorder ?? theme.buttonBorder ?? BorderSide.none;
    final buttonShadowList = buttonShadows ?? theme.buttonShadows ?? const <BoxShadow>[];
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonCorner));
    final buttonText = applyTextStyle(buttonStyle, theme.buttonStyle.copyWith(fontSize: 15, height: 1.2));
    final onConfirm = buttonStyle?.color?.flutter ?? confirmTextColor ?? ResolvedFeedbackTheme.onColor(confirmFill);
    final onCancel = buttonStyle?.color?.flutter ?? cancelTextColor ?? onSurface;
    // A set height is the buttons' height exactly, not just their least.
    final buttonSize = Size(64, buttonHeight ?? 44);
    final buttonMaxSize = buttonHeight == null ? null : Size(double.infinity, buttonHeight!);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 18);
    final dialogSide = border ?? theme.border;
    final dialogShadows = shadows ?? theme.shadows;

    Widget withShadow(Widget button) => buttonShadowList.isEmpty
        ? button
        : DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(buttonCorner), boxShadow: buttonShadowList),
            child: button,
          );

    final cancel = TextButton(
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
        tapTargetSize: buttonHeight == null ? null : MaterialTapTargetSize.shrinkWrap,
        padding: buttonPadding,
      ),
      child: Text(cancelLabel),
    );
    final confirm = FilledButton(
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
        tapTargetSize: buttonHeight == null ? null : MaterialTapTargetSize.shrinkWrap,
        padding: buttonPadding,
      ),
      child: Text(confirmLabel),
    );
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    Widget? leading = icon == null
        ? null
        : feedbackIcon(
            iconColor == null ? icon! : {...icon!, 'color': api.Color(iconColor!.toARGB32()).toJson()},
            iconSize,
            onSurface,
            key: const ValueKey('codelessly-confirm-icon'),
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
          border: iconDiscBorder == null ? null : Border.fromBorderSide(iconDiscBorder!),
        ),
        child: leading,
      );
    }
    final buttons = [cancelColor != null ? withShadow(cancel) : cancel, withShadow(confirm)];

    final Widget content = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title.isEmpty ? null : title,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading, const SizedBox(height: 16)],
            if (caption.isNotEmpty) ...[
              Text(
                caption,
                textAlign: textAlign,
                style: applyTextStyle(
                  captionStyle,
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
                style: applyTextStyle(titleStyle, theme.titleStyle.copyWith(fontSize: 18, height: 1.3, color: onSurface)),
              ),
            if (title.isNotEmpty && message.isNotEmpty) SizedBox(height: titleMessageGap),
            if (message.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    textAlign: textAlign,
                    style: applyTextStyle(
                      messageStyle,
                      theme.bodyStyle.copyWith(fontSize: 15, height: 1.45, color: onSurface.withValues(alpha: 0.74)),
                    ),
                  ),
                ),
              ),
            SizedBox(height: actionsGap),
            if (stackButtons)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [buttons[1], SizedBox(height: buttonGap ?? 8), buttons[0]],
              )
            else if (expandButtons)
              Row(children: [Expanded(child: buttons[0]), SizedBox(width: buttonGap ?? 12), Expanded(child: buttons[1])])
            else
              OverflowBar(
                alignment: centered ? MainAxisAlignment.center : MainAxisAlignment.end,
                overflowAlignment: centered ? OverflowBarAlignment.center : OverflowBarAlignment.end,
                // Outlined or shadowed buttons need room between them.
                spacing: buttonGap ?? (buttonShadowList.isEmpty && confirmBorder == null && cancelBorder == null ? 8 : 12),
                overflowSpacing: buttonGap ?? 8,
                children: buttons,
              ),
          ],
        ),
      ),
    );

    // Shadows of its own replace the dialog's elevation: drawn around a box
    // that carries its fill and outline.
    final widest = maxWidth ?? 400;
    Widget body = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widest),
      child: width == null ? content : SizedBox(width: math.min(width!, widest), child: content),
    );
    if (dialogShadows != null) {
      body = DecoratedBox(
        key: const ValueKey('codelessly-confirm-surface'),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radius),
          border: dialogSide == null ? null : Border.fromBorderSide(dialogSide),
          boxShadow: dialogShadows,
        ),
        child: body,
      );
    }

    return Theme(
      data: theme.apply(Theme.of(context)),
      child: switch (presentation) {
        ModalPresentation.bottomSheet || ModalPresentation.adaptive => SizedBox(
            width: double.infinity,
            child: Material(
              color: surface,
              child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.only(top: 8), child: content)),
            ),
          ),
        ModalPresentation.sideSheet => Material(
            color: surface,
            child: SafeArea(left: false, child: Align(alignment: Alignment.topLeft, child: content)),
          ),
        _ => Dialog(
            backgroundColor: dialogShadows != null ? Colors.transparent : surface,
            surfaceTintColor: Colors.transparent,
            shadowColor: dialogShadows != null ? Colors.transparent : null,
            elevation: dialogShadows != null ? 0 : 8,
            insetPadding: insets ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: dialogShadows == null ? dialogSide ?? BorderSide.none : BorderSide.none,
            ),
            child: body,
          ),
      },
    );
  }
}
