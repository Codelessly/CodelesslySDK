# 11. Theming and fonts

[Guide](README.md) · Previous: [Scripting](10-scripting.md) · Next: [Custom widgets and extending](12-custom-widgets.md)

## What a layout's look comes from

Almost everything you see in a layout is designed: each node carries its own colors, text styles, radii and
shadows, and renders with them wherever it is embedded. A Flutter `Theme` matters only for what the design leaves
to Material:

- Material widgets in the layout that keep default colors and shapes (buttons, switches, text fields, app bars);
- the runtime's own UI: toasts, confirmation dialogs, date pickers.

## The project's theme (default)

A project has theme tokens, published with it: `primary`, `onPrimary`, `surface`, `onSurface`, `error`,
`success`, `warning`, `fontFamily`, `titleFontFamily`, `radius` and `buttonRadius`. By default each
`CodelesslyWidget` wraps its layout in a `Theme` built from them (Flutter's default `ThemeData` with the tokens
over it), so a layout looks the same in every app. Your app's theme is not used inside the layout and is not
changed outside it.

`themeDataOf(tokens)` is that conversion, if you want the same `ThemeData` for your own widgets:

```dart
final theme = themeDataOf(codelessly.publishModel!.theme);
```

## Your app's theme

```dart
final codelessly = Codelessly(
  config: const CodelesslyConfig(slug: 'my-project', useHostTheme: true),
);
```

With `useHostTheme`, layouts render inside your app's `Theme`: Material widgets that keep their defaults take your
color scheme and shapes. Designed colors don't change.

## Dark mode

The SDK does not restyle a layout for dark mode. A layout can adapt itself: `${screen.isDark}` and
`${screen.brightness}` follow the platform's brightness, for conditions, bindings and variants. The project's
theme is built with light brightness; use `useHostTheme` if the layout's Material widgets should follow your
app's dark theme.

## Fonts

Each layout lists the fonts its text uses. When a layout loads, the SDK fetches and registers them, then shows the
layout. If they take longer than `CodelesslyConfig.fontTimeout` (2 seconds by default), the layout shows with
fallback fonts and re-renders when they arrive.

The default `HttpFontFetcher` downloads:

- a font uploaded to the project, from its URL;
- any other font from Google Fonts (`fonts.googleapis.com`), by family, weight and style.

Fonts are fetched once per run. They are not cached on disk by the SDK.

### Fonts shipped with the app

For offline apps, or to avoid the first-run download, ship the fonts.

If the families are declared in your `pubspec.yaml` under `flutter: fonts:` with the same family names, turn
fetching off; the engine already has them:

```dart
final codelessly = Codelessly.asset('assets/my_project.json.gz', fonts: const NoFontFetcher());
```

Or serve font files from your assets with a `FontFetcher` of your own:

```dart
class BundledFonts implements FontFetcher {
  const BundledFonts();

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    final style = '${font.weight}${font.italic ? 'i' : ''}';
    try {
      final data = await rootBundle.load('assets/fonts/${font.family}-$style.ttf');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null; // The text falls back to the platform's font.
    }
  }
}

final codelessly = Codelessly.asset('assets/my_project.json.gz', fonts: const BundledFonts());
```

`PublishFont` has `family`, `weight` (400, 700, ...), `italic` and `url`. Returning null skips a font.
The fonts a project uses are listed on the loaded model: `codelessly.publishModel!.fonts`.

In tests, always pass `fonts: const NoFontFetcher()` so fonts don't touch the network.

## Text scale

Layouts are designed at fixed sizes, so by default they ignore the platform's text size setting
(`maxTextScaleFactor: 1`). To let text grow for accessibility, raise the cap:

```dart
final codelessly = Codelessly(
  config: const CodelesslyConfig(slug: 'my-project', maxTextScaleFactor: 1.3),
);
```

Text then follows the platform's setting up to 1.3 times. Check your layouts at the largest scale you allow: text
in fixed-size boxes can overflow.

## Icons

Icons are drawn from SVGs fetched over the network when first used, not from icon fonts (this keeps Flutter's
icon font tree shaking working, since a layout names its icons at runtime):

| Icons | From |
|---|---|
| Material Icons, Material Symbols | `https://fonts.gstatic.com` |
| Cupertino icons | `https://icons.codelessly.com` (mirror it and point the SDK at your host with `--dart-define=CODELESSLY_CUPERTINO_SVG_BASE_URL=https://your-host`) |
| Image icons | Their own URL |

A web app with a Content Security Policy must allow those hosts. Offline, an icon that was never fetched leaves
its space empty.

Next: [Custom widgets and extending](12-custom-widgets.md)
