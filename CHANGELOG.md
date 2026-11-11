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
- Anchored modals: `openModal` honours `anchor`, `placement`, `anchorGap` and `anchorOffset`. A modal anchored to its
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
