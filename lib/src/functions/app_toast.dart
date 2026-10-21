import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

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
    required this.onAction,
    required this.onDone,
  });

  final ShowToastAction action;
  final String message;
  final String actionLabel;
  final ResolvedFeedbackTheme theme;
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
    final bool top = action.position == ToastPosition.top;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final TextStyle messageStyle = theme.bodyStyle.copyWith(
      color: textColor,
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    );

    Widget toast = Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 560),
      padding: EdgeInsets.fromLTRB(18, 10, hasButton ? 8 : 18, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          hasButton ? theme.buttonRadius.clamp(8, 999) : 999,
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
                foregroundColor: textColor,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: theme.buttonStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.buttonRadius),
                ),
              ),
              child: Text(widget.actionLabel),
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
      top: top ? safe.top + 16 : null,
      bottom: top ? null : action.bottomOffset,
      // Only a toast with a button takes taps; the rest passes them through.
      child: IgnorePointer(ignoring: !hasButton || !_visible, child: toast),
    );
  }
}
