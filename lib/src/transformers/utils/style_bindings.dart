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
/// * [fontFamily] (string): the font family of every span of a text node
///   (of a text field's input and hint),
///   e.g. one per script: `${= uiLang == 'ar' ? 'IBM Plex Sans Arabic' :
///   'DM Serif Display'}`. Weights and styles stay.
/// * [fontSize] (number, logical pixels): the size of every span of a text
///   node, e.g. a counter that grows past 99: `${= count > 99 ? 28 : 36}`.
///   Line heights and letter spacings given in percent scale with it.
/// * [textDecoration] (`none`, `underline`, `overline`, `strikethrough`
///   or `lineThrough`, see [TextDecorationEnum.parse]; true strikes
///   through): the decoration of every span of a text node, e.g.
///   a done checklist item struck through.
/// * [letterSpacing] (number in pixels, `"-2%"` of the font size,
///   `"-0.02em"`, or a letter spacing JSON map): every span's letter spacing.
/// * [lineHeight] (a multiplier up to 4 such as `1.1`, else pixels such as
///   `28`; `"28px"`, `"120%"` or `"1.2x"`; `"auto"`; or a line height JSON
///   map): every span's line height.
/// * [textAlign] (string): the horizontal alignment of a text node: `left`,
///   `center`, `right`, `justified` (or `justify`), `start` or `end`.
/// * [spacing] (number): the gap between a row's or column's children,
///   e.g. `${= screen.isMobile ? 28 : 56}`.
/// * [runSpacing] (number): the gap between the runs of a wrapping row or
///   column.
/// * [icon] (string): the name of the icon an icon node shows, in the
///   naming of its icon model (`star`, `star_border`, ...). Its family and
///   style stay. An icon model JSON map replaces the icon as a whole.
/// * [fillStop] `fill-stop-<index>` (color): the color of one stop of the
///   node's first fill when it is a gradient, e.g. a halo whose center
///   follows the phase color. A `#RRGGBB` color keeps the stop's own alpha
///   (a 35% halo stays 35%); `#AARRGGBB` sets it too.
/// * [notchOffset] (number): the offset of every notch of a node with
///   [CornerMixin.notches], in the notch's own unit (pixels, or a fraction
///   of the edge when the notch is relative), e.g. a ticket whose tear line
///   follows the screen width: `${146 * screen.width / 340}`.
/// * [notchOffsetAt] `notch-offset-<index>` (number): the offset of the
///   notch at index (0-based) of [CornerMixin.notches]. Wins over
///   [notchOffset].
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

  /// The font family of every span of a text node.
  static const String fontFamily = 'fontFamily';

  /// The font size of every span of a text node.
  static const String fontSize = 'fontSize';

  /// The decoration of every span of a text node.
  static const String textDecoration = 'textDecoration';

  /// The gap between a row's or column's children.
  static const String spacing = 'spacing';

  /// The gap between the runs of a wrapping row or column.
  static const String runSpacing = 'runSpacing';

  /// The name of the icon an icon node shows.
  static const String icon = 'icon';

  /// The offset of every notch of the node.
  static const String notchOffset = 'notchOffset';

  /// The offset of the notch at [index] of the node's notches.
  static String notchOffsetAt(int index) => 'notch-offset-$index';

  /// The letter spacing of every span of a text node.
  static const String letterSpacing = 'letterSpacing';

  /// The line height of every span of a text node.
  static const String lineHeight = 'lineHeight';

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

  /// The color of stop [index] of the first fill's gradient.
  static String fillStop(int index) => 'fill-stop-$index';

  /// A rectangle's SVG [RectangleNode.path] (text): an orbit drawn for the
  /// planet a screen shows, a curve built from data.
  static const String path = 'path';

  /// A stroke's [GeometryMixin.dashPattern]: a list of numbers or text such
  /// as `4 2` (dash, gap, ...).
  static const String dashPattern = 'dashPattern';

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
      final List? fills = _fillStops(
        (patch['fills'] as List?) ??
            [for (final paint in node.fills) paint.toJson()],
        node.variables,
        value,
      );
      if (fills != null) patch['fills'] = fills;
      final double? weight = value<double>(strokeWeight);
      if (weight != null && weight != node.strokeWeight) {
        patch['strokeWeight'] = weight < 0 ? 0.0 : weight;
      }
    }

    if (node is RectangleNode && node.variables.containsKey(path)) {
      final Object? data = value<Object>(path);
      if (data is String && data != node.path) patch['path'] = data;
    }

    if (node is GeometryMixin && node.variables.containsKey(dashPattern)) {
      final List<double>? dashes = _dashes(value<Object>(dashPattern));
      if (dashes != null &&
          !const ListEquality<double>().equals(dashes, node.dashPattern)) {
        patch['dashPattern'] = dashes;
      }
    }

    if (node is CornerMixin) {
      final CornerRadius? radius = _cornerRadius(value<Object>(cornerRadius));
      if (radius != null && radius != node.cornerRadius) {
        patch['cornerRadius'] = radius.toJson();
      }
    }

    if (node is RowColumnMixin) {
      final double? gap = gapOf(node, spacing, scopedValues: scopedValues);
      if (gap != null && gap != node.spacing) patch['spacing'] = gap;
      final double? runGap = gapOf(
        node,
        runSpacing,
        scopedValues: scopedValues,
      );
      if (runGap != null && runGap != node.runSpacing) {
        patch['runSpacing'] = runGap;
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
            <dynamic, dynamic>{
              ...span,
              // A span's JSON leaves out a default font name.
              if (weight != null || family != null)
                'fontName': node.textMixedProps[index].fontName
                    .copyWith(weight: weight, family: family)
                    .toJson(),
              if (size != null) 'fontSize': size,
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

    if (node is TextFieldNode) {
      // The typed text and the hint take a bound font too, e.g. an input
      // switching to an Arabic font when the query is Arabic.
      final String? family = value<Object>(fontFamily)?.toString().trim();
      final num? size = value<num>(fontSize);
      final FontWeightNumeric? weight = parseFontWeight(
        value<Object>(fontWeight),
      );
      Map<String, dynamic>? styled(TextProp style) {
        final FontName name = style.fontName.copyWith(
          family: family != null && family.isNotEmpty ? family : null,
          weight: weight,
        );
        final double fontSizeValue = size != null && size > 0
            ? size.toDouble()
            : style.fontSize;
        if (name == style.fontName && fontSizeValue == style.fontSize) {
          return null;
        }
        return {
          ...style.toJson(),
          'fontName': name.toJson(),
          'fontSize': fontSizeValue,
        };
      }

      final Map<String, dynamic>? input = styled(node.properties.inputStyle);
      final Map<String, dynamic>? hint = styled(
        node.properties.decoration.hintStyle,
      );
      if (input != null || hint != null) {
        final Map current =
            patch['properties'] as Map? ?? node.properties.toJson();
        patch['properties'] = {
          ...current,
          'inputStyle': ?input,
          if (hint != null)
            'decoration': {
              ...(current['decoration'] as Map? ??
                  node.properties.decoration.toJson()),
              'hintStyle': hint,
            },
        };
      }
    }

    if (node is TextNode) {
      final TextDecorationEnum? decoration = parseTextDecoration(
        value<Object>(textDecoration),
      );
      if (decoration != null &&
          node.textMixedProps.any(
            (prop) => prop.textDecoration != decoration,
          )) {
        final List spans =
            patch['textMixedProps'] as List? ??
            [for (final prop in node.textMixedProps) prop.toJson()];
        patch['textMixedProps'] = [
          for (final Map span in spans.cast<Map>())
            {...span, 'textDecoration': decoration.name},
        ];
      }
    }

    if (node is CornerMixin && node.notches.isNotEmpty) {
      final List<NotchModel> notches = boundNotches(node, scopedValues);
      if (!const ListEquality<NotchModel>().equals(notches, node.notches)) {
        patch['notches'] = [for (final notch in notches) notch.toJson()];
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

  /// [fills] (paint JSON) with the first gradient's stops recolored by
  /// their `fill-stop-<index>` bindings, or null when none changes.
  static List? _fillStops(
    List fills,
    Map<String, String> variables,
    T? Function<T extends Object>(String property) value,
  ) {
    if (fills.isEmpty ||
        !variables.keys.any((k) => k.startsWith('fill-stop-'))) {
      return null;
    }
    final PaintModel first = PaintModel.fromJson(fills.first as Map);
    final List<ColorStop>? stops = first.gradientStops;
    if (stops == null || stops.isEmpty) return null;
    bool changed = false;
    final List<ColorStop> next = [
      for (final (int i, ColorStop stop) in stops.indexed)
        if (variables.containsKey(fillStop(i)))
          switch (value<Object>(fillStop(i))) {
            final Object raw when raw.toColorRGBA() != null => () {
              final ColorRGBA bound = raw.toColorRGBA()!;
              // #RRGGBB names a hue only: keep the stop's transparency.
              final bool hueOnly =
                  raw is String &&
                  RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(raw.trim());
              final ColorRGBA color = hueOnly
                  ? bound.copyWith(a: stop.color.a)
                  : bound;
              if (color != stop.color) changed = true;
              return stop.copyWith(color: color);
            }(),
            _ => stop,
          }
        else
          stop,
    ];
    if (!changed) return null;
    return [first.copyWith(gradientStops: next).toJson(), ...fills.skip(1)];
  }

  /// [node]'s notches with the offsets their [notchOffsetAt] or
  /// [notchOffset] bindings give them, evaluated with [scopedValues]. A
  /// binding that is missing or isn't a finite number keeps the notch's own
  /// offset.
  static List<NotchModel> boundNotches(
    CornerMixin node,
    ScopedValues scopedValues,
  ) {
    double? number(String property) {
      if (node.variables[property] == null) return null;
      final num? offset = PropertyValueDelegate.getPropertyValue<num>(
        node,
        property,
        scopedValues: scopedValues,
      );
      return offset == null || !offset.isFinite ? null : offset.toDouble();
    }

    final double? all = number(notchOffset);
    return [
      for (final (int index, NotchModel notch) in node.notches.indexed)
        () {
          final double? offset = number(notchOffsetAt(index)) ?? all;
          return offset == null || offset == notch.offset
              ? notch
              : notch.copyWith(offset: offset);
        }(),
    ];
  }

  /// The gap the [property] ([spacing] or [runSpacing]) binding of [node]
  /// gives, evaluated with [scopedValues]: a number (or numeric text) of at
  /// least 0. Null when the node has no such binding or it gives no number.
  static double? gapOf(
    BaseNode node,
    String property, {
    required ScopedValues scopedValues,
  }) {
    if (node.variables[property]?.isNotEmpty != true) return null;
    final double? gap = _number(
      PropertyValueDelegate.getPropertyValue<Object>(
        node,
        property,
        scopedValues: scopedValues,
      ),
    );
    if (gap == null || !gap.isFinite) return null;
    return gap < 0 ? 0 : gap;
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

  static List<double>? _dashes(Object? value) {
    final List<Object?>? parts = switch (value) {
      List list => list,
      String text => text.trim().isEmpty ? <Object?>[] : text.trim().split(RegExp(r'[\s,]+')),
      _ => null,
    };
    if (parts == null) return null;
    final List<double> out = [];
    for (final Object? part in parts) {
      final double? n = switch (part) {
        num v => v.toDouble(),
        String v => double.tryParse(v),
        _ => null,
      };
      if (n == null || n < 0) return null;
      out.add(n);
    }
    return out;
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

  /// A text decoration from a binding's value: a [TextDecorationEnum] name
  /// as [TextDecorationEnum.parse] reads it (`lineThrough` for
  /// `strikethrough` too), true or false (strikethrough or none), or null.
  static TextDecorationEnum? parseTextDecoration(Object? value) {
    if (value is TextDecorationEnum) return value;
    // A bool strikes through: `${= m.wrong}`.
    if (value is bool) {
      return value ? TextDecorationEnum.strikethrough : TextDecorationEnum.none;
    }
    if (value is! String) return null;
    final String name = value.trim();
    if (name == 'true') return TextDecorationEnum.strikethrough;
    if (name == 'false') return TextDecorationEnum.none;
    return TextDecorationEnum.parse(name);
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

  /// The font size [value] gives: a positive number, or text that reads as
  /// one (`18`, `18.5`, `18px`). Null otherwise.
  static double? parseFontSize(Object? value) {
    final double? size = switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(
        s.trim().toLowerCase().replaceFirst(RegExp(r'(px|dp)$'), '').trim(),
      ),
      _ => null,
    };
    if (size == null || !size.isFinite || size <= 0) return null;
    return size;
  }

  static double? _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };

  static double? _fontSize(Object? value) => parseFontSize(value);

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
