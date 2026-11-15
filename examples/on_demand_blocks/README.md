# Blocks designed while a session runs

A fast model answers a chat request with a card. Where the design system has no block for the main piece, the
answer names the one it wanted and builds a stand-in from plain parts; the card shows at once. A stronger model
then designs the block, `OnDemandBlocks` checks it and adds it to the session, the fast model is asked again,
and the new card takes the old one's place.

Run it from this folder (it reads the SDK and the Cards design system by relative path, and
`ANTHROPIC_API_KEY` from the environment):

```sh
flutter pub get
flutter test test/live_test.dart     # three requests, live; writes $ON_DEMAND_RESULTS (default /tmp/on-demand-results.json)
flutter test test/render_test.dart   # replays those answers in a CodelesslyView at 420 and 320 wide
```

Until `codelessly_api` 31 is on pub.dev, add a `pubspec_overrides.yaml` that points `codelessly_api` at a
checkout of its master branch (`path: ../../../CodelesslyAPI`).

What it uses: `UiSession.notationInstructions(askForBlocks: true)`, `UiSession.wantedBlocks`,
`OnDemandBlocks.designWanted()`, `UiSession.applyNotation(answer, replace: true)`; the designer's instructions
are what `examples/showcase/tool/design_block.py brief` writes. Guide: `docs/guide/18-agent-ui.md`.

The composing model is Sonnet. Measured on 2026-11-15 with the smaller model composing and Opus designing: first card in 4 to 6 seconds; a block designed in 71 to
95 seconds and accepted on the first try; the card replaced 82 to 103 seconds after the request. Haiku named a
wanted block on two of the three requests. First written by an outside agent from the guide alone (run 9); its
finding that two accepted blocks overflowed in a real view is why a host should supply `check:` with a layout
test until the SDK has one.
