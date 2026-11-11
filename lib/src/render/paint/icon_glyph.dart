// An icon, painted at its box's size: Material Icons, Material Symbols and
// Cupertino icons drawn from their published SVGs, and image icons (SVG or
// raster).
import 'package:codelessly_api/codelessly_api.dart' show Json, readDouble, readInt, readString;
import 'package:flutter/rendering.dart';

import 'image_fill.dart';
import 'material_icon_versions.dart';

/// Where icon SVGs come from. Material icons and symbols load from Google's
/// prebuilt SVGs; Cupertino icons from Codelessly's icon CDN (override with
/// `--dart-define=CODELESSLY_CUPERTINO_SVG_BASE_URL=...`).
abstract final class IconSources {
  static const cupertinoBaseUrl =
      String.fromEnvironment('CODELESSLY_CUPERTINO_SVG_BASE_URL', defaultValue: 'https://icons.codelessly.com');

  /// The cupertino_icons version the Cupertino SVGs were exported from.
  static const cupertinoVersion = '1.0.9';

  /// The URL [icon] (an icon prop: `{"source": "icon"|"image", ...}`) is
  /// drawn from, or null when it has none.
  static String? urlOf(Json icon) {
    if (readString(icon['source']) == 'image') return readString(icon['image']);
    final name = (readString(icon['name']) ?? '').toLowerCase();
    switch (readString(icon['type'])) {
      case 'MATERIAL_ICON':
        if (name.isEmpty) return null;
        final style = switch (readString(icon['style'])) {
          'outlined' => 'outlined',
          'rounded' => 'round',
          'sharp' => 'sharp',
          'twoTone' => 'twotone',
          _ => '',
        };
        // An icon without a version (written by hand or by a tool) is served
        // from the version it was added in, as a picked one is.
        final version = readInt(icon['version']) ?? materialIconVersions[name] ?? 1;
        return 'https://fonts.gstatic.com/s/i/materialicons$style/$name/v$version/24px.svg';
      case 'MATERIAL_SYMBOL':
        if (name.isEmpty) return null;
        final style = readString(icon['style']) ?? 'outlined';
        return 'https://fonts.gstatic.com/s/i/short-term/release/materialsymbols$style/$name/'
            '${symbolVariant(fill: readDouble(icon['fill']), weight: readDouble(icon['weight']), grade: readDouble(icon['grade']))}/'
            '${_nearest(readDouble(icon['opticalSize']) ?? 24, const [20, 24, 40, 48])}px.svg';
      case 'CUPERTINO_ICON':
        final codepoint = readInt(icon['codepoint']) ?? 0;
        if (cupertinoBaseUrl.isEmpty || codepoint <= 0) return null;
        final root = cupertinoBaseUrl.endsWith('/') ? cupertinoBaseUrl.substring(0, cupertinoBaseUrl.length - 1) : cupertinoBaseUrl;
        return '$root/cupertino/$cupertinoVersion/${codepoint.toRadixString(16)}.svg';
    }
    return null;
  }

  /// The Material Symbols SVG variant nearest the axes (`wght700grad200fill1`,
  /// or `default`).
  static String symbolVariant({double? fill, double? weight, double? grade}) {
    final w = weight == null ? 400 : ((weight / 100).round() * 100).clamp(100, 700);
    final g = grade == null ? 0 : _nearest(grade, const [-25, 0, 200]);
    final v = [
      if (w != 400) 'wght$w',
      if (g != 0) 'grad${g < 0 ? 'N${-g}' : g}',
      if ((fill ?? 0) >= 0.5) 'fill1',
    ].join();
    return v.isEmpty ? 'default' : v;
  }

  static int _nearest(double value, List<int> options) =>
      options.reduce((a, b) => (a - value).abs() <= (b - value).abs() ? a : b);
}

/// Paints an icon to fill its box (contained, centered).
class RenderIconGlyph extends RenderBox with ImageClient {
  /// An icon's color where none is set: a light Material theme's
  /// `IconTheme` color (black87).
  static const Color defaultColor = Color(0xDD000000);

  Json _icon = const {};
  set icon(Json v) {
    if (identical(v, _icon)) return;
    _icon = v;
    showImages([IconSources.urlOf(v)]);
    markNeedsPaint();
  }

  Color? _color;
  set color(Color? v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  Size _designSize = Size.zero;
  set designSize(Size v) {
    if (v == _designSize) return;
    _designSize = v;
    markNeedsLayout();
  }

  @override
  bool get sizedByParent => true;

  /// The icon box: the size its fit box gives it, nothing of its
  /// own (so a row out of room can squeeze it).
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_icon['show'] == false) return;
    final loaded = imageFor(IconSources.urlOf(_icon));
    if (loaded == null) return;
    final color = _color ?? defaultColor;
    final isImage = readString(_icon['source']) == 'image';
    // A transparent color shows an image icon's own colors.
    final raw = isImage && _color != null && _color!.a == 0;
    paintLoaded(
      context.canvas,
      offset & size,
      loaded,
      // SvgPicture contains its picture; Image(Icon)s scale down.
      fit: loaded.isSvg ? BoxFit.contain : BoxFit.scaleDown,
      scale: isImage && !raw && !loaded.isSvg ? readDouble(_icon['scale']) ?? 1 : 1,
      colorFilter: raw ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
