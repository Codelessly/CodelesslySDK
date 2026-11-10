# 9. Cloud data and services

[Guide](README.md) · Previous: [Conditions and breakpoints](08-conditions-and-breakpoints.md) · Next: [Scripting](10-scripting.md)

Actions reach the outside world through **services**: one `Services` object per `Codelessly`, set on
`CodelesslyConfig.services`. Every service has a default that works with no backend, and each can be replaced.

## The services

| Field | Used by | Default | With Codelessly's Firebase |
|---|---|---|---|
| `api` | `callApi` actions, API-backed lists | `HttpApiService` (real HTTP) | Same |
| `storage` | `setStorage`, `${storage.*}`, persisted variables | In memory | `PreferencesLocalStorage` to keep values |
| `auth` | `auth` actions | Signed out; every operation fails | `FirebaseAuthService` |
| `cloud` | Cloud data actions, data-bound lists | In memory (`MemoryDocumentBackend`) | `FirestoreDocumentBackend` |
| `files` | `cloudFiles` (uploads) | In memory | `FirebaseFileStorage` |
| `analytics` | Screen views, events, errors | Printed in debug builds, dropped in release | Yours |
| `purchases`, `paywalls` | `paywall` actions | None | `StorePurchaseService`, `FirebasePaywallBackend` |
| `sound` | `playSound` | The browser's audio on the web; silent elsewhere | Same |
| `speech` | `speak` | The browser's voice on the web; none elsewhere | Same |
| `links` | `openLink` | `url_launcher` | Same |
| `scripts` | `runScript`, `script.name()` | The platform's sandbox ([Scripting](10-scripting.md)) | Same |
| `cache`, `fileCache` | Internal caches | In memory | Same |

With no `services` at all, `Codelessly` uses `Services()`: APIs and links work, and everything stateful is in
memory.

## Codelessly cloud data, accounts and files

Projects that use Codelessly's cloud data ("Cloud data" actions, lists bound to a collection), app user accounts
or file uploads keep them in Codelessly's Firebase, under the project. With a project token, one flag sets them
up:

```dart
final codelessly = await codelesslyWithToken('YOUR_PROJECT_TOKEN', cloudServices: true);
```

That authenticates the token first (the project's id is needed), then builds the project's services with
`codelesslyCloudServices`. The same by hand, for when you want to change a piece (here: storage that persists):

```dart
final app = await codelesslyFirebaseApp();
final firestore = FirebaseFirestore.instanceFor(app: app);
final services = codelesslyCloudServices(
  projectId: projectId,
  firestore: firestore,
  auth: FirebaseAuth.instanceFor(app: app),
  storage: FirebaseStorage.instanceFor(app: app),
  localStorage: await PreferencesLocalStorage.open(prefix: 'codelessly.$projectId.'),
);
final codelessly = codelesslyOnFirebase(
  firestore: firestore,
  config: CodelesslyConfig(projectId: projectId, authToken: 'YOUR_PROJECT_TOKEN', services: services),
);
```

What that wires:

| Service | Where the data lives |
|---|---|
| Cloud data | Firestore, under the document `data/{projectId}`. The project's data rules (who may read and write each collection, schemas, indexes) are the document `data_rules/{projectId}`; the SDK follows them live and applies them. |
| Accounts | Firebase Auth on Codelessly's Firebase app: email and password, email links, Google and Apple. Signing out signs in anonymously again, because the publish is read as an anonymous user. |
| Files | Firebase Storage, under `data/{projectId}`. |

Things to know:

- **Slug mode has no cloud services by itself.** A slug loads the publish over HTTP; cloud data still needs
  Firebase and the project's access. Build the services as above (you need the project id; the loaded model has
  it: `codelessly.publishModel!.projectId`), or use a token.
- **Google and Apple sign-in** need the platform setup those providers require (URL schemes, entitlements) and
  that the provider is enabled for the backend. Email and password needs nothing.
- **Linux desktop** has no Firebase: use your own `AuthService`, `DocumentBackend` and `CloudFileStorage`, or the
  in-memory ones.
- **The signed-in user in layouts**: see [Data and variables](05-data-and-variables.md#the-signed-in-user).

### Cloud data without a backend

The default cloud database is in memory: cloud data actions and data-bound lists work, and the data is gone when
the app closes. That is right for demos and tests:

```dart
final codelessly = Codelessly(
  config: CodelesslyConfig(
    slug: 'my-project',
    services: Services(cloud: BackendCloudDatabase(backend: MemoryDocumentBackend())),
  ),
);
```

To use your own database, implement `DocumentBackend` (get, watch, query, write documents) and give it to
`BackendCloudDatabase`, which adds the rules, owner stamps and relations on top.

## HTTP APIs

A project's APIs (made in the Editor's API builder) are published with it. A `callApi` action names one and gives
its inputs. The response is `${result}` for the next actions: `data` (the body, parsed when it is JSON),
`statusCode`, `headers`, `isSuccess`, `isError` and `error`. The action has `onSuccess` and `onError` chains.

The default `HttpApiService` sends the request from the device. On the web, browsers enforce CORS: an API that
doesn't allow your origin fails. Give the service a proxy you host:

```dart
final codelessly = Codelessly(
  config: CodelesslyConfig(
    slug: 'my-project',
    services: Services(api: HttpApiService(proxy: Uri.parse('https://example.com/api/proxy'))),
  ),
);
```

The request is then POSTed to the proxy as `{url, method, headers, body}`, and its reply
`{statusCode, headers, body}` is the response.

API secrets in a published project are in the client. Keep secrets on a server (your proxy, or a function your
app registers that calls your backend).

## Your own analytics and links

```dart
class MyAnalytics implements AnalyticsService {
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) => debugPrint('event $name $parameters');

  @override
  void logScreen(String name, {String? layoutId}) => debugPrint('screen $name');

  @override
  void logError(Object error,
          {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) =>
      debugPrint('error $type: $error');
}

class InAppLinks implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    debugPrint('open $url in the app');
    return true;
  }
}

final codelessly = Codelessly(
  config: CodelesslyConfig(
    slug: 'my-project',
    services: Services(analytics: MyAnalytics(), links: InAppLinks()),
  ),
);
```

`logError` is where failed actions end up. In production, send them to your crash reporter: the default drops
them in release builds.

## Purchases and paywalls

`package:codelessly_sdk/store.dart` has `StorePurchaseService` (StoreKit and Play Billing through the
`in_app_purchase` plugin). `firebase.dart` has `FirebasePaywallBackend`, which resolves paywall placements and
verifies purchases on Codelessly's backend. They are given to `Services(purchases:, paywalls:)` with a
`PaywallRuntime`. Paywalls need store products and the paywall configured for the project; without them, `paywall`
actions fail and the rest of the app is unaffected. See the API docs of `PaywallRuntime` and
`StorePurchaseService` for the constructor parameters.

## Lifetime

`Services` are yours when you create them: call `services.dispose()` when the app is done with them.
`Codelessly.dispose()` does not dispose its services.

Next: [Scripting](10-scripting.md)
