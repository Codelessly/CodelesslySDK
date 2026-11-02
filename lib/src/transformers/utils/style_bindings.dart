import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';

import 'property_value_delegate.dart';
import 'scoped_values.dart';

/// The style properties, beyond `fill`, `stroke`, `opacity`, `width` and
/// `height`, that conditions, bound variables or formulas can set at runtime.
///
/// Each is a key of [BaseNode.variables] whose value is a variable path or a
/// formula, e.g. `variables['strokeWeight'] = '${= selected ? 2 : 1}'`:
///
/// * [effectsVisible] (bool): shows or hides every effect of the node.
/// * [effectVisible] `effect-visible-<effectId>` (bool): shows or hides one
///   effect. Wins over [effectsVisible].
/// * [effectsColor] (color): the color of every drop and inner shadow.
/// * [shadowColor] `shadow-color-<effectId>` (color): the color of one
///   shadow. Wins over [effectsColor].
/// * [effectsOffsetX], [effectsOffsetY], [effectsSpread] (number): the
///   offset and spread of every drop and inner shadow.
/// * [effectsBlur] (number): the blur radius of every effect.
/// * [strokeWeight] (number): the node's stroke width.
/// * [cornerRadius] (number): the radius of every corner. A corner radius
///   JSON value (e.g. `[8, true, 'circular']`) is accepted too.
/// * [fontWeight] (number 100-900, or `w700`, `bold`, `normal`): the weight
///   of every span of a text node.
/// * [fontSize] (number): the font size of every span of a text node, e.g.
///   `${= screen.isMobile ? 40 : 66}`.
/// * [letterSpacing] (number in pixels, `"-2%"` of the font size,
///   `"-0.02em"`, or a letter spacing JSON map): every span's letter spacing.
/// * [lineHeight] (a multiplier up to 4 such as `1.1`, else pixels such as
///   `28`; `"28px"`, `"120%"` or `"1.2x"`; `"auto"`; or a line height JSON
///   map): every span's line height.
/// * [fontFamily] (string): the font family of every span, a Google Fonts
///   name such as `Inter`. Each span keeps its weight and style.
/// * [textAlign] (string): the horizontal alignment of a text node: `left`,
///   `center`, `right`, `justified` (or `justify`), `start` or `end`.
/// * [icon] (string): the name of the icon an icon node shows, in the
///   naming of its icon model (`star`, `star_border`, ...). Its family and
///   style stay. An icon model JSON map replaces the icon as a whole.
abstract final class StyleBindings {
  /// Shows or hides every effect of the node.
  static const String effectsVisible = 'effectsVisible';

  /// The color of every drop and inner shadow.
  static const String effectsColor = 'effectsColor';

  /// The x offset of every drop and inner shadow.
  static const String effectsOffsetX = 'effectsOffsetX';

  /// The y offset of every drop and inner shadow.
  static const String effectsOffsetY = 'effectsOffsetY';

  /// The blur radius of every effect.
  static const String effectsBlur = 'effectsBlur';

  /// The spread of every drop and inner shadow.
  static const String effectsSpread = 'effectsSpread';

  /// The stroke width of the node.
  static const String strokeWeight = 'strokeWeight';

  /// The radius of every corner of the node.
  static const String cornerRadius = 'cornerRadius';

  /// The font weight of every span of a text node.
  static const String fontWeight = 'fontWeight';

  /// The name of the icon an icon node shows.
  static const String icon = 'icon';

  /// The font size of every span of a text node.
  static const String fontSize = 'fontSize';

  /// The letter spacing of every span of a text node.
  static const String letterSpacing = 'letterSpacing';

  /// The line height of every span of a text node.
  static const String lineHeight = 'lineHeight';

  /// The font family of every span of a text node.
  static const String fontFamily = 'fontFamily';

  /// The horizontal alignment of a text node.
  static const String textAlign = 'textAlign';

  /// The bindable properties of a text node's style, beyond its color.
  static const List<String> textStyle = [
    fontWeight,
    fontSize,
    letterSpacing,
    lineHeight,
    fontFamily,
    textAlign,
  ];

  /// Shows or hides the effect [effectId].
  static String effectVisible(String effectId) => 'effect-visible-$effectId';

  /// The color of the shadow [effectId].
  static String shadowColor(String effectId) => 'shadow-color-$effectId';

  /// Adds to [patch], a partial node JSON, the values that the bindings of
  /// these properties give [node], evaluated with [scopedValues]. A property
  /// whose binding is missing, evaluates to null or gives the node's own
  /// value adds nothing.
  ///
  /// Text spans already in [patch] (a text's bound color) keep their
  /// changes.
  static void addTo(
    Map<String, dynamic> patch,
    BaseNode node, {
    required ScopedValues scopedValues,
  }) {
    T? value<T extends Object>(String property) =>
        PropertyValueDelegate.getPropertyValue<T>(
          node,
          property,
          scopedValues: scopedValues,
        );

    if (node is BlendMixin && node.effects.isNotEmpty) {
      final List<Effect> effects = _effects(node.effects, value);
      if (!const ListEquality<Effect>().equals(effects, node.effects)) {
        patch['effects'] = [for (final effect in effects) effect.toJson()];
      }
    }

    if (node is GeometryMixin) {
      final double? weight = value<double>(strokeWeight);
      if (weight != null && weight != node.strokeWeight) {
        patch['strokeWeight'] = weight < 0 ? 0.0 : weight;
      }
    }

    if (node is CornerMixin) {
      final CornerRadius? radius = _cornerRadius(value<Object>(cornerRadius));
      if (radius != null && radius != node.cornerRadius) {
        patch['cornerRadius'] = radius.toJson();
      }
    }

    if (node is TextNode) {
      final FontWeightNumeric? weight = parseFontWeight(
        value<Object>(fontWeight),
      );
      final double? size = _fontSize(value<Object>(fontSize));
      final LetterSpacing? spacing = parseLetterSpacing(
        value<Object>(letterSpacing),
      );
      final LineHeight? height = parseLineHeight(value<Object>(lineHeight));
      final String? family = _fontFamily(value<Object>(fontFamily));
      bool differs(StartEndProp prop) =>
          (weight != null && prop.fontName.weight != weight) ||
          (family != null && prop.fontName.family != family) ||
          (size != null && prop.fontSize != size) ||
          (spacing != null && prop.letterSpacing != spacing) ||
          (height != null && prop.lineHeight != height);
      if (node.textMixedProps.any(differs)) {
        final List spans =
            patch['textMixedProps'] as List? ??
            [for (final prop in node.textMixedProps) prop.toJson()];
        patch['textMixedProps'] = [
          for (final (int index, Map span) in spans.cast<Map>().indexed)
            {
              ...span,
              // A span's JSON leaves out a default font name.
              if (weight != null || family != null)
                'fontName': node.textMixedProps[index].fontName
                    .copyWith(weight: weight, family: family)
                    .toJson(),
              'fontSize': ?size,
              if (spacing != null) 'letterSpacing': spacing.toJson(),
              if (height != null) 'lineHeight': height.toJson(),
            },
        ];
      }
      final TextAlignHorizontalEnum? align = parseTextAlign(
        value<Object>(textAlign),
      );
      if (align != null && align != node.textAlignHorizontal) {
        patch['textAlignHorizontal'] = align.name;
      }
    }

    if (node is IconNode) {
      final IconModel? bound = _icon(
        node.properties.icon.icon,
        value<Object>(icon),
      );
      if (bound != null && bound != node.properties.icon.icon) {
        final Map? properties = patch['properties'] as Map?;
        final Map current = properties ?? node.properties.toJson();
        patch['properties'] = {
          ...current,
          'icon': {
            ...(current['icon'] as Map? ?? node.properties.icon.toJson()),
            'icon': bound.toJson(),
          },
        };
      }
    }
  }

  static List<Effect> _effects(
    List<Effect> effects,
    T? Function<T extends Object>(String property) value,
  ) {
    final bool? allVisible = value<bool>(effectsVisible);
    final ColorRGBA? color = value<ColorRGBA>(effectsColor);
    final double? offsetX = value<double>(effectsOffsetX);
    final double? offsetY = value<double>(effectsOffsetY);
    final double? blur = value<double>(effectsBlur);
    final double? spread = value<double>(effectsSpread);

    return [
      for (final Effect effect in effects)
        () {
          final bool isShadow =
              effect.type == EffectType.dropShadow ||
              effect.type == EffectType.innerShadow;
          final bool visible =
              value<bool>(effectVisible(effect.id)) ??
              allVisible ??
              effect.visible;
          if (!isShadow) {
            return effect.copyWith(
              visible: visible,
              radius: blur == null || blur < 0 ? null : blur,
            );
          }
          final Vec offset = effect.offset ?? const Vec(0, 0);
          return effect.copyWith(
            visible: visible,
            color: value<ColorRGBA>(shadowColor(effect.id)) ?? color,
            offset: offsetX == null && offsetY == null
                ? null
                : Vec(offsetX ?? offset.x, offsetY ?? offset.y),
            radius: blur == null || blur < 0 ? null : blur,
            spread: spread,
          );
        }(),
    ];
  }

  static CornerRadius? _cornerRadius(Object? value) {
    if (value == null) return null;
    if (value is num || value is String) {
      final double? radius = value is num
          ? value.toDouble()
          : double.tryParse(value as String);
      if (radius == null) return null;
      return CornerRadius.all(
        RadiusModel.circular(radius < 0 ? 0 : radius),
        linked: true,
      );
    }
    try {
      return CornerRadius.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  /// The font weight [value] names: a number from 100 to 900 (rounded to the
  /// nearest hundred), `w700`, or a name such as `bold`, `normal` or
  /// `semibold`. Null when it names none.
  static FontWeightNumeric? parseFontWeight(Object? value) {
    if (value == null) return null;
    if (value is FontWeightNumeric) return value;
    num? number = value is num ? value : null;
    if (value is String) {
      final String text = value.trim().toLowerCase().replaceAll(
        RegExp('[ _-]'),
        '',
      );
      number =
          num.tryParse(text) ??
          num.tryParse(text.startsWith('w') ? text.substring(1) : '') ??
          switch (text) {
            'thin' || 'hairline' => 100,
            'extralight' || 'ultralight' => 200,
            'light' => 300,
            'normal' || 'regular' || 'plain' => 400,
            'medium' => 500,
            'semibold' || 'demibold' => 600,
            'bold' => 700,
            'extrabold' || 'ultrabold' => 800,
            'black' || 'heavy' => 900,
            _ => null,
          };
    }
    if (number == null || number.isNaN) return null;
    final int index = ((number / 100).round() - 1).clamp(0, 8);
    return FontWeightNumeric.values[index];
  }

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };

  static double? _fontSize(Object? value) {
    final double? size = _number(value);
    if (size == null || !size.isFinite || size <= 0) return null;
    return size;
  }

  static String? _fontFamily(Object? value) {
    if (value is! String) return null;
    final String family = value.trim();
    return family.isEmpty ? null : family;
  }

  /// The letter spacing [value] gives: a number of pixels, text with a unit
  /// (`"1.5px"`, `"-2%"` of the font size, `"-0.02em"`, which is `-2%`), or
  /// a letter spacing JSON map (`{value: -2, unit: percent}`). Null when it
  /// gives none.
  static LetterSpacing? parseLetterSpacing(Object? value) {
    switch (value) {
      case null:
        return null;
      case LetterSpacing():
        return value;
      case num():
        return value.isFinite ? LetterSpacing.pixels(value.toDouble()) : null;
      case Map():
        try {
          return LetterSpacing.fromJson(value);
        } catch (_) {
          return null;
        }
      case String():
        final String text = value.trim().toLowerCase();
        double? amount(String suffix) => text.endsWith(suffix)
            ? double.tryParse(
                text.substring(0, text.length - suffix.length).trim(),
              )
            : null;
        if (amount('%') case final double percent) {
          return LetterSpacing.percent(percent);
        }
        if (amount('em') case final double em) {
          return LetterSpacing.percent(_times100(em));
        }
        if ((amount('px') ?? double.tryParse(text)) case final double px) {
          return LetterSpacing.pixels(px);
        }
    }
    return null;
  }

  /// [times] as a percentage, without float noise (1.1 is 110, not
  /// 110.00000000000001).
  static double _times100(num times) => (times * 1e8).round() / 1e6;

  /// The largest number [parseLineHeight] reads as a multiplier of the font
  /// size; a larger one is pixels.
  static const double maxLineHeightMultiplier = 4;

  /// The line height [value] gives: a number, which is a multiplier of the
  /// font size up to [maxLineHeightMultiplier] (`1.1`, as the editor API's
  /// text `style` writes it) and pixels above it (`28`, as a span stores
  /// it); text with a unit (`"28px"`, `"120%"` of the font size, `"1.2x"` or
  /// `"1.2em"`, which are `120%`); `"auto"` (or 0) for the font's own; or a
  /// line height JSON map (`{value: 120, unit: percent}`). Null when it
  /// gives none.
  static LineHeight? parseLineHeight(Object? value) {
    switch (value) {
      case null:
        return null;
      case LineHeight():
        return value;
      case num():
        if (!value.isFinite || value < 0) return null;
        if (value == 0) return LineHeight.auto;
        // No text is set 4px apart, and no text 4 lines apart: a small
        // number is a multiplier, as the editor API's text style writes it.
        return value <= maxLineHeightMultiplier
            ? LineHeight.percent(_times100(value))
            : LineHeight.pixels(value.toDouble());
      case Map():
        try {
          return LineHeight.fromJson(value);
        } catch (_) {
          return null;
        }
      case String():
        final String text = value.trim().toLowerCase();
        if (text == 'auto' || text == 'normal') return LineHeight.auto;
        double? amount(String suffix) => text.endsWith(suffix)
            ? double.tryParse(
                text.substring(0, text.length - suffix.length).trim(),
              )
            : null;
        final double? percent =
            amount('%') ??
            switch (amount('x') ?? amount('em')) {
              final double times => _times100(times),
              null => null,
            };
        if (percent != null) {
          return percent <= 0 ? LineHeight.auto : LineHeight.percent(percent);
        }
        return parseLineHeight(amount('px') ?? double.tryParse(text));
    }
    return null;
  }

  /// The text alignment [value] names: `left`, `center`, `right`,
  /// `justified` (or `justify`), `start` or `end`, in any case. Null when it
  /// names none.
  static TextAlignHorizontalEnum? parseTextAlign(Object? value) {
    if (value is TextAlignHorizontalEnum) return value;
    if (value is! String) return null;
    final String name = value.trim().toLowerCase();
    if (name == 'justify') return TextAlignHorizontalEnum.justified;
    return TextAlignHorizontalEnum.values.firstWhereOrNull(
      (align) => align.name == name,
    );
  }

  /// The icon [value] names: [current] with the name [value] gives it, or
  /// the icon an icon model JSON [value] describes.
  static IconModel? _icon(IconModel? current, Object? value) {
    if (value == null) return null;
    if (value is Map) {
      try {
        return IconModel.fromJson(Map<String, dynamic>.from(value));
      } catch (_) {
        return null;
      }
    }
    final String name = value.toString().trim();
    if (name.isEmpty || current == null || name == current.name) {
      return null;
    }
    return switch (current) {
      // Google serves every Material icon at version 1; a later version of
      // one icon need not exist for another.
      final MaterialIcon icon => icon.copyWith(name: name, version: 1),
      final MaterialSymbol icon => icon.copyWith(name: name),
      _ => null,
    };
  }
}
