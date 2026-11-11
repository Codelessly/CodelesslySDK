import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/material.dart';

/// [c] as a Flutter color.
Color? colorOf(api.Color? c) => c == null ? null : Color(c.value);

/// The Material theme a layout renders with: Flutter's defaults, with the
/// project's [tokens] over them (the runtime's own dialogs, toasts and
/// default widgets follow it).
ThemeData themeDataOf(api.ThemeTokens tokens, {Brightness brightness = Brightness.light}) {
  final base = ThemeData(brightness: brightness, fontFamily: tokens.fontFamily);
  final scheme = base.colorScheme.copyWith(
    primary: colorOf(tokens.primary),
    onPrimary: colorOf(tokens.onPrimary),
    surface: colorOf(tokens.surface),
    onSurface: colorOf(tokens.onSurface),
    error: colorOf(tokens.error),
  );
  final radius = tokens.radius;
  final buttonRadius = tokens.buttonRadius;
  final buttonShape = buttonRadius == null
      ? null
      : WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)));
  return base.copyWith(
    colorScheme: scheme,
    dialogTheme: radius == null
        ? null
        : DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))),
    filledButtonTheme: buttonShape == null ? null : FilledButtonThemeData(style: ButtonStyle(shape: buttonShape)),
    elevatedButtonTheme: buttonShape == null ? null : ElevatedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
    textButtonTheme: buttonShape == null ? null : TextButtonThemeData(style: ButtonStyle(shape: buttonShape)),
  );
}

/// The value of the `theme` name layouts read: [tokens] for a light or
/// [dark] screen ([api.ThemeTokens.forBrightness]):
///
/// * the roles: `primary`, `onPrimary`, `surface`, `onSurface`, `error`,
///   `success`, `warning` (colors as `#AARRGGBB` text), `fontFamily`,
///   `titleFontFamily`, `radius`, `buttonRadius`, when the project has them;
/// * `colors`: every named color by key (`${theme.colors.brandBlue}`);
/// * `text`: every named text style by key, its values by name
///   (`${theme.text.title.fontSize}`, `${theme.text.body.fontFamily}`);
/// * `isDark` and `brightness` (`light` or `dark`);
/// * `hasDark`: whether the project's theme has dark colors (else in dark
///   mode the colors are the light ones, and a layout may pick its own).
Map<String, Object?> themeValues(api.ThemeTokens tokens, {required bool dark}) {
  final json = tokens.forBrightness(dark: dark).toJson()..remove('dark');
  final colors = json.remove('colors');
  final text = json.remove('textStyles');
  return {
    ...json,
    'colors': colors ?? const <String, Object?>{},
    'text': text ?? const <String, Object?>{},
    'isDark': dark,
    'brightness': dark ? 'dark' : 'light',
    'hasDark': tokens.hasDark,
  };
}
