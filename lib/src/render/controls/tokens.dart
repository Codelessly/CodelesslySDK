// What a control draws with: SSUI's tokens (bundled as data,
// ssui_defaults.g.dart), the document's theme over them, for the screen's
// brightness and for what the control sits on. No Material theme, nothing
// from a host app.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../control_theme.dart' show backdropOf, contrastRatio, onColor;
import '../convert.dart';
import '../recipe.dart';
import 'ssui_defaults.g.dart';

/// SSUI's theme as tokens (the bundled data).
final api.ThemeTokens ssuiTokens = api.ThemeTokens.fromJson(ssuiTheme);

/// One step of the control scale (SSUI's `SoftSaaSControlSize`): a
/// control's height and what goes with it.
@immutable
class ControlScale {
  const ControlScale(this.name, this.height, this.paddingX, this.fontSize, this.iconSize, this.gap, this.radiusKey);

  final String name;
  final double height;

  /// Horizontal padding of a labelled control (SSUI's `paddingX + 2`).
  final double paddingX;
  final double fontSize;
  final double iconSize;

  /// Between an icon and its label.
  final double gap;

  /// The theme radius it takes (`inner` at xs, else `control`).
  final String radiusKey;

  /// The steps, smallest first. A button's label at `small` is 12 (as
  /// SSUI's button draws it; its field text is 12.5).
  static const steps = [
    ControlScale('xs', 24, 8, 11.5, 12, 6, 'inner'),
    ControlScale('compact', 28, 10, 12, 14, 6, 'control'),
    ControlScale('small', 32, 12, 12, 14, 6, 'control'),
    ControlScale('medium', 36, 12, 13, 16, 6, 'control'),
    ControlScale('large', 44, 14, 15, 18, 8, 'control'),
  ];

  /// The default step (28).
  static const compact = ControlScale('compact', 28, 10, 12, 14, 6, 'control');

  /// The icon of an icon-only control at this step (SSUI's
  /// `SoftSaaSIconButton.iconSizeFor`).
  double get iconOnlySize => switch (name) { 'xs' => 12, 'compact' => 14, 'small' || 'medium' => 16, _ => 20 };
}

/// The tokens one control draws with.
@immutable
class ControlTokens {
  ControlTokens._(this.theme, {required this.dark, this.backdrop, this.buttonRadius});

  /// The document's own `buttonRadius` (SSUI's is its `radii`, per step).
  final double? buttonRadius;

  /// SSUI's tokens for [dark], the document's [theme] (already or not yet for
  /// the brightness) over them, roles resolved; [backdrop] is what the
  /// control is drawn on, when the document says (an opaque fill under it).
  factory ControlTokens.resolve(api.ThemeTokens theme, {required bool dark, Color? backdrop}) {
    final own = theme.forBrightness(dark: dark);
    var merged = ssuiTokens.forBrightness(dark: dark).mergedWith(own).resolvedRoles();
    final derived = _derived(own, merged);
    if (derived.isNotEmpty) {
      merged = merged.mergedWith(api.ThemeTokens(colors: derived));
      final s = merged.surface;
      // A theme with its own surface is dark where that surface is.
      if (own.surface != null && s != null) dark = s.flutter.computeLuminance() < .18;
    }
    return ControlTokens._(merged, dark: dark, backdrop: backdrop, buttonRadius: theme.buttonRadius);
  }

  /// SSUI's neutral names follow the document's roles: a theme that gives
  /// its own `surface`, `onSurface` or `primary` and not SSUI's names (a
  /// field's `primaryBackground`, a border, a tint) gets those names made
  /// from its roles, so a control with nothing styled sits in the
  /// document's palette, not SSUI's white or blue.
  static Map<String, api.Color> _derived(api.ThemeTokens own, api.ThemeTokens merged) {
    final out = <String, api.Color>{};
    void put(String name, Color c) {
      if (!own.colors.containsKey(name)) out[name] = api.Color(c.toARGB32());
    }

    if (own.surface != null || own.onSurface != null) {
      final s = merged.surface?.flutter;
      if (s != null) {
        final o = own.onSurface == null ? onColor(s) : (merged.onSurface?.flutter ?? onColor(s));
        final onDark = s.computeLuminance() < .18;
        Color mix(double t) => Color.lerp(s, o, t)!;
        put('primaryBackground', s);
        put('secondaryBackground', mix(.04));
        put('subtleFill', mix(.07));
        put('tertiaryBackground', mix(onDark ? .16 : .08));
        put('raisedBackground', onDark ? mix(.16) : s);
        put('track', mix(.14));
        put('neutralFill', mix(.24));
        put('neutralTint', mix(.08));
        put('neutralTintBorder', mix(.16));
        put('primaryBorder', mix(.16));
        put('secondaryBorder', mix(.26));
        put('primaryText', o);
        put('secondaryText', o.withValues(alpha: .62));
        put('tertiaryText', o.withValues(alpha: .42));
        put('hoverOverlay', o.withValues(alpha: onDark ? .08 : .04));
        put('pressedOverlay', o.withValues(alpha: onDark ? .14 : .08));
        put('tooltipBackground', o);
        put('tooltipText', s);
      }
    }
    if (own.primary != null) {
      final p = merged.primary?.flutter;
      if (p != null) {
        put('focusBorder', p.withValues(alpha: .5));
        put('activeTint', p.withValues(alpha: .16));
        put('primaryTint', p.withValues(alpha: .12));
        put('primaryTintBorder', p.withValues(alpha: .3));
        final on = merged.onPrimary?.flutter;
        put('onAccent', own.onPrimary != null && on != null ? on : onColor(p));
      }
    }
    return out;
  }

  /// The tokens of the control [b] builds: its tree's theme and brightness,
  /// and the fills beneath its node. Its box is built again when the theme
  /// changes.
  factory ControlTokens.of(NodeBuilder b) {
    b.tree.dependOnTheme(b);
    final parent = b.source.parentOf(b.id);
    return ControlTokens.resolve(b.tree.theme, dark: b.tree.dark,
        backdrop: parent == null ? null : backdropOf(b.source.node, b.source.parentOf, parent));
  }

  /// The merged tokens.
  final api.ThemeTokens theme;
  final bool dark;
  final Color? backdrop;

  Color _c(String name, Color fallback) => theme.color(name)?.flutter ?? fallback;

  Color get primary => theme.primary?.flutter ?? _c('primary', const Color(0xFF2563EB));
  Color get onPrimary => theme.onPrimary?.flutter ?? const Color(0xFFFFFFFF);
  Color get surface => theme.surface?.flutter ?? (dark ? const Color(0xFF141414) : const Color(0xFFFFFFFF));
  Color get error => theme.error?.flutter ?? const Color(0xFFDC2626);

  /// Text and marks on the surface: the theme's `onSurface` where it reads
  /// on what the control sits on (3:1), else ink or near-white.
  Color get onSurface {
    final own = theme.onSurface?.flutter ?? (dark ? const Color(0xFFFFFFFF) : const Color(0xFF111827));
    final under = backdrop;
    if (under == null || contrastRatio(own, under) >= 3) return own;
    return onColor(under);
  }

  /// Secondary text (an icon button's glyph), [onSurface] where it would not
  /// read on the backdrop.
  Color get secondaryText {
    final own = _c('secondaryText', onSurface.withValues(alpha: .7));
    final under = backdrop;
    if (under == null || contrastRatio(Color.alphaBlend(own, under), under) >= 3) return own;
    return onSurface;
  }

  Color get primaryBorder => _c('primaryBorder', onSurface.withValues(alpha: .15));
  Color get secondaryBorder => _c('secondaryBorder', onSurface.withValues(alpha: .25));
  Color get raisedBackground => _c('raisedBackground', surface);
  Color get tertiaryBackground => _c('tertiaryBackground', onSurface.withValues(alpha: .06));
  Color get focusBorder => _c('focusBorder', primary.withValues(alpha: .5));
  Color get activeTint => _c('activeTint', primary.withValues(alpha: .14));
  Color get primaryTintBorder => _c('primaryTintBorder', primary.withValues(alpha: .28));
  Color get tooltipBackground => _c('tooltipBackground', dark ? const Color(0xFFF3F4F6) : const Color(0xFF111827));
  Color get tooltipText => _c('tooltipText', dark ? const Color(0xFF111827) : const Color(0xFFFFFFFF));

  /// The overlay of a hovered or pressed control drawn on the surface.
  Color get hoverOverlay => _c('hoverOverlay', dark ? const Color(0x14FFFFFF) : const Color(0x0A000000));
  Color get pressedOverlay => _c('pressedOverlay', dark ? const Color(0x24FFFFFF) : const Color(0x14000000));

  /// The overlay of a hovered or pressed filled control (SSUI darkens a
  /// fill in light mode and lightens it in dark).
  Color filledOverlay({required bool pressed}) =>
      dark ? (pressed ? const Color(0x33FFFFFF) : const Color(0x1FFFFFFF)) : (pressed ? const Color(0x29000000) : const Color(0x14000000));

  /// The font of control labels: the theme's `fontFamily`, else none (the
  /// platform's), never Roboto by default.
  String? get fontFamily => theme.fontFamily;

  /// Milliseconds of a state change (SSUI's `durations.control`).
  int get controlMs => theme.durations['control'] ?? 150;

  /// Milliseconds before a tooltip shows (SSUI's `durations.tooltipDelay`).
  int get tooltipDelayMs => theme.durations['tooltipDelay'] ?? 400;

  /// The default step of the scale, or the theme's `sizes.compact`.
  double get defaultHeight => theme.sizes['compact'] ?? ControlScale.compact.height;

  /// The step of the scale nearest [height] (the theme's `sizes` may move
  /// the heights).
  ControlScale scaleFor(double height) {
    ControlScale best = ControlScale.compact;
    var d = double.infinity;
    for (final s in ControlScale.steps) {
      final h = theme.sizes[s.name] ?? s.height;
      final e = (h - height).abs();
      if (e < d - .01) {
        d = e;
        best = s;
      }
    }
    return best;
  }

  /// The corner radius of a control at [scale]: the document's
  /// `buttonRadius`, else the `radii` of the step (SSUI: 5 at xs, else 7).
  double radiusFor(ControlScale scale) =>
      buttonRadius ?? theme.radii[scale.radiusKey] ?? (scale.radiusKey == 'inner' ? 5 : 7);

  /// The shadows named [name] in the theme (`level3`...), as Flutter's.
  List<BoxShadow> shadows(String name) => [for (final e in theme.shadows[name] ?? const <api.Effect>[]) if (e.visible) boxShadow(e)];

  /// A radius from the theme's `radii`, else [fallback].
  double radius(String name, double fallback) => theme.radii[name] ?? fallback;

  /// A label colour that reads on [fill] when the theme's choice does not.
  Color readableOn(Color fill, Color preferred) =>
      fill.a < .9 || contrastRatio(preferred, fill) >= 3 ? preferred : onColor(fill, preferred: [preferred]);

  static double clampRatio(double v) => math.max(0, math.min(1, v));
}
