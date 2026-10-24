import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// The look of the UI the runtime draws itself, such as the confirm dialog
/// and toasts: the app's fonts, primary color, surface and corner radius.
///
/// A layout provides one read from its own nodes ([FeedbackTheme.fromNodes])
/// through a [FeedbackThemeScope], so a dialog opened from a screen matches
/// that screen. An app can set any value by adding a [FeedbackTheme] to its
/// [ThemeData.extensions]; the values it sets win over the layout's.
@immutable
class FeedbackTheme extends ThemeExtension<FeedbackTheme> {
  /// Creates a [FeedbackTheme]. Null values fall back to the layout's look,
  /// then to the ambient [Theme].
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

  /// Font of messages, without size or color.
  final TextStyle? bodyStyle;

  /// Font of titles, without size or color.
  final TextStyle? titleStyle;

  /// Font of button labels, without size or color.
  final TextStyle? buttonStyle;

  /// Fill of primary buttons and info toasts.
  final Color? primary;

  /// Text on [primary].
  final Color? onPrimary;

  /// Background of dialogs.
  final Color? surface;

  /// Text on [surface].
  final Color? onSurface;

  /// Destructive buttons and error toasts.
  final Color? error;

  /// Success toasts.
  final Color? success;

  /// Warning toasts.
  final Color? warning;

  /// Corner radius of dialogs.
  final double? radius;

  /// Corner radius of buttons.
  final double? buttonRadius;

  /// Outline of dialogs.
  final BorderSide? border;

  /// Shadows of dialogs, in place of their elevation.
  final List<BoxShadow>? shadows;

  /// Outline of buttons.
  final BorderSide? buttonBorder;

  /// Shadows of filled buttons.
  final List<BoxShadow>? buttonShadows;

  /// Fills this theme's missing values from [other].
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

  /// The theme in effect at [context], with every value set: the app's
  /// [FeedbackTheme] extension, then the enclosing layout's, then [Theme].
  static ResolvedFeedbackTheme of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FeedbackTheme combined =
        (theme.extension<FeedbackTheme>() ?? const FeedbackTheme()).merge(
          FeedbackThemeScope.maybeOf(context),
        );
    return ResolvedFeedbackTheme._resolve(combined, theme);
  }

  /// The look a project's theme sets ([ThemeTokens], published with its
  /// layouts). Tokens it doesn't set stay null.
  factory FeedbackTheme.fromTokens(ThemeTokens? tokens) {
    if (tokens == null || tokens.isEmpty) return const FeedbackTheme();
    Color? color(ColorRGBA? value) => value?.toFlutterColor();
    final TextStyle? body = tokens.fontFamily == null
        ? null
        : TextStyle(fontFamily: tokens.fontFamily);
    return FeedbackTheme(
      bodyStyle: body,
      buttonStyle: body,
      titleStyle: tokens.titleFontFamily == null
          ? body
          : TextStyle(fontFamily: tokens.titleFontFamily),
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

  /// Reads the look of a layout from its [nodes]: the font most of its text
  /// uses, the fill of its buttons, its canvas color and its text color.
  ///
  /// Values the layout does not show stay null.
  factory FeedbackTheme.fromNodes(Iterable<BaseNode> nodes) {
    final Map<String, int> familyWeight = {};
    final List<(TextProp, int)> props = [];
    final Map<int, int> textColors = {};
    final Map<int, int> primaryVotes = {};
    final Map<int, int> radiusVotes = {};
    // Outlines and shadows of tappable shapes, keyed by their look.
    final Map<BorderSide, int> buttonBorderVotes = {};
    final Map<String, (List<BoxShadow>, int)> buttonShadowVotes = {};
    int tappableShapes = 0;
    TextProp? buttonLabel;
    Color? surface;

    void vote(Map<int, int> votes, int key, int weight) =>
        votes[key] = (votes[key] ?? 0) + weight;

    for (final BaseNode node in nodes) {
      if (!node.visible) continue;
      switch (node) {
        case CanvasNode canvas:
          surface ??= _solidFill(canvas.fills);
        case TextNode text:
          for (final StartEndProp prop in text.textMixedProps) {
            final int length = (prop.end - prop.start).clamp(1, 1 << 20);
            familyWeight[prop.fontName.family] =
                (familyWeight[prop.fontName.family] ?? 0) + length;
            props.add((prop, length));
            final Color? color = TextUtils.retrievePropColor(prop);
            if (color != null && color.a > 0.5) {
              vote(textColors, color.toARGB32(), length);
            }
          }
        case ButtonNode button:
          final ButtonProperties properties = button.properties;
          buttonLabel ??= properties.labelStyle;
          vote(radiusVotes, properties.cornerRadius.tl.x.round(), 1);
          switch (properties.buttonType) {
            case ButtonTypeEnum.elevated ||
                ButtonTypeEnum.filled ||
                ButtonTypeEnum.filledTonal:
              // Buttons count more than other tappable shapes.
              vote(
                primaryVotes,
                properties.effectiveButtonColor.toFlutterColor().toARGB32(),
                3,
              );
            case ButtonTypeEnum.text ||
                ButtonTypeEnum.outlined ||
                ButtonTypeEnum.icon:
              break;
          }
        case SceneNode scene
            when scene is GeometryMixin &&
                scene.reactions.any(
                  (Reaction r) => r.trigger.type == TriggerType.click,
                ):
          // A tappable shape with a solid fill is a button too.
          final GeometryMixin shape = scene as GeometryMixin;
          final Color? fill = _solidFill(shape.fills);
          if (fill != null) {
            vote(primaryVotes, fill.toARGB32(), 1);
            tappableShapes++;
            final Color? stroke = shape.strokeWeight > 0
                ? _solidFill(shape.strokes)
                : null;
            if (stroke != null) {
              final BorderSide side = BorderSide(
                color: stroke,
                width: shape.strokeWeight,
              );
              buttonBorderVotes[side] = (buttonBorderVotes[side] ?? 0) + 1;
            }
            if (scene is BlendMixin) {
              final List<BoxShadow> shadows = boxShadowsOf(
                (scene as BlendMixin).effects,
              );
              if (shadows.isNotEmpty) {
                final String key = shadows.join();
                buttonShadowVotes[key] = (
                  shadows,
                  (buttonShadowVotes[key]?.$2 ?? 0) + 1,
                );
              }
            }
          }
          if (scene is CornerMixin) {
            vote(
              radiusVotes,
              (scene as CornerMixin).cornerRadius.tl.x.round(),
              1,
            );
          }
        default:
          break;
      }
    }

    // The family most of the text uses, and its regular and boldest styles.
    final String? family = maxBy(
      familyWeight.entries,
      (MapEntry<String, int> e) => e.value,
    )?.key;
    TextStyle? bodyStyle;
    TextStyle? titleStyle;
    if (family != null) {
      final List<(TextProp, int)> ofFamily = props
          .where((p) => p.$1.fontName.family == family)
          .toList();
      int weightOf(TextProp prop) =>
          (prop.fontName.weight ?? FontWeightNumeric.w400).index;
      final TextProp body = maxBy(
        ofFamily,
        // Prefer the regular weight most of the text uses.
        ((TextProp, int) p) =>
            p.$2 * 10 - (weightOf(p.$1) - FontWeightNumeric.w400.index).abs(),
      )!.$1;
      final TextProp title = maxBy(
        ofFamily,
        ((TextProp, int) p) => weightOf(p.$1) * 1000 + p.$1.fontSize,
      )!.$1;
      bodyStyle = _fontOf(body);
      titleStyle = weightOf(title) > weightOf(body)
          ? _fontOf(title)
          : bodyStyle.copyWith(fontWeight: FontWeight.w600);
    }

    final int? primary = maxBy(
      primaryVotes.entries.where((e) => e.key != surface?.toARGB32()),
      (MapEntry<int, int> e) => e.value,
    )?.key;
    final int? onSurface = maxBy(
      textColors.entries,
      (MapEntry<int, int> e) => e.value,
    )?.key;
    final int? buttonRadius = maxBy(
      radiusVotes.entries,
      (MapEntry<int, int> e) => e.value,
    )?.key;

    // Outlined, stamped buttons: when most tappable shapes share an outline
    // or a shadow, so do the dialog's buttons.
    final MapEntry<BorderSide, int>? buttonBorder = maxBy(
      buttonBorderVotes.entries,
      (MapEntry<BorderSide, int> e) => e.value,
    );
    final (List<BoxShadow>, int)? buttonShadows = maxBy(
      buttonShadowVotes.values,
      ((List<BoxShadow>, int) e) => e.$2,
    );

    return FeedbackTheme(
      bodyStyle: bodyStyle,
      titleStyle: titleStyle,
      buttonStyle: buttonLabel != null
          ? _fontOf(buttonLabel)
          : bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      primary: primary == null ? null : Color(primary),
      surface: surface,
      onSurface: onSurface == null ? null : Color(onSurface),
      buttonRadius: buttonRadius?.toDouble(),
      buttonBorder:
          buttonBorder != null && buttonBorder.value * 2 > tappableShapes
          ? buttonBorder.key
          : null,
      buttonShadows:
          buttonShadows != null && buttonShadows.$2 * 2 > tappableShapes
          ? buttonShadows.$1
          : null,
    );
  }

  static TextStyle _fontOf(TextProp prop) {
    final TextStyle style = TextUtils.retrieveTextStyle(
      fontName: prop.fontName,
    );
    // Keep the font only: dialogs and toasts set their own size and color.
    return TextStyle(
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
    );
  }

  static Color? _solidFill(List<PaintModel> fills) {
    for (final PaintModel paint in fills.reversed) {
      if (!paint.visible || paint.type != PaintType.solid) continue;
      final Color? color = paint.toFlutterColor();
      if (color != null && color.a > 0.9) return color;
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
  }) => FeedbackTheme(
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

/// A [FeedbackTheme] with every value set, see [FeedbackTheme.of].
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

  factory ResolvedFeedbackTheme._resolve(FeedbackTheme t, ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final Color surface = t.surface ?? scheme.surface;
    final bool dark =
        ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    Color onSurface = t.onSurface ?? scheme.onSurface;
    // Text the layout uses on a different background may not read here.
    if (_contrast(onSurface, surface) < 3) {
      onSurface = dark ? Colors.white : const Color(0xFF1C1B1F);
    }
    final Color primary = t.primary ?? scheme.primary;
    final double buttonRadius = t.buttonRadius ?? 12;
    final TextStyle base = theme.textTheme.bodyMedium ?? const TextStyle();
    final TextStyle body = base.merge(t.bodyStyle);
    return ResolvedFeedbackTheme._(
      bodyStyle: body,
      titleStyle: t.titleStyle != null
          ? base.merge(t.titleStyle)
          : body.copyWith(fontWeight: FontWeight.w600),
      buttonStyle: t.buttonStyle != null
          ? base.merge(t.buttonStyle)
          : body.copyWith(fontWeight: FontWeight.w600),
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

  /// Font of messages, without size or color.
  final TextStyle bodyStyle;

  /// Font of titles, without size or color.
  final TextStyle titleStyle;

  /// Font of button labels, without size or color.
  final TextStyle buttonStyle;

  /// Fill of primary buttons and info toasts.
  final Color primary;

  /// Text on [primary].
  final Color onPrimary;

  /// Background of dialogs.
  final Color surface;

  /// Text on [surface].
  final Color onSurface;

  /// Destructive buttons and error toasts.
  final Color error;

  /// Text on [error].
  final Color onError;

  /// Success toasts.
  final Color success;

  /// Warning toasts.
  final Color warning;

  /// Corner radius of dialogs.
  final double radius;

  /// Corner radius of buttons.
  final double buttonRadius;

  /// Outline of dialogs, if any.
  final BorderSide? border;

  /// Shadows of dialogs in place of their elevation, if set.
  final List<BoxShadow>? shadows;

  /// Outline of buttons, if any.
  final BorderSide? buttonBorder;

  /// Shadows of filled buttons, if any.
  final List<BoxShadow>? buttonShadows;

  /// Black or white, whichever reads on [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1C1B1F);

  static double _contrast(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) /
        (la > lb ? lb + 0.05 : la + 0.05);
  }

  /// A [ThemeData] whose color scheme and fonts are this theme's, for the
  /// Material widgets inside a dialog or toast.
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
    textTheme: theme.textTheme.apply(
      fontFamily: bodyStyle.fontFamily,
      fontFamilyFallback: bodyStyle.fontFamilyFallback,
    ),
  );
}

/// Provides the [FeedbackTheme] of the layout below it.
class FeedbackThemeScope extends InheritedWidget {
  /// Creates a [FeedbackThemeScope].
  const FeedbackThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// The layout's look.
  final FeedbackTheme theme;

  /// The nearest layout's look, if any.
  static FeedbackTheme? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedbackThemeScope>()?.theme;

  @override
  bool updateShouldNotify(FeedbackThemeScope oldWidget) =>
      theme != oldWidget.theme;
}

/// The visible drop shadows of [effects] as [BoxShadow]s.
List<BoxShadow> boxShadowsOf(Iterable<Effect>? effects) => [
  for (final Effect effect in effects ?? const <Effect>[])
    if (effect.type == EffectType.dropShadow && effect.visible)
      BoxShadow(
        color: effect.color?.toFlutterColor() ?? const Color(0x40000000),
        offset: Offset(
          effect.offset?.x.toDouble() ?? 0,
          effect.offset?.y.toDouble() ?? 0,
        ),
        blurRadius: effect.radius,
        spreadRadius: effect.spread ?? 0,
      ),
];

/// [model] as a Flutter [BorderSide]; [BorderSide.none] for a border of
/// style none.
BorderSide borderSideOf(BorderSideModel model) =>
    model.style == BorderStyleEnum.none || model.width <= 0
    ? BorderSide.none
    : BorderSide(color: model.color.toFlutterColor(), width: model.width);

/// Applies a [TextStyleModel] to a Flutter [TextStyle].
extension TextStyleModelApply on TextStyleModel? {
  /// [base] with this style's values in place of its own. A font family
  /// loads like a text node's, Google Fonts included.
  TextStyle applyTo(TextStyle base) {
    final TextStyleModel? model = this;
    if (model == null) return base;
    TextStyle style = base;
    final FontName? font = model.fontName;
    if (font != null) {
      final TextStyle loaded = TextUtils.retrieveTextStyle(fontName: font);
      style = style.copyWith(
        fontFamily: loaded.fontFamily,
        fontFamilyFallback: loaded.fontFamilyFallback,
        fontWeight: loaded.fontWeight,
        fontStyle: loaded.fontStyle,
      );
    } else {
      if (model.fontWeight != null) {
        style = style.copyWith(
          fontWeight: FontWeight.values[model.fontWeight!.index],
        );
      }
      if (model.italic != null) {
        style = style.copyWith(
          fontStyle: model.italic! ? FontStyle.italic : FontStyle.normal,
        );
      }
    }
    return style.copyWith(
      fontSize: model.fontSize,
      height: model.lineHeight,
      letterSpacing: model.letterSpacing,
      color: model.color?.toFlutterColor(),
    );
  }
}
