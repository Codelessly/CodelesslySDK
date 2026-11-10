# 4. Loading modes and caching

[Guide](README.md) · Previous: [Embedding and sizing](03-embedding-and-sizing.md) · Next: [Data and variables](05-data-and-variables.md)

A `Codelessly` gets its publish from a `PublishLoader` and keeps it in a `PublishCache`. This chapter covers the
loaders that ship with the SDK, what is cached, and how to run offline.

## The modes at a glance

| Mode | Create it with | Loader | Firebase | Live updates | Offline |
|---|---|---|---|---|---|
| Slug | `Codelessly(config: CodelesslyConfig(slug: ...))` | `HttpPublishLoader` (one bundle) | No | No | With a cache that persists |
| Project token | `codelesslyWithToken(token)` | `FirestorePublishLoader` | Yes, set up for you | Yes | With a cache that persists |
| Project id | `codelesslyOnFirebase(config: CodelesslyConfig(projectId: ...))` | `FirestorePublishLoader` | Yes | Yes | With a cache that persists |
| Asset bundle | `Codelessly.asset(path)` | `AssetPublishLoader` | No | No | Always |
| In-memory bundle | `Codelessly.fromBundle(bundle)` | `MemoryPublishLoader` | No | No | Always |
| Self-hosted | `Codelessly(loader: HttpPublishLoader(...))` | `HttpPublishLoader` | No | No | With a cache that persists |
| Your own | `Codelessly(loader: MyLoader())` | A `PublishLoader` you write | Up to you | If it is a `LivePublishLoader` | Up to you |

## What loading does

1. `initialize()` loads the **publish model**: the list of layouts, the entry screen, fonts, theme, APIs, app
   variables and breakpoints. A `CodelesslyWidget` calls it when it first builds, and calling it again is free.
2. Each **layout** loads when a widget first shows it (or all at once with `preload`), followed by its fonts.
3. If the loader is live and `liveUpdates` is on, the instance follows the publish model. When a publish arrives,
   layouts that were republished are dropped and load again the next time they are shown; widgets showing one
   reload it.

```dart
// Load before the first frame, and handle a failure yourself.
try {
  await codelessly.initialize();
} on PublishLoadException catch (e) {
  debugPrint('Could not load the project: ${e.message}');
}
```

`codelessly.status` is `CEmpty`, `CLoading`, `CLoaded` or `CError`, and the instance notifies its listeners when
it changes.

Options on `CodelesslyConfig`:

| Option | Default | Effect |
|---|---|---|
| `preload` | `false` | `initialize()` also loads every layout, so screens show without a loading state. |
| `liveUpdates` | `true` | Follow a live loader's publishes while the app runs. |
| `publishSource` | `PublishSource.publish` | `preview` shows the Editor's unpublished preview; `template` a template project. |
| `fontTimeout` | 2 seconds | How long a layout waits for its fonts before it shows. They apply when they arrive. |

## Slug

```dart
final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'));
```

The publish is one file in Codelessly's storage bucket, `publish/<slug>.json`, fetched with a plain HTTP GET. It
is fetched when the instance initializes, so the app gets a new publish the next time it starts (or after
`reset()`).

## Project token

```dart
final codelessly = await codelesslyWithToken('YOUR_PROJECT_TOKEN');
```

What happens:

1. `codelesslyFirebaseApp()` creates (once) a secondary Firebase app named `codelessly` with
   `CodelesslyFirebaseOptions.currentPlatform`: the public client options of Codelessly's Firebase project. Your
   app's default Firebase app is not used or changed.
2. On first load, `FirebaseProjectAuth` signs in anonymously on that app and sends the token to Codelessly's
   backend, which names the token's project and grants the signed-in user a claim for it. The security rules of
   the publish check that claim.
3. `FirestorePublishLoader` reads `publish/{projectId}` and its layouts, and watches the model for live updates.

The same, assembled by hand, for when you need to change a piece:

```dart
final app = await codelesslyFirebaseApp();
final codelessly = codelesslyOnFirebase(
  firestore: FirebaseFirestore.instanceFor(app: app),
  config: const CodelesslyConfig(authToken: 'YOUR_PROJECT_TOKEN'),
);
```

`package:codelessly_sdk/firebase.dart` exports `Firebase`, `FirebaseApp`, `FirebaseOptions`, `FirebaseFirestore`,
`FirebaseAuth` and `FirebaseStorage`, so you don't add the Firebase packages to your pubspec for this.

The Editor's preview instead of the publish (for a debug build that follows your edits):

```dart
final codelessly = await codelesslyWithToken(
  'YOUR_PROJECT_TOKEN',
  config: const CodelesslyConfig(publishSource: PublishSource.preview),
);
```

A token is a client credential: it ships in your app, like a Firebase API key. It grants read access to that
project's publish.

Not supported: Linux desktop (no Firebase there).

## Asset bundle

```dart
final codelessly = Codelessly.asset('assets/my_project.json.gz');
```

The asset is a bundle: `{"model": {...}, "layouts": {"<layoutId>": {...}}}`, as JSON or gzipped JSON (detected by
its first bytes, not its name). It is read once. The bundle holds the project, not its media: fonts, icons and
images still load from their URLs ([Theming and fonts](11-theming-and-fonts.md) covers shipping fonts).

### Where a bundle file comes from

- **A published slug**: download its bundle.

  ```sh
  curl -o assets/my_project.json \
    'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/publish%2Fmy-project.json?alt=media'
  ```

- **A loaded instance**: save what any mode loaded.

  ```dart
  final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project', preload: true));
  await codelessly.initialize();
  final bundle = PublishBundle(model: codelessly.publishModel!, layouts: codelessly.layouts);
  final json = jsonEncode(bundle.toJson()); // write it to a file
  ```

- **The Editor's automation API** (MCP): `publish.export` builds the publish of the open page without publishing
  it.
- **Code**: build one with `codelessly_api`
  ([building a layout in code](https://github.com/Codelessly/CodelesslyAPI/blob/master/docs/guide/04-building-layouts-in-code.md)).

## In-memory bundle

```dart
final codelessly = Codelessly.fromBundle(PublishBundle.fromJson(json));
```

For a bundle your app downloaded itself, `decodeBundle(bytes)` reads JSON, gzipped or not:

```dart
final bundle = decodeBundle(bytes);
final codelessly = Codelessly.fromBundle(bundle);
```

## Self-hosted

`HttpPublishLoader` reads a publish from any HTTP server.

```dart
final codelessly = Codelessly(
  loader: HttpPublishLoader(
    projectId: 'my-project',
    baseUrl: 'https://cdn.example.com/codelessly',
    bundle: true, // GET https://cdn.example.com/codelessly/publish/my-project.json
    headers: const {'Authorization': 'Bearer <token>'},
  ),
);
```

| `bundle` | Requests |
|---|---|
| `true` | `<baseUrl>/publish/<projectId>.json`: the whole publish in one file |
| `false` | `<baseUrl>/publish/<projectId>.json` (the model) and `<baseUrl>/publish/<projectId>/layouts/<layoutId>.json` (each layout, when first shown) |

`urlFor` maps a path to any URL you like, and `client` takes your own `http.Client`.

## Your own loader

Implement `PublishLoader` (two methods), or `LivePublishLoader` to also push new publishes:

```dart
abstract interface class PublishLoader {
  Future<PublishModel> loadModel(PublishSource source);
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId);
}

abstract interface class LivePublishLoader implements PublishLoader {
  Stream<PublishModel> watchModel(PublishSource source);
}
```

Throw a `PublishLoadException` on failure; its message reaches the error builder.

## Caching and offline

Everything loaded goes through the instance's `PublishCache`:

- `initialize()` reads the model from the cache first. If it is there, the instance is ready at once and the model
  is refreshed from the loader in the background. If not, it waits for the loader.
- A cached layout is used while it is as new as the model says it should be (`lastUpdated`). Otherwise the loader
  is asked, and if that fails the cached copy is used.

**The default cache is in memory**: it lasts for the run. So by default an app loads its publish at each start and
needs the network to do so, except with an asset or in-memory bundle. The SDK does not ship a disk cache. To open
instantly and work offline after the first run, give the instance a cache that persists. `PublishCache` has three
methods:

```dart
/// A PublishCache that keeps the last publish between runs, in the platform's preferences.
class PreferencesPublishCache implements PublishCache {
  PreferencesPublishCache(this.storage);

  final PreferencesLocalStorage storage;

  @override
  Future<Json?> read(String key) async {
    final value = storage.get(key);
    return value is String ? (jsonDecode(value) as Map).cast<String, Object?>() : null;
  }

  @override
  Future<void> write(String key, Json value) => storage.put(key, jsonEncode(value));

  @override
  Future<void> clear() => storage.clear();
}

final cache = PreferencesPublishCache(await PreferencesLocalStorage.open(prefix: 'codelessly.cache.'));
final codelessly = Codelessly(config: const CodelesslyConfig(slug: 'my-project'), cache: cache);
```

`PreferencesLocalStorage` is the SDK's wrapper over `shared_preferences`. For large projects prefer files or a
database: on the web, preferences are `localStorage`, which is limited to a few megabytes.

To start over:

```dart
await codelessly.reset(clearCache: true);
await codelessly.initialize();
```

A bundle in your assets plus a persistent cache is the most robust setup: ship a bundle for the first run, and let
a slug or token refresh it afterwards. That needs a loader of your own that tries the network and falls back to
the asset; the SDK has no built-in fallback chain.

Next: [Data and variables](05-data-and-variables.md)
