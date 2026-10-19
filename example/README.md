# Codelessly SDK Example

This is a runnable example Flutter app that uses the Codelessly SDK with a sample
auth token and layout id to display a published layout.

## Running

```bash
flutter run
```

By default the example loads layouts from the legacy Codelessly backend. To load
them from the new Codelessly Editor's backend instead:

```bash
flutter run --dart-define=CODELESSLY_BACKEND=editor
```

## macOS

macOS builds must be signed by a development team, or the SDK can't sign in and
shows an error instead of the layouts. Firebase Auth keeps its user in the macOS
keychain, which ad-hoc signed apps can't write to (`errSecMissingEntitlement`,
-34018).

Before running on macOS:

1. Add an **Apple Development** certificate for your team in Xcode
   (**Settings → Accounts → Manage Certificates → +**).
2. Open `macos/Runner.xcworkspace`, select the **Runner** target, and choose
   your team under **Signing & Capabilities**. Xcode creates the provisioning
   profile automatically.
3. Run `flutter run -d macos`.

iOS simulator and Android builds don't need this.
