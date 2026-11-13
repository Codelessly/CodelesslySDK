## Unreleased

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
