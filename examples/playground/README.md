# Playground

Type the compact notation (`package:codelessly_api/notation.dart`) on the left and see it rendered on the right
as you type.

```bash
flutter run -d chrome
```

- **Samples**: a starting card and a few of the targets from `design_systems/ssui/examples/targets`.
- **Design system**: Soft SaaS UI, Paper or Harbor. The text does not change; the controls and components do.
- **Width**: 320, 420 or 720, to see how a card holds up.
- **Under the preview**: each line the parser could not read, with its line and column; what the UI told the app
  (`emit`, `toast`); and "Show document", the layout document the notation expands to.
- **Counts**: nodes, characters written, and characters of the document they became.
- A link can open on a sample and a look: `?sample=approval_card&system=harbor`.

State starts over at each edit: the text is read again and shown in a new session.

`tool/bundle.sh` writes the SDK's design systems into `assets/design_systems`. Run it after they change.

Not here yet: writing the UI from a prompt (the chat example, `examples/stream_chat`, does that with a model),
and whole-app generation (codelessly_api `docs/design/15-the-middle-and-generated-apps.md`).
