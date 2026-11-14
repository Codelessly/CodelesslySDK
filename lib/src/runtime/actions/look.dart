// Reading an action's look (its `look` JSON) and evaluated bindings as
// painting values: colors, sides, shadows, insets, text styles. No widgets.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json;
import 'package:flutter/painting.dart';

import '../../render/convert.dart';

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
