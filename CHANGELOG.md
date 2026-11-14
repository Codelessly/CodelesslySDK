## Unreleased

**A site looks like itself: theme mode, declared fonts, local images** (with codelessly_api's unreleased
additions).

- **Theme mode.** `Codelessly.themeMode`, `themeModeChoice` and `setThemeMode(mode, persist:)`: the site's
  `ThemeMode` (a choice over the theme's own `mode`, kept in local storage under `codelessly.themeMode` when
  persisted, so a reload starts in it). Every screen follows it at once: named colours, named text styles, the
  control theme (control_theme.dart, still the single source) and `${theme.isDark}`, `${screen.isDark}` and the new
  `${theme.mode}`. The `setThemeMode` action reaches it through `ThemeModeUi`, which the screen's UI implements.
  `ThemeMode` is hidden from the barrel export (it shares Flutter's name): import codelessly_api with a prefix.
- **Site files.** `PublishAssetSource`: a loader that serves a site's own files (`MemoryPublishLoader(assets:,
  readAsset:)`, `AssetPublishLoader` from assets beside the bundle, `HttpPublishLoader` at
  `publish/{slug}/files/{path}`). A declared font (a `PublishFont` whose `url` is a relative path) is read through it
  (`SiteFontFetcher`, falling back to the app's fetcher), WOFF unwrapped (`sfntOf`, moved here from the render tool);
  an image a layout or component names by a relative path (`images/hero.jpg`) becomes the file's URL or a `data:`
  URL, a missing one logged as `site_file_missing`.
- **render.sh.** `--theme light|dark|system` (PNG names end `-<mode>`; steps may toggle it). The fonts `site.json`
  declares are used with no `--fonts`, loaded before the page shows; a missing declared file is `font_missing`, a
  WOFF2 `font_format`; `font_fallback` names the nodes that asked for the family and how to declare it. Relative
  image paths start from the site's folder. `--fonts system` is no longer turned into a relative path.

The render command (`tool/render`), from nine agents' reports of building multi-page sites:

- **Full-page captures draw what a reader sees once, once.** A `sticky` node is drawn in its place in the page,
  not pinned at the top of every window; an open modal, dialog or sheet and its backdrop are drawn in the first
  window only, the page below undimmed; after `--navigate` or a tap that navigates, the page navigated to is
  captured at its own height (routes a navigator keeps offstage are skipped by steps, checks and captures).
- **`--navigate` takes a query string** (`speaker?id=ada`, `/project?id=7`: a leading slash no longer opened the
  entry screen), reports a screen it cannot find with the list, and later steps (`--set`) act on the screen
  navigated to.
- **`--drag <id>=<dx>,<dy>`** (or `=<other id>`): press, move and release; held first where a drag starts on a long
  press.
- **Runs take turns** on one SDK checkout (a lock around `flutter test`, which rewrites `build/` as it starts), so
  concurrent runs no longer race on `build/native_assets` or `NativeAssetsManifest.json`.
- **`render.sh` finds Flutter** in `FLUTTER`, `FLUTTER_ROOT`, the `PATH`, then `/opt/flutter`; runs `flutter pub get`
  when the dependencies are missing or stale; and uses a sibling `CodelesslyAPI` checkout through a
  `pubspec_overrides.yaml` it writes (never touching one of your own), else the published package.
- **`downloadFile` succeeds headless**: the file is saved under `<out>/downloads/<capture>/`; `copyToClipboard`
  copies in memory and the chain after it runs. Both are printed and listed in the diagnostics (`downloads`,
  `clipboard`).
- **`--now <ISO time>`** pins `now()`; a `--set` holds against a timer or `load` reaction that writes the variable
  later (`set_overwritten` says so).
- **Steps**: a step on a node hidden at one size is skipped there with a note, not an error; an id two shown nodes
  share (a page's and a component's) is an error naming each by path (`page/saved`, `footer/saved`);
  `evCard#0/evReserve` reaches a node inside a list's copy; a tap, a drag or a navigation first unfocuses a text
  field elsewhere (typing and then tapping a button that removes the form no longer ends in a detached
  render-object assertion from the tool's side).
- **`--compare`** matches a reference by its exact screen, state and size (`saved` no longer takes
  `saved-empty`), and `--compare-map home=index` renames.
- **`unknown_screen`** is reported once per missing screen with how many links name it, not once per link.

- **A migrated stroke path draws itself on again.** codelessly_api's migration now writes `strokePath.drawMs` as an
  animation of the path op's `trimEnd` and a transition of it; the player draws it frame for frame as 30.0.0's
  RenderStrokePath did (`test/custom_paint/stroke_draw_on_test.dart`: the drawn share against the old formula and
  the pixels against the static drawing at that share). Three general fixes made that exact:
  - a track with no `from` or `to` on a path the player patches into the node (not `motion`, `opacity`) reads the
    node's own value without the track's last value (`RenderTree.resolveUnanimated`; before, it read back what it
    had drawn and stayed at its start), the field's declared default where the JSON omits it
    (`BindPaths.declaredDefault`), and an inline expression there evaluated;
  - a transition on such a path watches the node's own value, not the animated one, so a bound change under a
    settled track eases;
  - a node its animations patch re-applies when a binding changes even if the node as shown did not (a top-level
    node, or a binding change that left it equal), so its player sees the change.
- **A time picker's `use24h` is `alwaysUse24HourFormat`** (codelessly_api; `TimePickerProps.alwaysUse24HourFormat`).
- **State patches on `self` and `@<key>`** in schema-2 documents are migrated to the node's id (codelessly_api), so
  those hover, press and selection styles now apply.

Requires the codelessly_api changes of the same name (forms, grid placement, scroll control).

- **Forms work.** A text field's `validator` runs: the field shows its error as its own and its form's
  `autovalidateMode` say (`always`, `onUserInteraction`, `onUnfocus`, `onUserInteractionIfError`) and when its form
  is validated. `validate` checks a form, focuses the first invalid field on screen and gives whether all are valid;
  a `form` node publishes `${form.valid}` and `${form.errors}`. A radio inside a `radioGroup` takes the group's value
  and runs the group's `changed`. An outlined or filled field with no `contentPadding` takes `InputDecorator`'s
  default (12 px at the sides) instead of none.
- **Grid spans.** A `gridView` places items by their `columnSpan`, `rowSpan`, `columnStart` and `rowStart` as CSS
  grid's sparse auto-placement does; a span is at most the grid's columns. Grids whose items set none lay out as
  before.
- **Scroll control.** Scroll reactions give `${result.index}` and `${result.count}`; `itemSnapping` comes to rest with
  an item at the start (render-object scroll views, and `ItemSnapPhysics` in data-bound lists). Data-bound and
  counted lists now run their `scroll` and `scrollEnd` reactions.
- **Fixes.** A focused field hidden or removed by a tap's actions lets the focus go, instead of asserting
  `attached` from its keyboard connection (type, then tap). An icon chosen by a binding on a button draws its glyph
  (it drew nothing offline: codepoint 0 was taken for a codepoint). A text run that starts or ends inside an
  expression styles the text as shown, instead of printing the expression. The render command answers clipboard
  calls from memory, so a chain that copies runs on.

## 30.1.0

Requires codelessly_api 30.1.0. **The schema stays 3**: every loader reads `"schema": 2` and `3`, migrating 2 in
memory (`migrate2to3`), never writing back (`kLoadableSchemas` is `{2, 3}`). 30.0.0's schema-3 documents keep
loading, read as they are: one written with 30.0.0's spellings of a node's scale and rotation, its flight key, a
stroke path, a box drawn as a path or per-shape paints must be updated (codelessly_api's changelog has the
mapping; a schema-2 document is migrated to the one spelling when it loads).

- **No Material defaults reach the screen.** Controls (the Material islands: buttons, chips, fields, switches,
  sliders, pickers, tabs, navigation bars, progress) and the runtime's chrome (dialogs, toasts, sheets, menus,
  tooltips, date and time pickers) take every color and font their node leaves unset from one theme,
  `themeDataOf(tokens)` (lib/src/render/control_theme.dart): every `ColorScheme` role is a token or derived from
  one, and without a theme the set is neutral (`kInk` near-black on `kPaper` white; near-white on `kPaperDark`
  in dark mode; greys between). No purple seed, no tints (`surfaceTint` transparent), no splashes
  (`NoSplash`), no elevation unless a node sets one, and text in the tokens' `fontFamily` (`titleFontFamily` for
  titles) or no family at all, never Roboto. A token `primary` that doesn't read on the surface (3:1) gives way to
  the surface's ink for what controls draw on it; filled buttons and floating action buttons keep it as their
  fill. `buttonRadius` shapes every kind of button, chip and segmented button; `radius` dialogs, menus, pickers
  and (when set) the default text field border.
- **Controls read what they sit on.** Each island's theme is made for the surface under it (the node's and its
  ancestors' fills, `ControlTheme`): an unstyled text, outlined or icon button, a check or a thumb on a dark band of
  a light page is drawn light. A button, floating action button or chip with a fill of its own but no label color
  is labelled in ink or paper, whichever reads on it; a button's `style.textStyle.color` is its label color when
  `foregroundColor` is unset (Flutter drew the theme's over it). Labels Flutter dropped the color of (a chip's, a
  navigation bar's, an input's text in a style of its own) are in the theme's ink instead of white.
- **The icon button is a plain button** (a `TextButton` around the glyph): no raised lavender tile. A tonal
  filled button is the theme's selected tint. An unset divider is the theme's faint outline over what it's drawn
  on, an unset badge the theme's error color, an unset activity indicator the theme's muted ink.
- **Breaking: `CodelesslyConfig.useHostTheme` is removed.** Layouts never render with the app's `Theme`; the mode
  is always the device's. Islands hosted outside a `CodelesslyWidget` (a `NodeView` in an app) get the neutral
  theme, not the app's. The runtime's dialogs, toasts and sheets open from inside the layout's theme (they opened
  from above it, so they took the app's), and the confirm dialog's and toast's buttons, the pickers and their
  `pickerTheme` start from the layout's look (`ResolvedFeedbackTheme.themeData`; `apply(ThemeData)` and the
  inputs' `ColorScheme.fromSeed` are gone). A `FeedbackTheme` in the app's `ThemeData.extensions` no longer reaches
  a layout. `themeDataOf` takes an optional `surface`; `kInk`, `kInkOnDark`, `kPaper`, `kPaperDark` are exported.
- **Guard:** test/app/no_material_look_test.dart renders every control type of the inputs, material, collections
  and indicators groups unstyled, with no theme and with a brand theme, light and dark, and fails on any pixel of
  Material 3's baseline palette, on a ripple when a button is pressed, or on a control text not in the theme's font.
- **Render tool:** the published theme's `fontFamily` defaults to Roboto, as its text styles' does (the controls
  took the tool's own `ThemeData(fontFamily: 'Roboto')` before).
- **A node's scale and rotation are its motion.** The chain's own `scale` layer and the `RenderTransform` of
  `layout.rotation` are gone: `RenderMotion` draws `motion.scale` and `motion.rotate` (the migration keeps
  30.0.0's rotation pivot, moved by half an uneven margin, as a translation). A state style that moves a node
  (`states.pressed.<id>.motion`) keeps its motion layer at rest, as the scale layer was kept (a layer added
  mid-press lost the tap). Migrated documents draw pixel for pixel as before: the parity goldens are unchanged,
  and 48 renders of 16 corpus documents and a page of state scales and rotations (at rest, hovered, selected)
  match codelessly_sdk 30.0.0's (codelessly_api docs/design/03-motion.md).
- **One shared element.** `hero` with `flies: betweenScreens` (Flutter's `Hero`) is the navigation flight, its
  look `flightShuttle` (`RenderHeroMark.flightShuttle`, was `flight`); `flies: inPlace` is what `flightKey`
  was: `RenderFlightBox` flies it in from where the node with its tag was, on a spring or as its `flight`
  says, and a dropped drag copy records its place under that tag. The two kinds don't fly to each other.
- **A `customPaint` path op's `commands`** draw: Flutter's `Path` calls (`moveTo`, `lineTo`,
  `quadraticBezierTo`, `cubicTo`, `close`) in order, each number a literal or a formula, a call skipped while its
  `when` is false; what draws a migrated stroke path's curves and `untilWidth`. **The path node reads
  `strokeMiterLimit`** (default 4 as before).
- **Breaking: the 30.0.0 paint painters are gone.** `RenderStrokePath` and `StrokePathPainter` (and their place
  in `paintLayers`), a box drawn as a path (`buildBoxPath`, `RenderShapePath`'s box painter, the box-path case of
  the paint plan and of the render tool's `path_overflow`), the path painter's per-shape colors and gradients
  (`PathShapes`) and `dashPath` (the box path's dashes). A stroke path's draw-on animation (`drawMs`) is not
  drawn: the migration keeps it as `legacy.strokePath.draw` and the line shows at its progress at once.
- **Run time:** a `setValue` path 30.1.0 moved (`scale`, `layout.rotation`, `flightKey`, `flight.*`,
  `strokePath.*`, `props.path`, `props.subpathColors`) that reaches a running app (from a script or another
  document) sets nothing and says, once, what to write (`olderSchemaPathHint`), as schema-2 paths already did.
- **Tests:** test/motion/fold_transform_test.dart (a migrated scale, rotation and uneven margin drawn where
  30.0.0 drew them; a state's scale snapping beside an easing motion; a scale transition on its own timing;
  setValue paths); hero and in-place flight tests; test/custom_paint/migrated_paint_test.dart (each 30.0.0 paint
  feature as the migration rewrites it, matched against a golden in test/custom_paint/goldens taken while the
  30.0.0 painters still drew it and agreed: pixel for pixel, a fading fill within 1/255, a box path's fill edge
  within 3/255); test/paint/paths_test.dart's stroke path and box path tests check the migrated document's pixels
  against Flutter's own `Path` calls. The catalog corpus digests of the five files whose documents hold a moved
  field, and strata_tabs' stroke path, were taken again (179 lines). The recorded op streams of
  `restaurant_menu` and `saas_pricing` (3 rates each) say their box paths as path nodes (`"type": "path"`,
  `props.data`), each delta and its time kept but for the characters that changed. The stream chat example's
  `assets/system_prompt.md` is regenerated.
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
