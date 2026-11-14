import 'package:codelessly_api/codelessly_api.dart' as api;

export '../render/control_theme.dart' show colorOf, kControlRadius, kInk, kInkOnDark, kPaper, kPaperDark, kSurfaceRadius, themeDataOf;

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
/// * `mode`: the site's theme mode (`system`, `light` or `dark`: Flutter's
///   `ThemeMode`), which a `setThemeMode` action changes;
/// * `hasDark`: whether the project's theme has dark colors (else in dark
///   mode the colors are the light ones, and a layout may pick its own).
Map<String, Object?> themeValues(api.ThemeTokens tokens, {required bool dark, api.ThemeMode? mode}) {
  final t = tokens.forBrightness(dark: dark);
  final json = t.toJson()
    ..remove('dark')
    ..remove('media')
    ..remove('mode');
  final colors = {for (final k in t.colors.keys) k: ?t.color(k)?.toJson()};
  json.remove('colors');
  json.remove('textStyles');
  // Each style resolved: what it starts from, and the colors it names.
  final text = {for (final k in t.textStyles.keys) k: ?t.textStyle(k)?.toJson()};
  return {
    ...json,
    'colors': colors,
    'text': text,
    'isDark': dark,
    'brightness': dark ? 'dark' : 'light',
    'mode': (mode ?? tokens.mode).name,
    'hasDark': tokens.hasDark,
  };
}
