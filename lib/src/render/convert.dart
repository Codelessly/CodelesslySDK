// Model values → Flutter values.
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';

import '../text_defaults.dart';

extension ColorToFlutter on api.Color {
  Color get flutter => Color(value);
}

extension InsetsToFlutter on api.EdgeInsets {
  /// Flutter's insets. Flutter asserts insets (a margin, a padding) are
  /// never negative, and one negative side would fail the whole screen's
  /// layout; a negative side reads as 0, as the API reads a bad value.
  EdgeInsets get flutter => EdgeInsets.fromLTRB(
        left < 0 ? 0 : left,
        top < 0 ? 0 : top,
        right < 0 ? 0 : right,
        bottom < 0 ? 0 : bottom,
      );
}

extension RadiusToFlutter on api.BorderRadius {
  /// Each corner circular or elliptical (decoration, clip and paint all
  /// take it from here).
  BorderRadius get flutter => BorderRadius.only(
        topLeft: Radius.elliptical(topLeft, topLeftY),
        topRight: Radius.elliptical(topRight, topRightY),
        bottomRight: Radius.elliptical(bottomRight, bottomRightY),
        bottomLeft: Radius.elliptical(bottomLeft, bottomLeftY),
      );
}

extension ConstraintsToFlutter on api.BoxConstraints {
  BoxConstraints get flutter => BoxConstraints(
        minWidth: minWidth ?? 0,
        maxWidth: maxWidth ?? double.infinity,
        minHeight: minHeight ?? 0,
        maxHeight: maxHeight ?? double.infinity,
      );
}

extension AlignmentToFlutter on api.Alignment {
  Alignment get flutter => Alignment(x, y);
}

MainAxisAlignment mainAxisAlignment(api.MainAxisAlignment a) => MainAxisAlignment.values.byName(a.name);
CrossAxisAlignment crossAxisAlignment(api.CrossAxisAlignment a) => CrossAxisAlignment.values.byName(a.name);
Clip clip(api.Clip c) => Clip.values.byName(c.name);
TextAlign textAlign(api.TextAlign a) => TextAlign.values.byName(a.name);
TextOverflow textOverflow(api.TextOverflow o) => TextOverflow.values.byName(o.name);
BlendMode blendMode(api.BlendMode b) => BlendMode.values.byName(b.name);

/// A drop shadow effect as Flutter's `BoxShadow`.
BoxShadow boxShadow(api.Effect e) => BoxShadow(
      color: e.color.flutter,
      offset: Offset(e.offset.dx, e.offset.dy),
      blurRadius: e.blurRadius,
      spreadRadius: e.spreadRadius,
    );

/// [style]'s OpenType features: its `fontFeatures`, one per tag (the last
/// wins), plus `tnum` for `tabularFigures` unless they set it.
List<ui.FontFeature>? fontFeatures(api.TextStyle style) {
  final tabular = style.tabularFigures == true;
  if (style.fontFeatures.isEmpty) return tabular ? const [ui.FontFeature.tabularFigures()] : null;
  final resolved = api.OpenTypeFeature.resolve(style.fontFeatures);
  return [
    for (final f in resolved) ui.FontFeature(f.tag, f.value),
    if (tabular && !resolved.any((f) => f.tag == 'tnum')) const ui.FontFeature.tabularFigures(),
  ];
}

/// [style] as Flutter's `TextStyle`, over the base text style
/// ([kTextBase]).
TextStyle textStyle(api.TextStyle style) {
  final weight = style.fontWeight;
  return kTextBase.merge(TextStyle(
    fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
    fontWeight: weight == null ? null : FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
    fontStyle: style.fontStyle == null ? null : FontStyle.values.byName(style.fontStyle!.name),
    fontSize: style.fontSize,
    color: style.foreground == null ? style.color?.flutter : null,
    letterSpacing: style.letterSpacing ?? 0,
    height: style.height,
    decoration: switch (style.decoration) {
      null || api.TextDecoration.none => null,
      api.TextDecoration.underline => TextDecoration.underline,
      api.TextDecoration.overline => TextDecoration.overline,
      api.TextDecoration.lineThrough => TextDecoration.lineThrough,
    },
    decorationColor: style.decorationColor?.flutter,
    backgroundColor: style.backgroundColor?.flutter,
    decorationStyle: style.decorationStyle == null || style.decorationStyle == api.TextDecorationStyle.solid
        ? null
        : TextDecorationStyle.values.byName(style.decorationStyle!.name),
    decorationThickness: style.decorationThickness,
    fontFeatures: fontFeatures(style),
    leadingDistribution: style.leadingDistribution == api.TextLeadingDistribution.even
        ? TextLeadingDistribution.even
        : null,
    shadows: [
      for (final s in style.shadows)
        if (s.visible && s.type == api.EffectType.dropShadow)
          Shadow(color: s.color.flutter, offset: Offset(s.offset.dx, s.offset.dy), blurRadius: s.blurRadius),
    ],
  ));
}
