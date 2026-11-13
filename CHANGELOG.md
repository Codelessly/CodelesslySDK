## Unreleased

**Streaming generative UI, hardened against real model output**

- `UiSession`: a batch or stream applied to a UI that already has roots cannot replace them or add a canvas
  (`protectRoots`, on: `start_over`), so a retry patches the UI; the end of a stream adds `renderDiagnostics`
  (`empty_button`, `low_contrast`, and with `glyphCoverage`, `missing_glyph`) to the result, and
  `layoutDiagnostics()` reports nodes with content laid out with no size (`no_size`); `lastStreamEnd` (repairs
  of malformed JSON, ops recovered); `docs()` answers `ui_docs`; `values` (the views' variable values). A canvas's
  body with a fill (the card) shows as soon as it arrives instead of waiting for its first child: first paint of
  the recorded live cards 0.4 to 1.0 s earlier.
- `CodelesslyView(services:)`: with a `ScriptRunner` among the services, the session's own scripts run
  (`runScript`, where the profile allows them: `TrustProfile.agentApps`).
- Replay command (`tool/stream`): ops recovered from malformed input, JSON repairs, first text, render
  diagnostics, scripts, and "works when used" (a scripted interaction per brief, `tool/stream/interactions`;
  scripts run in QuickJS); `tool/stream/live_summary.py`. The three live recordings re-replayed
  (`tool/stream/out/live`).
- `examples/stream_chat`: the compact prompt (the generated base set, compact tools, `ui_docs`), lookups answered
  within the turn, the retry protocol with a cap, forced tool use where the model allows it, six app briefs,
  `tool/record_all.sh` (the live matrix), `tool/use_local_api.sh` and `tool/check.sh` (CI: the example builds
  against the sibling `codelessly_api`).

**Authoring fixes from the third direct-authoring experiment (cycle 3)**

- Named colors and text styles resolve against the published theme as the screen shows it (its media rules at
  the screen's size, its dark colors in dark mode), on the page and in components (`ComponentRegistry.theme`); a
  change of theme re-applies only the nodes whose resolved values differ. `${theme.text.*}` reads resolved styles.
- Icon `size`: the glyph at that size, centred in the node's box; a hugging icon takes it.
- Actions naming a node from inside a component instance (`scrollTo`, `animate`, `focus`, `editText`) act on that
  instance's node. **Behaviour change (bug fix):** they acted on every instance's (or none).
- A node written `visible: false` whose media rule binds `visible` collapses when hidden.
- `RenderFitBox.designWidthUsed` / `designHeightUsed`: a fill laid out with no room took its design size.
- Render command: `fill_fallback` (a fill whose size came from its design number, naming the parent and the fix);
  diagnostics find a node's parent in its own document and name component nodes by path (no more false
  `layout_overflow` when a page and a component share an id); `--full-page` captures the whole page while the
  window keeps its size (**behaviour change:** `screen.height` and anything pinned to the window's top and bottom
  are no longer stretched to the page; page content is unchanged), and `--dump-layout` reports boxes where the PNG
  draws them; `--unfocus`, `--key`; `--compare` (side-by-side and diff images, bands, height difference); of a
  font package's subset files the one with Latin text's characters is served; the site manifest's theme is
  validated, published and its fonts loaded.

**Authoring fixes from the second direct-authoring experiment (cycle 2)**
