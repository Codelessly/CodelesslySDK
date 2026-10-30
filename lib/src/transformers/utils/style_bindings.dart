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
/// * [fontSize] (number, logical pixels): the size of every span of a text
///   node, e.g. a counter that grows past 99: `${= count > 99 ? 28 : 36}`.
///   Line heights and letter spacings given in percent scale with it.
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

  /// The font size of every span of a text node.
  static const String fontSize = 'fontSize';

  /// The name of the icon an icon node shows.
  static const String icon = 'icon';

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
      if (weight != null &&
          node.textMixedProps.any((prop) => prop.fontName.weight != weight)) {
        final List spans =
            patch['textMixedProps'] as List? ??
            [for (final prop in node.textMixedProps) prop.toJson()];
        patch['textMixedProps'] = [
          for (final (int index, Map span) in spans.cast<Map>().indexed)
            {
              ...span,
              // A span's JSON leaves out a default font name.
              'fontName': node.textMixedProps[index].fontName
                  .copyWith(weight: weight)
                  .toJson(),
            },
        ];
      }
    }

    if (node is TextNode) {
      final double? size = parseFontSize(value<Object>(fontSize));
      if (size != null &&
          node.textMixedProps.any((prop) => prop.fontSize != size)) {
        final List spans =
            patch['textMixedProps'] as List? ??
            [for (final prop in node.textMixedProps) prop.toJson()];
        patch['textMixedProps'] = [
          for (final Map span in spans.cast<Map>()) {...span, 'fontSize': size},
        ];
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
