// What a control or an indicator is drawn in, for the surface it sits on:
// the handful of color roles every unstyled thing reads from the project's
// theme, and the color of the surface itself as the document says it. No
// widgets and no Material: a render object asks here.
import 'dart:ui';

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;

/// [c] as a Flutter color.
Color? colorOf(api.Color? c) => c == null ? null : Color(c.value);

/// Text and marks on light surfaces without a theme: near-black.
const Color kInk = Color(0xFF111111);

/// Text and marks on dark surfaces without a theme: near-white.
const Color kInkOnDark = Color(0xFFF2F2F2);

/// The surface of a light layout without a theme.
const Color kPaper = Color(0xFFFFFFFF);

/// The surface of a dark layout without a theme.
const Color kPaperDark = Color(0xFF121212);

/// The contrast ratio of [a] and [b] (WCAG: 1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + .05) / (lb + .05) : (lb + .05) / (la + .05);
}

/// Text that reads on [background]: the first of [preferred] that does
/// (3:1, so a theme's own choice is kept), else ink or near-white,
/// whichever contrasts more.
Color onColor(Color background, {Iterable<Color?> preferred = const []}) {
  for (final c in preferred) {
    if (c != null && c.a > .9 && contrastRatio(c, background) >= 3) return c;
  }
  return contrastRatio(kInk, background) >= contrastRatio(kInkOnDark, background) ? kInk : kInkOnDark;
}

/// The roles an unstyled control or indicator draws in on one surface.
///
/// | Role | From |
/// |---|---|
/// | [surface] | the surface given, else `tokens.surface`, else paper (white; near-black in dark mode) |
/// | [onSurface] | `tokens.onSurface` when it reads on the surface (3:1), else ink |
/// | [primary] | `tokens.primary` when it reads on the surface, else [onSurface] |
/// | [muted], [outline], [hairline] | [onSurface] at 68 %, 45 %, 18 % over the surface |
/// | [error] | `tokens.error`, else a neutral red |
typedef SurfaceRoles = ({
  bool dark,
  Color surface,
  Color onSurface,
  Color primary,
  Color muted,
  Color outline,
  Color hairline,
  Color error,
});

/// The roles of [tokens] on [surface] (what the thing sits on, when it
/// isn't the tokens' own surface: a card, a dark band). [dark] is the
/// screen's mode, used when neither names a surface.
SurfaceRoles surfaceRoles(api.ThemeTokens tokens, {bool dark = false, Color? surface}) {
  // A role that names a theme color (`"primary": "forest"`) is that color.
  tokens = tokens.resolvedRoles();
  final on = surface ?? colorOf(tokens.surface) ?? (dark ? kPaperDark : kPaper);
  final isDark = isDarkSurface(on);
  final onSurface = onColor(on, preferred: [colorOf(tokens.onSurface)]);
  Color mix(double t) => Color.lerp(on, onSurface, t)!;
  final brand = colorOf(tokens.primary);
  return (
    dark: isDark,
    surface: on,
    onSurface: onSurface,
    // What controls draw straight on the surface: the brand color where it
    // reads there, else the surface's ink.
    primary: brand != null && brand.a > .9 && contrastRatio(brand, on) >= 3 ? brand : onSurface,
    muted: mix(.68),
    outline: mix(.45),
    hairline: mix(.18),
    error: colorOf(tokens.error) ?? (isDark ? const Color(0xFFF28B82) : const Color(0xFFC4302B)),
  );
}

/// Whether [surface] takes light text: the threshold Material's
/// `ThemeData.estimateBrightnessForColor` uses, so both agree.
bool isDarkSurface(Color surface) {
  final l = surface.computeLuminance() + .05;
  return l * l <= .15;
}

/// The color a control at node [id] is drawn on, as its document says: the
/// visible fills of the node and then of its ancestors, top down, until an
/// opaque one (translucent ones over it composited; a gradient counts as
/// the average of its stops). Null when an image or noise paint is in the
/// way, or nothing opaque is found: the theme's surface, then.
Color? backdropOf(Node? Function(String id) nodeOf, String? Function(String id) parentOf, String id) {
  final layers = <Color>[];
  String? at = id;
  for (var depth = 0; at != null && depth < 128; depth++) {
    final node = nodeOf(at);
    if (node != null && node.visible) {
      for (final p in node.decoration.fills.reversed) {
        if (!p.visible || p.opacity <= 0) continue;
        final c = _paintColor(p);
        if (c == null) return null;
        if (c.a >= .99) {
          var out = c.withValues(alpha: 1);
          for (final top in layers.reversed) {
            out = Color.alphaBlend(top, out);
          }
          return out;
        }
        if (c.a > 0) layers.add(c);
      }
    }
    at = parentOf(at);
  }
  return null;
}

Color? _paintColor(api.Paint p) {
  switch (p.type) {
    case api.PaintType.solid:
      final c = p.color;
      if (c == null) return const Color(0x00000000);
      return Color(c.value).withValues(alpha: (c.alpha / 255) * p.opacity.clamp(0, 1));
    case api.PaintType.linear || api.PaintType.radial || api.PaintType.sweep || api.PaintType.diamond:
      if (p.stops.isEmpty) return const Color(0x00000000);
      double a = 0, r = 0, g = 0, b = 0;
      for (final s in p.stops) {
        final c = Color(s.color.value);
        a += c.a;
        r += c.r;
        g += c.g;
        b += c.b;
      }
      final n = p.stops.length;
      return Color.from(alpha: (a / n) * p.opacity.clamp(0, 1), red: r / n, green: g / n, blue: b / n);
    case api.PaintType.image || api.PaintType.noise:
      return null;
  }
}
