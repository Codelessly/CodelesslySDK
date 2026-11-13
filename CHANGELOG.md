## Unreleased

**New**

- An app's own node types: `CodelesslyConfig.recipes` (and `NodeTree(recipes:)`) map a node type to a
  `WidgetRecipe`, over the built-in ones. `WidgetRecipe`, `NodeBuilder` and `RenderFitBox` are exported. Recipes
  are per tree, not a global table.
- An app's own action types: a handler in `CodelesslyActions(handlers:)` for a type the API doesn't declare now
  runs (the action is an `UnknownAction`; its fields are `json`). Before, an unknown type was skipped even with a
  handler, so handlers could only replace built-in types.
- The render core (`lib/src/render`) stands on its own: it imports Flutter, the model and drawing packages
  only, and takes what it needs from the layers above through interfaces it owns (`TreeBindings`, `BoundValues`,
  `NodeGestures`, `ImageBytesLoader`, `RecipeCatalog`). `RenderTree` is its tree; `NodeTree` is a `RenderTree`
  with the SDK's widgets, gestures and HTTP image loader, so `NodeTree(source)` renders as before. Boxes, views
  and recipes name their tree as `RenderTree` (`NodeBox.tree`, `NodeView.tree`, `ActionHost.tree`): code that
  held one in a `NodeTree` variable types it `RenderTree`. `tree.binder` is unchanged. A render object that
  paints images outside any tree (a bare `RenderIconGlyph`) fetches SVGs only when given an `imageLoader`.
  `test/architecture_test.dart` checks the layering.

**Fixes**

- A paywall `restore` action outside a paywall screen (a Restore purchases row in Settings) restores through
  the action's `placement`, or the project's first placement, instead of failing with "Paywall action outside a
  paywall". It never opens the paywall; an empty restore reaches the screen's `actionError` reaction as
  `nothing-to-restore`. New: `PaywallRuntime.restoreAt`.

## 24.0.0

**Breaking changes**

- Requires `codelessly_api` 24.0.0.
- A `submitForm` action with the removed Mailchimp service (or no service and the removed fields) sends nothing
  and fails as `unsupported_service`, through the same result and error callbacks. Use a `callApi` action to your
  own endpoint, which keeps the provider's key server-side.
- A canvas's `actionError` event has `retryable` beside `type`, `code`, `message`, `action` and `nodeId`.

**New**

- `retryFailed` action: in a canvas's `actionError` reaction (a toast's Retry), runs the failed action chain again —
  the same node's reactions to the same trigger, with the same event and list item. The error event has
  `retryable`. `RuntimeActionContext.failed` (`FailedActions`).
- Paywall test store, for web preview and demo sites: on the web (no store), a paywall published with
  `"testStore": true` (or any, with `Services(testStore: TestStoreMode.force)` for the editor's run preview) runs its
  whole flow — products, trial, purchase, restore, cancel and decline — from its slots' test data
  (`ProductSlot.test`) without charging and without real entitlements. `TestPurchaseService`, `TestPaywallBackend`
  (never contacts the paywall server), `TestPurchaseLedger` (test purchases per user, in `Services.storage`),
  `TestStore`, `TestStoreMode` (`auto`, `force`, `off`); `Services.testStore`, `web`, `usesTestStore` and
  `paywallsChanged` (`Services.paywalls` and `purchases` are the test store's while it's on);
  `codelesslyCloudServices(testStore:)`, `codelesslyWithToken(testStore:)`. `PaywallProduct.test` (`test` in its
  value, false for real products). Never on iOS, Android or desktop by the published flag, nor forced in their
  release builds. See the guide's [Paywalls](docs/guide/16-paywalls.md#test-store-web-previews-and-demos).
- `PaywallRuntime.open` adds a verified purchase's entitlement to `entitlements` before disposing its session (it
  could be dropped when the session was disposed before its result's listener ran).
- Backdrop screens: a project's backdrop canvases (`CanvasProps.backdrop`, `PublishModel.backdrops`) are drawn once
  beneath every screen, outside navigation, by `CodelesslyBackdropHost(codelessly:, child:)` as
  `MaterialApp.builder` (a `CodelesslyPresenterHost` there draws them too; `backdrops: false` leaves them out).
  Route transitions move only the screens; the backdrop keeps its state and stays still. Screens whose canvas has
  no fill show it through: while backdrops are shown, `CodelesslyPageRoute` plays the theme's page transition
  without the scrim or surface color it paints behind the screens (`seeThroughPageTransitions`,
  `SeeThroughZoomPageTransitionsBuilder`). Projects without backdrops are unchanged.
- Cloud data follows the new data rules `ownerRead` (each user reads their own documents, which only the project
  writes; the owner may change the rules' `ownerFields`) and `audience` (a user reads the documents whose `audience`
  list names them, their role, signed-in users or everyone), and a collection's `expiry` field: queries filter
  `field > now` and keep that bound (and the owner or audience filter) on the database when the app finishes the
  rest, live queries drop documents as they expire, and writes store the field as ISO text (empty or missing:
  `DataRules.neverExpires`). `BackendCloudDatabase(audience:)` gives what the user matches;
  `codelesslyCloudServices` gives it an `AuthAudience` (the role in the user's profile, signed in unless anonymous),
  and live queries, joins and live counts follow a change of user or role. `CloudQuery.plan`
  takes `keepOnServer`. See the guide's [Cloud data and services](docs/guide/09-cloud-data-and-services.md).
- Presenting layouts from anywhere: `codelessly.present(layoutId, presentation:, params:, data:, dismissible:,
  priority:, anchor:, ...)` shows a layout above the host app (dialog, sheet, side sheet, full screen, popover or
  banner) and completes with its `closeModal` result (null when dismissed). One at a time, by priority.
  `CodelesslyPresenterHost` (as `MaterialApp.builder`) leads it to the app's navigator; `codelessly.presenter`.
- Banners: `openModal` with `presentation: banner`, along the top (or bottom) edge with no barrier; swipe to
  dismiss. A presented full-screen layout or banner closes itself with `closeModal`.
- Automations: the publish model's `automations` run on app start, session start, resume, app events,
  intervals and screens shown, with a `when` formula and `maxRuns` / `maxPerSession` / `everyDays`
  (`codelessly.automations`, started by the presenter host). `${usage}` (launches, sessions, first launch, event and
  automation counts per user) in every layout.
- App events: `codelessly.emit(name, props)`, `codelessly.events`, and the `emitEvent` action.
- `captureScreenshot` action (a screen, a node, or the whole app in a `CodelesslyCaptureScope`) giving a PNG
  `data:` URL; `cloudFiles` with `source` uploads such a value instead of asking the user.
- `codelessly.registerFunction` / `unregisterFunction` / `functions` (live, over `CodelesslyConfig.functions`);
  `callFunction` with `optional: true` skips a function the app didn't register.
- `listView` with `stickToEnd: true`: opens at its end, keeps its place when items are put in front, follows new
  items at the end only while there (chats, logs).
- A bottom sheet modal rises above the keyboard.
- A plain box as a canvas's body keeps its own size (it had none): it paints and runs its click reactions, as a
  stack does.
- Guide: [Presenting, automations and host features](docs/guide/17-presenting-and-automations.md).

- `screen.backdrop`: whether the app draws backdrop screens beneath the screen (false inside a backdrop, in dialogs
  and sheets), so a screen can hide its own background where one is drawn (`${= !screen.backdrop}`).
- `Services.filePicker` (`PlatformFilePicker`, the browser's or platform's file dialog, by default;
  `FixedFilePicker` for tests and previews): a `cloudFiles` upload without a `source` asks it for the files.

**Improvements and fixes**

- A row or column that hugs its height and stretches its children measures again when a child changes while the
  tree lays out, and when a bound text changes only its words: longer text no longer overflows at the old height.
- A paywall `purchase` with a bound slot (`${sel}`) buys the selected plan.
- A toast raised from a dialog shows above the dialog's barrier, not dimmed under it.
- Confirm sheets take gradient confirm colors, cancel-only shadows and a floating margin.
- More reliable layout of hugging lists, tables, text fields and typewriters, and of links and their parameters.

## 23.0.0

**Breaking changes**

- Requires `codelessly_api` 23.0.0.

**Breaking changes**

- The SDK no longer calls Mailchimp. Requires the `codelessly_api` release that removes the Mailchimp service of
  `SubmitFormAction` (`FormService.mailchimp`, `apiKey`, `dataCenter`, `listId`, `emailField`, `firstNameField`,
  `lastNameField`). The SDK makes no calls to third-party services on its own.

**Migration**

- Published layouts still load and run. An old Mailchimp `submitForm` action (now `FormService.unsupported`) sends
  nothing: it fails with `{ok: false, error: {code: 'unsupported_service', ...}}` in `${result}` and its
  `resultVariable`, runs its `onError` if it has one, and otherwise stops its chain and is reported like any failed
  action (`onError` of the context, the `actionError` trigger). To keep collecting sign-ups, replace it with a
  `callApi` action to your own endpoint, which keeps the provider's key on your server.

**New**

- Relative times in formulas: `timeAgo(date, style?, locale?, labels?)` (alias `formatRelative`): `now`, `5m`,
  `3h`, `Yesterday`, `3d`, then `Mar 4` / `Mar 4, 2025` (`long`: `5 minutes ago`, `March 4`); dates to come read
  `in 5m`, `Tomorrow`; dates in the locale's words and digits, other words from `labels` (text or plural forms).
  Also `isToday`, `isPast`, `isFuture`, `isSameDay`, `isBefore`, `isAfter`.
- Clocks tick only as often as a value can change: `now()` every second; `today()`, `timeAgo`, `isToday`,
  `isPast` and `isFuture` every minute (`FormulaClock.minutes`, `ClockTick`); `nowMs()` every frame again
  (`FrameClock`). Bindings and conditions that call a function or computed variable reading the clock now tick
  too (they didn't).
  `FormulaClock.tick()` steps a clock by hand (tests, editors).
- `${theme.*}`: the project's theme for the current mode, live: role colors (`theme.surface`), every color style
  (`theme.colors.brandBlue`), text style values (`theme.text.title.fontSize`), `theme.isDark`, `theme.brightness`, `theme.hasDark`.
  Dark values of color styles (`ThemeTokens.dark`) apply in dark mode, and a theme with dark values gives a dark
  Material theme in dark mode. The mode is the device's, or with `useHostTheme` the app's theme's.
  `themeValues(tokens, dark:)`.
- `${screen.dark}`: the same as `${screen.isDark}`.
- `loadCloudData` with `scope: app`: one live subscription per `Codelessly`, shared by every screen and every
  `CodelesslyWidget` of the instance, writing an app variable; it outlives the screen that opened it and opens
  again when the signed-in user changes (`Codelessly.appData`, `AppDataSources`).
- Paywalls: `codelessly.paywall.present(context, placement: 'onboarding')` shows the paywall published at a
  placement as a full-screen route and returns a `PaywallResult` (`purchased`, `restored`, `closed`, `skipped`
  or `failed`). With `cloudServices: true` paywalls are managed by Codelessly (`codelesslyPaywalls`): placements
  resolved and purchases verified by Codelessly's server. See the guide's [Paywalls](docs/guide/16-paywalls.md).
- `CodelesslyWidget(paywall:)`: a layout's `paywall` actions act on that `PaywallSession` and its bindings read
  `product`, `products`, `paywall` and `entitlements`.
- The publish model's `paywall` setup (product slots, placements, legal links) reaches `Services.config.paywall`.
- `codelesslyCloudServices(functions:)`; `firebase.dart` exports `FirebaseFunctions`. `LazyPurchaseService`.
  `PaywallOutcome.skipped`.
- Live cloud data bindings (guide: [Live cloud data in a layout](docs/guide/09-cloud-data-and-services.md#live-cloud-data-in-a-layout)):
  - `loadCloudData` with `aggregate` (`count`, `sum`, `average`) keeps a live number in its variable without loading
    the documents (`BackendCloudDatabase.watchAggregate`: the database's aggregate, run again after this app's
    writes to the collection, on a sign in and every `refreshSeconds`).
  - `query.joins` attach another collection's document to each item (`${item.state.read}`), by a key template or a
    field, read live with `in` queries of 30 keys (`watchJoined`), not one read per item.
  - A load runs again by itself when a value its query reads changes (`${auth.uid}`, a bound limit), with a guard
    against loops; `"reactive": false` opts out. `BackendCloudDatabase(userChanges:)` makes live owner-only queries
    and counts follow sign in and out (`codelesslyCloudServices` wires it).
  - A query loads at most its `limit` (an expression), the query's limit, or 500, and its variable's `hasMore` says
    truthfully whether more match. A list variable gets the documents; a number variable an aggregate.
  - `reloadCloudData { variable }` subscribes a load afresh.
  - An app-scoped load (`"scope": "app"`) takes the same limit, aggregate and joins (a live unread badge).
  - `cloudBatch` commits its writes at once (`BackendCloudDatabase.commitBatch`), with `forEach` once per item of a
    list; more than 500 writes go in chunks, or fail first with `transaction`.
  - A list pulls to refresh without pagination (`pullToRefresh`, or a `refresh` reaction).
  - Triggers: `onceKey` (a reaction runs once per key per app session) and `enterViewport`'s `visibleMs` (stays in
    view that long first), for impressions.

**Fixes**

- Running `loadCloudData` again for the same variable replaced nothing: each run added a listener, and the older
  ones kept writing the variable until the screen went. One variable now has one subscription.
- A signed-out live query of an owner-only collection closed its stream; it now stays open and follows a sign in.

**Migration**

- A `loadCloudData` query without a limit now loads at most 500 documents (it loaded every one). Layouts with fewer
  documents see no change; past 500, `hasMore` is true and a debug message names the collection. Set `"limit": "0"`
  to load everything as before, or page with a bound limit.
- A load whose query reads a variable now follows it. A layout that relied on a load keeping the values it started
  with sets `"reactive": false`.
- `cloudBatch` steps that only write now commit together instead of one by one; a batch with a read step runs as
  before.

**Improvements and fixes**

- Form submission, action error triggers, accessible actions, media playback controls and status, and reactive audio waveforms.
- More reliable rendering and disposal of retained subtrees, virtualized lists, render layers, audio resources and asynchronous services.
- Refined scrolling, drag interactions, charts, dialog layouts, and authentication and purchase-service ownership.

## 22.0.0

**Breaking changes**

- Requires `codelessly_api` 22.0.0, where `Behaviours` is now `Behaviors`, `BehaviourFields` is now
  `BehaviorFields` and `Node.behaviours` is now `Node.behaviors`.
- `ActionsCancelled` is now `ActionsCanceled`.
- `ActionCancellation.isCancelled` is now `ActionCancellation.isCanceled`.
- `ActionRun.isCancelled` is now `ActionRun.isCanceled`.
- `PaywallOutcome.cancelled` is now `PaywallOutcome.canceled`.

## 21.0.0

**Breaking changes**

- Requires the current Firebase majors: `firebase_core` 5, `firebase_auth` 7, `cloud_firestore` 7,
  `cloud_functions` 7 and `firebase_storage` 14. If your app depends on any of these directly, move it to the same
  major.
- Apps that use `package:codelessly_sdk/firebase.dart` need Android `minSdk` 24, iOS 15 and macOS 11, the minimums
  of those Firebase plugins.
- Requires `codelessly_api` 21.0.0, Dart 3.12 and Flutter 3.35 or newer.

**New**

- `codelesslyWithToken` (`package:codelessly_sdk/firebase.dart`) creates a `Codelessly` from a project token alone.
  It opens Codelessly's Firebase project as a secondary app (`codelesslyFirebaseApp`, `CodelesslyFirebaseOptions`),
  so your app needs no Firebase setup of its own. Pass `cloudServices: true` to also enable the project's cloud
  data, accounts and files (`codelesslyCloudServices`).
- `firebase.dart` now exports the Firebase types its functions take (`Firebase`, `FirebaseApp`, `FirebaseOptions`,
  `FirebaseFirestore`, `FirebaseAuth`, `FirebaseStorage`), so you don't need extra imports to call them.
- Anchored modals: `openModal` honors `anchor`, `placement`, `anchorGap` and `anchorOffset`. A modal anchored to its
  trigger or the pointer opens beside it as a popover, flips side when it doesn't fit and stays on screen.

**Fixes**

- Actions can read a trigger's value as `${value}` as well as `${result}`, so a search field's changed action gets
  the typed text.
- A link to the app's root with a query (`/?state=empty`) opens the entry screen with those params.
- A list whose scroll axis is flexible hugs its items within the space it is given and scrolls beyond that.
- Google Fonts load the font's Latin subset, so Latin text no longer falls back to the platform font.

## 20.0.3

**Fixes**

- `CodelesslyWidget.data`: a screen variable with the same name as a data key starts at that value and follows it
  when the data changes, unless the user has changed it since. The data stays readable as `data.<key>`.

## 20.0.2

**Fixes**

- `storage.<key>` in expressions reads what the app keeps on the device (`setStorage`), and updates live.
- Lists whose item updates rebuild nested lists no longer throw a concurrent modification error.

## 20.0.1

**Fixes**

- App variables (the publish model's variables) are shared by every screen. Previously a screen reading one got
  null.

## 20.0.0

**Breaking changes**

- A new SDK that renders published screens natively, straight into Flutter render objects, and reads the
  `codelessly_api` 20 format (`"schema": 2`).
- Create the instance with `Codelessly(config: CodelesslyConfig(...))`, optionally with a `loader`, and show a screen
  with `CodelesslyWidget(codelessly: ..., layoutId: ...)`.
