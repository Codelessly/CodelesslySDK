# 12. Custom widgets and extending

[Guide](README.md) · Previous: [Theming and fonts](11-theming-and-fonts.md) · Next: [Publishing and environments](13-publishing-and-environments.md)

Three ways to extend what a layout can do, from most to least common:

1. [Your Flutter widgets inside a layout](#your-widgets-inside-a-layout) (external components).
2. [Your code behind a layout](#your-code-behind-a-layout) (functions, services).
3. [Wrapping a layout](#wrapping-a-layout) (`layoutBuilder`).

![Three ways to extend: your Flutter widgets inside a layout, your code behind it, and wrapping it with layoutBuilder](images/12-custom-widgets/ways.png)

*Three ways to extend, from most to least common.*

What is **not** supported: registering a new node type with its own renderer from outside the SDK. Widget types
are part of the SDK ([`CONTRIBUTING.md`](../../CONTRIBUTING.md) is the contributor's guide to adding one). A node type
this version doesn't know still decodes and round-trips, and renders as an empty box of its size.

## Your widgets inside a layout

![ExternalComponents in MaterialApp.builder maps the builder id map to your widget, which fills the external component's box in the layout](images/12-custom-widgets/hero.png)

*An external component node, filled by your widget. The screen is an illustration.*

In the Editor, an **external component** node reserves a box in the layout and names a builder (its
`builderId`). In your app, `ExternalComponents` maps builder ids to widgets:

```dart
MaterialApp(
  // Above the navigator, so every screen the project pushes has them.
  builder: (context, child) => ExternalComponents(
    builders: {
      'map': (context) => const Placeholder(), // your map widget
      'ad-banner': (context) => const SizedBox(height: 50, child: Center(child: Text('Ad'))),
    },
    child: child!,
  ),
  home: CodelesslyWidget(codelessly: codelessly),
)
```

- The widget is laid out in the node's box, with the node's size and fits.
- Put `ExternalComponents` above everything that shows layouts. Screens pushed by navigation actions live under
  the `Navigator`, so placing it in `MaterialApp.builder` (or above `MaterialApp`) covers them; wrapping a single
  `CodelesslyWidget` covers only that widget.
- A builder id with no builder shows a `Placeholder`.
- A builder gets a `BuildContext` only. To give the widget data, read it from your own state (a provider, an
  inherited widget), or have the layout call a [function](06-actions-and-functions.md) that updates that state.
  The node's props are not passed to the builder.

Use this for things that must be native widgets of your app: maps, ads, camera previews, charts from a package,
platform views, or a widget you already have.

## Your code behind a layout

- **Functions** (`CodelesslyConfig.functions`): a layout's "call function" action runs your Dart code and can use
  its result. See [Actions and functions](06-actions-and-functions.md).
- **Native scripts** (`FunctionScriptRunner`): implement a project's scripts in Dart. See
  [Scripting](10-scripting.md#replacing-or-turning-off-the-engine).

### Replacing a service

Every field of `Services` is an interface with a default; implement the interface and pass yours. The ones apps
most often replace:

| Interface | Why replace it |
|---|---|
| `AnalyticsService` | Send screen views, events and action errors to your analytics and crash reporter. |
| `LinkOpener` | Open links in an in-app browser, or route app links yourself. |
| `LocalStorage` | Keep `storage` values and persisted variables in your own store (secure storage, a database). |
| `AuthService` | Use your own accounts instead of Codelessly's. |
| `DocumentBackend` (in a `BackendCloudDatabase`) | Serve "cloud data" from your own backend. |
| `CloudFileStorage` | Upload files to your own storage. |
| `ApiService` | Add headers, logging or a proxy to every API call. |
| `FontFetcher` (on `Codelessly`) | Ship fonts with the app. |
| `PublishLoader`, `PublishCache` (on `Codelessly`) | Load the publish from your own server; cache it on disk. |

```dart
final codelessly = Codelessly(
  config: CodelesslyConfig(
    slug: 'my-project',
    services: Services(analytics: MyAnalytics(), links: InAppLinks()),
  ),
);
```

The SDK ships in-memory and recording implementations of most interfaces (`MemoryLocalStorage`,
`MemoryAuthService`, `MemoryDocumentBackend`, `MemoryFileStorage`, `RecordingAnalytics`, `RecordingLinkOpener`),
which make good starting points and test doubles.

## Wrapping a layout

`layoutBuilder` wraps the loaded layout with any widgets: a `SafeArea`, an overlay, a `RefreshIndicator`, a
banner.

```dart
CodelesslyWidget(
  codelessly: codelessly,
  layoutId: 'home',
  layoutBuilder: (context, layout) => Stack(
    children: [
      Positioned.fill(child: layout),
      const Positioned(right: 12, bottom: 12, child: Text('beta')),
    ],
  ),
)
```

With `CodelesslyWidget.onGenerateRoute(codelessly, template: ...)`, the template's `layoutBuilder` wraps every
screen.

## Lower-level building blocks

The SDK exports its render layer for hosts that show nodes without a publish (an editor's canvas, a preview
tool): `NodeTree` (the render tree of a document), `NodeView` (the widget that shows one of its roots),
`DocumentSource`, and the island interfaces. `NodeView(interactive: false)` draws a design at rest. These are
stable enough for the Codelessly Editor, which is built on them, but they are a lower-level API than
`CodelesslyWidget`: prefer the widget unless you are building tooling.

Next: [Publishing and environments](13-publishing-and-environments.md)
