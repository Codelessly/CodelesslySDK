// Show toast actions: a toast near the bottom or top of the screen that
// fades and slides in, stays for the action's duration and fades out. A new
// toast replaces the one on screen.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, ShowToastAction, ToastPosition, ToastStyle;
import 'package:flutter/material.dart';

import '../../render/paint/icon_names.dart';
import 'feedback_icon.dart';
import 'feedback_theme.dart';

/// What a show toast action shows, its text and bindings already evaluated
/// where the action ran (the chain may navigate away right after).
@immutable
class ToastRequest {
  const ToastRequest(
    this.action, {
    required this.message,
    this.title = '',
    this.actionLabel = '',
    this.bound = const {},
    this.onAction,
    this.breakpoints,
  });

  final ShowToastAction action;

  /// The project's breakpoints, which per-breakpoint look values
  /// (`alignments`, `sideMargins`, `bottomOffsets`) are keyed by; null:
  /// [api.Breakpoints.defaults].
  final api.Breakpoints? breakpoints;
  final String message, title, actionLabel;

  /// [ShowToastAction.variables] evaluated, by key (colors, `icon`,
  /// `duration`), and the look's `offset` evaluated.
  final Map<String, Object?> bound;

  /// Runs the button's actions; null: no button.
  final VoidCallback? onAction;
}

/// Names the overlay toasts of the app below it show in, instead of the
/// root overlay: an app embedded in another (the editor's run preview)
/// keeps its toasts in its own window.
class ToastOverlayScope extends InheritedWidget {
  const ToastOverlayScope({super.key, required this.overlay, required super.child});

  final GlobalKey<OverlayState> overlay;

  static OverlayState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ToastOverlayScope>()?.overlay.currentState;

  @override
  bool updateShouldNotify(ToastOverlayScope oldWidget) => oldWidget.overlay != overlay;
}

/// The color fields a toast's `variables` can bind. `borderColor` colors
/// the border (a 1px one when there's none).
const toastBindableColors = [
  'backgroundColor',
  'textColor',
  'messageColor',
  'accentColor',
  'iconColor',
  'iconDiscColor',
  'actionColor',
  'actionBackgroundColor',
  'closeColor',
  'borderColor',
];

/// The value [values] (a per-breakpoint look value: breakpoint id or name →
/// value) gives a screen [width] wide, by the project's [breakpoints]
/// (DESIGN.md §5.3): the entry of its breakpoint's id, else of its name or
/// name key; null when it has none.
Object? perBreakpointValue(Map<String, Object?>? values, double width, api.Breakpoints breakpoints) {
  if (values == null || values.isEmpty) return null;
  final b = breakpoints.forWidth(width);
  return values[b.id] ?? values[b.name] ?? values[b.key];
}

abstract final class CodelesslyToast {
  static OverlayEntry? _current;

  /// The barriers of the dialogs and sheets open over the toast, newest
  /// last ([ToastBelowRoute]). The toast lives in the root overlay, above
  /// every route, so it paints each barrier's color over itself, as the
  /// barrier would if it covered it, and stops taking taps while one is up.
  static final ValueNotifier<List<ModalRoute<Object?>>> covers = ValueNotifier(const []);

  static void _cover(ModalRoute<Object?> route) => covers.value = [...covers.value, route];
  static void _uncover(ModalRoute<Object?> route) => covers.value = [
        for (final r in covers.value)
          if (r != route) r,
      ];

  /// The icon [action] shows: its `icon` binding naming a Material icon
  /// (in the action icon's size and color), else its own icon. A binding
  /// that names nothing keeps the action's icon (or none).
  static Json? iconOf(ShowToastAction action, Map<String, Object?> bound) {
    if (!action.variables.containsKey('icon')) return action.icon;
    final name = '${bound['icon'] ?? ''}'.trim();
    if (name.isEmpty) return action.icon;
    final base = action.icon ?? const {'source': 'icon', 'size': 18, 'color': '#000000'};
    final named = iconWithName(base, name);
    return identical(named, base) ? action.icon : named;
  }

  /// How long the toast stays, in milliseconds: its `duration` binding,
  /// else the action's. Zero or less keeps it until it's closed or
  /// replaced.
  static int durationOf(ShowToastAction action, Map<String, Object?> bound) {
    if (!action.variables.containsKey('duration') || action.variables['duration']!.trim().isEmpty) return action.durationMs;
    return numberValue(bound['duration'])?.round() ?? action.durationMs;
  }

  /// The message's text style: [base] in the look's font family and
  /// weight (semibold without one).
  static TextStyle fontForAction(ShowToastAction action, TextStyle base) {
    final look = Look(action.style);
    final w = look.number('fontWeight')?.round();
    final weight = w == null ? FontWeight.w600 : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)];
    final family = look.string('fontFamily')?.trim() ?? '';
    if (family.isEmpty) return base.copyWith(fontWeight: weight);
    return base.copyWith(fontFamily: family, fontFamilyFallback: const <String>[], fontWeight: weight);
  }

  /// The background and text colors of a toast of [style] in [theme].
  static (Color, Color) colorsOf(ToastStyle style, ResolvedFeedbackTheme theme) {
    final background = switch (style) {
      // Like a snackbar: the app's text color as the background.
      ToastStyle.neutral => Color.alphaBlend(theme.onSurface.withValues(alpha: 0.92), theme.surface),
      ToastStyle.info => theme.primary,
      ToastStyle.success => theme.success,
      ToastStyle.warning => theme.warning,
      ToastStyle.error => theme.error,
    };
    final foreground = switch (style) {
      ToastStyle.neutral => theme.surface,
      ToastStyle.info => theme.onPrimary,
      ToastStyle.error => theme.onError,
      _ => ResolvedFeedbackTheme.onColor(background),
    };
    return (background, foreground);
  }

  /// Shows [request]'s toast over [context]. False when there's no overlay
  /// to show it in.
  static bool show(BuildContext context, ToastRequest request) {
    final overlay = ToastOverlayScope.maybeOf(context) ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;
    final action = request.action;
    final theme = FeedbackTheme.of(context);
    final bound = request.bound;
    final hasButton = request.actionLabel.trim().isNotEmpty && request.onAction != null;

    hide();
    // A toast shown from a dialog or sheet (its "Password needed") sits
    // above that one's barrier: only those opened after it cover it.
    final shownOver = List<ModalRoute<Object?>>.of(covers.value);
    late final OverlayEntry entry;
    // The toast's buttons take the layout's look, not the app's theme the
    // overlay is in.
    final themeData = theme.themeData;
    entry = OverlayEntry(
      builder: (context) => Theme(data: themeData, child: _ToastView(
        shownOver: shownOver,
        action: action,
        message: request.message,
        title: request.title.trim().isEmpty ? '' : request.title,
        icon: iconOf(action, bound),
        colors: boundColors(bound, toastBindableColors),
        actionLabel: hasButton ? request.actionLabel : '',
        theme: theme,
        font: fontForAction(action, theme.bodyStyle),
        offset: numberValue(bound['offset']),
        duration: durationOf(action, bound),
        onAction: hasButton ? request.onAction : null,
        breakpoints: request.breakpoints ?? api.Breakpoints.defaults,
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      )),
    );
    _current = entry;
    overlay.insert(entry);
    return true;
  }

  /// Removes the toast on screen, if any.
  static void hide() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
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
    required this.breakpoints,
    required this.onDone,
    this.shownOver = const [],
  });

  /// The dialogs and sheets already open when it was shown: their barriers
  /// don't cover it.
  final List<ModalRoute<Object?>> shownOver;
  final ShowToastAction action;
  final api.Breakpoints breakpoints;
  final String message, title;
  final Json? icon;
  final Map<String, Color> colors;
  final String actionLabel;
  final ResolvedFeedbackTheme theme;
  final TextStyle font;
  final double? offset;
  final int duration;
  final VoidCallback? onAction;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ApiCurve extends Curve {
  const _ApiCurve(this.curve);
  final api.AnimationCurve curve;

  @override
  double transformInternal(double t) => curve.transform(t);
}

class _ToastViewState extends State<_ToastView> {
  static const _fade = Duration(milliseconds: 220);

  bool _visible = false;

  /// Fading out: taps pass through.
  bool _closing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The time on screen counts from the toast's first frame: shown while
    // a screen's first frame is still being built (a load action), it would
    // otherwise run out before anyone saw it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
      if (widget.duration > 0 && !_closing) _timer = Timer(Duration(milliseconds: widget.duration), _close);
    });
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
    final action = widget.action;
    final look = Look(action.style);
    final theme = widget.theme;
    final (styleBackground, styleForeground) = CodelesslyToast.colorsOf(action.toastStyle, theme);
    final bound = widget.colors;
    final ownBackground = bound['backgroundColor'] ?? look.color('backgroundColor');
    final background = ownBackground ?? styleBackground;
    final textColor = bound['textColor'] ??
        look.color('textColor') ??
        (ownBackground == null ? styleForeground : ResolvedFeedbackTheme.onColor(background));
    final hasTitle = widget.title.trim().isNotEmpty;
    final ownMessageColor = bound['messageColor'] ?? look.color('messageColor');
    final accent = bound['accentColor'] ?? look.color('accentColor');
    // The icon's own color, unless the toast's iconColor is set.
    final iconColor = bound['iconColor'] ?? look.color('iconColor');
    final iconModel = iconColor == null || widget.icon == null
        ? widget.icon
        : {...widget.icon!, 'color': api.Color(iconColor.toARGB32()).toJson()};
    final iconDisc = bound['iconDiscColor'] ?? look.color('iconDiscColor');
    final iconSize = look.numberOr('iconSize', 18);
    Widget? icon = iconModel == null
        ? null
        : feedbackIcon(
            iconModel,
            // A toast icon size of its own wins over the icon's.
            iconSize != 18 ? iconSize : (numberValue(iconModel['size']) ?? 18),
            textColor,
          );
    final iconShadows = look.shadows('iconShadows') ?? const <BoxShadow>[];
    if (icon != null && iconDisc != null) {
      final disc = look.numberOr('iconDiscSize', 36);
      icon = Container(
        key: const ValueKey('codelessly-toast-icon-disc'),
        width: disc,
        height: disc,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconDisc,
          shape: BoxShape.circle,
          boxShadow: iconShadows.isEmpty ? null : iconShadows,
        ),
        child: icon,
      );
    } else if (icon != null && iconShadows.isNotEmpty) {
      // A halo round the icon itself: a small round icon becomes a lamp.
      icon = DecoratedBox(
        key: const ValueKey('codelessly-toast-icon-glow'),
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: iconShadows),
        child: icon,
      );
    }
    final hasButton = widget.onAction != null;
    final hasClose = action.showClose;
    final media = MediaQuery.of(context);
    final breakpoints = widget.breakpoints;
    final width = media.size.width;
    final alignment = perBreakpointValue(look.map('alignments'), width, breakpoints) as String? ?? look.string('alignment') ?? 'center';
    final maxWidth = look.numberOr('maxWidth', 560);
    final minWidth = look.numberOr('minWidth', 0);
    // A fixed-width card spreads its row like a stretched toast.
    final stretch = alignment == 'stretch' || (minWidth > 0 && minWidth >= maxWidth);
    final top = action.position == ToastPosition.top;
    final fontSize = look.numberOr('fontSize', 14);
    final font = widget.font;
    final messageLook = look.textStyle('messageStyle');
    final family = look.string('fontFamily')?.trim() ?? '';
    final textStyle = applyTextStyle(
      messageLook,
      font.copyWith(color: textColor, fontSize: fontSize, height: 1.35, decoration: TextDecoration.none),
    ).copyWith(fontFamily: family.isNotEmpty ? font.fontFamily : null);
    // Under a title the message is a fainter body line.
    final messageStyle = ownMessageColor != null
        ? textStyle.copyWith(color: ownMessageColor)
        : hasTitle && messageLook?.color == null
            ? textStyle.copyWith(color: textColor.withValues(alpha: 0.72))
            : textStyle;
    final titleStyle = applyTextStyle(
      look.textStyle('titleStyle'),
      textStyle.copyWith(color: textColor, fontWeight: FontWeight.w700, height: 1.25),
    );
    final actionColor = bound['actionColor'] ?? look.color('actionColor') ?? textStyle.color!;
    final actionLook = look.textStyle('actionStyle');
    final actionStyle = applyTextStyle(
      actionLook,
      theme.buttonStyle.merge(font).copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: actionColor,
            decoration: TextDecoration.none,
          ),
    );
    final closeColor = bound['closeColor'] ?? look.color('closeColor') ?? textStyle.color!;
    final cornerRadius = look.number('radius');
    final buttonRadius =
        cornerRadius != null ? (cornerRadius / 2).clamp(0, theme.buttonRadius).toDouble() : theme.buttonRadius;
    var outline = look.side('border');
    final borderColor = bound['borderColor'];
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
              Text(widget.title, key: const ValueKey('codelessly-toast-title'), style: titleStyle),
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

    final radius = BorderRadius.circular(cornerRadius ?? (hasButton ? theme.buttonRadius.clamp(8, 999).toDouble() : 999));
    final actionRadius = look.number('actionCornerRadius') ?? buttonRadius;
    final actionShadows = look.shadows('actionShadows');
    Widget toast = Container(
      key: const ValueKey('codelessly-toast'),
      constraints: BoxConstraints(minHeight: 44, minWidth: minWidth.clamp(0, maxWidth).toDouble(), maxWidth: maxWidth),
      padding: look.insets('padding') ??
          EdgeInsets.fromLTRB(
            accent == null ? 18 : 14,
            hasButton || hasClose ? 6 : 10,
            hasButton || hasClose ? 8 : 18,
            hasButton || hasClose ? 6 : 10,
          ),
      // The clip below rounds the accent bar and a differently colored
      // outline.
      decoration: BoxDecoration(
        color: background,
        borderRadius: accent == null && outline != null ? radius : null,
        border: accent == null
            ? (outline == null ? null : Border.fromBorderSide(outline))
            : Border(
                left: BorderSide(color: accent, width: look.numberOr('accentWidth', 4)),
                top: outline ?? BorderSide.none,
                right: outline ?? BorderSide.none,
                bottom: outline ?? BorderSide.none,
              ),
      ),
      child: Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[icon, SizedBox(width: iconDisc != null || hasTitle ? 12 : 8)],
          if (stretch) Expanded(child: texts) else Flexible(child: texts),
          if (hasButton) ...[
            const SizedBox(width: 8),
            _withShadows(
              TextButton(
                key: const ValueKey('codelessly-toast-action'),
                onPressed: _onActionPressed,
                style: TextButton.styleFrom(
                  foregroundColor: actionColor,
                  backgroundColor: bound['actionBackgroundColor'] ?? look.color('actionBackgroundColor'),
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // The action's own font size wins over the message's.
                  textStyle: actionLook?.fontSize != null ? actionStyle : actionStyle.copyWith(fontSize: fontSize),
                  side: look.side('actionBorder'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(actionRadius)),
                ),
                child: Text(widget.actionLabel),
              ),
              actionShadows,
              actionRadius,
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
                iconSize: 18,
                color: closeColor,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
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
        boxShadow: look.shadows('shadows') ??
            const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: ClipRRect(borderRadius: radius, child: _UnderBarriers(shownOver: widget.shownOver, child: toast)),
    );
    final enterOffset = look.numberOr('enterOffset', 0.25);
    final rotation = look.numberOr('rotation', 0);
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
          offset: _visible ? Offset.zero : Offset(0, top ? -enterOffset : enterOffset),
          duration: _fade,
          // Coming in on the action's curve; going out eases as before.
          curve: _visible
              ? _ApiCurve(api.AnimationCurve.parse(look.string('enterCurve')) ?? api.AnimationCurve.easeOutCubic)
              : Curves.easeOutCubic,
          child: Align(
            alignment: switch (alignment) {
              'start' => Alignment.centerLeft,
              'end' => Alignment.centerRight,
              _ => Alignment.center,
            },
            child: Material(
              type: MaterialType.transparency,
              child: rotation == 0 ? toast : Transform.rotate(angle: rotation * math.pi / 180, child: toast),
            ),
          ),
        ),
      ),
    );

    // A side margin is a number (both sides) or [left, right]: a toast
    // centered in the part of the screen beside a rail or sidebar.
    final sides = perBreakpointValue(look.map('sideMargins'), width, breakpoints);
    final sideMargin = numberValue(sides) ?? look.numberOr('sideMargin', 16);
    final (leftMargin, rightMargin) = switch (sides) {
      [final l, final r] when numberValue(l) != null && numberValue(r) != null => (numberValue(l)!, numberValue(r)!),
      _ => (sideMargin, sideMargin),
    };
    final bottomOffset =
        numberValue(perBreakpointValue(look.map('bottomOffsets'), width, breakpoints)) ?? look.numberOr('bottomOffset', 104);
    return Positioned(
      left: leftMargin,
      right: rightMargin,
      top: top ? media.padding.top + (widget.offset ?? 16) : null,
      bottom: top ? null : widget.offset ?? bottomOffset,
      // Only a toast with a button takes taps; the rest passes them through.
      child: ValueListenableBuilder<List<ModalRoute<Object?>>>(
        valueListenable: CodelesslyToast.covers,
        child: toast,
        builder: (context, covers, toast) => IgnorePointer(
          ignoring: !(hasButton || hasClose) || _closing || covers.any((r) => !widget.shownOver.contains(r)),
          child: toast,
        ),
      ),
    );
  }
}

/// [shadows] under a toast's action [button].
Widget _withShadows(Widget button, List<BoxShadow>? shadows, double radius) {
  if (shadows == null || shadows.isEmpty) return button;
  return DecoratedBox(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadows),
    child: button,
  );
}

/// Paints the barriers of [CodelesslyToast.covers] over [child], each as
/// far as its route has faded it in.
class _UnderBarriers extends StatelessWidget {
  const _UnderBarriers({required this.child, this.shownOver = const []});

  final Widget child;

  /// Routes the toast was shown over: their barriers stay under it.
  final List<ModalRoute<Object?>> shownOver;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<ModalRoute<Object?>>>(
        valueListenable: CodelesslyToast.covers,
        child: child,
        builder: (context, covers, child) {
          var result = child!;
          for (final route in covers) {
            if (shownOver.contains(route)) continue;
            final color = route.barrierColor;
            final animation = route.animation;
            if (color == null || color.a == 0) continue;
            result = AnimatedBuilder(
              animation: animation ?? kAlwaysCompleteAnimation,
              child: result,
              builder: (context, child) => DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(color: color.withValues(alpha: color.a * (animation?.value ?? 1))),
                child: child,
              ),
            );
          }
          return result;
        },
      );
}

/// The content of a dialog or sheet the runtime opens: while it's up, a
/// toast on screen is covered by its barrier ([CodelesslyToast.covers]).
class ToastBelowRoute extends StatefulWidget {
  const ToastBelowRoute({super.key, required this.child});

  final Widget child;

  @override
  State<ToastBelowRoute> createState() => _ToastBelowRouteState();
}

class _ToastBelowRouteState extends State<ToastBelowRoute> {
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) CodelesslyToast._uncover(_route!);
    _route = route;
    if (route != null && route.barrierColor != null) {
      // Not while building: the toast rebuilds on the change.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _route == route) CodelesslyToast._cover(route);
      });
    }
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => CodelesslyToast._uncover(route));
      WidgetsBinding.instance.scheduleFrame();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
