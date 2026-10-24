import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../codelessly_sdk.dart';
import 'action_chain.dart';

/// Shows [ShowToastAction] messages: a toast near the bottom or top of the
/// screen that fades in, stays for the action's duration and fades out. A
/// new toast replaces the one on screen.
///
/// The toast takes the app's look ([FeedbackTheme.of]): its font, and the
/// color of its [ShowToastAction.style]. It can carry a button, e.g. Undo,
/// that runs [ShowToastAction.actions].
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  /// Shows [action]'s message. Returns false when there is no overlay to
  /// show it in.
  static bool show(BuildContext context, ShowToastAction action) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

    // Read variables and the look now: the action that follows may navigate
    // away.
    final ScopedValues scopedValues = ActionChain.scopedValuesOf(context);
    String text(String value) => PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    final String message = text(action.message);
    final String actionLabel = action.hasAction ? text(action.actionLabel) : '';
    final ResolvedFeedbackTheme theme = FeedbackTheme.of(context);
    // Without a font of its own, the toast takes the app's text style at
    // the trigger, not Material's default.
    final TextStyle appText = DefaultTextStyle.of(context).style;
    final String? themeFamily = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.fontFamily;
    final TextStyle appFont =
        theme.bodyStyle.fontFamily == themeFamily && appText.fontFamily != null
        ? theme.bodyStyle.copyWith(
            fontFamily: appText.fontFamily,
            fontFamilyFallback: appText.fontFamilyFallback,
          )
        : theme.bodyStyle;
    final TextStyle font = fontOf(action, appFont);
    final double? offset = offsetOf(action, scopedValues);
    // The button's actions run on the chain that showed the toast, whenever
    // it is pressed: with its captured scope (the `${item}` of a row that has
    // since left the list) and its `${result}` then (e.g. the id of the item
    // an Undo restores), on the first of its hosts still mounted. See
    // [ActionChain.defer].
    final VoidCallback? onAction = actionLabel.trim().isEmpty
        ? null
        : ActionChain.defer(
            context,
            (context) =>
                FunctionsRepository.runActions(context, action.actions),
            label: 'The toast button "$actionLabel"',
          );

    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        action: action,
        message: message,
        actionLabel: actionLabel,
        theme: theme,
        font: font,
        offset: offset,
        onAction: onAction,
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    return true;
  }

  /// The message's text style: [base] in [ShowToastAction.fontFamily] (a
  /// Google font or one the project loaded) and [ShowToastAction.fontWeight]
  /// when set. Without a weight it is semibold.
  static TextStyle fontOf(ShowToastAction action, TextStyle base) {
    final FontWeight weight =
        action.fontWeight?.flutterFontWeight ?? FontWeight.w600;
    final String family = action.fontFamily?.trim() ?? '';
    if (family.isEmpty) return base.copyWith(fontWeight: weight);
    if (GoogleFonts.asMap().containsKey(family)) {
      return GoogleFonts.getFont(family, textStyle: base, fontWeight: weight);
    }
    return base.copyWith(
      fontFamily: family,
      fontFamilyFallback: const <String>[],
      fontWeight: weight,
    );
  }

  /// The distance from the screen edge [action]'s bound
  /// [ShowToastAction.offset] gives, read with [scopedValues], or null when
  /// it is empty or not a number.
  static double? offsetOf(ShowToastAction action, ScopedValues scopedValues) {
    final String template = action.offset.trim();
    if (template.isEmpty) return null;
    final Object? value =
        FormulaEvaluator.exactExpression(template) != null ||
            RegExp(r'^\$\{[^{}]+\}$').hasMatch(template)
        ? PropertyValueDelegate.getVariableValueFromPath<Object>(
            template,
            scopedValues: scopedValues,
          )
        : PropertyValueDelegate.substituteVariables(
            template,
            scopedValues: scopedValues,
            nullSubstitutionMode: NullSubstitutionMode.emptyString,
          );
    return value.toDouble();
  }

  /// Removes the toast on screen, if any.
  static void hide() {
    final OverlayEntry? entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  /// The background and text colors of a toast of [style] in [theme].
  static (Color background, Color foreground) colorsOf(
    ToastStyle style,
    ResolvedFeedbackTheme theme,
  ) {
    final Color background = switch (style) {
      // Like a snackbar: the app's text color as the background.
      ToastStyle.neutral => Color.alphaBlend(
        theme.onSurface.withValues(alpha: 0.92),
        theme.surface,
      ),
      ToastStyle.info => theme.primary,
      ToastStyle.success => theme.success,
      ToastStyle.warning => theme.warning,
      ToastStyle.error => theme.error,
    };
    final Color foreground = switch (style) {
      ToastStyle.neutral => theme.surface,
      ToastStyle.info => theme.onPrimary,
      ToastStyle.error => theme.onError,
      _ => ResolvedFeedbackTheme.onColor(background),
    };
    return (background, foreground);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.action,
    required this.message,
    required this.actionLabel,
    required this.theme,
    required this.font,
    required this.offset,
    required this.onAction,
    required this.onDone,
  });

  final ShowToastAction action;
  final String message;
  final String actionLabel;
  final ResolvedFeedbackTheme theme;
  final TextStyle font;
  final double? offset;
  final VoidCallback? onAction;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  static const Duration _fade = Duration(milliseconds: 220);

  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _timer = Timer(Duration(milliseconds: widget.action.duration), _close);
  }

  void _close() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _visible = false);
    _timer = Timer(_fade, widget.onDone);
  }

  void _onActionPressed() {
    _close();
    widget.onAction?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShowToastAction action = widget.action;
    final ResolvedFeedbackTheme theme = widget.theme;
    final (Color styleBackground, Color styleForeground) = AppToast.colorsOf(
      action.style,
      theme,
    );
    final Color background =
        action.backgroundColor?.toFlutterColor() ?? styleBackground;
    final Color textColor =
        action.textColor?.toFlutterColor() ??
        (action.backgroundColor == null
            ? styleForeground
            : ResolvedFeedbackTheme.onColor(background));
    final Widget? icon = action.icon == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(color: textColor),
            child: retrieveIconWidget(action.icon!, 18) ?? const SizedBox(),
          );
    final bool hasButton = widget.onAction != null;
    final bool hasClose = action.showClose;
    final bool top = action.position == ToastPosition.top;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double fontSize = action.fontSize ?? 14;
    final Color actionColor = action.actionColor?.toFlutterColor() ?? textColor;
    final TextStyle messageStyle = widget.font.copyWith(
      color: textColor,
      fontSize: fontSize,
      height: 1.35,
      decoration: TextDecoration.none,
    );

    Widget toast = Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 560),
      padding: EdgeInsets.fromLTRB(18, 10, hasButton || hasClose ? 4 : 18, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          action.cornerRadius ??
              (hasButton ? theme.buttonRadius.clamp(8, 999) : 999),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 8)],
          Flexible(child: Text(widget.message, style: messageStyle)),
          if (hasButton) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('codelessly-toast-action'),
              onPressed: _onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: theme.buttonStyle.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.buttonRadius),
                ),
              ),
              child: Text(widget.actionLabel),
            ),
          ],
          if (hasClose) ...[
            if (!hasButton) const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('codelessly-toast-close'),
              onPressed: _close,
              tooltip: 'Close',
              color: textColor,
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
    toast = Semantics(
      liveRegion: true,
      container: true,
      label: widget.message,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: _fade,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : Offset(0, top ? -0.25 : 0.25),
          duration: _fade,
          curve: Curves.easeOutCubic,
          child: Center(
            child: Material(type: MaterialType.transparency, child: toast),
          ),
        ),
      ),
    );

    return Positioned(
      left: 16,
      right: 16,
      top: top ? safe.top + (widget.offset ?? 16) : null,
      bottom: top ? null : widget.offset ?? action.bottomOffset,
      // Only a toast with a button takes taps; the rest passes them through.
      child: IgnorePointer(
        ignoring: !(hasButton || hasClose) || !_visible,
        child: toast,
      ),
    );
  }
}
