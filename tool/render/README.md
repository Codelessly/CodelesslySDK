# The render command

`tool/render/render.sh` checks Codelessly layout documents strictly and renders them with this SDK, headless,
so a person or an agent writing documents by hand can see what they made and what is wrong with it.

```sh
tool/render/render.sh <document.json | directory> [...] --out <dir> [options]
```

It:

1. **validates** every document strictly (`validateProject` from `package:codelessly_api/validate.dart`, with the
   SDK's own formula parser for `${= ...}`), printing each problem with a code, a JSON pointer and a suggestion;
2. **publishes** the documents as the editor does: each document is a page; canvases that share `props.screen`
   are one screen with a canvas per breakpoint (`props.breakpoint`); every other canvas is a screen of its own;
3. **renders** every screen with `CodelesslyWidget` (bindings, variables, conditions, breakpoints and reactions
   run as in a published app) at each size, writing `<out>/<screen>@<w>x<h>.png`;
4. **reports** what only rendering shows (below), tied to node ids;
5. writes everything to `<out>/diagnostics.json` (`<out>/diagnostics-<label>.json` with `--label`, so one run per
   state keeps each state's) and **exits 1 when there are errors**, 0 when there are only warnings or none, 2 for
   bad arguments.

A directory with a `site.json` is a site of pages and components (codelessly_api guide §19): its pages (the
manifest's `pages`, else its `.json` files), its components (the manifest's `components`, else the files under
`components/`, each named after its type) and its project variables. Steps name a node inside a component instance
by its path, the call ids from the page down and then its id (`--tap plans/card1/cta`; `#n` picks the n-th copy a
list repeats: `--tap faq/fq#1`); `--dump-layout` writes each such node's `path`.

A directory is every `.json` file in it (not those starting with `_`, nor `diagnostics*.json`), as the pages of one
site: navigation may name a canvas of another page.

## Options

| Option | |
|---|---|
| `--out <dir>` | Where PNGs and `diagnostics.json` go (required). |
| `--sizes <WxH,...>` | Screen sizes, default `390x844,834x1112,1440x900`. |
| `--screen <id or name>` | Only this screen: a canvas id, a layout id, a `props.screen` name, a canvas name or path. Repeatable. |
| `--full-page` | Capture the whole page: the window is made as tall as the page's own scroll view scrolls (the largest one a user can scroll; lists and decorations that do not scroll add nothing). Content fixed to the window (outside that scroll view: a bar pinned to the bottom of a stack over the page, a canvas's bottom bar or floating button) is drawn where a user first sees it, in the first window, as a browser's full-page screenshot shows it. |
| `--fonts <dir>` | Font files (`.ttf`, `.otf`), read by the family, weight and style inside each file. Repeatable. |
| `--tap <id>` | Tap the node where it shows. `<id>#<n>` taps the n-th copy (from 0) of a node a list repeats. |
| `--hover <id>` | Move a mouse over the node (hover states, `cursorEnter`). |
| `--focus <id>` | Focus the text field (a `textField`, or the one inside the node). |
| `--type <id>=<text>` | Focus the text field and type the text, as a user would: its `changed` reactions run, and a field whose `props.initialValue` is bound to a variable sets it. |
| `--set <name>=<json>` | Set a variable of the screen: `--set annual=true`, `--set 'email="a@b.co"'`. |
| `--scroll <id or screen>=<px>` | Scroll a scrolling node, or the page, to an offset. |
| `--navigate <screen>` | Push a screen (a canvas id, a layout id or a URL path). |
| `--wait <ms>` | Let time pass (animations, delays, toasts). |
| `--label <text>` | Add `-<text>` to the PNG names and write `diagnostics-<text>.json`, to keep states apart. |
| `--dump-layout` | Also write `<png name>.layout.json`: every node's box on screen (`id`, `x`, `y`, `w`, `h`). |
| `--component <Type>` | Render one component of the site alone: once per preview (at its size), else with its defaults at each size. |
| `--props '<json>'` | With `--component`: its parameters, as a call's `props`, at each size. A `variable` parameter becomes a page variable of the same name. |
| `--slots <file>` | With `--component`: what the call passes, `{"children": [ids], "slots": {"name": id}, "nodes": {...}}`. |
| `--validate-only` | Only validate. |

Steps (`--tap`, `--hover`, `--focus`, `--type`, `--set`, `--scroll`, `--navigate`, `--wait`) run in the order given, after the screen
has loaded and before the capture, at every size. A step that names a node the current canvas does not have (it
is in another breakpoint's canvas) is a warning, not an error.

```sh
# The whole site at three sizes, full pages.
tool/render/render.sh site/ --out shots/ --full-page
# The pricing toggle switched to annual, on desktop only.
tool/render/render.sh site/ --out shots/ --screen home --sizes 1440x900 --tap billing-toggle --label annual
# A form's error state.
tool/render/render.sh site/ --out shots/ --screen contact --tap submit --label errors
```

## What it reports

Validation codes are listed in the API reference (`docs/reference/index.md`, "Checking your work"). The render
step adds:

| Code | Severity | Meaning |
|---|---|---|
| `invalid_json` | error | A file is not valid JSON (with line and column). |
| `no_documents` | error | No `.json` documents at the paths given. |
| `unknown_screen_arg` | error | `--screen` names no canvas, screen or layout. |
| `render_exception` | error | Flutter threw while building, laying out or painting; the message names the node (`Node "price-row" (row): ...`). A flex overflow under 0.01 px (rounding) is not reported. |
| `action_error` | error | An action chain failed (a `load` reaction, or one a step ran). |
| `interaction_failed` | error | A step could not be applied: no such node on screen, nothing scrolls, the node is covered wherever it shows (the message names what covers it), nothing in it takes a tap (no fill, no reaction), no text field to type into. |
| `tap_no_reaction` | warning | A `--tap` hit its node, but neither it nor anything around it reacts to a tap: nothing happened. |
| `missing_glyph` | warning | A text has characters its font has no glyph for (drawn as empty boxes): the message lists them. |
| `icon_not_drawn` | warning | An icon names no glyph the renderer can draw. |
| `expression_not_evaluated` | warning | A text shows `${` on screen: an expression that did not evaluate. |
| `path_overflow` | warning | A `path` (or a box's `path`) draws outside its box; it is not clipped to it, as Flutter's `CustomPaint` is not. |
| `layout_overflow` | warning | A node extends past its parent's box where the parent does not scroll that way. |
| `offscreen` | warning | A node extends past the screen's edge where nothing scrolls: on a device it is cut off. |
| `text_clipped` | warning | A text's lines are taller than its box, or a word is wider than it. |
| `text_truncated` | warning | A text is cut at `maxLines` with overflow `clip`. |
| `text_no_color` | warning | A text has no `style.color`: the engine paints it white. |
| `font_fallback` | warning | A font family (or a weight far from any it has) is not in the fonts directories. |
| `image_failed` | error | An image file is missing, or an image does not decode. |
| `image_network` | warning | An image is on the network: not fetched, so blank in the screenshot. |
| `empty_screen` | warning | The screen drew no nodes. |
| `component_missing` | error | A call rendered without its component's definition (or nested more than 32 deep): an empty box of its size. Named by its path. |

`test/tool/render_command_test.dart` checks that these codes are reported for the fixtures in
`test/tool/fixtures`.

## Fonts

A text style names its family with `fontFamily` and its file with `fontWeight` (100 to 900) and `fontStyle`.
The command registers every font file under `--fonts` directories by the family, weight and style written inside
the file (its `name` and `OS/2` tables), so file names do not matter. It always has Roboto (all weights the
Flutter SDK ships: 100, 300, 400, 500, 700, 900) and the Material Icons font, from the Flutter SDK's cache.

Text that names no family is drawn in Roboto, the default family of a Flutter app on Android and on the web (in
an app it is the platform's font). A family the command does not have is drawn in Roboto and reported as
`font_fallback`; a missing weight next to one the family has (600 when there are 500 and 700) is drawn with the
nearest and not reported.

## Images

The SDK draws `https://` and `data:image/...` URLs. Offline, the command also reads an image path relative to
the document (`"url": "assets/photo.png"`, or `file://...`) and inlines the file as a `data:` URL. Network images
are not fetched: they are reported (`image_network`) and stay blank. Material icons named without a codepoint
(an app fetches their SVG) are drawn from the Material Icons font.

## How it runs, and how fast

It is a `flutter test` harness (`render_harness.dart`, run by `render.sh`): headless, no device, no network,
real fonts. Its arguments go through a temporary file inside `--out`, and nothing is shared between runs, so
several agents can run it at once on different `--out` directories. A run takes about 6 seconds once Flutter has
compiled the harness (the first run after the SDK changes takes 20 to 30 seconds), plus about half a second per
screen and size.

A `--tap` or `--hover` puts the pointer on a point of the node that a hit test reaches (its center, else the
center of what it draws: a text or an icon is smaller than its slot when it is stretched or aligned there, or has a
margin). A node out of view, or covered where it shows (a header over the page), is first scrolled to the middle of
its scrolling ancestor. A tap that would land on another node is not made: it is reported with the node that covers
it. Icons are drawn from the Material Icons font, also when their name comes from a binding.

Differences from an app that matter: the window is exactly the size given, at a pixel ratio of 1; text with no
font family is drawn in Roboto; there is no network; `openLink` opens nothing; platform services (storage,
clipboard) are in memory.
