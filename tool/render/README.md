# The render command

`tool/render/render.sh` renders Codelessly layout documents with this SDK, headless,
so a person or an agent writing documents by hand can see what they made and what is wrong with it.

```sh
tool/render/render.sh <document.json | directory> [...] --out <dir> [options]
```

The documents themselves are described by codelessly_api's reference: start with `docs/reference/STARTER.md` (the
base, which ends with an index of the feature pages); `docs/reference/render.md` is this command's page there
(the loop of checking and capturing states).

It:

1. **publishes** the documents as the editor does: each document is a page; canvases that share `props.screen`
   are one screen with a canvas per breakpoint (`props.breakpoint`); every other canvas is a screen of its own;
2. **renders** every screen with `CodelesslyWidget` (bindings, variables, conditions, breakpoints and reactions
   run as in a published app) at each size, writing `<out>/<screen>@<w>x<h>.png` (after a `--navigate`, or a tap
   that navigates, `<screen>` is the screen the capture shows);
3. **reports** what only rendering shows (below), tied to node ids;
4. writes everything to `<out>/diagnostics.json` and **exits 1 when there are errors**, 0 when there are only
   warnings or none, 2 for bad arguments. The file's name carries what the run was limited to, as a PNG's does, so
   runs of one label on other screens or at other sizes keep each its own: the `--screen` (several joined by `+`),
   then `@` and the `--sizes` when they are not the default ones, then the `--label`: `diagnostics-<label>.json`,
   `diagnostics-home-<label>.json` (`--screen home`), `diagnostics-home@1440x900-<label>.json` (`--screen home
   --sizes 1440x900`), `diagnostics@390x844.json`. Its `images` lists the PNGs it is about; a capture named after a
   screen it navigated to is under `startedOn` with the screen its run started on (what its diagnostics' `screen`
   says).

A directory with a `site.json` is a site of pages and components (codelessly_api guide §19): its pages (the
manifest's `pages`, else its `.json` files), its components (the manifest's `components`, else the files under
`components/`, each named after its type) and its project variables. Steps name a node inside a component instance
by its path, the call ids from the page down and then its id (`--tap plans/card1/cta`; `#n` picks the n-th copy a
list repeats: `--tap faq/fq#1`); `--dump-layout` writes each such node's `path`. The end of the path is enough when
one node on screen has a path ending so (`--tap joinSeason/action` or `--tap action` for
`FieldSeason1/joinSeason/action`); when several do, the step is an error listing their full paths.

The manifest's `theme` (named colors and text styles, codelessly_api guide "the theme") is published as
the project's theme and resolved as an app resolves it: at each size its media rules, the fonts its styles name.
A manifest that names a design system (`"designSystem": "../design_systems/ssui"`, its folder relative to
`site.json`, or an absolute path) gets its components (callable by type, rendered as the site's own; `--components-all`
renders them too), its tokens as the base theme the site's `theme` is merged over, and its fonts.

Paths (the documents, `--out`, `--fonts`) are taken relative to the directory the command is run in: a script
that `cd`s into the SDK first passes absolute ones, or its PNGs land in the SDK's checkout. In Git Bash on Windows
a value starting with `/` is rewritten to a Windows path before the command sees it (`--key /` arrives as
`C:/Program Files/Git/`): run the command with `MSYS2_ARG_CONV_EXCL='*'` set (not `MSYS_NO_PATHCONV=1`, which
also stops the paths the tools need from being converted). `--outline` and `--sheet` are options of `tool/codelessly render`, which runs this command; `--outline` prints the
outline of the captures that run made (not of the files earlier runs left in `--out`).

A directory is every `.json` file in it (not those starting with `_`, nor `diagnostics*.json`), as the pages of one
site: navigation may name a canvas of another page.

## Options

| Option | |
|---|---|
| `--out <dir>` | Where PNGs and `diagnostics.json` go (required). |
| `--sizes <WxH,...>` | Screen sizes, default `390x844,834x1112,1440x900`. |
| `--screen <id or name>` | Only this screen: a canvas id, a layout id, a `props.screen` name, a canvas name or path. Repeatable. Without it, every screen but a canvas only ever opened as a modal (an `openModal` names it, in a page or inside a component, and no `navigate` does): name it to render it alone, or pass `--modals`; each such screen is named in a `modal_screen_not_captured` line. |
| `--modals` | With no `--screen`: the screens only ever opened as a modal are captured too, each alone (as `--screen` names one). |
| `--full-page` | Capture the whole page: its own scroll view (the largest one a user can scroll, at least 60 % of the window's width: a window of panes that each scroll, a mail list beside its reader, is captured at the window's size; lists and decorations that do not scroll add nothing) over its whole extent, while the window keeps the size asked for, as a browser's full-page screenshot does. What stands beside that scroll view (an app frame's sidebar, a rail) is as tall as the window: its content shows once, in the first window, and its background (its fill and border) carries on to the capture's bottom, so nothing under it is left unpainted. `${screen.height}` and anything sized or pinned to the window (a drawer pinned to the window's top and bottom) stay as on the device. What a reader sees once is drawn once: content fixed to the window over the page (a header, a drawer, a bar pinned to the bottom, a canvas's bottom bar or floating button) is drawn where a user first sees it, in the first window; with anything open over the page (a modal, dialog, drawer, sheet, dropdown menu or toast) the capture is the window as it shows, its dimmed backdrop over all of it, not the whole page; a list that loads more as its end comes into view (`onEnterViewport` on a sentinel) loads nothing more while the page passes through the window to be drawn; a page laid out differently once it scrolls (a header that shrinks on a `scroll` reaction) continues below the first window as laid out scrolled, with no rows lost or doubled at a seam; a `sticky` node is drawn once, in its place in the page (not pinned at the top of every window); after `--navigate` or a tap that navigates, the capture is the page navigated to, at its own height (a page covered by another is never measured or drawn). The capture always starts at the page's top, whatever a step scrolled it to (a `--tap` scrolls its node into view first); without `--full-page` the capture is the window where the steps left the page, which is how to see a sticky header pinned. `--dump-layout` gives every box where the PNG draws it. |
| (default faces) | Roboto (text that names no family), Roboto Mono (`monospace`, `mono`, `ui-monospace`, and the notation's `Text.mono`: no `font_fallback` for them) and Material Icons, from the Flutter SDK; every style falls back last to the system's symbol font (Segoe UI Symbol, Apple Symbols, DejaVu Sans or Noto Sans Symbols 2, whichever is there) for the arrows, `↵`, `⌘` and marks the others lack, as a device's own fallback fonts draw them. Without one, those are `missing_glyph`. |
| `--fonts <dir>` | Font files (`.ttf`, `.otf`, `.woff`), searched recursively and read by the family, weight and style inside each file: a font package folder (`node_modules/@fontsource/<family>`, or the whole `node_modules/@fontsource`), a site's fonts folder, or `system` (the system's font directories). Repeatable. Of a package's subset files for one face (`latin`, `latin-ext`, `cyrillic`...), the one with Latin text's characters is used. `.woff2` is not read (it is reported, with the `.woff` to use instead). |
| `--no-google-fonts` | Fetch nothing from Google Fonts (also `CODELESSLY_NO_GOOGLE_FONTS=1`, for CI): a family no file provides is drawn from the cache (`CODELESSLY_FONT_CACHE`, else `.dart_tool/codelessly_google_fonts`) or falls back to a face of its class on this machine ([Fonts](#fonts)). |
| `--theme <mode>` | `light`, `dark` or `system`: the theme mode the site starts in, as a `setThemeMode` action sets it (named colors, text styles and controls follow). PNG names end `-<mode>`; a later `--tap` on the site's switch changes it. |
| `--tap <id>` | Tap the node where it shows. `<id>#<n>` taps the n-th copy (from 0) of a node a list repeats, counting only the copies shown (a copy a condition or a filter hides is not counted: `message#0` is the first row a reader sees); `<template>#<n>/<id>` the node inside a list's n-th copy (`evCard#0/evReserve`, the same node as `evReserve#0`). `<id>@<n>` taps the n-th part (from 0) of a control with several: a segment of a `segmentedButton`, a tab of a `tabBar` or `tabs`, a destination of a `navigationBar` or `bottomNavigationBar` (`--tap billing@1`). A unique part `id` or `value` in a control's `tabs`, `segments` or `destinations` can be tapped directly (`--tap stay` for a tab with `"id": "stay"`). `@<n>` also counts the numbered parts of a design system's control that take a tap (`--tap sorter@1` for a Segments call `sorter`, whose cells are `cell0`, `cell1`...). A tap on a block that takes no tap itself goes to the one part inside it that does (`--tap dates` for the one field of a picker); with several, the warning names them. A step whose node is not found, or takes no tap, names the nodes it may have meant (`Perhaps: datePicker1, datePicker2`): the parts inside the block it names, else the nodes whose name is like it. A node drawn for show inside one that takes the press (a Table's row checkbox, `ignorePointer`) is tapped where it shows, so its row gets the press, as in a browser. A list row's swipe action, once a `--drag` revealed it, is tapped by its id or label (`--tap delete`, `--tap Delete`), or under its row when several show (`--tap ListRow1#0/delete`). A focused text field elsewhere is unfocused first, as a click outside a field does in a browser (its blur reactions run before the tap's). The built-in confirm dialog's buttons are `confirmOk` and `confirmCancel` (`--tap confirmOk`; `--dump-layout` lists them with their text). Modifier keys held through the tap go before the target: `--tap shift+row#3`, `--tap ctrl+row#5` (`mod+`: Control, Command on a Mac; `alt+`, `meta+`), as on `--double-tap`, `--long-press`, `--right-click`, `--hover` and `--drag` (`--drag alt+clip=40,0`); the reaction reads them as `result.shift`, `result.ctrl`, `result.meta` (Control or Command), `result.alt`. |
| `--tap <calendar>@<yyyy-MM-dd>` | Tap a visible day in an inline `calendar` (for example `--tap stay@2026-11-23`). Repeat to pick the range end. A day of another month is an error: tap the calendar's next-month arrow first. |
| `--tap <id>@<part>` | A named part of a built-in control (any pointer step takes them: `--drag vol@thumb=40,0`): a number field's minus and plus, `quantity@decrement` and `quantity@increment` (or `@0` and `@2` as they are drawn, `@1` the field between); a slider's thumb, `vol@thumb` (a range's upper one `vol@thumb-end`); a dropdown's (a Select's) option by its label, `region@option:Alaska` (the dropdown is opened first when it is closed). An option of the dropdown or menu open on screen is also tapped by its label alone (`--tap regionPick --tap Alaska`), and so is a line of a menu, a popover or a dialog open over the page by the text it shows first (`--tap more --tap "Leo Marsh"` for a `MenuItem "{a}"` under an each; two lines that show it: give the one meant an id). `--dump-layout` lists each control's part names as `parts` (`"parts": ["@decrement", "@increment"]`); a part the control has not is an error listing them. |
| `--drag <id>=<dx>,<dy>` | Press on the node, move by `dx`, `dy` in a dozen steps over a fifth of a second and release: a reorder handle, a slider, a draggable card, a swipe (`--drag row#0=-140,0` fires the row's `swipeLeft`; the moves are timed, so the release has the speed a swipe needs). `--drag <id>=<other id>` drags it onto another node (a drop target). `--drag <id>=<dx>,<dy>,hold` does not let go: the capture shows the drag in progress (a row swiped part of the way, its actions showing); the next step lets go. A drag that starts on a long press (a list reordered by touch, a long-press draggable) is held first. A bottom sheet with stops (`Sheet stops=[0.5,0.9]`) moves to its next stop when dragged anywhere (`--drag <sheet id>=0,-300`; its content scrolls once it is at its top stop) or by its handle, which is no node: `--drag <sheet id>/handle=0,-300`, `--tap <sheet id>/handle` (one stop on, from the top one back to the first), `--key alt+ArrowUp` / `alt+ArrowDown`. |
| `--long-press <id>` | Hold a finger on the node for 700 ms, then lift: a `longPress` reaction, the context menu a node opens on touch (`menu=<id>` in the notation). The finger goes where no control inside the node would act as it lands (a slider in a card keeps its value). When nothing there reacts to a hold, the hold ends as a tap does, as on a device: `long_press_no_reaction` says so. |
| `--right-click <id>` | Click the node with a mouse's secondary button: a `secondaryClick` reaction, the context menu a node opens on a desktop. |
| `--reload` | Close the app and start it again on the page it shows (after a navigation, the page navigated to, as a browser reloads its address; dialogs and sheets are gone), in the mode `--theme` gave unless a step stored another, with what it kept on the device (a variable with `"persist": true`, `saved` in the notation; storage actions; the theme mode). Every other variable starts from its declared value, so a capture after `--tap add --reload` shows what survives a reload. Each capture starts with nothing stored. |
| `--double-tap <id>` | Tap the node twice in quick succession: a double tap, a double click (a photo's zoom, a `doubleTap` reaction). |
| `--wheel <id>=<dy>` | Turn a mouse wheel over the node by `dy` pixels (negative: away from the user, which zooms in where a wheel zooms); `--wheel <id>=ctrl+<dy>` with Control held (a browser's trackpad pinch). |
| `--pinch <id>=<scale>` | Two fingers on the node, 80 px apart, spread to `scale` times as far apart (`2` zooms in, `0.5` out). |
| `--hover <id>` | Move a mouse over the node (hover states, `cursorEnter`). |
| `--focus <id>` | Put the keyboard focus on the node, as Tab would: a text field (a `textField`, or the one inside the node) gets the caret; else the first control or press target in the node (a button, a tab, a row or card with a tap reaction, a reorder handle `--focus grip#1`), with its focus ring. The next `--key` goes to it (`--focus newDeck --key Enter` presses it, `--focus grip#1 --key alt+ArrowUp` moves the row). A node that cannot take the focus (a text, a picture) is an error naming the nearest that can. |
| `--unfocus` | Take the focus from the focused field: no caret in the capture (an error state after `--type`); its blur reactions run. |
| `--key <key>` | Press a key on what has the focus, as a keyboard does: `ArrowLeft`, `ArrowRight`, `ArrowUp`, `ArrowDown`, `Enter`, `Escape`, `Tab`, `Space`, `Home`, `End`, `Backspace`, `Delete`, `PageUp`, `PageDown`, `F1` to `F24`, a letter, a digit or a printable character (`/`, `?` (Shift+/), `[`, `+`), with modifiers (`shift+Tab`, `ctrl+a`, `mod+k`: `mod` is Control, Command on a Mac). A character key with a text field focused types the character into it (`--key o`). A canvas's `keyDown` reactions run when no field has the focus. In a focused text field `Enter` is what the device's keyboard sends: a one-line field is submitted (its `submitted` reactions, `onSubmitted` in the notation), a multi-line field gets a new line (`shift+Enter` too). `Tab` moves the focus through the page's stops (controls, text fields, nodes with a click reaction) or, with an overlay open, through the overlay's; `Enter` and `Space` press the focused one; in a menu the arrows, `Home`, `End` and a letter move; `Escape` closes the top overlay. The run reports where the focus ends ("Where the focus is", below). |
| `--type <id>=<text>` | Focus the text field and type the text, as a user would: its `changed` reactions run, and a field whose `props.initialValue` is bound to a variable sets it. When two shown nodes share the id and only one has a text field (a form's `company` field and a footer's `company` heading), that one is typed into; else name it by path (`contact/company=Vertex`, `<canvas id>/<id>` for the page's own). A name under a block with one text field is that field (`--type quiz/field=Paris`). |
| `--set <name>=<json>` | Set a variable of the screen in view (after `--navigate`, of the screen navigated to): `--set annual=true`, `--set 'email="a@b.co"'`. It holds: when nothing but `--wait` and other `--set` steps comes after it, a timer or `load` reaction that writes the variable later does not change the capture (it is set again before the capture, with a `set_overwritten` warning). |
| `--now <ISO time>` | The time `now()` (and `nowMs()`) returns for the whole run: `--now 2026-11-13T09:00:00Z`. A clock or countdown a timer writes from `now()` shows that time; check before, during and after an event without a test-only variable. |
| `--scroll <id or screen>=<px>` | Scroll a scrolling node, or the page, to an offset: one number, along the way it scrolls (`--scroll reading=650`), or `x,y` (`--scroll reading=0,650`; in a node that scrolls both ways, its first horizontal scroll view takes `x` and its first vertical one `y`). `--scroll screen` on a page that fits its window does nothing: a `scroll_nothing` warning, not an error. |
| `--navigate <screen>` | Push a screen: a canvas id, a screen name or a URL path (`/project`, `speaker.html`), with a query string for its params: `--navigate speaker?id=ada`, `--navigate /project?id=soft-signal`. The screen reads them as `${route.id}`, as from a `navigate` action's `params`. A screen no such name finds is an error listing the screens. Later steps act on the screen navigated to, and the capture is named after it (`speaker@390x844.png`, not the starting screen's name; `--compare` looks for its reference). |
| `--wait <ms>` | Let time pass (animations, delays, toasts, timers), and `now()` and `nowMs()` with it: a clock or a deadline written from `now()` is that much later after the wait, as the timers that ran in it are (without `--now`, the run starts at the real time). |
| `--label <text>` | Add `-<text>` to the PNG names and the diagnostics file's (`diagnostics-<text>.json`; with `--screen home`, `diagnostics-home-<text>.json`), to keep states apart. |
| `--state <label> <steps>` | Several states in one run: each `--state` starts a state named `<label>` (its PNGs and `diagnostics-<label>.json` as `--label` names them) with the steps after it, up to the next `--state`, each from a fresh start; what comes before the first `--state` (sizes, screens, `--full-page`, `--dump-layout`) is every state's (so its diagnostics file is named with them too: `diagnostics-home-<label>.json` with `--screen home`). One start of Flutter and one compile for a whole drive: `--state empty --state added --tap add --state removed --tap add --tap remove`. The report has a `== state <label>` part per state; the exit status is the worst. Runs on one SDK checkout still take turns (Flutter's test runner rewrites the checkout's `build/` as it starts): a drive written as one run with `--state` takes its turn once, and `tool/codelessly serve` keeps one renderer up so each turn costs the rendering alone. |
| `--compare <png or dir>` | Compare each capture with a reference screenshot: the file, or in a directory the PNG of the same size (`390x844`) whose name is exactly the screen and the state (the `--label`; without one, `default` or no state), the parts separated by `--`, `-`, `_`, `@` or `.`: `section--saved--390x844.png` for `--label saved`, never `section--saved-empty--390x844.png`. Writes `<png>.compare.png` (the capture left, the reference right) and `<png>.diff.png` (the capture dimmed, differing pixels red), and prints the share of matching pixels, the height difference, the first differing row and the vertical bands where they differ, each with the offset at which it matches the reference when it is only shifted. Images of different heights compare; a reference of another width is scaled to the capture's. The figures go to the diagnostics file's `comparisons`. |
| `--compare-map <screen>=<name>` | Compare a screen under the name its reference has (`--compare-map home=index`), or a screen and state (`--compare-map home-empty=index--no-results`). Repeatable. |
| `--image-map <url prefix>=<folder>` | Read network images whose URL starts with the prefix from the folder (the rest of the URL, decoded and without its query, is the file's path there) and inline them, as local paths are: `--image-map https://cdn.example.com/art/=assets/art`. For documents that name published image URLs whose files you have (a reference app's assets). A mapped URL with no file there is `image_failed`, naming the path. For URLs no prefix covers (a storage bucket's tokens), name a table instead: `--image-map asset_urls.json=assets/art`, a JSON object pairing each file (relative to the folder) with its URL, either way round, as an asset upload writes it; a URL also matches without its query. Repeatable. |
| `--pick-file <path>` | The file a `pickFile` action (or a `cloudFiles` upload) picks when it opens the file chooser, which a headless run has not: `--pick-file fixtures/map.png --tap attach`. Repeatable (a `pickFile` with `multiple` takes them all, in order; one without takes the first). Without it nothing is picked, as when the person closes the chooser: the chain ends there. A `share` action has no share panel here either: the link (or the text) is copied, and listed under `copied to the clipboard`. |
| `--dump-layout` | Also write `<png name>.layout.json`: every node's box on screen (`id`, `x`, `y`, `w`, `h`) and, for a node that draws text, the `text` it shows (what a value check reads). The node that has the keyboard focus has `"focused": true`. A built-in control's parts a step names with `@` are its `parts` (`@0`... for tabs and segments, `@decrement`/`@increment`, `@thumb`, `@option:<label>`, `@<yyyy-MM-dd>`). |
| `--design-system <folder>` | With one document: render it with that design system's blocks and theme (a card expanded from the notation with `--design-system`). The tool makes the one-page site for it under `<out>/.site`. |
| `--component <Type>` | Render one component of the site alone: once per preview (at its size), else with its defaults at each size. |
| `--props '<json>'` | With `--component`: its parameters, as a call's `props`, at each size. A `variable` parameter becomes a page variable of the same name. |
| `--slots <file>` | With `--component`: what the call passes, `{"children": [ids], "slots": {"name": id}, "nodes": {...}}`. |

Steps (`--tap`, `--double-tap`, `--long-press`, `--right-click`, `--hover`, `--focus`, `--unfocus`, `--key`, `--type`, `--set`, `--scroll`, `--drag`, `--wheel`, `--pinch`, `--navigate`, `--reload`, `--wait`) run in the order given, after the screen
has loaded and before the capture, at every size. Each step settles about a second; before the capture, number variables still counting (`animate`
`animateTo` in a `load` reaction) are let arrive (up to 20 s), so counters show the numbers they end at. A step that names a node not shown at a size (hidden there by a
media rule or a binding, or on another breakpoint's canvas) is skipped at that size, with one warning per size
listing the skipped steps; the other steps run and the capture is made.

Node ids are per document (a page's, a component's, a modal canvas's): two nodes on screen may share one. A step
naming an id that two different shown nodes have is an error listing how to name each: `<canvas id>/<id>` for the
page's own node (`page/saved`), the call path for a component's (`footer/saved`). Copies a list repeats are one
node (`#n` picks a copy, from 0, among the copies shown; `--dump-layout` lists the hidden ones too, so count the
rows the capture shows).

```sh
# The whole site at three sizes, full pages.
tool/render/render.sh site/ --out shots/ --full-page
# A detail page opened with its route parameter, and a modal opened on it.
tool/render/render.sh site/ --out shots/ --navigate 'speaker?id=ada' --tap bioMore --full-page --label speaker-modal
# A reordered list and a slider.
tool/render/render.sh site/ --out shots/ --screen planner --drag stopHandle#0=0,120 --drag budget=80,0 --label dragged
# The pricing toggle switched to annual, on desktop only.
tool/render/render.sh site/ --out shots/ --screen home --sizes 1440x900 --tap billing-toggle --label annual
# A photo viewer: opened at the third photo, zoomed by a double tap, then panned.
tool/render/render.sh site/ --out shots/ --tap thumb#2 --double-tap viewerPhoto --drag viewerPhoto=-200,0 --label zoomed
# A form's error state.
tool/render/render.sh site/ --out shots/ --screen contact --tap submit --label errors
```

## Where the focus is

After the steps, when something has the keyboard focus (a `--key Tab`, a `--focus`, an overlay the keyboard opened),
the run prints one line per capture and lists the same in the diagnostics file's `focus`:

```
focus on sortBtn "Sort" (ring shown) [screen overlays 1440x900]
focus on MenuPopover1/sortPrice/item "Price" (ring shown), in the open overlay [screen overlays 1440x900]
```

```json
"focus": [{"image": "overlays@1440x900-menu.png", "screen": "overlays", "size": "1440x900", "id": "item",
           "path": "MenuPopover1/sortPrice/item", "ring": true, "text": "Price", "inOverlay": true}]
```

`id` is the node around the focused control or press target (`path` when it is inside a component instance), `text` what
it is called, `ring` whether its focus ring is drawn (the keyboard brought the focus; a pointer never shows one) and
`inOverlay` whether it is in an open dialog, sheet, popover or menu. No line: nothing has the focus (a page nobody
tabbed into, an overlay a tap opened). To walk a page by keyboard, add one `--key Tab` per stop and read the line;
`--key Tab --key Tab --key Enter` presses the second stop.

## What a screen reader was told

Each run lists what a screen reader would have spoken, one line per announcement, and the same in the diagnostics
file's `announcements`: the text of each `announce` action as it ran, and of each live region (a toast, a text marked
`live`) when its text changed (not as it first showed), with its politeness and the step after which it was said
(`load` for the screen's load reactions; `the steps, before the capture` for a timer that spoke after the last step).

```
announced "Added, 2 in the cart" (polite) after --tap add [screen cart 390x844]
live region "Saved your changes" (polite) after --tap save [screen cart 390x844]
```

```json
"announcements": [{"image": "cart@390x844.png", "screen": "cart", "size": "390x844", "text": "Added, 2 in the cart",
                   "politeness": "polite", "source": "announce", "after": "--tap add"}]
```

## What it reports

A page `site.json` lists whose file is not written yet is one `page_not_written` warning per file, not an
error: write the site page by page. The codes:

| Code | Severity | Meaning |
|---|---|---|
| `invalid_json` | error | A file is not valid JSON (with line and column). |
| `schema_unsupported` | error | A document is not of schema 3, the only one read; the message names the schema it has. It is not rendered. |
| `page_not_written` | warning | A page `site.json` lists has no file yet: once per file. |
| `design_system_missing` | error | The design system `site.json` names (`"designSystem"`, a folder relative to it, or an absolute path) has no readable `design_system.json`. |
| `no_documents` | error | No `.json` documents at the paths given. |
| `unknown_screen_arg` | error | `--screen` names no canvas, screen or layout. |
| `modal_screen_not_captured` | info | A screen only ever opened as a modal was not captured (no `--screen` names it, no `--modals`). |
| `render_exception` | error | Flutter threw while building, laying out or painting; the message names the node (`Node "price-row" (row): ...`). A flex overflow names the list copy that overflows (`dish#2`) and says what its content needs, the children it holds and what to change (a fixed height a longer item outgrows: hug it, or raise it); one under 0.01 px (rounding) is not reported. |
| `action_error` | error | An action chain failed (a `load` reaction, or one a step ran). |
| `formula_failed` | warning | A formula an action works out does not parse, or fails as it is worked out (an unknown field or function, a list function given a text): the action got null. The message gives the expression and why. |
| `interaction_failed` | error | A step could not be applied: no such node on screen (the message lists the ids it may have meant), an id two shown nodes have (the message names each by path), a node named to `--scroll` that does not scroll, the node is covered wherever it shows (the message names what covers it), nothing in it takes a tap (no fill, no reaction), no text field to type into, no such screen. |
| `step_skipped` | warning | A step names a node not shown at that size (hidden there by a media rule or a binding, or on another breakpoint's canvas; a component's node named by its path too): skipped there, one note per size listing the steps; the other steps ran and the capture was made. Nothing to fix when the node is meant to be hidden at that width (a menu button shown only on phones). |
| `scroll_nothing` | warning | `--scroll screen` on a page that does not scroll at that size (it fits the window): the step did nothing. |
| `tap_no_reaction` | warning | A `--tap` hit its node, but neither it nor anything around it reacts to a tap: nothing happened. |
| `long_press_no_reaction` | warning | A `--long-press` held its node, but nothing there reacts to a hold: the hold ended as a tap does (the message says whether its tap reactions ran). |
| `missing_glyph` | warning | A text (or a control's label: a button's `"←"`) has characters its font has no glyph for (drawn as empty boxes): the message lists them. |
| `icon_not_drawn` | warning | An icon names no glyph the renderer can draw. |
| `expression_not_evaluated` | warning | A text shows `${` on screen: an expression that did not evaluate. |
| `path_overflow` | warning | A `path` (or a box's `path`) draws outside its box; it is not clipped to it, as Flutter's `CustomPaint` is not. |
| `layout_overflow` | warning | A node extends past its parent's box where the parent does not scroll that way. A node of a component instance is named by its path, and its parent is the one in its own document. |
| `fill_fallback` | warning | A node fills an axis its parent measures with no limit (a column that hugs its height, a wrapping row's line, a grid row sized to its content): it takes the design number of its `{"fill": n}` (with no number, `{"fill": 0}`, it is as big as its content and nothing is reported). The message names the parent and the fix. |
| `set_overwritten` | warning | A timer or `load` reaction wrote a variable a `--set` step set, after it: the capture shows the `--set` value. `--now` pins a clock. |
| `compare_failed` | warning | `--compare` found no reference for a capture, or could not read it: the message lists the candidates. |
| `offscreen` | warning | A node extends past the screen's edge where nothing scrolls: on a device it is cut off. |
| `text_clipped` | warning | A text's lines are taller than its box, or a word is wider than it. |
| `text_truncated` | warning | A text is cut at `maxLines` with overflow `clip`. |
| `text_no_color` | warning | A text has no `style.color` (the engine paints it white), or a transparent one (alpha 0). The check is the one a `UiSession` runs on what it shows (`paragraphIssues`). |
| `font_fallback` | warning | A font family (or a weight far from any it has) is not in the fonts directories. |
| `image_failed` | error | An image file is missing, or an image does not decode. |
| `image_network` | warning | An image is on the network: not fetched, so blank in the screenshot. |
| `empty_screen` | warning | The screen drew no nodes. |
| `formula_invalid` | warning | A formula of a node (a binding, a value, an action) or of a variable does not parse, so it gives nothing where it is used (a list with no rows, a text with no value): the node, the field, why and the expression. `notation.sh expand` says the same at the line it was written on. |
| `transparent_background` | warning | 2% or more of a capture has nothing painted behind it (transparent in the PNG): a reader sees the host's background there (black in an app with none, the page's color in a browser), not the document's. Give the screen's canvas a fill. |
| `component_missing` | error | A call rendered without its component's definition (or nested more than 32 deep): an empty box of its size. Named by its path. |
| `placeholder_word` | warning | A word that stood in as a placeholder when the site's notation was expanded (`--open`), or, closed, a type refused: one per use, on its node (the outline marks the node `[placeholder: Word]`), with the word, its kind, its file and line, the shape it was written in and the hint "define it, or it is recorded for support". Read from the vocabulary record `notation.sh expand` saves beside the site (`vocabulary.json`, in the site's folder or the one above), so a site rendered without expanding again still says it; the summary line counts the words. |

`test/tool/render_command_test.dart` checks that these codes are reported for the fixtures in
`test/tool/fixtures`.

## Fonts

A text style names its family with `fontFamily` and its file with `fontWeight` (100 to 900) and `fontStyle`.
A site's own fonts need no flag: the families `site.json` declares (`"fonts": [{"family": ..., "fonts": [{"asset": "fonts/..."}]}]`, files beside it) are registered under their declared names and loaded before the page shows; a missing file is `font_missing`. Images a document names by a path relative to the site are read from its folder (`image_failed` names a missing one).

The command registers every font file under `--fonts` directories by the family, weight and style written inside
the file (its `name` and `OS/2` tables), so file names do not matter. It always has Roboto (all weights the
Flutter SDK ships: 100, 300, 400, 500, 700, 900) and the Material Icons font, from the Flutter SDK's cache.

Text that names no family is drawn in Roboto, the default family of a Flutter app on Android and on the web (in
an app it is the platform's font).

**Google Fonts.** A family that is neither among the command's own faces, the `--fonts` directories nor the site's
declared files is fetched from Google Fonts by family, weight and style, as an app fetches it (the SDK's
`HttpFontFetcher`: the Google Fonts CSS API's TrueType file), and drawn. Each file is kept in a cache directory,
`CODELESSLY_FONT_CACHE` or else `.dart_tool/codelessly_google_fonts` in the SDK checkout, so a second run needs no
network; the families the pages ask for are fetched before the first screen is drawn. `--no-google-fonts` (or
`CODELESSLY_NO_GOOGLE_FONTS=1`, for CI) fetches nothing: the cache is still read. A fetch that fails (no network)
never fails a render: the family falls back as below, and its `font_fallback` warning says Google Fonts gave no
file for it.

A family Google Fonts does not have (a system or commercial face) is drawn in an open face fetched the same way,
the same on every machine:

| Asked for | Drawn in |
|---|---|
| Georgia | Gelasio (Georgia's metrics) |
| Times New Roman, Times | Tinos (Times New Roman's metrics) |
| Arial, Helvetica, Helvetica Neue | Arimo (Arial's metrics) |
| Courier New, Courier | Cousine (Courier New's metrics) |
| another serif (by its name: `serif`, Garamond, Baskerville, Didot…) | Gelasio |
| a slab (Rockwell, Museo Slab…) | Roboto Slab |
| a script (Brush Script, Freestyle Script, `cursive`…) | Dancing Script |
| a monospace face | Roboto Mono (built in) |
| a sans | Roboto (built in) |

Only where fetching is off or fails (and the cache has no file) is it the machine's own face of the class: a serif
the first of Georgia, Times New Roman, Garamond, Book Antiqua (DejaVu or Liberation Serif on Linux), a slab Rockwell
else a serif, a script Brush Script or Freestyle Script else a serif; Roboto for a sans. Such a picture can differ
between machines. A family drawn in another face is reported as `font_fallback`, whose message names the family,
weight and style asked for, the weights the family has, where the command looked (Google Fonts among them) and
any file of that family found but not read; a missing weight next to one the family has (600 when there are 500
and 700) is drawn with the nearest and not reported. A variable font (a file with a `wght` axis) has every weight of
its axis, whether declared once in `site.json` or found under `--fonts`.

Web fonts: a `.woff` file is decoded by the command (its tables are zlib streams) and read as the TrueType or
OpenType file it wraps. A `.woff2` file (Brotli-compressed) is not read: it is reported, and an npm
`@fontsource/<family>` package has a `.woff` of every face beside its `.woff2`, so `--fonts
node_modules/@fontsource/<family>` works as it is. `--fonts system` adds the system's font directories
(`/usr/share/fonts`, `~/.fonts`, `/Library/Fonts`, `C:\Windows\Fonts`...). Besides Google Fonts' files (above), the command downloads nothing.

## Images

The SDK draws `https://` and `data:image/...` URLs. Offline, the command also reads an image path (`"url":
"images/photo.png"`, or `file://...`) and inlines the file as a `data:` URL. In a site the path is relative to the
site's folder (the one with `site.json`) in every document, components included (`images/bowl.svg` from
`components/ProductCard.json` too, never `../images/bowl.svg`), as a published site reads it: its files are served
from the site's root. A document rendered on its own (no `site.json`) reads paths relative to its own folder. A
path written from a component's folder is reported (`image_failed`) with the site-relative path to write. Network images
are not fetched: they are reported (`image_network`) and stay blank. Material icons named without a codepoint
(an app fetches their SVG) are drawn from the Material Icons font.

Text inside an SVG (`<text>`) is drawn in the site's fonts, as a text node's is: a generic family (`sans-serif`,
`serif`, `monospace`, `system-ui`) and text naming no family take the theme's `fontFamily`; a named family is
used when the site declares it (or `--fonts` has it), else drawn in the theme's font and reported as
`font_fallback` naming the SVG (`by "the text of images/map.svg"`). Declare the family in `site.json` to draw
it as designed.

## How it runs, and how fast

It is a `flutter test` harness (`render_harness.dart`, run by `render.sh`): headless, no device, no network,
real fonts. A run takes about 6 seconds once Flutter has compiled the harness (the first run after the SDK changes
takes 20 to 30 seconds), plus about half a second per screen and size.

`render.sh` finds Flutter in `$FLUTTER` (the `flutter` command), else `$FLUTTER_ROOT/bin/flutter`, else `flutter`
on the `PATH`, else the usual install places (`/opt/flutter`, `~/flutter`, `~/.tools/flutter`,
`/workspace/.tools/flutter`, `/usr/local/flutter`, `~/development/flutter`). When it finds none it says so and exits
2: set `FLUTTER=/path/to/flutter/bin/flutter` on the command (`FLUTTER=... tool/render/render.sh site/ --out shots/`).
This command and the reference (codelessly_api's `docs/reference/`) are on the `master` branch of both repositories:
a checkout without `tool/render` or `docs/reference` is an older branch (`git fetch origin master && git checkout
master`). Every run first prints what it uses: `Rendering with codelessly_sdk <version> @ <commit> on <branch> at
<path>, codelessly_api <version> @ <commit> from <path>, Flutter <path>`. It resolves the SDK's dependencies itself (`flutter pub get`) when
they never were or the pubspec (or its overrides) changed since. `codelessly_api` comes from a sibling checkout
when there is one (`../CodelesslyAPI` or `../codelessly_api` next to the SDK, or the directory `$CODELESSLY_API`
names): the script writes a `pubspec_overrides.yaml` saying so on its first line, and removes it when the sibling
is gone. An overrides file of your own is never touched. Without a sibling, the published `codelessly_api` is used.

**The render server.** `tool/render/serve.sh` (or `tool/codelessly serve`) starts the harness once and keeps it
running: every later `render.sh` run on the checkout is a request to it and skips Flutter's start (about 5 s), with
the same arguments, report, files and exit status. It serves the code it started with: when the SDK's `lib/` or
`tool/render/`, its pubspecs or the sibling `codelessly_api`'s `lib/` change after it started, `render.sh` stops it
and renders the usual way. `serve.sh --status` and `--stop`; it stops by itself after `--idle` seconds without a
request (default 1800). Its state and log are in `build/.render-server/`.

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
