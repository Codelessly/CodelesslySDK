// Model values → Flutter values.
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/rendering.dart';

import '../text_defaults.dart';

extension ColorToFlutter on api.Color {
  Color get flutter => Color(value);
}

extension InsetsToFlutter on api.EdgeInsets {
  /// Flutter's insets. Flutter asserts insets (a padding) are never
  /// negative, and one negative side would fail the whole screen's layout;
  /// a negative side reads as 0, as the API reads a bad value. (A margin
  /// keeps its negative sides: RenderMargin lays them out.)
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

/// Fonts a text style asks for while it renders. A family can reach a
/// style only through a binding (a caption's look from data), which no
/// publish lists: [handler] (installed by the app's font loader) fetches
/// such a family the first time it is drawn. Each family, weight and style
/// is asked for once.
abstract final class FontDemand {
  static void Function(String family, int weight, bool italic)? handler;
  static final Set<String> _asked = {};

  /// Whether a family's characters beyond a browser's `latin` subset come as
  /// a family of their own ([glyphFamily]), which every style using the
  /// family falls back to. Set by the app's font loader on the web.
  static bool glyphFallback = false;

  /// The family holding [family]'s characters beyond `latin`. On the web a
  /// family's later files don't add glyphs to its first (the engine draws
  /// the first's empty glyph), so they are a family of their own.
  static String glyphFamily(String family) => '$family glyphs';

  static void need(String family, int weight, bool italic) {
    final h = handler;
    if (h == null || family.isEmpty) return;
    if (_asked.add('$family/$weight/$italic')) h(family, weight, italic);
  }
}

/// [style] as Flutter's, merged over [inherited] (the default text style the
/// node inherits: `Node.behaviors.defaultTextStyle` on the node a tree
/// renders) and the base style ([kTextBase]).
TextStyle textStyle(api.TextStyle style, [api.TextStyle? inherited]) {
  if (inherited != null) style = inherited.merge(style);
  final weight = style.fontWeight;
  if (style.fontFamily case final String family) {
    FontDemand.need(family, ((weight ?? 400) ~/ 100 * 100).clamp(100, 900), style.fontStyle == api.FontStyle.italic);
  }
  return kTextBase.merge(TextStyle(
    fontFamily: style.fontFamily,
      fontFamilyFallback: FontDemand.glyphFallback && style.fontFamily != null
          ? [FontDemand.glyphFamily(style.fontFamily!), ...style.fontFamilyFallback]
          : style.fontFamilyFallback,
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
