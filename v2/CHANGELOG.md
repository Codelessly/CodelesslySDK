## 20.1.0

- `codelesslyWithToken` (`package:codelessly_sdk/firebase.dart`): a `Codelessly` from a project token alone. It opens
  Codelessly's Firebase project as a secondary Firebase app (`codelesslyFirebaseApp`, `CodelesslyFirebaseOptions`),
  so an app needs no Firebase setup of its own; `cloudServices: true` also sets up the project's cloud data,
  accounts and files (`codelesslyCloudServices`).
- `firebase.dart` exports the Firebase types its functions take (`Firebase`, `FirebaseApp`, `FirebaseOptions`,
  `FirebaseFirestore`, `FirebaseAuth`, `FirebaseStorage`).
- A README, an example app and a developer guide: https://github.com/Codelessly/CodelesslySDK/tree/master/docs/guide
- Anchored modals: `openModal` honours `anchor`, `placement`, `anchorGap` and `anchorOffset`. A modal anchored to its
  trigger or the pointer opens beside it as a popover, flips to the other side when it doesn't fit and stays on screen.
  They used to open centred.
- Actions read a trigger's value as `${value}` as well as `${result}`, as SDK 8.x named it, so migrated actions
  (a search field's changed action) get the value.
- A link to the app's root with a query (`/?state=empty`) opens the entry screen with those params.
- A running list whose scroll axis is flexible hugs its items within the room it is given and scrolls past that,
  as the 8.x runtime does. A design canvas keeps the design size.
- Google Fonts: the font fetcher takes a font's latin subset, not the first subset the CSS lists, so Latin text no
  longer falls back to the platform font.

## 20.0.3

- `CodelesslyWidget.data`: a screen variable named like a data key starts at that value and follows it when the
  data changes (unless the user changed it since), as in 10.x. Data stays readable as `data.<key>` too.

## 20.0.2

- `storage.<key>` in expressions reads what the app keeps on the device (`setStorage`), live. It read null.
- A list whose item updates rebuild nested lists no longer throws a concurrent modification.

## 20.0.1

- App variables: the publish model's variables (and a converted v1 publish's `app_variables`) are shared by every
  screen. 20.0.0 never declared them, so a screen reading one read null.

## 20.0.0

- The new format (`"schema": 2`), from the v2 rewrite. Projects made with the v1 editor are converted to it; a
  converted project can't be read by 10.x or older, and an unconverted one can't be read by 20.
