// The one theme everything the SDK draws with Flutter's Material widgets
// takes: the controls that are islands (buttons, chips, fields, switches,
// sliders, pickers...) and the runtime's own chrome (dialogs, toasts,
// sheets, menus, tooltips). Every color role and every font is the
// project's theme tokens, or, where it has none, a neutral set of ink,
// paper and the greys between them: nothing is Material's default (its
// purple seed, tints, ripples, elevation, Roboto) and nothing comes from the
// app the layout is shown in.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/material.dart';

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

/// The corner radius of buttons, chips, fields, dropdowns and segmented
/// buttons without a theme's `buttonRadius`: a small radius, not
/// Material's stadium.
const double kControlRadius = 6;

/// The corner radius of dialogs, menus, pickers and cards without a
/// theme's `radius`.
const double kSurfaceRadius = 8;

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

/// The project's theme tokens a [ThemeData] was made from
/// ([themeDataOf]), so the islands under it can make the same theme again
/// for the surface they sit on ([ControlTheme]).
@immutable
class CodelesslyThemeTokens extends ThemeExtension<CodelesslyThemeTokens> {
  const CodelesslyThemeTokens(this.tokens, this.brightness);

  final api.ThemeTokens tokens;

  /// The mode the theme was asked for (its surface may say otherwise).
  final Brightness brightness;

  @override
  CodelesslyThemeTokens copyWith({api.ThemeTokens? tokens, Brightness? brightness}) =>
      CodelesslyThemeTokens(tokens ?? this.tokens, brightness ?? this.brightness);

  @override
  CodelesslyThemeTokens lerp(CodelesslyThemeTokens? other, double t) => t < .5 || other == null ? this : other;

  @override
  bool operator ==(Object other) => other is CodelesslyThemeTokens && other.tokens == tokens && other.brightness == brightness;

  @override
  int get hashCode => Object.hash(tokens, brightness);
}

/// The themes made lately, by what they're made of (making one is costly
/// and islands ask on every rebuild).
final Map<(api.ThemeTokens, Brightness, Color?), ThemeData> _made = {};

/// The theme of a layout's controls and of the runtime's dialogs, toasts,
/// sheets, pickers, menus and tooltips: every [ColorScheme] role and every
/// text style from the project's [tokens] (already for the screen's mode:
/// [api.ThemeTokens.forBrightness]), neutral where the tokens say nothing.
///
/// [surface] is what the controls sit on, when it isn't the tokens'
/// surface (a card, a dark band): text and marks are chosen to read on it.
///
/// | Role | From |
/// |---|---|
/// | `surface` | [surface], else `tokens.surface`, else paper (white; near-black in dark mode) |
/// | `onSurface` | `tokens.onSurface` when it reads on the surface (3:1), else ink (near-black on light, near-white on dark) |
/// | `primary` | `tokens.primary` when it reads on the surface, else `onSurface`: what controls draw on the surface (checks, thumbs, text button labels) |
/// | `onPrimary` | `tokens.onPrimary` when it reads on `primary`, else ink or paper |
/// | containers, `surfaceTint` | `primary` at 12 % over the surface (selected tint); greys from `onSurface` over `surface`; tint transparent |
/// | `outline`, `outlineVariant`, `onSurfaceVariant` | `onSurface` at 45 %, 18 %, 68 % over the surface |
/// | `error` | `tokens.error`, else a neutral red |
///
/// Filled buttons and floating action buttons fill with `tokens.primary` as
/// it is (ink without one), labelled in `onPrimary` (else ink or paper,
/// whichever reads). No splashes, no elevation unless a node sets one, no
/// tints. Text takes `tokens.fontFamily` (titles `tokens.titleFontFamily`),
/// else no family at all, as text nodes do.
ThemeData themeDataOf(api.ThemeTokens tokens, {Brightness brightness = Brightness.light, Color? surface}) {
  final key = (tokens, brightness, surface);
  final made = _made.remove(key);
  if (made != null) return _made[key] = made;
  final data = _themeData(tokens, brightness, surface);
  _made[key] = data;
  if (_made.length > 64) _made.remove(_made.keys.first);
  return data;
}

/// A [WidgetStateProperty] of [enabled], [disabled] when disabled.
WidgetStateProperty<Color?> _states(Color enabled, Color disabled) =>
    WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? disabled : enabled);

/// The state layer over a control drawn in [ink]: faint on hover, a little
/// more when focused or pressed; nothing else.
WidgetStateProperty<Color?> stateLayer(Color ink) => WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) return null;
      if (s.contains(WidgetState.pressed) || s.contains(WidgetState.focused)) return ink.withValues(alpha: .10);
      if (s.contains(WidgetState.hovered)) return ink.withValues(alpha: .06);
      return null;
    });

/// A text theme of color only (no font family, no geometry): what
/// [Typography] gives each style before [ThemeData] applies the tokens'
/// family, so no style falls back to Roboto or San Francisco.
TextTheme _colorOnly(Color color) {
  TextStyle s(String label) =>
      TextStyle(debugLabel: 'codelessly $label', color: color, decorationColor: color, decoration: TextDecoration.none);
  return TextTheme(
    displayLarge: s('displayLarge'),
    displayMedium: s('displayMedium'),
    displaySmall: s('displaySmall'),
    headlineLarge: s('headlineLarge'),
    headlineMedium: s('headlineMedium'),
    headlineSmall: s('headlineSmall'),
    titleLarge: s('titleLarge'),
    titleMedium: s('titleMedium'),
    titleSmall: s('titleSmall'),
    bodyLarge: s('bodyLarge'),
    bodyMedium: s('bodyMedium'),
    bodySmall: s('bodySmall'),
    labelLarge: s('labelLarge'),
    labelMedium: s('labelMedium'),
    labelSmall: s('labelSmall'),
  );
}

ThemeData _themeData(api.ThemeTokens tokens, Brightness requested, Color? backdrop) {
  // A role that names a theme colour (`"primary": "forest"`) is that colour.
  tokens = tokens.resolvedRoles();
  final surface = backdrop ?? colorOf(tokens.surface) ?? (requested == Brightness.dark ? kPaperDark : kPaper);
  final brightness = ThemeData.estimateBrightnessForColor(surface);
  final onSurface = onColor(surface, preferred: [colorOf(tokens.onSurface)]);
  Color mix(double t) => Color.lerp(surface, onSurface, t)!;
  final brand = colorOf(tokens.primary);
  final onBrand = colorOf(tokens.onPrimary);
  // What controls draw straight on the surface: the brand color where it
  // reads there, else the surface's ink.
  final accent = brand != null && brand.a > .9 && contrastRatio(brand, surface) >= 3 ? brand : onSurface;
  final onAccent = onColor(accent, preferred: [if (accent == brand) onBrand, surface]);
  // What fills a filled button: the brand color as it is.
  final fill = brand != null && brand.a > .9 ? brand : onSurface;
  final onFill = onColor(fill, preferred: [onBrand, surface]);
  final selected = Color.lerp(surface, accent, brightness == Brightness.dark ? .24 : .12)!;
  final selectedDim = Color.lerp(surface, accent, brightness == Brightness.dark ? .36 : .24)!;
  final error = colorOf(tokens.error) ?? (brightness == Brightness.dark ? const Color(0xFFF28B82) : const Color(0xFFC4302B));
  final onSurfaceVariant = mix(.68);
  final outline = mix(.45);
  final outlineVariant = mix(.18);
  final disabledFill = mix(.12);
  final disabledInk = mix(.45);
  const shadow = Color(0xFF000000);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: selected,
    onPrimaryContainer: onSurface,
    primaryFixed: selected,
    primaryFixedDim: selectedDim,
    onPrimaryFixed: onSurface,
    onPrimaryFixedVariant: onSurfaceVariant,
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: selected,
    onSecondaryContainer: onSurface,
    secondaryFixed: selected,
    secondaryFixedDim: selectedDim,
    onSecondaryFixed: onSurface,
    onSecondaryFixedVariant: onSurfaceVariant,
    tertiary: accent,
    onTertiary: onAccent,
    tertiaryContainer: selected,
    onTertiaryContainer: onSurface,
    tertiaryFixed: selected,
    tertiaryFixedDim: selectedDim,
    onTertiaryFixed: onSurface,
    onTertiaryFixedVariant: onSurfaceVariant,
    error: error,
    onError: onColor(error, preferred: [surface]),
    errorContainer: Color.lerp(surface, error, .12),
    onErrorContainer: onSurface,
    surface: surface,
    onSurface: onSurface,
    surfaceDim: mix(.06),
    surfaceBright: surface,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: mix(.03),
    surfaceContainerHigh: mix(.05),
    surfaceContainerHighest: mix(.08),
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: shadow,
    scrim: shadow,
    inverseSurface: onSurface,
    onInverseSurface: surface,
    inversePrimary: onColor(onSurface, preferred: [brand, surface]),
    surfaceTint: Colors.transparent,
  );

  final colors = _colorOnly(onSurface);
  final body = tokens.fontFamily;
  final title = tokens.titleFontFamily ?? body;
  final titled = title == null
      ? null
      : TextTheme(
          displayLarge: TextStyle(fontFamily: title),
          displayMedium: TextStyle(fontFamily: title),
          displaySmall: TextStyle(fontFamily: title),
          headlineLarge: TextStyle(fontFamily: title),
          headlineMedium: TextStyle(fontFamily: title),
          headlineSmall: TextStyle(fontFamily: title),
          titleLarge: TextStyle(fontFamily: title),
          titleMedium: TextStyle(fontFamily: title),
          titleSmall: TextStyle(fontFamily: title),
        );
  final typography = Typography.material2021(black: colors, white: colors);

  // Shapes: the tokens' radii, else small ones (never Material's stadium
  // buttons, pill indicators or 28 px dialogs). Surfaces that float (dialogs,
  // menus, pickers) have a hairline border.
  final buttonRadius = tokens.buttonRadius ?? kControlRadius;
  final radius = tokens.radius ?? kSurfaceRadius;
  final OutlinedBorder buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius));
  final OutlinedBorder cardShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  final OutlinedBorder surfaceShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: outlineVariant));
  // Fields: an outline of the theme's radius, else the control radius (a
  // hairline at rest, the accent when focused), the label inside as a hint,
  // never floating into a notch; no underline.
  final fieldRadius = BorderRadius.circular(tokens.radius ?? kControlRadius);

  // Buttons: no elevation unless a node sets one (then a black shadow), no
  // tint, no splash; a faint state layer of the label's color.
  ButtonStyle button({required Color background, required Color foreground, BorderSide? side}) => ButtonStyle(
        backgroundColor: _states(background, background.a == 0 ? background : disabledFill),
        foregroundColor: _states(foreground, disabledInk),
        iconColor: _states(foreground, disabledInk),
        overlayColor: stateLayer(foreground),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(shadow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: side == null
            ? null
            : WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled) ? side.copyWith(color: outlineVariant) : side),
        shape: WidgetStatePropertyAll(buttonShape),
        splashFactory: NoSplash.splashFactory,
      );
  final filled = button(background: fill, foreground: onFill);
  final plain = button(background: Colors.transparent, foreground: accent);
  final outlined = button(background: Colors.transparent, foreground: accent, side: BorderSide(color: outline));
  final menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(shadow),
    elevation: const WidgetStatePropertyAll(0),
    side: WidgetStatePropertyAll(BorderSide(color: outlineVariant)),
    shape: WidgetStatePropertyAll(surfaceShape),
  );

  return ThemeData(
    useMaterial3: true,
    // A control fits the node it is drawn in: no 48 px tap-target margin
    // around it and no platform density, so a 28 or 32 px node shows the
    // whole control with its label centred, never a taller control cut or
    // shifted.
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    colorScheme: scheme,
    typography: typography,
    fontFamily: body,
    textTheme: titled,
    primaryTextTheme: titled,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: onSurface.withValues(alpha: .04),
    focusColor: onSurface.withValues(alpha: .10),
    applyElevationOverlayColor: false,
    canvasColor: surface,
    scaffoldBackgroundColor: surface,
    cardColor: surface,
    dividerColor: outlineVariant,
    disabledColor: disabledInk,
    hintColor: onSurfaceVariant,
    unselectedWidgetColor: onSurfaceVariant,
    secondaryHeaderColor: mix(.04),
    shadowColor: shadow,
    iconTheme: IconThemeData(color: onSurface),
    primaryIconTheme: IconThemeData(color: onAccent),
    extensions: [CodelesslyThemeTokens(tokens, requested)],
    filledButtonTheme: FilledButtonThemeData(style: filled),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filled),
    textButtonTheme: TextButtonThemeData(style: plain),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlined),
    iconButtonTheme: IconButtonThemeData(style: plain),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        overlayColor: stateLayer(onSurface),
        side: WidgetStatePropertyAll(BorderSide(color: outline)),
        shape: WidgetStatePropertyAll(buttonShape),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: fill,
      foregroundColor: onFill,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      splashColor: Colors.transparent,
      hoverColor: onFill.withValues(alpha: .06),
      focusColor: onFill.withValues(alpha: .10),
      shape: buttonShape,
    ),
    chipTheme: ChipThemeData(
      elevation: 0,
      pressElevation: 0,
      shadowColor: shadow,
      selectedShadowColor: shadow,
      surfaceTintColor: Colors.transparent,
      checkmarkColor: onSurface,
      shape: buttonShape,
    ),
    // A square box of a small radius and a hairline-weight border.
    checkboxTheme: CheckboxThemeData(
      splashRadius: 0,
      overlayColor: stateLayer(onSurface),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      side: WidgetStateBorderSide.resolveWith((s) => s.contains(WidgetState.selected)
          ? BorderSide(color: s.contains(WidgetState.disabled) ? disabledFill : accent, width: 1.5)
          : BorderSide(color: s.contains(WidgetState.disabled) ? outlineVariant : outline, width: 1.5)),
    ),
    radioTheme: RadioThemeData(overlayColor: stateLayer(onSurface)),
    // A plain toggle: no track outline, one thumb size on and off (no icon
    // in it), the thumb in the surface's color.
    switchTheme: SwitchThemeData(
      overlayColor: stateLayer(onSurface),
      thumbIcon: const WidgetStatePropertyAll<Icon?>(Icon(null)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackOutlineWidth: const WidgetStatePropertyAll(0),
      thumbColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        if (s.contains(WidgetState.disabled)) return on ? surface : mix(.30);
        return on ? onAccent : surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        if (s.contains(WidgetState.disabled)) return on ? mix(.30) : disabledFill;
        return on ? accent : mix(.24);
      }),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 0, pressedElevation: 0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      overlayColor: accent.withValues(alpha: .10),
      inactiveTrackColor: mix(.16),
      disabledActiveTrackColor: disabledInk,
      disabledInactiveTrackColor: disabledFill,
      disabledThumbColor: disabledInk,
      valueIndicatorColor: onSurface,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: mix(.12),
      circularTrackColor: Colors.transparent,
    ),
    // A square underline of the tab's width, not Material's rounded pill.
    tabBarTheme: TabBarThemeData(
      indicatorColor: accent,
      indicator: UnderlineTabIndicator(borderSide: BorderSide(color: accent, width: 2)),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: onSurface,
      unselectedLabelColor: onSurfaceVariant,
      dividerColor: outlineVariant,
      overlayColor: stateLayer(onSurface),
      splashFactory: NoSplash.splashFactory,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      indicatorColor: selected,
      indicatorShape: buttonShape,
      overlayColor: stateLayer(onSurface),
    ),
    navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface, elevation: 0, indicatorColor: selected, indicatorShape: buttonShape),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      selectedItemColor: accent,
      unselectedItemColor: onSurfaceVariant,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(color: surface, surfaceTintColor: Colors.transparent, elevation: 0),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      shape: cardShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      barrierColor: Colors.black54,
      shape: surfaceShape,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      scrimColor: Colors.black54,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      modalElevation: 0,
      dragHandleColor: outline,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      shape: surfaceShape,
    ),
    menuTheme: MenuThemeData(style: menuStyle),
    dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: shadow,
      elevation: 0,
      headerBackgroundColor: surface,
      headerForegroundColor: onSurface,
      dividerColor: outlineVariant,
      shape: surfaceShape,
      dayShape: WidgetStatePropertyAll(buttonShape),
      todayBorder: BorderSide(color: outline),
      cancelButtonStyle: plain,
      confirmButtonStyle: plain,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surface,
      elevation: 0,
      shape: surfaceShape,
      cancelButtonStyle: plain,
      confirmButtonStyle: plain,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: onSurface, borderRadius: const BorderRadius.all(Radius.circular(4))),
      textStyle: TextStyle(color: surface, fontFamily: body, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      actionTextColor: surface,
      elevation: 0,
      contentTextStyle: TextStyle(color: surface, fontFamily: body),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: onSurfaceVariant,
      textColor: onSurface,
      selectedColor: accent,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: onSurface,
      collapsedIconColor: onSurfaceVariant,
      textColor: onSurface,
      collapsedTextColor: onSurface,
    ),
    dividerTheme: DividerThemeData(color: outlineVariant),
    badgeTheme: BadgeThemeData(backgroundColor: error, textColor: onColor(error, preferred: [surface])),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: .24),
      selectionHandleColor: accent,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      fillColor: mix(.04),
      hoverColor: onSurface.withValues(alpha: .04),
      focusColor: onSurface.withValues(alpha: .10),
      // The shape only: Flutter draws its side by state (outline at rest,
      // primary when focused, error, faint when disabled). A field without
      // a border of its own shows its label as its placeholder
      // (`inputDecoration`), so nothing floats into a notch.
      border: OutlineInputBorder(borderRadius: fieldRadius),
    ),
  );
}

/// [style] in the font of the theme at [context] (the tokens' family) when
/// it names none; null stays null (the widget's theme style applies).
TextStyle? themeFont(BuildContext context, TextStyle? style) {
  if (style == null || style.fontFamily != null) return style;
  final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  return family == null ? style : style.copyWith(fontFamily: family);
}

/// The theme of the controls under it ([themeDataOf]) for the surface they
/// sit on: the project's tokens of the theme above (a `CodelesslyWidget`'s),
/// or none (neutral) when the theme above isn't one of the SDK's: an app's
/// theme never reaches a layout's controls.
class ControlTheme extends StatelessWidget {
  const ControlTheme({super.key, this.surface, required this.child});

  /// What the controls are drawn on (null: the tokens' surface).
  final Color? surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final above = Theme.of(context);
    final ours = above.extension<CodelesslyThemeTokens>();
    // Always a Theme, so a control keeps its state when what it sits on
    // changes (its node moved under another parent).
    final data = ours != null && surface == null
        ? above
        : themeDataOf(ours?.tokens ?? api.ThemeTokens.none, brightness: ours?.brightness ?? above.brightness, surface: surface);
    return Theme(data: data, child: child);
  }
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
