# 9. Cloud data and services

[Guide](README.md) · Previous: [Conditions and breakpoints](08-conditions-and-breakpoints.md) · Next: [Scripting](10-scripting.md)

Actions reach the outside world through **services**: one `Services` object per `Codelessly`, set on
`CodelesslyConfig.services`. Every service has a default that works with no backend, and each can be replaced.

![Services fields with their defaults and their Firebase counterparts: api, storage, auth, cloud, files, analytics and more](images/09-cloud-data-and-services/hero.png)

*Every service has a default that needs no backend.*

## The services

| Field | Used by | Default | With Codelessly's Firebase |
|---|---|---|---|
| `api` | `callApi` actions, API-backed lists | `HttpApiService` (real HTTP) | Same |
| `storage` | `setStorage`, `${storage.*}`, persisted variables | In memory | `PreferencesLocalStorage` to keep values |
| `auth` | `auth` actions, `codelessly.auth`, `${auth.*}` | Signed out; every operation fails | `CodelesslyAuthService` (Codelessly accounts) or `FirebaseAuthService` |
| `cloud` | Cloud data actions, data-bound lists | In memory (`MemoryDocumentBackend`) | `FirestoreDocumentBackend` |
| `files` | `cloudFiles` (uploads) | In memory | `FirebaseFileStorage` |
| `analytics` | Screen views, events, errors | Printed in debug builds, dropped in release | Yours |
| `purchases`, `paywalls` | `paywall` actions, `codelessly.paywall` | None | `StorePurchaseService`, `FirebasePaywallBackend` |
| `sound` | `playSound` | The browser's audio on the web; silent elsewhere | Same |
| `speech` | `speak` | The browser's voice on the web; none elsewhere | Same |
| `links` | `openLink` | `url_launcher` | Same |
| `scripts` | `runScript`, `script.name()` | The platform's sandbox ([Scripting](10-scripting.md)) | Same |
| `cache`, `fileCache` | Internal caches | In memory | Same |

With no `services` at all, `Codelessly` uses `Services()`: APIs and links work, and everything stateful is in
memory.

## Codelessly cloud data, accounts and files

![codelesslyWithToken with cloudServices true wires cloud data, accounts and files in Codelessly's Firebase; slug mode has none by itself](images/09-cloud-data-and-services/cloud-services.png)

*One flag, three services.*

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
| Accounts | Codelessly accounts: the project's own users, kept by Codelessly ([below](#codelessly-accounts)). On the old backend (`codeless-app`, the platforms where `codeless-editor` has no app yet): Firebase Auth accounts, signed in anonymously to read the publish. |
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

## Codelessly accounts

With `cloudServices: true` on Codelessly's backend (`codeless-editor`), each project has **its own users**,
kept by Codelessly: the same email in two apps is two accounts, and app users never mix with Codelessly Editor
accounts. `codelessly.auth` is the API, shaped like Supabase's:

```dart
Future<void> accounts(Codelessly codelessly) async {
  final auth = codelessly.auth;
  final events = auth.onAuthStateChange.listen((state) {
    debugPrint('${state.event.name}: ${state.user?.email ?? 'signed out'}');
  });
  // An anonymous user (the cloud services make one on first use) keeps their
  // uid and data when they sign up.
  await auth.signUp(email: 'ada@example.com', password: 'a long password', data: {'displayName': 'Ada'});
  await auth.signOut();
  await auth.signInWithPassword(email: 'ada@example.com', password: 'a long password');
  await auth.updateUser(const UserAttributes(displayName: 'Ada L.'));
  debugPrint('Signed in as ${auth.currentUser?.displayName}');
  await events.cancel();
}
```

| Member | What it does |
|---|---|
| `currentUser`, `currentSession` | The user (`AppUser`; an anonymous one has `isAnonymous`) and the session token, or null |
| `onAuthStateChange` | `AuthState`s: `initialSession`, `signedIn`, `signedOut`, `userUpdated`, `tokenRefreshed`, `merged` |
| `signUp(email:, password:, data:)` | Creates the account and signs it in. `data['displayName']` names the user; the rest of `data` goes in their profile |
| `signInWithPassword(email:, password:)` | Signs in. Five wrong passwords lock the account for a minute, then longer |
| `signInAnonymously()` | A guest session (as the `signInAnonymously` auth action): the anonymous session, made now when there is none, marked `isGuest`, so `${auth.uid}` shows it. A signed-in user is signed out first. Works on Firebase Auth accounts too |
| `updateUser(UserAttributes(...))` | Name, photo, password (with `currentPassword`, or within 5 minutes of signing in) |
| `signOut(scope:)` | This device (`SignOutScope.local`), or every session of the user (`SignOutScope.global`) |
| `refreshSession()`, `deleteUser()` | A fresh token; deletes the account (needs a recent sign-in) |

How sessions work:

- **No session until one is needed.** Showing the publish needs none. The first cloud data read or write, or file
  upload, signs in anonymously.
- **Sign-up keeps the anonymous user.** Their uid, data and purchases carry over. A guest session
  (`signInAnonymously()`) is that anonymous session, marked: the uid stays the same. Signing in to an existing
  account from an anonymous session sends `AuthChangeEvent.merged` with `mergedFrom`, the anonymous uid, so the
  app can move a cart over.
- **The session persists.** Each project has its own Firebase app (`codelessly.{projectId}`) that keeps the
  session between runs and refreshes its token. `codelessly.auth.onAuthStateChange` starts with the restored
  session.
- **Roles and disabling take effect live.** The project's editors set a user's role or disable them in the
  Editor's Users table; a running app picks the role up at once (`${auth.role}`), and a disabled user is signed
  out.
- **Not available yet:** email verification (new accounts have `emailVerified: false`), password reset by email,
  email links, codes, and Google or Apple sign-in. Those operations fail with an `AuthFailure` whose `code` is
  `not_available`.

Failures are `AuthFailure`s with a message to show and the store's `code` (`invalid_credentials`,
`email_exists`, `weak_password`, `too_many_attempts`, `rate_limited`, `user_disabled`,
`requires_recent_login`).

The `auth` actions of a layout (sign in, sign up, sign out, update profile or password, delete account) run on the
same accounts, and layouts read the user as `${auth.*}`
([Data and variables](05-data-and-variables.md#the-signed-in-user)).

For tests and demos, `MemoryAuthService` behaves the same (anonymous users included) without a backend:
`Services(auth: MemoryAuthService())`.

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

![On the web, callApi posts {url, method, headers, body} to your proxy, which calls the API and returns {statusCode, headers, body}](images/09-cloud-data-and-services/api-proxy.png)

*A proxy you host gets past CORS on the web.*

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

`codelessly.paywall.present(context, placement: ...)` shows a published paywall: see [Paywalls](16-paywalls.md).
With cloud services (`codelesslyWithToken(..., cloudServices: true)`, or `codelesslyCloudServices(functions:)`)
paywalls are managed by Codelessly: `codelesslyPaywalls` sets `Services(paywalls:, purchases:)` to a
`PaywallRuntime` on `FirebasePaywallBackend` (placements resolved and purchases verified by Codelessly's backend)
and a `StorePurchaseService` (`package:codelessly_sdk/store.dart`: StoreKit and Play Billing through the
`in_app_purchase` plugin). Without them, `paywall` actions outside a presented paywall fail and the rest of the
app is unaffected.

## Lifetime

`Services` are yours when you create them: call `services.dispose()` when the app is done with them.
`Codelessly.dispose()` does not dispose its services.

Next: [Scripting](10-scripting.md)

### Read-along word boundaries

The live `speech` expression value includes `speaking`, `text`, `available`,
`boundaryAvailable`, `charIndex`, `charLength`, `wordIndex` and `word`.
`wordIndex` starts at -1 and updates only when the platform voice delivers a
real word boundary; it returns to -1 when narration ends or is stopped.
Character offsets use UTF-16, matching browser SpeechSynthesis events.
Whitespace separates words and punctuation stays with its word.

For read-along text, repeat `split(text, ' ')` and highlight the item where
`index == speech.wordIndex`. Some browser voices do not emit word boundaries;
those voices can narrate without a moving highlight. There is no estimated
timer fallback. `boundaryAvailable` means the engine exposes the boundary API,
not that every voice guarantees events.

Native hosts can keep an existing `SpeechEngine` implementation, or implement
`BoundarySpeechEngine.speakWithBoundaries` and send `SpeechBoundary` events
from their platform TTS. Late events from canceled utterances are ignored.
