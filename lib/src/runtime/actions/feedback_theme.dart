// The look of the UI the runtime draws itself (toasts, the confirm dialog):
// the app's fonts, primary color, surface and corner radii, read from the
// project's theme tokens and the layout's own nodes.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show ButtonProps, Json, LayoutDocument, Node, TextProps, TriggerType;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../render/convert.dart';

/// The look of the runtime's own dialogs and toasts. A layout provides one
/// read from its nodes ([FeedbackTheme.fromDocument]) and its theme tokens
/// through a [FeedbackThemeScope]; an app sets any value by adding a
/// [FeedbackTheme] to its [ThemeData.extensions], which wins.
@immutable
class FeedbackTheme extends ThemeExtension<FeedbackTheme> {
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
  });

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
    );
  }

  /// The theme at [context], every value set: the app's extension, then
  /// the layout's ([FeedbackThemeScope]), then [Theme].
  static ResolvedFeedbackTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final combined = (theme.extension<FeedbackTheme>() ?? const FeedbackTheme()).merge(FeedbackThemeScope.maybeOf(context));
    return ResolvedFeedbackTheme.resolve(combined, theme);
  }

  /// The look a project's [tokens] set.
  factory FeedbackTheme.fromTokens(api.ThemeTokens? tokens) {
    if (tokens == null || tokens.isEmpty) return const FeedbackTheme();
    Color? color(api.Color? c) => c?.flutter;
    final body = tokens.fontFamily == null ? null : TextStyle(fontFamily: tokens.fontFamily);
    return FeedbackTheme(
      bodyStyle: body,
      buttonStyle: body,
      titleStyle: tokens.titleFontFamily == null ? body : TextStyle(fontFamily: tokens.titleFontFamily),
      primary: color(tokens.primary),
      onPrimary: color(tokens.onPrimary),
      surface: color(tokens.surface),
      onSurface: color(tokens.onSurface),
      error: color(tokens.error),
      success: color(tokens.success),
      warning: color(tokens.warning),
      radius: tokens.radius,
      buttonRadius: tokens.buttonRadius,
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
      fontFamilyFallback: s.fontFamilyFallback,
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

  @override
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
      );

  @override
  FeedbackTheme lerp(FeedbackTheme? other, double t) {
    if (other == null) return this;
    return FeedbackTheme(
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      buttonStyle: TextStyle.lerp(buttonStyle, other.buttonStyle, t),
      primary: Color.lerp(primary, other.primary, t),
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t),
      surface: Color.lerp(surface, other.surface, t),
      onSurface: Color.lerp(onSurface, other.onSurface, t),
      error: Color.lerp(error, other.error, t),
      success: Color.lerp(success, other.success, t),
      warning: Color.lerp(warning, other.warning, t),
      radius: t < 0.5 ? radius : other.radius,
      buttonRadius: t < 0.5 ? buttonRadius : other.buttonRadius,
      border: t < 0.5 ? border : other.border,
      shadows: BoxShadow.lerpList(shadows, other.shadows, t),
      buttonBorder: t < 0.5 ? buttonBorder : other.buttonBorder,
      buttonShadows: BoxShadow.lerpList(buttonShadows, other.buttonShadows, t),
    );
  }

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
      listEquals(other.buttonShadows, buttonShadows);

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
  });

  factory ResolvedFeedbackTheme.resolve(FeedbackTheme t, ThemeData theme) {
    final scheme = theme.colorScheme;
    final surface = t.surface ?? scheme.surface;
    final dark = ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    var onSurface = t.onSurface ?? scheme.onSurface;
    // Text the layout uses on another background may not read here.
    if (_contrast(onSurface, surface) < 3) onSurface = dark ? Colors.white : const Color(0xFF1C1B1F);
    final primary = t.primary ?? scheme.primary;
    final buttonRadius = t.buttonRadius ?? 12;
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
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
    );
  }

  final TextStyle bodyStyle, titleStyle, buttonStyle;
  final Color primary, onPrimary, surface, onSurface, error, onError, success, warning;
  final double radius, buttonRadius;
  final BorderSide? border;
  final List<BoxShadow>? shadows;
  final BorderSide? buttonBorder;
  final List<BoxShadow>? buttonShadows;

  /// Black or white, whichever reads on [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : const Color(0xFF1C1B1F);

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  /// [theme] with this theme's colors and fonts, for the Material widgets
  /// in a dialog or toast.
  ThemeData apply(ThemeData theme) => theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: primary,
          onPrimary: onPrimary,
          surface: surface,
          onSurface: onSurface,
          error: error,
          onError: onError,
          surfaceTint: Colors.transparent,
        ),
        textTheme: theme.textTheme.apply(fontFamily: bodyStyle.fontFamily, fontFamilyFallback: bodyStyle.fontFamilyFallback),
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

// --- reading an action's look (JSON) ---------------------------------------

/// The visible drop shadows of [effects].
List<BoxShadow> boxShadowsOf(Iterable<api.Effect> effects) => [
      for (final e in effects)
        if (e.visible && e.type == api.EffectType.dropShadow) boxShadow(e),
    ];

/// An action look's values (`look` JSON), read leniently.
extension type const Look(Json json) {
  double? number(String key) => switch (json[key]) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s.trim()),
        _ => null,
      };
  double numberOr(String key, double fallback) => number(key) ?? fallback;
  bool flag(String key) => json[key] == true;
  String? string(String key) => json[key] is String ? json[key] as String : null;
  Color? color(String key) => api.Color.fromJson(json[key])?.flutter;

  /// A border side; [BorderSide.none] for one of style none or no width.
  BorderSide? side(String key) => borderSideOf(api.BorderSide.fromJson(json[key]));

  /// Drop shadows; null when unset (an empty list is set: no shadows).
  List<BoxShadow>? shadows(String key) => json[key] is List ? boxShadowsOf(api.Effect.listFromJson(json[key])) : null;
  EdgeInsets? insets(String key) => json[key] == null ? null : api.EdgeInsets.fromJson(json[key]).flutter;
  api.TextStyle? textStyle(String key) => json[key] is Map ? api.TextStyle.fromJson(json[key]) : null;
  Json? map(String key) => json[key] is Map ? (json[key] as Map).cast<String, Object?>() : null;
}

/// [side] as Flutter's; [BorderSide.none] for style none or no width.
BorderSide? borderSideOf(api.BorderSide? side) {
  if (side == null) return null;
  if (side.style == api.BorderStyle.none || side.width <= 0) return BorderSide.none;
  return BorderSide(color: side.color?.flutter ?? const Color(0xFF000000), width: side.width);
}

/// [base] with [style]'s set values over it.
TextStyle applyTextStyle(api.TextStyle? style, TextStyle base) {
  if (style == null) return base;
  final weight = style.fontWeight;
  return base.copyWith(
    fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
    fontWeight: weight == null ? null : FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
    fontStyle: style.fontStyle == null ? null : (style.fontStyle == api.FontStyle.italic ? FontStyle.italic : FontStyle.normal),
    fontSize: style.fontSize,
    height: style.height,
    letterSpacing: style.letterSpacing,
    color: style.color?.flutter,
  );
}

/// The color [value] (an evaluated binding: a color, a hex string, a
/// color's JSON) gives, or null.
Color? colorValue(Object? value) => switch (value) {
      null => null,
      final Color c => c,
      final api.Color c => c.flutter,
      final String s when s.trim().isEmpty => null,
      final String s => api.Color.fromJson(s.trim())?.flutter,
      _ => api.Color.fromJson(value)?.flutter,
    };

/// The colors of [bound] (evaluated bindings) at [keys].
Map<String, Color> boundColors(Map<String, Object?> bound, Iterable<String> keys) => {
      for (final k in keys)
        if (colorValue(bound[k]) case final Color c) k: c,
    };

/// [value] (an evaluated binding) as a number.
double? numberValue(Object? value) => switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim()),
      _ => null,
    };
