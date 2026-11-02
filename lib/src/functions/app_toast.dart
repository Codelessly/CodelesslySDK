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
/// color of its [ShowToastAction.style]. The action's own colors, fonts,
/// radius, border and shadows override that look. It can carry a button,
/// e.g. Undo, that runs [ShowToastAction.actions], and a close (×) button.
///
/// With a [ShowToastAction.title] the toast is a card: the bold title over
/// the message, after the icon (in a filled disc with
/// [ShowToastAction.iconDiscColor]). Colors bound in
/// [ShowToastAction.variables] are read when the toast shows (see
/// [ActionColorBindings]) and win over the action's own.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  /// The icon [action] shows with [scopedValues]: its `icon` binding
  /// (`variables: {"icon": "${toastNext.icon}"}`) naming a Material icon,
  /// such as `check_circle` or `info_outlined`, in [ShowToastAction.icon]'s
  /// size and colour, else [ShowToastAction.icon]. A binding that gives no
  /// name keeps the action's icon (or none).
  static MultiSourceIconModel? iconOf(
    ShowToastAction action,
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
        action.icon ?? const MultiSourceIconModel.icon(size: 18);
    final MultiSourceIconModel named = iconWithName(base, name);
    return identical(named, base) ? action.icon : named;
  }

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
    final String title = action.hasTitle ? text(action.title) : '';
    final Map<String, Color> colors = ActionColorBindings.resolve(
      action.variables,
      scopedValues,
      keys: ShowToastAction.bindableColors,
    );
    final MultiSourceIconModel? icon = iconOf(action, scopedValues);
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
    final TextStyle font = fontForAction(action, appFont);
    final double? offset = offsetOf(action, scopedValues);
    final int duration = durationOf(action, scopedValues);
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
        title: title,
        icon: icon,
        colors: colors,
        actionLabel: actionLabel,
        theme: theme,
        font: font,
        offset: offset,
        duration: duration,
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
  static TextStyle fontForAction(ShowToastAction action, TextStyle base) {
    final FontWeight weight =
        action.fontWeight?.flutterFontWeight ?? FontWeight.w600;
    final String family = action.fontFamily?.trim() ?? '';
    if (family.isEmpty) return base.copyWith(fontWeight: weight);
    if (GoogleFonts.asMap().containsKey(family)) {
      // The SDK's font resolver selects the loaded face for the requested
      // weight (including the semibold face) rather than just a family name.
      final TextStyle? resolved = fontOf(family);
      return base.copyWith(
        fontFamily: resolved?.fontFamily,
        fontFamilyFallback: resolved?.fontFamilyFallback,
        fontWeight: weight,
      );
    }
    final TextStyle? resolved = action.fontWeight == null
        ? fontOf(family)
        : null;
    return base.copyWith(
      fontFamily: resolved?.fontFamily ?? family,
      fontFamilyFallback: resolved?.fontFamilyFallback ?? const <String>[],
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

  /// How long [action]'s toast stays, in milliseconds: its `duration`
  /// binding (`variables: {"duration": "${= toast.sticky ? 0 : 6000}"}`)
  /// read with [scopedValues], else [ShowToastAction.duration]. Zero or less
  /// keeps the toast up until it is closed or replaced.
  static int durationOf(ShowToastAction action, ScopedValues scopedValues) {
    final String? binding = action.variables['duration'];
    if (binding == null || binding.trim().isEmpty) return action.duration;
    final Object? value =
        FormulaEvaluator.exactExpression(binding) != null ||
            RegExp(r'^\$\{[^{}]+\}$').hasMatch(binding)
        ? PropertyValueDelegate.getVariableValueFromPath<Object>(
            binding,
            scopedValues: scopedValues,
          )
        : binding;
    return value.toDouble()?.round() ?? action.duration;
  }

  /// Removes the toast on screen, if any.
  static void hide() {
    final OverlayEntry? entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  /// The font of [family], e.g. `Barlow`: a Google font or one the app
  /// loaded. Null when [family] is null or empty.
  static TextStyle? fontOf(String? family) {
    if (family == null || family.trim().isEmpty) return null;
    final TextStyle style = TextUtils.retrieveTextStyle(
      fontName: FontName(family: family.trim(), weight: FontWeightNumeric.w600),
    );
    return TextStyle(
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
    );
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
    required this.title,
    required this.icon,
    required this.colors,
    required this.actionLabel,
    required this.theme,
    required this.font,
    required this.offset,
    required this.duration,
    required this.onAction,
    required this.onDone,
  });

  final ShowToastAction action;
  final String message;

  /// The bold line above [message]; empty for none.
  final String title;

  /// The icon before the message: [ShowToastAction.icon], or the one its
  /// `icon` binding names.
  final MultiSourceIconModel? icon;

  /// Colors bound in [ShowToastAction.variables], by field name.
  final Map<String, Color> colors;
  final String actionLabel;
  final ResolvedFeedbackTheme theme;
  final TextStyle font;
  final double? offset;

  /// Milliseconds the toast stays; zero or less keeps it until closed.
  final int duration;
  final VoidCallback? onAction;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  static const Duration _fade = Duration(milliseconds: 220);

  bool _visible = false;

  /// Fading out: taps pass through. Fading in, the toast already takes them:
  /// its semantics stay as they are from the first frame, since the web
  /// engine keeps a node's stacking only while its siblings don't change.
  bool _closing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    if (widget.duration > 0) {
      _timer = Timer(Duration(milliseconds: widget.duration), _close);
    }
  }

  void _close() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _visible = false;
      _closing = true;
    });
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
    final Map<String, Color> bound = widget.colors;
    final Color? ownBackground =
        bound['backgroundColor'] ?? action.backgroundColor?.toFlutterColor();
    final Color background = ownBackground ?? styleBackground;
    final Color textColor =
        bound['textColor'] ??
        action.textColor?.toFlutterColor() ??
        (ownBackground == null
            ? styleForeground
            : ResolvedFeedbackTheme.onColor(background));
    final bool hasTitle = widget.title.trim().isNotEmpty;
    final Color? ownMessageColor =
        bound['messageColor'] ?? action.messageColor?.toFlutterColor();
    final Color? accent =
        bound['accentColor'] ?? action.accentColor?.toFlutterColor();
    // The icon's own color, unless [ShowToastAction.iconColor] is set, else
    // the message color.
    final Color? iconColor =
        bound['iconColor'] ?? action.iconColor?.toFlutterColor();
    final MultiSourceIconModel? iconModel = iconColor == null
        ? widget.icon
        : widget.icon?.copyWith(color: iconColor.toColorRGBA());
    final Color? iconDisc =
        bound['iconDiscColor'] ?? action.iconDiscColor?.toFlutterColor();
    Widget? icon = iconModel == null
        ? null
        : retrieveIconWidget(
            iconModel,
            // A toast icon size of its own wins over the icon's.
            action.iconSize != 18 ? action.iconSize : iconModel.size ?? 18,
            textColor,
          );
    if (icon != null && iconDisc != null) {
      icon = Container(
        key: const ValueKey('codelessly-toast-icon-disc'),
        width: action.iconDiscSize,
        height: action.iconDiscSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: iconDisc, shape: BoxShape.circle),
        child: icon,
      );
    }
    final bool hasButton = widget.onAction != null;
    final Map<dynamic, dynamic> options = action.toJson();
    final bool hasClose =
        action.showClose || options['showCloseButton'] == true;
    final MediaQueryData media = MediaQuery.of(context);
    final String alignment = action.alignmentFor(media.size.width).name;
    // A fixed-width card (minWidth up to maxWidth) spreads its row like a
    // stretched toast: the button and close sit at its end.
    final bool stretch =
        alignment == 'stretch' ||
        (action.minWidth > 0 && action.minWidth >= action.maxWidth);
    final bool top = action.position == ToastPosition.top;
    final double fontSize =
        action.fontSize ?? (options['fontSize'] as num?)?.toDouble() ?? 14;
    final TextStyle font = widget.font;
    final TextStyle textStyle = action.messageStyle
        .applyTo(
          font.copyWith(
            color: textColor,
            fontSize: fontSize,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
        )
        .copyWith(
          fontFamily: action.fontFamily?.trim().isNotEmpty == true
              ? font.fontFamily
              : null,
        );
    // Under a title the message is a fainter body line.
    final TextStyle messageStyle = ownMessageColor != null
        ? textStyle.copyWith(color: ownMessageColor)
        : hasTitle && action.messageStyle?.color == null
        ? textStyle.copyWith(color: textColor.withValues(alpha: 0.72))
        : textStyle;
    final TextStyle titleStyle = action.titleStyle.applyTo(
      textStyle.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
    final Color actionColor =
        bound['actionColor'] ??
        action.actionColor?.toFlutterColor() ??
        textStyle.color!;
    final TextStyle actionStyle = action.actionStyle.applyTo(
      theme.buttonStyle
          .merge(font)
          .copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: actionColor,
            decoration: TextDecoration.none,
          ),
    );
    final Color closeColor =
        bound['closeColor'] ??
        action.closeColor?.toFlutterColor() ??
        textStyle.color!;
    final double buttonRadius = action.cornerRadius != null
        ? (action.cornerRadius! / 2).clamp(0, theme.buttonRadius).toDouble()
        : theme.buttonRadius;
    BorderSide? outline = action.border == null
        ? null
        : borderSideOf(action.border!);
    final Color? borderColor = bound['borderColor'];
    if (borderColor != null) {
      outline = outline == null || outline == BorderSide.none
          ? BorderSide(color: borderColor)
          : outline.copyWith(color: borderColor);
    }

    final Widget texts = !hasTitle
        ? Text(widget.message, style: messageStyle)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                key: const ValueKey('codelessly-toast-title'),
                style: titleStyle,
              ),
              if (widget.message.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.message,
                  key: const ValueKey('codelessly-toast-message'),
                  style: messageStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          );

    final BorderRadius radius = BorderRadius.circular(
      action.cornerRadius ??
          (hasButton ? theme.buttonRadius.clamp(8, 999) : 999),
    );
    Widget toast = Container(
      key: const ValueKey('codelessly-toast'),
      constraints: BoxConstraints(
        minHeight: 44,
        minWidth: action.minWidth.clamp(0, action.maxWidth).toDouble(),
        maxWidth: action.maxWidth,
      ),
      padding:
          action.padding?.flutterEdgeInsets ??
          EdgeInsets.fromLTRB(
            accent == null ? 18 : 14,
            hasButton || hasClose ? 6 : 10,
            hasButton || hasClose ? 8 : 18,
            hasButton || hasClose ? 6 : 10,
          ),
      // Clip below rounds the accent bar and differently colored outline.
      decoration: BoxDecoration(
        color: background,
        borderRadius: accent == null && outline != null ? radius : null,
        border: accent == null
            ? (outline == null ? null : Border.fromBorderSide(outline))
            : Border(
                left: BorderSide(color: accent, width: action.accentWidth),
                top: outline ?? BorderSide.none,
                right: outline ?? BorderSide.none,
                bottom: outline ?? BorderSide.none,
              ),
      ),
      child: Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon,
            SizedBox(width: iconDisc != null || hasTitle ? 12 : 8),
          ],
          if (stretch) Expanded(child: texts) else Flexible(child: texts),
          if (hasButton) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('codelessly-toast-action'),
              onPressed: _onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: actionStyle.copyWith(fontSize: fontSize),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(buttonRadius),
                ),
              ),
              child: Text(widget.actionLabel),
            ),
          ],
          if (hasClose) ...[
            SizedBox(width: hasButton ? 0 : 8),
            Semantics(
              button: true,
              label: 'Dismiss',
              excludeSemantics: true,
              child: IconButton(
                key: const ValueKey('codelessly-toast-close'),
                onPressed: _close,
                tooltip: null,
                iconSize: 18,
                color: closeColor,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonRadius),
                  ),
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ],
      ),
    );
    toast = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: action.shadows != null
            ? boxShadowsOf(action.shadows)
            : const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: radius, child: toast),
    );
    toast = Semantics(
      liveRegion: true,
      container: true,
      label: hasTitle && widget.message.trim().isNotEmpty
          ? '${widget.title}. ${widget.message}'
          : hasTitle
          ? widget.title
          : widget.message,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        alwaysIncludeSemantics: true,
        duration: _fade,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : Offset(0, top ? -0.25 : 0.25),
          duration: _fade,
          curve: Curves.easeOutCubic,
          child: Align(
            alignment: switch (alignment) {
              'start' => Alignment.centerLeft,
              'end' => Alignment.centerRight,
              _ => Alignment.center,
            },
            child: Material(type: MaterialType.transparency, child: toast),
          ),
        ),
      ),
    );

    final double sideMargin = action.sideMarginFor(media.size.width);
    return Positioned(
      left: sideMargin,
      right: sideMargin,
      top: top ? media.padding.top + (widget.offset ?? 16) : null,
      bottom: top
          ? null
          : widget.offset ?? action.bottomOffsetFor(media.size.width),
      // Only a toast with a button takes taps; the rest passes them through.
      child: IgnorePointer(
        ignoring: !(hasButton || hasClose) || _closing,
        child: toast,
      ),
    );
  }
}
