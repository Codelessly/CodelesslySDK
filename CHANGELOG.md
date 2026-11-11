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
  Also `isToday`, `isSameDay`, `isBefore`, `isAfter`.
- Clocks tick only as often as a value can change: `now()` every second, `today()`, `timeAgo` and `isToday`
  every minute (`FormulaClock.minutes`, `ClockTick`), `nowMs()` every frame again (`FrameClock`); bindings and
  conditions that call a function or computed variable reading the clock now tick too (they didn't).
  `FormulaClock.tick()` steps a clock by hand (tests, editors).
- `${theme.*}`: the project's theme for the current mode, live: role colors (`theme.surface`), every color style
  (`theme.colors.brandBlue`), text style values (`theme.text.title.fontSize`), `theme.isDark`, `theme.brightness`.
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
