// The fonts of text inside an SVG image. flutter_svg draws an SVG's `<text>`
// with the engine's fonts by the `font-family` it names: a generic family
// (`sans-serif`, `monospace`) or one the app never loaded is not the site's
// font (and in a test, or the render command, it is drawn as solid blocks).
// Before an SVG is drawn its families are resolved as a text node's are:
// a generic family becomes the site's font (the theme's `fontFamily`), a
// named family is asked for as a text style's is ([FontDemand]: fetched by
// name, or reported where it can't be) with the site's font after it as the
// fallback, and text naming no family takes the site's font.
import 'dart:convert';

import '../convert.dart' show FontDemand;

/// Resolves the font families an SVG document's text names.
abstract final class SvgFonts {
  /// CSS generic families and the platform aliases that mean "the default
  /// font": drawn in the site's font.
  static const generic = {
    'serif', 'sans-serif', 'monospace', 'cursive', 'fantasy', 'system-ui', 'ui-serif', 'ui-sans-serif',
    'ui-monospace', 'ui-rounded', 'emoji', 'math', 'fangsong', '-apple-system', 'blinkmacsystemfont',
  };

  /// Called with each named (not generic) family an SVG's text asks for and
  /// the SVG's URL: a tool lists the images that use a family it lacks.
  static void Function(String family, String url)? onFamily;

  static final _attribute = RegExp(r'''font-family\s*=\s*("([^"]*)"|'([^']*)')''');
  static final _property = RegExp(r'''(font-family\s*:\s*)([^;"}<>]+)''');
  static final _weight = RegExp(r'''font-weight\s*[=:]\s*["']?\s*([a-z0-9]+)''');
  static final _svgTag = RegExp(r'<svg\b');

  /// [svg] (an SVG document's text) with its text's families resolved over
  /// [defaultFamily] (the site's font; null: the platform's, and generic
  /// families are left to the engine). Named families are asked for
  /// ([FontDemand.need]) at each weight the document uses. A document with
  /// no `<text>` is returned as it is.
  static String resolve(String svg, {String? defaultFamily, String? url}) {
    if (!svg.contains('<text')) return svg;
    final weights = <int>{};
    for (final m in _weight.allMatches(svg)) {
      final w = switch (m.group(1)!) {
        'bold' || 'bolder' => 700,
        'normal' || 'lighter' => 400,
        final n => int.tryParse(n),
      };
      if (w != null) weights.add((w ~/ 100 * 100).clamp(100, 900));
    }
    if (weights.isEmpty) weights.add(400);
    final asked = <String>{};
    String families(String list) {
      final out = <String>[];
      for (var part in list.split(',')) {
        part = part.trim();
        if (part.length >= 2 && (part[0] == '"' || part[0] == "'") && part.endsWith(part[0])) {
          part = part.substring(1, part.length - 1).trim();
        }
        if (part.isEmpty) continue;
        if (generic.contains(part.toLowerCase())) {
          out.add(defaultFamily ?? part);
        } else {
          out.add(part);
          if (asked.add(part)) {
            onFamily?.call(part, url ?? '');
            for (final w in weights) {
              FontDemand.need(part, w, false);
            }
          }
        }
      }
      if (defaultFamily != null) out.add(defaultFamily);
      // Unquoted: flutter_svg splits the list at commas and trims each name.
      return {...out}.join(', ');
    }

    var s = svg.replaceAllMapped(_attribute, (m) => 'font-family="${families(m.group(2) ?? m.group(3)!)}"');
    s = s.replaceAllMapped(_property, (m) => '${m.group(1)}${families(m.group(2)!)}');
    // Text naming no family inherits the root's: the site's font.
    if (defaultFamily != null) {
      final root = _svgTag.firstMatch(s);
      if (root != null) {
        final end = s.indexOf('>', root.end);
        final tag = end < 0 ? '' : s.substring(root.start, end);
        if (end > 0 && !tag.contains('font-family')) {
          final at = tag.endsWith('/') ? end - 1 : end;
          s = '${s.substring(0, at)} font-family="$defaultFamily"${s.substring(at)}';
        }
      }
    }
    return s;
  }

  /// [resolve] over an SVG file's bytes (UTF-8); bytes that aren't text are
  /// returned as they are.
  static List<int> resolveBytes(List<int> bytes, {String? defaultFamily, String? url}) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return bytes;
    }
    final out = resolve(text, defaultFamily: defaultFamily, url: url);
    return identical(out, text) ? bytes : utf8.encode(out);
  }
}
