## Unreleased: schema 4

Requires the codelessly_api of the same release (schema 4).

**Schema 4: one Transform, one Hero.** Every loader reads `"schema": 2`, `3` and `4`, migrating 2 and 3 in
memory (`migrate2to3`, `migrate3to4`), never writing back; a stored document or bundle in a newer schema is
refused, the message naming 2, 3 and 4 (`kLoadableSchemas` is `{2, 3, 4}`). The render command publishes
schema 4.

- **A node's scale and rotation are its motion.** The chain's own `scale` layer and the `RenderTransform` of
  `layout.rotation` are gone: `RenderMotion` draws them (schema 4 folded them into `motion.scale` and
  `motion.rotate`; the migration keeps schema 3's rotation pivot, moved by half an uneven margin, as a
  translation). A state style that moves a node (`states.pressed.<id>.motion`) keeps its motion layer at rest,
  as the scale layer was kept (a layer added mid-press lost the tap). Older documents draw pixel for pixel as
  before: the parity goldens are unchanged, and 48 renders of 16 corpus documents (reference apps, an
  experiment, the SDK's benchmark and example) and a schema-3 page of state scales and rotations (at rest,
  hovered, selected) match codelessly_sdk 30.0.0's (codelessly_api docs/design/03-motion.md).
- **One shared element.** `hero` with `flies: betweenScreens` (Flutter's `Hero`) is the navigation flight, its
  look `flightShuttle` (`RenderHeroMark.flightShuttle`, was `flight`); `flies: inPlace` is what `flightKey`
  was: `RenderFlightBox` flies it in from where the node with its tag was, on a spring or as its `flight`
  says, and a dropped drag copy records its place under that tag. The two kinds don't fly to each other.
- **Run time:** a `setValue` path schema 4 moved (`scale`, `layout.rotation`, `flightKey`, `flight.*`) that
  reaches a running app unmigrated (from a script or another document) sets nothing and says, once, what to
  write (`olderSchemaPathHint`), as schema-2 paths already did.
- **Tests:** test/motion/schema4_transform_test.dart (an older document's scale, rotation and uneven margin
  drawn where 30.0.0 drew them; a state's scale snapping beside an easing motion; a scale transition on its own
  timing; setValue paths), hero and in-place flight tests, schema 4 in the loading and relay-site tests. The
  catalog corpus digests of the five files whose documents hold a moved field were taken again at schema 4.

**Schema 4's paint:** `strokePath`, a box's `path`, `subpathColors` and `gradientPerSubpath` are migrated onto
`customPaint` and the path node (codelessly_api's `paintSteps4`).

- **A `customPaint` path op's `commands`** draw: Flutter's `Path` calls (`moveTo`, `lineTo`,
  `quadraticBezierTo`, `cubicTo`, `close`) in order, each number a literal or a formula, a call skipped while its
  `when` is false. This is what draws a migrated `strokePath`'s curves and `untilWidth`.
- **The path node reads `strokeMiterLimit`** (`Paint.strokeMiterLimit` of its strokes, default 4 as before).
- **Breaking: the schema-3 paint painters are gone.** A schema-3 document loads through schema 4's paint steps, so
  `RenderStrokePath` and `StrokePathPainter` (and their place in `paintLayers`), a box drawn as a path
  (`buildBoxPath`, `RenderShapePath`'s box painter, the box-path case of the paint plan and of the render tool's
  `path_overflow`), the path painter's per-shape colors and gradients (`PathShapes`) and `dashPath` (the box
  path's dashes) are deleted. A stroke path's draw-on animation (`drawMs`) is not drawn: the migration keeps it as
  `legacy.strokePath.draw` and the line shows at its progress at once.
- `test/custom_paint/migrated_paint_test.dart`: each schema-3 feature as the migration rewrites it, matched
  against a golden (test/custom_paint/goldens) taken while schema 3's painters still drew it and agreed (pixel
  for pixel; a fading fill within 1/255, a box path's fill edge within 3/255). The stroke path and box path tests
  of test/paint/paths_test.dart check the migrated document's pixels against Flutter's own `Path` calls. The
  catalog corpus digests of strata_tabs' document and its diagram_0 node were taken again (2 lines). The parity
  goldens are unchanged.

## Unreleased

- **The reference is one base plus links** (codelessly_api's `docs/reference`). The chat example's compact prompt
  is the base's runtime form (`runtimeStarter()`, ≈ 43.7k characters, ending with the index of `ui_docs`
  topics) and `ui_docs` answers with the reference's pages (`UiSession.docs`, unchanged); its full prompt carries
  the base's file form (`assets/system_prompt.md`, regenerated). The render and stream READMEs point at the base
  and at the reference's render page.

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
- **A schema-2 path a `setValue` names** (not migrated: it is read against its target when it runs) sets nothing
  and is said once, with the schema-3 path to write (`schema2PathHint`); the action's other values apply.
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
