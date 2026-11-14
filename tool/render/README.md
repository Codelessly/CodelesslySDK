# The render command

`tool/render/render.sh` checks Codelessly layout documents strictly and renders them with this SDK, headless,
so a person or an agent writing documents by hand can see what they made and what is wrong with it.

```sh
tool/render/render.sh <document.json | directory> [...] --out <dir> [options]
```

The documents themselves are described by codelessly_api's reference: start with `docs/reference/STARTER.md` (the
base, which ends with an index of the feature pages); `docs/reference/render.md` is this command's page there
(the loop of checking, capturing states, every validation code).

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

The manifest's `theme` (named colors and text styles, codelessly_api guide "the theme") is validated, published as
the project's theme and resolved as an app resolves it: at each size its media rules, the fonts its styles name.
A manifest that names a design system (`"designSystem": "../design_systems/ssui"`, its folder relative to
`site.json`) gets its components (callable by type, validated and rendered as the site's own; `--components-all`
renders them too), its tokens as the base theme the site's `theme` is merged over, and its fonts.

A directory is every `.json` file in it (not those starting with `_`, nor `diagnostics*.json`), as the pages of one
site: navigation may name a canvas of another page.

## Options

| Option | |
|---|---|
| `--out <dir>` | Where PNGs and `diagnostics.json` go (required). |
| `--sizes <WxH,...>` | Screen sizes, default `390x844,834x1112,1440x900`. |
| `--screen <id or name>` | Only this screen: a canvas id, a layout id, a `props.screen` name, a canvas name or path. Repeatable. |
| `--full-page` | Capture the whole page: its own scroll view (the largest one a user can scroll; lists and decorations that do not scroll add nothing) over its whole extent, while the window keeps the size asked for, as a browser's full-page screenshot does. `${screen.height}` and anything sized or pinned to the window (a drawer pinned to the window's top and bottom) stay as on the device. What a reader sees once is drawn once: content fixed to the window over the page (a header, a drawer, a bar pinned to the bottom, a canvas's bottom bar or floating button) and an open modal, dialog or sheet with its dimmed backdrop are drawn where a user first sees them, in the first window, and the page continues below them undimmed; a `sticky` node is drawn once, in its place in the page (not pinned at the top of every window); after `--navigate` or a tap that navigates, the capture is the page navigated to, at its own height (a page covered by another is never measured or drawn). The capture always starts at the page's top, whatever a step scrolled it to (a `--tap` scrolls its node into view first); without `--full-page` the capture is the window where the steps left the page, which is how to see a sticky header pinned. `--dump-layout` gives every box where the PNG draws it. |
| `--fonts <dir>` | Font files (`.ttf`, `.otf`, `.woff`), searched recursively and read by the family, weight and style inside each file: a font package folder (`node_modules/@fontsource/<family>`, or the whole `node_modules/@fontsource`), a site's fonts folder, or `system` (the system's font directories). Repeatable. Of a package's subset files for one face (`latin`, `latin-ext`, `cyrillic`...), the one with Latin text's characters is used. `.woff2` is not read (it is reported, with the `.woff` to use instead). |
| `--theme <mode>` | `light`, `dark` or `system`: the theme mode the site starts in, as a `setThemeMode` action sets it (named colours, text styles and controls follow). PNG names end `-<mode>`; a later `--tap` on the site's switch changes it. |
| `--tap <id>` | Tap the node where it shows. `<id>#<n>` taps the n-th copy (from 0) of a node a list repeats; `<template>#<n>/<id>` the node inside a list's n-th copy (`evCard#0/evReserve`, the same node as `evReserve#0`). A focused text field elsewhere is unfocused first, as a click outside a field does in a browser (its blur reactions run before the tap's). |
| `--drag <id>=<dx>,<dy>` | Press on the node, move by `dx`, `dy` in a dozen steps and release: a reorder handle, a slider, a draggable card, a swipe. `--drag <id>=<other id>` drags it onto another node (a drop target). A drag that starts on a long press (a list reordered by touch, a long-press draggable) is held first. |
| `--hover <id>` | Move a mouse over the node (hover states, `cursorEnter`). |
| `--focus <id>` | Focus the text field (a `textField`, or the one inside the node). |
| `--unfocus` | Take the focus from the focused field: no caret in the capture (an error state after `--type`); its blur reactions run. |
| `--key <key>` | Press a key on what has the focus, as a keyboard does: `ArrowLeft`, `ArrowRight`, `ArrowUp`, `ArrowDown`, `Enter`, `Escape`, `Tab`, `Space`, `Home`, `End`, `Backspace`, `Delete`, `PageUp`, `PageDown`, a letter or a digit, with modifiers (`shift+Tab`, `ctrl+a`). A canvas's `keyDown` reactions run when no field has the focus. |
| `--type <id>=<text>` | Focus the text field and type the text, as a user would: its `changed` reactions run, and a field whose `props.initialValue` is bound to a variable sets it. |
| `--set <name>=<json>` | Set a variable of the screen in view (after `--navigate`, of the screen navigated to): `--set annual=true`, `--set 'email="a@b.co"'`. It holds: when nothing but `--wait` and other `--set` steps comes after it, a timer or `load` reaction that writes the variable later does not change the capture (it is set again before the capture, with a `set_overwritten` warning). |
| `--now <ISO time>` | The time `now()` (and `nowMs()`) returns for the whole run: `--now 2026-11-13T09:00:00Z`. A clock or countdown a timer writes from `now()` shows that time; check before, during and after an event without a test-only variable. |
| `--scroll <id or screen>=<px>` | Scroll a scrolling node, or the page, to an offset. |
| `--navigate <screen>` | Push a screen: a canvas id, a screen name or a URL path (`/project`, `speaker.html`), with a query string for its params: `--navigate speaker?id=ada`, `--navigate /project?id=soft-signal`. The screen reads them as `${route.id}`, as from a `navigate` action's `params`. A screen no such name finds is an error listing the screens. Later steps act on the screen navigated to. |
| `--wait <ms>` | Let time pass (animations, delays, toasts). |
| `--label <text>` | Add `-<text>` to the PNG names and write `diagnostics-<text>.json`, to keep states apart. |
| `--compare <png or dir>` | Compare each capture with a reference screenshot: the file, or in a directory the PNG of the same size (`390x844`) whose name is exactly the screen and the state (the `--label`; without one, `default` or no state), the parts separated by `--`, `-`, `_`, `@` or `.`: `section--saved--390x844.png` for `--label saved`, never `section--saved-empty--390x844.png`. Writes `<png>.compare.png` (the capture left, the reference right) and `<png>.diff.png` (the capture dimmed, differing pixels red), and prints the share of matching pixels, the height difference, the first differing row and the vertical bands where they differ, each with the offset at which it matches the reference when it is only shifted. Images of different heights compare; a reference of another width is scaled to the capture's. The figures go to the diagnostics file's `comparisons`. |
| `--compare-map <screen>=<name>` | Compare a screen under the name its reference has (`--compare-map home=index`), or a screen and state (`--compare-map home-empty=index--no-results`). Repeatable. |
| `--dump-layout` | Also write `<png name>.layout.json`: every node's box on screen (`id`, `x`, `y`, `w`, `h`). |
| `--component <Type>` | Render one component of the site alone: once per preview (at its size), else with its defaults at each size. |
| `--props '<json>'` | With `--component`: its parameters, as a call's `props`, at each size. A `variable` parameter becomes a page variable of the same name. |
| `--slots <file>` | With `--component`: what the call passes, `{"children": [ids], "slots": {"name": id}, "nodes": {...}}`. |
| `--validate-only` | Only validate. |

Steps (`--tap`, `--hover`, `--focus`, `--unfocus`, `--key`, `--type`, `--set`, `--scroll`, `--drag`, `--navigate`, `--wait`) run in the order given, after the screen
has loaded and before the capture, at every size. A step that names a node not shown at a size (hidden there by a
media rule or a binding, or on another breakpoint's canvas) is skipped at that size, with one warning per size
listing the skipped steps; the other steps run and the capture is made.

Node ids are per document (a page's, a component's, a modal canvas's): two nodes on screen may share one. A step
naming an id that two different shown nodes have is an error listing how to name each: `<canvas id>/<id>` for the
page's own node (`page/saved`), the call path for a component's (`footer/saved`). Copies a list repeats are one
node (`#n` picks a copy).

```sh
# The whole site at three sizes, full pages.
tool/render/render.sh site/ --out shots/ --full-page
# A detail page opened with its route parameter, and a modal opened on it.
tool/render/render.sh site/ --out shots/ --navigate 'speaker?id=ada' --tap bioMore --full-page --label speaker-modal
# A reordered list and a slider.
tool/render/render.sh site/ --out shots/ --screen planner --drag stopHandle#0=0,120 --drag budget=80,0 --label dragged
# The pricing toggle switched to annual, on desktop only.
tool/render/render.sh site/ --out shots/ --screen home --sizes 1440x900 --tap billing-toggle --label annual
# A form's error state.
tool/render/render.sh site/ --out shots/ --screen contact --tap submit --label errors
```

## What it reports

Validation codes are listed in the API reference (codelessly_api's `docs/reference/render.md`, "Validation
codes"; the reference starts with `docs/reference/STARTER.md`, the base). Links to one missing screen are reported
once per screen (`unknown_screen`, with how many links name it and where), not once per link: list every page in
`site.json` before writing the pages that link to them. The render step adds:

| Code | Severity | Meaning |
|---|---|---|
| `invalid_json` | error | A file is not valid JSON (with line and column). |
| `design_system_missing` | error | The design system `site.json` names (`"designSystem"`, a folder relative to it) has no readable `design_system.json`. |
| `no_documents` | error | No `.json` documents at the paths given. |
| `unknown_screen_arg` | error | `--screen` names no canvas, screen or layout. |
| `render_exception` | error | Flutter threw while building, laying out or painting; the message names the node (`Node "price-row" (row): ...`). A flex overflow under 0.01 px (rounding) is not reported. |
| `action_error` | error | An action chain failed (a `load` reaction, or one a step ran). |
| `interaction_failed` | error | A step could not be applied: no such node on screen, an id two shown nodes have (the message names each by path), nothing scrolls, the node is covered wherever it shows (the message names what covers it), nothing in it takes a tap (no fill, no reaction), no text field to type into, no such screen. A warning when the steps' nodes are not shown at that size (skipped there). |
| `tap_no_reaction` | warning | A `--tap` hit its node, but neither it nor anything around it reacts to a tap: nothing happened. |
| `missing_glyph` | warning | A text has characters its font has no glyph for (drawn as empty boxes): the message lists them. |
| `icon_not_drawn` | warning | An icon names no glyph the renderer can draw. |
| `expression_not_evaluated` | warning | A text shows `${` on screen: an expression that did not evaluate. |
| `path_overflow` | warning | A `path` (or a box's `path`) draws outside its box; it is not clipped to it, as Flutter's `CustomPaint` is not. |
| `layout_overflow` | warning | A node extends past its parent's box where the parent does not scroll that way. A node of a component instance is named by its path, and its parent is the one in its own document. |
| `fill_fallback` | warning | A node fills an axis its parent measures with no limit (a column that hugs its height, a wrapping row's line, a grid row sized to its content): it takes the design number of its `{"fill": n}`. The message names the parent and the fix. |
| `set_overwritten` | warning | A timer or `load` reaction wrote a variable a `--set` step set, after it: the capture shows the `--set` value. `--now` pins a clock. |
| `compare_failed` | warning | `--compare` found no reference for a capture, or could not read it: the message lists the candidates. |
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
A site's own fonts need no flag: the families `site.json` declares (`"fonts": [{"family": ..., "fonts": [{"asset": "fonts/..."}]}]`, files beside it) are registered under their declared names and loaded before the page shows; a missing file is `font_missing`. Images a document names by a path relative to the site are read from its folder (`image_failed` names a missing one).

The command registers every font file under `--fonts` directories by the family, weight and style written inside
the file (its `name` and `OS/2` tables), so file names do not matter. It always has Roboto (all weights the
Flutter SDK ships: 100, 300, 400, 500, 700, 900) and the Material Icons font, from the Flutter SDK's cache.

Text that names no family is drawn in Roboto, the default family of a Flutter app on Android and on the web (in
an app it is the platform's font). A family the command does not have is drawn in Roboto and reported as
`font_fallback`, whose message names the family, weight and style asked for, the weights the family has, the
directories searched and any file of that family found but not read; a missing weight next to one the family has
(600 when there are 500 and 700) is drawn with the nearest and not reported.

Web fonts: a `.woff` file is decoded by the command (its tables are zlib streams) and read as the TrueType or
OpenType file it wraps. A `.woff2` file (Brotli-compressed) is not read: it is reported, and an npm
`@fontsource/<family>` package has a `.woff` of every face beside its `.woff2`, so `--fonts
node_modules/@fontsource/<family>` works as it is. `--fonts system` adds the system's font directories
(`/usr/share/fonts`, `~/.fonts`, `/Library/Fonts`, `C:\Windows\Fonts`...). The command downloads nothing.

## Images

The SDK draws `https://` and `data:image/...` URLs. Offline, the command also reads an image path relative to
the document (`"url": "assets/photo.png"`, or `file://...`) and inlines the file as a `data:` URL. Network images
are not fetched: they are reported (`image_network`) and stay blank. Material icons named without a codepoint
(an app fetches their SVG) are drawn from the Material Icons font.

## How it runs, and how fast

It is a `flutter test` harness (`render_harness.dart`, run by `render.sh`): headless, no device, no network,
real fonts. A run takes about 6 seconds once Flutter has compiled the harness (the first run after the SDK changes
takes 20 to 30 seconds), plus about half a second per screen and size.

`render.sh` finds Flutter in `$FLUTTER` (the `flutter` command), else `$FLUTTER_ROOT/bin/flutter`, else `flutter`
on the `PATH`, else `/opt/flutter/bin/flutter`. It resolves the SDK's dependencies itself (`flutter pub get`) when
they never were or the pubspec (or its overrides) changed since. `codelessly_api` comes from a sibling checkout
when there is one (`../CodelesslyAPI` or `../codelessly_api` next to the SDK, or the directory `$CODELESSLY_API`
names): the script writes a `pubspec_overrides.yaml` saying so on its first line, and removes it when the sibling
is gone. An overrides file of your own is never touched. Without a sibling, the published `codelessly_api` is used.

Runs take turns: `flutter test` rewrites the checkout's `build/` (native assets, test assets, the compiled harness)
as it starts, so `render.sh` holds a lock (`build/.render.lock`) for the run, and a run started meanwhile says it is
waiting and starts when the one before ends. Start as many as you like, each with its own `--out` (or `--label`):
they finish one after another, never fail for it. For runs truly in parallel, use separate SDK checkouts (git
worktrees), one run at a time each.

## What a run keeps

Storage (`setStorage`, persisted variables), variables and the clipboard are in memory, for one run: the steps and
`--navigate` see what earlier steps wrote; each size starts afresh, and so does each run (nothing persists between
runs: capture a "restored" state by writing it first in the same run, then navigating). `downloadFile` succeeds
and saves its file under `<out>/downloads/<capture name>/<fileName>`; `copyToClipboard` copies in memory (reading
the clipboard gives it back). Both are printed (`downloaded ...`, `copied to the clipboard: ...`) and listed in the
diagnostics file (`downloads`, `clipboard`). `openLink` opens nothing.

A `--tap` or `--hover` puts the pointer on a point of the node that a hit test reaches (its center, else the
center of what it draws: a text or an icon is smaller than its slot when it is stretched or aligned there, or has a
margin). A node out of view, or covered where it shows (a header over the page), is first scrolled to the middle of
its scrolling ancestor. A tap that would land on another node is not made: it is reported with the node that covers
it. Icons are drawn from the Material Icons font, also when their name comes from a binding.

Differences from an app that matter: the window is exactly the size given, at a pixel ratio of 1; text with no
font family is drawn in Roboto; there is no network; `openLink` opens nothing; platform services (storage,
clipboard, file saving) are in memory or in `--out` (above).
