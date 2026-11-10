## 20.1.0

- `codelesslyWithToken` (`package:codelessly_sdk/firebase.dart`): a `Codelessly` from a project token alone. It opens
  Codelessly's Firebase project as a secondary Firebase app (`codelesslyFirebaseApp`, `CodelesslyFirebaseOptions`),
  so an app needs no Firebase setup of its own; `cloudServices: true` also sets up the project's cloud data,
  accounts and files (`codelesslyCloudServices`).
- `firebase.dart` exports the Firebase types its functions take (`Firebase`, `FirebaseApp`, `FirebaseOptions`,
  `FirebaseFirestore`, `FirebaseAuth`, `FirebaseStorage`).
- A README, an example app and a developer guide: https://github.com/Codelessly/CodelesslySDK/tree/master/docs/guide

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
