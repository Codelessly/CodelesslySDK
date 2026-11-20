// The project's theme where widgets are: the tokens the render tree draws
// with, handed down to the runtime's own chrome (a player's controls, a
// list's footer, a toast, a dialog) and to the widgets hosted in a screen.
// Nothing here is Flutter's Material theme, and nothing comes from the app
// the layout is shown in.
import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/widgets.dart';
import 'controls/buttons.dart' show ButtonKind, ButtonSpec;
import 'controls/tokens.dart' show ControlTokens;

import 'surface_roles.dart';

export 'surface_roles.dart';

/// The corner radius of buttons, chips, fields, dropdowns and segmented
/// buttons without a theme's `buttonRadius`: a small radius, not
/// Material's stadium.
const double kControlRadius = 6;

/// The corner radius of dialogs, menus, pickers and cards without a
/// theme's `radius`.
const double kSurfaceRadius = 8;

/// The project's theme tokens for the widgets below: the tokens of the
/// screen's mode, whether that mode is [dark], and the [surface] those
/// widgets are drawn on when it is not the tokens' own (a card, a dark
/// band). The screen, a session's view, a toast and a dialog each put one
/// above what they show; a route or an overlay entry opened from under one
/// carries it along (it is an [InheritedTheme]).
class ThemeTokensScope extends InheritedTheme {
  const ThemeTokensScope({super.key, required this.tokens, required this.dark, this.surface, required super.child});

  /// [child] under [tokens], with the default text style and icon color
  /// they give (the surface's ink, the theme's font).
  static Widget withDefaults({
    Key? key,
    required api.ThemeTokens tokens,
    required bool dark,
    Color? surface,
    required Widget child,
  }) {
    final roles = surfaceRoles(tokens, dark: dark, surface: surface);
    return ThemeTokensScope(
      key: key,
      tokens: tokens,
      dark: dark,
      surface: surface,
      child: DefaultTextStyle(
        style: bodyTextStyle(tokens, roles.onSurface),
        child: IconTheme(data: IconThemeData(color: roles.onSurface), child: child),
      ),
    );
  }

  final api.ThemeTokens tokens;
  final bool dark;
  final Color? surface;

  static ThemeTokensScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeTokensScope>();

  @override
  Widget wrap(BuildContext context, Widget child) =>
      ThemeTokensScope(tokens: tokens, dark: dark, surface: surface, child: child);

  @override
  bool updateShouldNotify(ThemeTokensScope oldWidget) =>
      tokens != oldWidget.tokens || dark != oldWidget.dark || surface != oldWidget.surface;
}

/// The text of the runtime's own chrome before a look styles it: 14 px in
/// [color] and the theme's font.
TextStyle bodyTextStyle(api.ThemeTokens tokens, Color color) => TextStyle(
      inherit: false,
      color: color,
      fontFamily: tokens.fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.43,
      textBaseline: TextBaseline.alphabetic,
      leadingDistribution: TextLeadingDistribution.even,
      decoration: TextDecoration.none,
      decorationColor: color,
    );

/// The color roles of the theme at [context] for the surface it is on
/// ([surfaceRoles]); neutral ones where no screen of the SDK's is above.
SurfaceRoles rolesOf(BuildContext context) {
  final scope = ThemeTokensScope.maybeOf(context);
  return surfaceRoles(scope?.tokens ?? api.ThemeTokens.none, dark: scope?.dark ?? false, surface: scope?.surface);
}

/// The tokens of the SDK's own controls where the runtime's chrome is drawn
/// (a player's controls, a list's Undo bar): the theme's at [context]; drawn
/// [on] a color of the chrome's own, the tokens that read on it.
ControlTokens chromeTokensOf(BuildContext context, {Color? on}) {
  final scope = ThemeTokensScope.maybeOf(context);
  final own = scope?.tokens ?? const api.ThemeTokens();
  final dark = scope?.dark ?? false;
  on ??= scope?.surface;
  // What it is on is of the other mode (a dark band on a light page): the
  // tokens that read there.
  if (on == null || on.a <= .9 || (on.computeLuminance() < .18) == dark) {
    return ControlTokens.resolve(own, dark: dark, backdrop: on);
  }
  return ControlTokens.resolve(
    own.mergedWith(api.ThemeTokens(surface: api.Color(on.toARGB32()), colors: const {})),
    dark: on.computeLuminance() < .18,
    backdrop: on,
  );
}

/// One of the chrome's buttons: the SDK's stock button of [kind] (a text
/// button with a [label], an icon button without one), its sizes, states
/// and focus ring the tokens'. [foreground], [background], [style], [side],
/// [shape] and [padding] are what the chrome's own look sets over it.
ButtonSpec chromeButton({
  required ControlTokens tokens,
  ButtonKind? kind,
  String label = '',
  Map<String, Object?> icon = const {},
  Color? foreground,
  Color? background,
  TextStyle style = const TextStyle(),
  BorderSide? side,
  OutlinedBorder? shape,
  EdgeInsets? padding,
  bool enabled = true,
  bool wrapLabel = false,
  api.FloatingActionButtonType fabType = api.FloatingActionButtonType.regular,
}) =>
    ButtonSpec(
      kind: kind ?? (label.isEmpty ? ButtonKind.icon : ButtonKind.text),
      tokens: tokens,
      label: label,
      icon: icon,
      foreground: foreground,
      background: background,
      labelStyle: style,
      side: side,
      shape: shape,
      padding: padding,
      enabled: enabled,
      wrapLabel: wrapLabel,
      fabType: fabType,
    );

/// A glyph of the MaterialIcons font as a button's icon. [icon] is a
/// constant `IconData`: a build that keeps only the icon font's glyphs it
/// finds in the app's constants (`--tree-shake-icons`, the default of a
/// release build) keeps this one.
Map<String, Object?> chromeGlyph(String name, IconData icon) => {
      'type': 'MATERIAL_ICON',
      'name': name,
      'codepoint': icon.codePoint,
      'render': 'glyph',
    };
