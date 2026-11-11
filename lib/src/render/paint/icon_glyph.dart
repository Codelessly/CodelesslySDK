// An icon, painted at its box's size: Material Icons, Material Symbols and
// Cupertino icons drawn from their published SVGs, and image icons (SVG or
// raster).
import 'package:codelessly_api/codelessly_api.dart' show Json, readDouble, readInt, readString;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

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
    var name = (readString(icon['name']) ?? '').toLowerCase();
    // A feedback icon written `{"source": "icon", "name": "check_rounded"}`
    // (as a toast's default is) names a Material icon; it drew nothing.
    final type = readString(icon['type']) ?? (readString(icon['source']) == 'icon' && name.isNotEmpty ? 'MATERIAL_ICON' : null);
    switch (type) {
      case 'MATERIAL_ICON':
        if (name.isEmpty) return null;
        // Flutter's names carry the style (`download_rounded`, `Icons.
        // download_rounded`); the font serves the base name in that style's
        // folder (`materialiconsround/download`), and 404s for the full name.
        String? styleOfName;
        for (final (suffix, s) in const [('_rounded', 'rounded'), ('_outlined', 'outlined'), ('_sharp', 'sharp')]) {
          if (name.length > suffix.length && name.endsWith(suffix)) {
            name = name.substring(0, name.length - suffix.length);
            styleOfName = s;
            break;
          }
        }
        final style = switch (readString(icon['style']) ?? styleOfName) {
          'outlined' => 'outlined',
          'rounded' => 'round',
          'sharp' => 'sharp',
          'twoTone' => 'twotone',
          _ => '',
        };
        // Served from the version the icon was added in, known by name: an
        // icon written without one (by hand, by a tool) or renamed by a
        // binding (whose version is still the old icon's) loads too.
        final version = materialIconVersions[name] ?? readInt(icon['version']) ?? 1;
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

  /// The MaterialIcons font codepoint a Material icon draws while its SVG
  /// isn't available, or null (other icon types, no codepoint).
  static int? glyphOf(Json icon) {
    final type = readString(icon['type']);
    if (type != null && type != 'MATERIAL_ICON') return null;
    if (readString(icon['source']) == 'image') return null;
    final c = readInt(icon['codepoint']);
    return c == null || c <= 0 ? null : c;
  }

  /// Where a Material icon saved without its version (an icon named in
  /// node JSON, `{"name": "calendar_view_week"}`) is drawn from when its
  /// first SVG ([urlOf], `v1`) fails: icons added after Material's first
  /// release have no `v1`. Null when [icon] names its version, isn't a
  /// Material icon, or has no later version.
  static String? fallbackUrlOf(Json icon) {
    if (readString(icon['type']) != 'MATERIAL_ICON' || readString(icon['source']) == 'image') return null;
    if (readInt(icon['version']) != null) return null;
    final name = (readString(icon['name']) ?? '').toLowerCase();
    final latest = materialIconVersions[name];
    if (latest == null || latest <= 1) return null;
    final url = urlOf({...icon, 'version': latest});
    return url == urlOf(icon) ? null : url;
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
  Json get icon => _icon;
  String? _url, _fallback;
  bool _fallbackShown = false;
  set icon(Json v) {
    if (identical(v, _icon)) return;
    _icon = v;
    _url = IconSources.urlOf(v);
    _fallback = IconSources.fallbackUrlOf(v);
    _fallbackShown = false;
    showImages([_url]);
    markNeedsPaint();
  }

  /// The icon's image: its SVG, or once that failed, the latest version's
  /// (loaded from the frame after the failure is seen).
  LoadedImage? _loaded() {
    final loaded = imageFor(_url);
    if (loaded != null || _fallback == null || !imageFailed(_url)) return loaded;
    if (!_fallbackShown) {
      _fallbackShown = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached && _fallbackShown) showImages([_url, _fallback]);
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    }
    return imageFor(_fallback);
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

  /// An icon is solid to the pointer, as Flutter's `Icon` is: a drag handle
  /// or a button that is only an icon takes the press, not what lies under.
  @override
  bool hitTestSelf(Offset position) => true;

  /// The icon box: the size its fit box gives it, nothing of its
  /// own (so a row out of room can squeeze it).
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_icon['show'] == false) return;
    final loaded = _loaded();
    final color = _color ?? defaultColor;
    if (loaded == null) {
      // Its SVG is loading (or neither version loaded):
      // a Material icon with a codepoint draws that glyph of the bundled
      // MaterialIcons font meanwhile, instead of nothing.
      _paintGlyph(context.canvas, offset, color);
      return;
    }
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

  /// The font glyph of a Material icon with a `codepoint` (its SVG's
  /// stand-in), filling the box; nothing for other icons.
  void _paintGlyph(Canvas canvas, Offset offset, Color color) {
    final codepoint = IconSources.glyphOf(_icon);
    if (codepoint == null || size.isEmpty) return;
    final extent = size.shortestSide;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(codepoint),
        style: TextStyle(fontFamily: 'MaterialIcons', fontSize: extent, height: 1, color: color, inherit: false),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset + Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
    painter.dispose();
  }
}
