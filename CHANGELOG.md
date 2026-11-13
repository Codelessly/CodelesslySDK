## 30.0.0

Requires `codelessly_api: ^30.0.0`.

**Schema 3.** Published apps hold schema 2: every loader (Firestore, HTTP files and bundle, asset bundle,
memory) reads `"schema": 2` and `3`, migrating 2 in memory (`migrate2to3`), never writing back; a stored
component is checked against its digest as stored, then migrated. A stored document in a newer schema is
refused (`PublishLoadException`, naming the SDK update). Schema 2 documents load and are migrated in memory;
write schema 3. The render command publishes schema 3 and leaves the validator's notes (`schema_outdated`)
out of its findings.

- **Breaking:** the code of the removed one-app fields is gone (see codelessly_api 30.0.0): the track's fine
  mode, double tap, parking (`defaultValue`, `parkedProgress`), `smooth` glide and arc `gain`; a dismissible's
  and pan's tilt (`rotateFactor`, `originX/Y`), disabled follow and shake, `shareAs`, `follow: false` and the
  fly-off spin; area path pacing and the upright flip (`MeasuredPath.at` takes no `byArea`); a transition's
  arc; a drop target's `fullIf`, `hoverDelay`, refused slot and the `dropFull`/`dragHover` triggers
  (`${drag.full}` is gone); snap `projectVelocity` and `rotationSnap`. The `setVariable` glide (`animateMs`)
  is an `animate` action (the migration rewrites it). `trackValues` loses `fine`.
- **Flutter's reading:** a text node applies its `layout.padding` around its lines, as `Padding(child: Text)` (a
  hugging text grows by it; a fixed one insets its lines). Schema-2 documents are unchanged: the migration drops
  the padding schema 2 ignored (step `text.padding`). A text style without a `height` is laid out at the
  font's own line height, as Flutter's `Text` (`kTextBase` has no height), under the nearest `defaultTextStyle`
  (Flutter's `DefaultTextStyle`), which every text style a node draws merges over: a text's style and runs, a
  widget's label and field styles, a painter's paragraphs, a typewriter's caret, a chart's tooltips, the nodes
  an island shows again (`TextDefaultScope`) and a view's root (`RenderTree.rootSlot`). Schema-2 documents keep
  1.33 through the migration (the 66 parity pages and the m05 sites render byte-identical PNGs).
  **Breaking:** `RenderTree.naturalLineHeight` and `kTextBaseNatural` are removed; `textStyle(style, [inherited])`;
  `Slot.textDefault`.
- **Behaviour changes:** a track with no value is drawn at its minimum (the `drag_misc` parity golden moves
  three thumbs: `fader cap`, `knob`, `path track`); the other dropped fields no longer act. Everything else
  renders as before: the 66 parity pages, the m05 experiments' sites (byte-identical PNGs), the Relay site
  (schema 2 through the migration and schema 3 rewritten draw the same boxes).


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

**Components in published apps, hosted plugins as components (sections and components, phase 2)**

- A published site with components just works. `PublishLoader.loadComponent` (memory, asset bundle, HTTP bundle
  or files, Firestore `publish/{p}/components/{type}` with `compressedDocument`); `Codelessly` loads a layout's
  closure of components (listed by the model and found in the documents) before the screen shows, caches each
  at its publish path by digest (offline: any cached copy), refuses one whose document doesn't match its digest,
  reloads a component whose model entry changed (a `LivePublishLoader` follows it: every instance updates in
  place, the pages don't reload), loads the fonts of called components, and fetches a missing definition when a
  call renders without it. Misses are logged as `component_missing`. `Codelessly.loadComponent`,
  `publishedComponents`; components an app defines itself win over published ones. `componentDigest`,
  `componentIntact`, `decodeStoredPublishComponent`, `ComponentRegistry.onMissing`.
- Hosted plugins: `Codelessly` installs the plugins a publish lists (`model.plugins`) before decoding layouts,
  through the loader as a `PluginSource` (a bundle's embedded versions; `plugins/{id}/versions/{n}` over HTTP
  and in Firestore), the cache, digests, minSdk and the catalog check; `Codelessly.hostedPlugins`,
  `Codelessly.actions` (the runner with the plugins' action types). A plugin node type is a component definition
  (`CodelesslyFeature.components`) rendered as ordinary boxes of the screen's tree: hug and fill through the
  seam, interaction, slots and events as any component's. **Behaviour change:** the island path for plugin
  widgets (`_HostedRecipe`, a fixed-size fit box) is gone; `hostedPluginFeature` returns no recipes.
- Per instance: `setValue` / `setVariant` inside a component instance set that instance's node
  (`RenderTree.setInstanceValue`); slot content inside a list of the definition shows once per item, in the
  caller's scope (`SlotContent`); an instance's scopes are released when it leaves the tree
  (`InstanceBindings.releaseInstance`); `persist` on a component variable is kept per instance path
  (`NodeBinder.persistComponentVariable`, `PersistedVariable.attach(key:)`); a changed declaration decodes the
  loaded layouts that call it again. **Behaviour change (bug fix):** set value inside an instance changed the
  page's node of that id.
- Render command: `--components-all`; a call can be tapped by its id (`--tap send`, `--tap 'sizes#3'`);
  `render_exception` names a node inside an instance by path and its component's file; publishing writes the
  components, their digests and each layout's closure into the bundle.
- `examples/relay-pricing` is a three-page site sharing header, menu, footer, call to action, button, cards and
  a theme, published and loaded over HTTP then offline in `test/examples/relay_site_test.dart`.

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
