![Codelessly](https://raw.githubusercontent.com/Codelessly/CodelesslySDK/master/packages/Codelessly-Logo-Text.png)

# Codelessly SDK

Server-driven UI for Flutter. Design screens in the [Codelessly Editor](https://codelessly.com), publish, and show
them in your app with one widget. The SDK renders a published layout natively, straight into Flutter render objects,
and runs it: variables, conditions, actions, navigation, data, APIs and scripts. A new publish reaches running apps
without an app release.

```dart
final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'));

runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
```

- [Install](#install)
- [Quickstart](#quickstart): by [slug](#1-a-published-slug-http), by [project token](#2-a-project-token-firebase-live-updates), or [offline](#3-a-bundle-shipped-with-the-app-offline)
- [`CodelesslyWidget` essentials](#codelesslywidget-essentials)
- [Developer guide](#developer-guide)
- [Coming from 10.x?](#coming-from-10x)

## Install

```sh
flutter pub add codelessly_sdk
```

Requires Dart 3.12 and Flutter 3.35 or newer. Runs on Android, iOS, web, macOS, Windows and Linux.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';
```

## Quickstart

A `Codelessly` is one published project. A `CodelesslyWidget` shows one of its screens. Pick how the project loads:

| | You need | Network | Live updates |
|---|---|---|---|
| [Slug](#1-a-published-slug-http) | The project's public slug | One HTTP request | On the next start |
| [Project token](#2-a-project-token-firebase-live-updates) | The project's SDK token | Firebase (set up by the SDK) | While the app runs |
| [Bundle](#3-a-bundle-shipped-with-the-app-offline) | A bundle file in your assets | None | With an app release |

### 1. A published slug (HTTP)

A project with a public slug (the name in `site.codelessly.com/<slug>`) publishes one bundle file. The SDK fetches
it over HTTP; there is nothing else to set up.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

void main() {
  final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'));

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}
```

### 2. A project token (Firebase, live updates)

A project's SDK token gives an app access to its publish in Codelessly's backend. Each new publish reaches the
running app. The token is all you need: `codelesslyWithToken` opens Codelessly's Firebase project as a secondary
Firebase app, in Dart. No `google-services.json`, no `flutterfire configure`, and your own Firebase project (if you
have one) is not touched.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final codelessly = await codelesslyWithToken('YOUR_PROJECT_TOKEN');

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}
```

Firebase has no Linux support, so a token can't be used on Linux desktop: load by slug or from a bundle there.
If the project uses Codelessly cloud data, accounts or file uploads, pass `cloudServices: true`
([Cloud data and services](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/09-cloud-data-and-services.md)).

### 3. A bundle shipped with the app (offline)

A bundle is a publish in one JSON file (gzipped or not). Ship it as an asset and the app runs with no network.

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/my_project.json.gz
```

```dart
void main() {
  final codelessly = Codelessly.asset('assets/my_project.json.gz');

  runApp(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
}
```

A bundle already in memory works the same way: `Codelessly.fromBundle(PublishBundle.fromJson(json))`.
[Loading modes and caching](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/04-loading-and-caching.md)
says where a bundle file comes from.

## `CodelesslyWidget` essentials

```dart
CodelesslyWidget(
  codelessly: codelessly,
  controller: controller,
  // A layout id, a custom id, or the id of one of its canvases.
  // Without it: the project's entry screen.
  layoutId: 'profile-card',
  // `${route.userId}` in the layout.
  params: const {'userId': 'u_42'},
  // `${data.user.name}` in the layout.
  data: const {
    'user': {'name': 'Ada', 'plan': 'pro'},
  },
  sizing: CanvasSizing.fill,
  loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error) => Center(child: Text('Could not load: $error')),
  layoutBuilder: (context, layout) => SafeArea(child: layout),
  onNavigate: (context, request) => false,
)
```

**Which screen.** `layoutId` names a layout by its id, its custom id, or the id of one of its canvases. A layout
can hold one canvas per breakpoint (mobile, tablet, desktop); the widget shows the one for the width it is given.
`canvasId` forces one. With no `layoutId`, `initialScreen` opens a screen by its URL path (`'/guide/42'`), id or
name (`'record-form'` opens "Record form"); with neither, the project's entry screen shows.

**Which project.** Pass `codelessly`, or put a `CodelesslyScope(codelessly: ..., child: ...)` above the widgets, or
call `Codelessly.setDefault(codelessly)` once.

**Data.** `data` is read in the layout as `${data.<key>}`. Rebuild the widget with new data and the layout updates
in place. `Codelessly(data: ...)` and `codelessly.setData(key, value)` set data for every screen. `params` are read
as `${route.<name>}`.

**Sizing.** `CanvasSizing.fill` (the default) makes the canvas fill the space it is given: use it for screens.
`CanvasSizing.design` keeps the canvas's design size (a card, a dialog). `CanvasSizing.fillWidth` fills the width
and keeps the design height (a sheet). In a scroll view, where the height is unbounded, a canvas takes its own
height.

**Loading and errors.** `loadingBuilder` and `errorBuilder` replace the default spinner and error text.
`layoutBuilder` wraps the loaded layout.

**Functions.** A "call function" action calls a function of your app, by name:

```dart
final codelessly = Codelessly(
  config: CodelesslyConfig(
    slug: 'my-project',
    functions: {
      'addToCart': (context, params) async {
        final id = params['productId'] as String?;
        debugPrint('add $id to the cart');
        // Change a variable of the screen that called.
        context.setVariable('cartCount', 3);
        // The result is `${result}` for the next action of the chain.
        return {'ok': true};
      },
    },
  ),
);
```

**Navigation.** Navigation actions push the project's screens on the nearest `Navigator`. A project that is the
whole app gives its screens to `MaterialApp`, so each has its URL path:

```dart
MaterialApp(onGenerateRoute: CodelesslyWidget.onGenerateRoute(codelessly))
```

To route some destinations yourself, return `true` from `onNavigate`:

```dart
CodelesslyWidget(
  codelessly: codelessly,
  layoutId: 'home',
  onNavigate: (context, request) {
    if (request.type == NavigationType.push && request.destinationId == 'settings') {
      Navigator.of(context).pushNamed('/settings', arguments: request.params);
      return true; // Handled: the SDK does nothing more.
    }
    return false; // The SDK navigates.
  },
)
```

**Controller.** A `CodelesslyWidgetController` reads and changes the shown screen from outside:

```dart
final controller = CodelesslyWidgetController(layoutId: 'cart');

controller.read('count');                 // a variable, `route.id`, `data.user.name`
controller.setVariable('count', 0);
controller.trigger('checkout-button', 'click');
controller.layoutId = 'checkout';         // show another layout
```

## Developer guide

The [developer guide](https://github.com/Codelessly/CodelesslySDK/tree/master/docs/guide) covers each topic with
working code:

| | |
|---|---|
| [Introduction and concepts](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/01-introduction.md) | Editor, publish, SDK; the model and the renderer |
| [Quickstart](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/02-quickstart.md) | Five minutes to a running screen |
| [Embedding and sizing](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/03-embedding-and-sizing.md) | Layout ids, canvases, sizing, builders, the controller |
| [Loading modes and caching](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/04-loading-and-caching.md) | Slug, token, bundles, self-hosting, offline |
| [Data and variables](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/05-data-and-variables.md) | `data`, `route`, `storage`, screen and app variables |
| [Actions and functions](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/06-actions-and-functions.md) | Triggers, the action list, your functions |
| [Navigation](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/07-navigation.md) | Routes, deep links, `onNavigate` |
| [Conditions and breakpoints](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/08-conditions-and-breakpoints.md) | Conditions, `${screen}`, responsive canvases |
| [Cloud data and services](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/09-cloud-data-and-services.md) | Firebase, auth, APIs, storage, analytics |
| [Scripting](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/10-scripting.md) | JavaScript in a sandbox; the QuickJS engine |
| [Theming and fonts](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/11-theming-and-fonts.md) | Project theme, host theme, fonts, text scale |
| [Custom widgets](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/12-custom-widgets.md) | Your widgets inside a layout; your own services |
| [Publishing and environments](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/13-publishing-and-environments.md) | Publish, preview, templates, app identity |
| [Testing](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/14-testing.md) | Widget tests without a network |
| [Troubleshooting and FAQ](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/15-troubleshooting.md) | Errors and what they mean |
| [Migrating from 10.x](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/16-migrating-from-10.md) | What changed in 20 |

The [example app](https://github.com/Codelessly/CodelesslySDK/tree/master/v2/example) runs offline and shows an
embedded layout with data, a function and a controller, and a whole project as an app.

## Libraries

| Import | What |
|---|---|
| `package:codelessly_sdk/codelessly_sdk.dart` | `Codelessly`, `CodelesslyWidget`, loaders, services. Never imports Firebase. |
| `package:codelessly_sdk/firebase.dart` | `codelesslyWithToken`, and Codelessly's services on Firebase (publish, accounts, cloud data, files, paywalls). |
| `package:codelessly_sdk/store.dart` | In-app purchases through the App Store and Google Play. |

Scripts need an engine on devices: add
[`codelessly_quickjs`](https://pub.dev/packages/codelessly_quickjs) to apps whose projects use scripts. The data
model is its own package, [`codelessly_api`](https://pub.dev/packages/codelessly_api).

## Coming from 10.x?

Version 20 reads projects in the new format (`"schema": 2`) that the Codelessly Editor now publishes. SDK 10.x and
older can't read a project published in that format, and SDK 20 can't read one that was never converted: it fails
with a `PublishLoadException` that says so. The API changed too (`layoutID` is `layoutId`, instances are explicit,
functions are plain Dart functions). See
[Migrating from 10.x](https://github.com/Codelessly/CodelesslySDK/blob/master/docs/guide/16-migrating-from-10.md).

## License

BSD 3-Clause. See [LICENSE](https://github.com/Codelessly/CodelesslySDK/blob/master/v2/LICENSE).
