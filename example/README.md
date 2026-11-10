# Codelessly SDK example

A complete app that shows published Codelessly projects with `codelessly_sdk`. It runs offline by default.

```sh
flutter create .     # once, to add the platform folders you want (they are not published with the package)
flutter run          # -d chrome, -d macos, -d linux, -d windows, or a phone
```

## What it shows

| Screen | What |
|---|---|
| **Embedded widget** | One layout inside a Flutter screen. The layout reads the app's data (`${data.name}`) and a route param, its button changes a screen variable and calls a function of the app, and the app resets the variable through a `CodelesslyWidgetController`. The project is a bundle written by hand in [`lib/hello_bundle.dart`](lib/hello_bundle.dart). |
| **Whole app** | A published project of several screens as an app of its own: `CodelesslyWidget.onGenerateRoute` gives each screen a route, navigation actions move between them, and each screen picks its mobile, tablet or desktop canvas by width. Resize the window to see it. |

## The three ways to load a project

`openProject` in [`lib/main.dart`](lib/main.dart) has all three:

```sh
# 1. A bundle shipped with the app (the default): offline.
flutter run

# 2. A published slug: one HTTP request, no Firebase.
flutter run --dart-define=CODELESSLY_SLUG=<your project's slug>

# 3. A project token: Codelessly's Firebase, with live updates. Not on Linux desktop.
flutter run --dart-define=CODELESSLY_TOKEN=<your project's token>
```

## Files

| File | |
|---|---|
| [`lib/main.dart`](lib/main.dart) | The app. |
| [`lib/hello_bundle.dart`](lib/hello_bundle.dart) | A publish bundle as a JSON literal: what a publish looks like. |
| [`lib/snippets.dart`](lib/snippets.dart) | Every code sample of the README and the developer guide, so they are analyzed. Not used by the app. |
| [`test/widget_test.dart`](test/widget_test.dart) | Tests of the app. |
| [`test/guide_test.dart`](test/guide_test.dart) | The developer guide's testing chapter, as tests. |
| `assets/rigcheck.json.gz` | The publish bundle of a project (Rigcheck), as the editor exports it. |

The developer guide: https://github.com/Codelessly/CodelesslySDK/tree/master/docs/guide
