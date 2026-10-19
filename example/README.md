# Codelessly SDK Example

This is a runnable example Flutter app that uses the Codelessly SDK with a sample
auth token and layout id to display a published layout.

## Running

```sh
cd example
flutter run                                          # legacy backend
flutter run --dart-define=CODELESSLY_BACKEND=editor  # new Codelessly Editor backend
```

## macOS

macOS builds must be signed with an Apple Development team. Ad-hoc signing
("Sign to Run Locally") is not enough, even with the app sandbox turned off.

The SDK signs in to Firebase Auth, which saves the user in the keychain. On
macOS that keychain only accepts apps whose signature carries an application
identifier, which comes from a team-signed build with a provisioning profile.
An ad-hoc build fails at sign-in with `[firebase_auth/keychain-error]`
(`errSecMissingEntitlement`, -34018), and the SDK shows an initialization error.
iOS simulators don't enforce this, so the same code works there unsigned.

To run on macOS:

1. Add an Apple Development certificate in Xcode → Settings → Accounts →
   Manage Certificates.
2. Open `macos/Runner.xcworkspace`, select the Runner target → Signing &
   Capabilities, and pick your team. The project defaults to the Codelessly
   team (`72KLUSSLV3`). If you use your own team, keep the change local and
   change the bundle identifier if your team can't register
   `com.codelessly.sdk.example`.
3. Keep the Keychain Sharing capability (`keychain-access-groups` in
   `DebugProfile.entitlements` and `Release.entitlements`).
4. Run `flutter run -d macos`.
