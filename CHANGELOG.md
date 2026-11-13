## Unreleased

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
