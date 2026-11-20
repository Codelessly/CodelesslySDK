// The look of the UI the runtime draws itself (toasts, the confirm dialog):
// the app's fonts, primary color, surface and corner radii, read from the
// project's theme tokens and the layout's own nodes.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show ButtonProps, LayoutDocument, Node, TextProps, TriggerType;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../../render/controls/buttons.dart' show ButtonSpec;
import '../../render/controls/tokens.dart' show ControlTokens;

import '../../runtime/actions/look.dart';

export '../../runtime/actions/look.dart';

import '../../render/control_theme.dart' as theme show onColor;
import '../../render/control_theme.dart' show SurfaceRoles, ThemeTokensScope, bodyTextStyle, chromeButton, contrastRatio, isDarkSurface, kInk, kInkOnDark, rolesOf;
import '../../render/convert.dart';

/// The look of the runtime's own dialogs and toasts. A layout provides one
/// read from its nodes ([FeedbackTheme.fromDocument]) and its theme tokens
/// through a [FeedbackThemeScope]; an app's theme doesn't reach it.
@immutable
class FeedbackTheme {
  const FeedbackTheme({
    this.bodyStyle,
    this.titleStyle,
    this.buttonStyle,
    this.primary,
    this.onPrimary,
    this.surface,
    this.onSurface,
    this.error,
    this.success,
    this.warning,
    this.radius,
    this.buttonRadius,
    this.border,
    this.shadows,
    this.buttonBorder,
    this.buttonShadows,
    this.titleSize,
    this.messageSize,
    this.buttonHeight,
    this.cancelBorder,
  });

  /// A design system's sizes for a dialog's title and message, and its
  /// buttons' height (null: the runtime's own, 18, 15 and 44).
  final double? titleSize, messageSize, buttonHeight;

  /// The outline of a dialog's cancel button (a design system's secondary
  /// button); null: a text button.
  final BorderSide? cancelBorder;

  /// Fonts (no size or color) of messages, titles and button labels.
  final TextStyle? bodyStyle, titleStyle, buttonStyle;

  final Color? primary, onPrimary, surface, onSurface, error, success, warning;

  /// Corner radius of dialogs, of buttons.
  final double? radius, buttonRadius;

  /// Outline and shadows of dialogs (shadows replace the elevation).
  final BorderSide? border;
  final List<BoxShadow>? shadows;

  /// Outline and shadows of buttons.
  final BorderSide? buttonBorder;
  final List<BoxShadow>? buttonShadows;

  /// This theme's missing values from [other].
  FeedbackTheme merge(FeedbackTheme? other) {
    if (other == null) return this;
    return FeedbackTheme(
      bodyStyle: bodyStyle ?? other.bodyStyle,
      titleStyle: titleStyle ?? other.titleStyle,
      buttonStyle: buttonStyle ?? other.buttonStyle,
      primary: primary ?? other.primary,
      onPrimary: onPrimary ?? other.onPrimary,
      surface: surface ?? other.surface,
      onSurface: onSurface ?? other.onSurface,
      error: error ?? other.error,
      success: success ?? other.success,
      warning: warning ?? other.warning,
      radius: radius ?? other.radius,
      buttonRadius: buttonRadius ?? other.buttonRadius,
      border: border ?? other.border,
      shadows: shadows ?? other.shadows,
      buttonBorder: buttonBorder ?? other.buttonBorder,
      buttonShadows: buttonShadows ?? other.buttonShadows,
      titleSize: titleSize ?? other.titleSize,
      messageSize: messageSize ?? other.messageSize,
      buttonHeight: buttonHeight ?? other.buttonHeight,
      cancelBorder: cancelBorder ?? other.cancelBorder,
    );
  }

  /// The look at [context], every value set: the layout's
  /// ([FeedbackThemeScope]), then the colors and font of the layout's theme
  /// tokens (neutral without).
  static ResolvedFeedbackTheme of(BuildContext context) => ResolvedFeedbackTheme.resolve(
        FeedbackThemeScope.maybeOf(context) ?? const FeedbackTheme(),
        rolesOf(context),
        fontFamily: ThemeTokensScope.maybeOf(context)?.tokens.fontFamily,
      );

  /// The look a project's [tokens] set.
  factory FeedbackTheme.fromTokens(api.ThemeTokens? tokens) {
    if (tokens == null || tokens.isEmpty) return const FeedbackTheme();
    tokens = tokens.resolvedRoles();
    Color? color(api.Color? c) => c?.flutter;
    final body = tokens.fontFamily == null ? null : TextStyle(fontFamily: tokens.fontFamily);
    return FeedbackTheme(
      bodyStyle: body,
      // Titles and button labels in the theme's font keep their weight (a
      // style given here replaces the resolved default's semibold).
      buttonStyle: body?.copyWith(fontWeight: FontWeight.w600),
      titleStyle: tokens.titleFontFamily == null ? body?.copyWith(fontWeight: FontWeight.w600) : TextStyle(fontFamily: tokens.titleFontFamily, fontWeight: FontWeight.w600),
      primary: color(tokens.primary),
      onPrimary: color(tokens.onPrimary),
      surface: color(tokens.surface),
      onSurface: color(tokens.onSurface),
      error: color(tokens.error),
      success: color(tokens.success),
      warning: color(tokens.warning),
      // A theme's look for what floats (`radii.dialog`, else `radii.popup`,
      // `shadows.popup`) and its large control's corner when it gives no one
      // buttonRadius.
      radius: tokens.radii['dialog'] ?? tokens.radii['popup'] ?? tokens.radius,
      // A design system's dialog: its title and body sizes, its control
      // height, and its secondary button's outline (Desk drew the runtime's
      // own 18 / 15 / 44 and a text button beside its outlined ones).
      titleSize: tokens.textStyles['dialogTitle']?.fontSize,
      messageSize: tokens.textStyles['dialogTitle'] == null ? null : tokens.textStyles['body']?.fontSize,
      buttonHeight: tokens.textStyles['dialogTitle'] == null ? null : tokens.sizes['control'],
      cancelBorder: switch (tokens.textStyles['dialogTitle'] == null ? null : tokens.color('secondaryBorder') ?? tokens.color('primaryBorder')) {
        final api.Color c => BorderSide(color: c.flutter),
        _ => null,
      },
      buttonRadius: tokens.buttonRadius ?? tokens.radii['controlLarge'],
      shadows: switch (tokens.shadows['popup']) {
        final List<api.Effect> e => [for (final s in e) if (s.visible) boxShadow(s)],
        _ => null,
      },
    );
  }

  /// The look of a layout read from its nodes: the font most of its text
  /// uses, the fill of its buttons (and tappable shapes), its canvas color,
  /// its text color, its buttons' corner radius, and the outline and shadow
  /// most tappable shapes share. Values it doesn't show stay null.
  factory FeedbackTheme.fromDocument(LayoutDocument document) {
    final familyWeight = <String, int>{};
    final styles = <(api.TextStyle, int)>[];
    final textColors = <int, int>{};
    final primaryVotes = <int, int>{};
    final radiusVotes = <int, int>{};
    final borderVotes = <BorderSide, int>{};
    final shadowVotes = <String, (List<BoxShadow>, int)>{};
    var tappableShapes = 0;
    api.TextStyle? buttonLabel;
    Color? surface;

    void vote(Map<int, int> votes, int key, int weight) => votes[key] = (votes[key] ?? 0) + weight;

    for (final node in document.nodes.values) {
      if (!node.visible) continue;
      switch (node.type) {
        case 'canvas':
          surface ??= _solidFill(node.decoration.fills);
        case 'text':
          final text = node.props.get(TextProps.text);
          final base = node.props.get(TextProps.style);
          final runs = node.props.get(TextProps.runs);
          final parts = runs.isEmpty
              ? [(base, text.length)]
              : [for (final r in runs) (base.merge(r.style), r.end - r.start)];
          for (final (style, length) in parts) {
            final weight = length.clamp(1, 1 << 20);
            final family = style.fontFamily ?? '';
            familyWeight[family] = (familyWeight[family] ?? 0) + weight;
            styles.add((style, weight));
            final c = style.color?.flutter;
            if (c != null && c.a > 0.5) vote(textColors, c.toARGB32(), weight);
          }
        case 'elevatedButton' || 'filledButton' || 'textButton' || 'outlinedButton':
          final style = node.props.get(ButtonProps.style);
          buttonLabel ??= style.textStyle;
          final radius = style.shape?.borderRadius.topLeft;
          if (radius != null) vote(radiusVotes, radius.round(), 1);
          if (node.type == 'elevatedButton' || node.type == 'filledButton') {
            final fill = style.backgroundColor?.flutter;
            // Buttons count more than other tappable shapes.
            if (fill != null) vote(primaryVotes, fill.toARGB32(), 3);
          }
        default:
          if (!_tappable(node)) break;
          final fill = _solidFill(node.decoration.fills);
          if (fill != null) {
            vote(primaryVotes, fill.toARGB32(), 1);
            tappableShapes++;
            final stroke = node.decoration.strokeWidth > 0 ? _solidFill(node.decoration.strokes) : null;
            if (stroke != null) {
              final side = BorderSide(color: stroke, width: node.decoration.strokeWidth);
              borderVotes[side] = (borderVotes[side] ?? 0) + 1;
            }
            final shadows = boxShadowsOf(node.decoration.effects);
            if (shadows.isNotEmpty) {
              final key = shadows.join();
              shadowVotes[key] = (shadows, (shadowVotes[key]?.$2 ?? 0) + 1);
            }
          }
          vote(radiusVotes, node.decoration.radius.topLeft.round(), 1);
      }
    }

    K? maxKey<K>(Iterable<MapEntry<K, int>> entries) {
      MapEntry<K, int>? best;
      for (final e in entries) {
        if (best == null || e.value > best.value) best = e;
      }
      return best?.key;
    }

    final family = maxKey(familyWeight.entries.where((e) => e.key.isNotEmpty));
    TextStyle? bodyStyle, titleStyle;
    if (family != null) {
      final ofFamily = styles.where((s) => s.$1.fontFamily == family).toList();
      int weightOf(api.TextStyle s) => (s.fontWeight ?? 400) ~/ 100;
      (api.TextStyle, int) best((api.TextStyle, int) a, (api.TextStyle, int) b, num Function((api.TextStyle, int)) by) =>
          by(b) > by(a) ? b : a;
      // The regular weight most of the text uses; the boldest, largest.
      final body = ofFamily.reduce((a, b) => best(a, b, (p) => p.$2 * 10 - (weightOf(p.$1) - 4).abs())).$1;
      final title = ofFamily.reduce((a, b) => best(a, b, (p) => weightOf(p.$1) * 1000 + (p.$1.fontSize ?? 14))).$1;
      bodyStyle = _fontOf(body);
      titleStyle = weightOf(title) > weightOf(body) ? _fontOf(title) : bodyStyle.copyWith(fontWeight: FontWeight.w600);
    }
    // Neutral paper-colored controls must not outvote the accent on a light canvas.
    // White remains a valid inferred accent on a dark canvas; explicit tokens win above.
    final lightSurface = surface == null || surface.computeLuminance() > .8;
    final primary = maxKey(primaryVotes.entries.where((e) =>
        e.key != surface?.toARGB32() && !(lightSurface && Color(e.key).computeLuminance() > .95)));
    final onSurface = maxKey(textColors.entries);
    final buttonRadius = maxKey(radiusVotes.entries);
    MapEntry<BorderSide, int>? border;
    for (final e in borderVotes.entries) {
      if (border == null || e.value > border.value) border = e;
    }
    (List<BoxShadow>, int)? shadows;
    for (final e in shadowVotes.values) {
      if (shadows == null || e.$2 > shadows.$2) shadows = e;
    }
    return FeedbackTheme(
      bodyStyle: bodyStyle,
      titleStyle: titleStyle,
      buttonStyle: buttonLabel?.fontFamily != null ? _fontOf(buttonLabel!) : bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      primary: primary == null ? null : Color(primary),
      surface: surface,
      onSurface: onSurface == null ? null : Color(onSurface),
      buttonRadius: buttonRadius?.toDouble(),
      buttonBorder: border != null && border.value * 2 > tappableShapes ? border.key : null,
      buttonShadows: shadows != null && shadows.$2 * 2 > tappableShapes ? shadows.$1 : null,
    );
  }

  static bool _tappable(Node node) => node.actions.any((r) => r.trigger.type == TriggerType.click);

  static TextStyle _fontOf(api.TextStyle s) {
    final weight = s.fontWeight;
    return TextStyle(
      fontFamily: s.fontFamily,
      fontFamilyFallback: FontDemand.fallbackOf(s.fontFamily, s.fontFamilyFallback),
      fontWeight: weight == null ? null : FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontStyle: s.fontStyle == api.FontStyle.italic ? FontStyle.italic : null,
    );
  }

  static Color? _solidFill(List<api.Paint> fills) {
    for (final p in fills.reversed) {
      if (!p.visible || p.type != api.PaintType.solid || p.color == null) continue;
      final c = p.color!.flutter;
      final color = c.withValues(alpha: c.a * p.opacity);
      if (color.a > 0.9) return color;
    }
    return null;
  }

  FeedbackTheme copyWith({
    TextStyle? bodyStyle,
    TextStyle? titleStyle,
    TextStyle? buttonStyle,
    Color? primary,
    Color? onPrimary,
    Color? surface,
    Color? onSurface,
    Color? error,
    Color? success,
    Color? warning,
    double? radius,
    double? buttonRadius,
    BorderSide? border,
    List<BoxShadow>? shadows,
    BorderSide? buttonBorder,
    List<BoxShadow>? buttonShadows,
    double? titleSize,
    double? messageSize,
    double? buttonHeight,
    BorderSide? cancelBorder,
  }) =>
      FeedbackTheme(
        bodyStyle: bodyStyle ?? this.bodyStyle,
        titleStyle: titleStyle ?? this.titleStyle,
        buttonStyle: buttonStyle ?? this.buttonStyle,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        surface: surface ?? this.surface,
        onSurface: onSurface ?? this.onSurface,
        error: error ?? this.error,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        radius: radius ?? this.radius,
        buttonRadius: buttonRadius ?? this.buttonRadius,
        border: border ?? this.border,
        shadows: shadows ?? this.shadows,
        buttonBorder: buttonBorder ?? this.buttonBorder,
        buttonShadows: buttonShadows ?? this.buttonShadows,
        titleSize: titleSize ?? this.titleSize,
        messageSize: messageSize ?? this.messageSize,
        buttonHeight: buttonHeight ?? this.buttonHeight,
        cancelBorder: cancelBorder ?? this.cancelBorder,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedbackTheme &&
      other.bodyStyle == bodyStyle &&
      other.titleStyle == titleStyle &&
      other.buttonStyle == buttonStyle &&
      other.primary == primary &&
      other.onPrimary == onPrimary &&
      other.surface == surface &&
      other.onSurface == onSurface &&
      other.error == error &&
      other.success == success &&
      other.warning == warning &&
      other.radius == radius &&
      other.buttonRadius == buttonRadius &&
      other.border == border &&
      listEquals(other.shadows, shadows) &&
      other.buttonBorder == buttonBorder &&
      listEquals(other.buttonShadows, buttonShadows) &&
      other.titleSize == titleSize &&
      other.messageSize == messageSize &&
      other.buttonHeight == buttonHeight &&
      other.cancelBorder == cancelBorder;

  @override
  int get hashCode => Object.hash(
        bodyStyle,
        titleStyle,
        buttonStyle,
        primary,
        onPrimary,
        surface,
        onSurface,
        error,
        success,
        warning,
        radius,
        buttonRadius,
        border,
        shadows == null ? null : Object.hashAll(shadows!),
        buttonBorder,
        buttonShadows == null ? null : Object.hashAll(buttonShadows!),
        Object.hash(titleSize, messageSize, buttonHeight, cancelBorder),
      );
}

/// A [FeedbackTheme] with every value set ([FeedbackTheme.of]).
@immutable
class ResolvedFeedbackTheme {
  const ResolvedFeedbackTheme._({
    required this.bodyStyle,
    required this.titleStyle,
    required this.buttonStyle,
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.onSurface,
    required this.error,
    required this.onError,
    required this.success,
    required this.warning,
    required this.radius,
    required this.buttonRadius,
    required this.border,
    required this.shadows,
    required this.buttonBorder,
    required this.buttonShadows,
    this.titleSize,
    this.messageSize,
    this.buttonHeight,
    this.cancelBorder,
  });

  /// [t] with every value set: what it leaves out from the theme's [roles]
  /// and [fontFamily].
  factory ResolvedFeedbackTheme.resolve(FeedbackTheme t, SurfaceRoles roles, {String? fontFamily}) {
    final scheme = roles;
    final surface = t.surface ?? scheme.surface;
    final dark = isDarkSurface(surface);
    var onSurface = t.onSurface ?? scheme.onSurface;
    // Text the layout uses on another background may not read here.
    if (contrastRatio(onSurface, surface) < 3) onSurface = dark ? kInkOnDark : kInk;
    final primary = t.primary ?? scheme.primary;
    final buttonRadius = t.buttonRadius ?? 12;
    final base = bodyTextStyle(api.ThemeTokens(fontFamily: fontFamily), scheme.onSurface);
    final body = base.merge(t.bodyStyle);
    return ResolvedFeedbackTheme._(
      bodyStyle: body,
      titleStyle: t.titleStyle != null ? base.merge(t.titleStyle) : body.copyWith(fontWeight: FontWeight.w600),
      buttonStyle: t.buttonStyle != null ? base.merge(t.buttonStyle) : body.copyWith(fontWeight: FontWeight.w600),
      primary: primary,
      onPrimary: t.onPrimary ?? onColor(primary),
      surface: surface,
      onSurface: onSurface,
      error: t.error ?? scheme.error,
      onError: onColor(t.error ?? scheme.error),
      success: t.success ?? const Color(0xFF1E8E3E),
      warning: t.warning ?? const Color(0xFFF2A600),
      radius: t.radius ?? (buttonRadius + 8).clamp(12, 28).toDouble(),
      buttonRadius: buttonRadius,
      border: t.border,
      shadows: t.shadows,
      buttonBorder: t.buttonBorder,
      buttonShadows: t.buttonShadows,
      titleSize: t.titleSize,
      messageSize: t.messageSize,
      buttonHeight: t.buttonHeight,
      cancelBorder: t.cancelBorder,
    );
  }

  final TextStyle bodyStyle, titleStyle, buttonStyle;
  final Color primary, onPrimary, surface, onSurface, error, onError, success, warning;
  final double radius, buttonRadius;
  final BorderSide? border;
  final List<BoxShadow>? shadows;
  final BorderSide? buttonBorder;
  final List<BoxShadow>? buttonShadows;
  final double? titleSize, messageSize, buttonHeight;
  final BorderSide? cancelBorder;

  /// Ink or near-white, whichever reads on [background].
  static Color onColor(Color background) => theme.onColor(background);

  /// This look's colors, fonts and radii as theme tokens: the theme of what
  /// a dialog or a toast shows.
  api.ThemeTokens get tokens => api.ThemeTokens(
        primary: _api(primary),
        onPrimary: _api(onPrimary),
        surface: _api(surface),
        onSurface: _api(onSurface),
        error: _api(error),
        success: _api(success),
        warning: _api(warning),
        fontFamily: bodyStyle.fontFamily,
        titleFontFamily: titleStyle.fontFamily,
        radius: radius,
        buttonRadius: buttonRadius,
      );

  /// Whether the look's surface is a dark one.
  bool get dark => isDarkSurface(surface);

  static api.Color _api(Color c) => api.Color(c.toARGB32());

  /// The tokens of the SDK's own controls in a dialog or a toast (their
  /// font, their timing, their states): this look's colors, fonts and radii.
  ControlTokens get controlTokens => ControlTokens.resolve(
        api.ThemeTokens(
          primary: _api(primary),
          onPrimary: _api(onPrimary),
          surface: _api(surface),
          onSurface: _api(onSurface),
          error: _api(error),
          fontFamily: bodyStyle.fontFamily,
          titleFontFamily: titleStyle.fontFamily,
          radius: radius,
          buttonRadius: buttonRadius,
        ),
        dark: dark,
      );

  /// One of the look's buttons, the SDK's stock button: [label] (or an
  /// [icon] alone) in [foreground] and [style] on [background].
  ButtonSpec button({
    String label = '',
    Map<String, Object?> icon = const {},
    required Color foreground,
    Color? background,
    TextStyle style = const TextStyle(),
    BorderSide? side,
    required double radius,
    EdgeInsets? padding,
    bool enabled = true,
    bool wrapLabel = false,
  }) =>
      chromeButton(
        tokens: controlTokens,
        label: label,
        icon: icon,
        foreground: foreground,
        background: background,
        style: style,
        side: side,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        padding: padding,
        enabled: enabled,
        wrapLabel: wrapLabel,
      );
}

/// Provides the [FeedbackTheme] of the layout below it.
class FeedbackThemeScope extends InheritedWidget {
  const FeedbackThemeScope({super.key, required this.theme, required super.child});

  final FeedbackTheme theme;

  static FeedbackTheme? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedbackThemeScope>()?.theme;

  @override
  bool updateShouldNotify(FeedbackThemeScope oldWidget) => theme != oldWidget.theme;
}
