## Unreleased

### Behaviour changes (read before upgrading)

**Theme**

The SDK no longer uses Flutter's Material theme at all. It reads no `Theme` and puts none above a layout: a
layout, and the runtime's own dialogs, toasts, sheets, players and lists, draw with the project's theme tokens
and nothing else. A project looks the same in a `MaterialApp`, a `CupertinoApp` and a plain `WidgetsApp`.

- **Nothing of your app's theme colours anything of the SDK's.** The loading spinner (`CodelesslyLoadingScreen`)
  took your app theme's primary colour before a project had loaded; it is the project's primary, or a neutral
  ink. A dialog's barrier is black at 54% unless the action sets a scrim; your `DialogTheme.barrierColor` is
  not read.
- **`themeDataOf` is removed.** For the project's colours in your own widgets use `surfaceRoles(tokens)` (see
  Added); the theming guide shows a `ThemeData` built from them.
- **`FeedbackTheme` is no longer a `ThemeExtension`** (its `lerp` is gone), and a `FeedbackTheme` in your
  `ThemeData.extensions` is not looked for. `ResolvedFeedbackTheme.themeData` is removed
  (`ResolvedFeedbackTheme.tokens` gives the look as theme tokens), and `ResolvedFeedbackTheme.resolve` takes
  the theme's colour roles and font instead of a `ThemeData`.
- **A widget of your own shown inside a layout (an external component, a registered widget) finds your app's
  theme**, where it found one the SDK made from the project's tokens. In an app with no Material theme it finds
  none, as anywhere else in that app. It still gets the layout's default text style and icon colour.
- **A widget of your own inside a layout is no longer on a `Material`.** One that needs a Material ancestor (an
  `InkWell`, a `TextField`, a `ListTile`) must bring its own `Material`.
- **The confirm dialog's shadow is the theme's** (its largest shadow token), where it was Material's elevation.
  A dialog look with shadows of its own is unchanged.
- **The audio player's background and text are the theme's**: its tertiary background, its text colours and
  its font. The sizes of the text are the same.

**Screens, dialogs and sheets**

- **Your app's `ThemeData.pageTransitionsTheme` (and `ThemeData.platform`) no longer change how a project's
  screens come and go.** A screen with no transition of its own plays the SDK's page transition
  (`CodelesslyConfig.pageTransitions`, see Added): by default the platform's, which is what an app with an
  untouched theme played before. An app that customised its theme's page transitions and wants them for the
  project's screens passes them in; the navigation guide has the few lines that do it.
- **On Android the system's back swipe plays the screen's own way out under the finger**, as far as the first
  15% of it, then leaves or comes back. It played Material's predictive-back look (the screen shrinking in a
  rounded frame). Only apps with `android:enableOnBackInvokedCallback` are affected.
- **On the web a screen opened through `CodelesslyWidget.onGenerateRoute` (your own `pushNamed`, a link) has no
  page transition**, as a `navigate` action's screen already had none there. It played the transition of the
  visitor's operating system.
- **`CodelesslyPageRoute` is no longer a `MaterialPageRoute`** (it is a `PageRoute`): `route is
  MaterialPageRoute` is false for a project's screens, and a paywall and a full-screen modal open in a
  `CodelesslyPageRoute` too. `seeThroughPageTransitions` is removed, with
  `SeeThroughZoomPageTransitionsBuilder` (`internals.dart`): above backdrop screens the SDK's transitions paint
  nothing behind the screens by themselves.
- **Behind two screens while they move, Android's transition and the desktop's scrim are the project's surface
  color**, not your app theme's.
- **A dialog comes and goes as the SDK's other presented layouts do**: it fades in and grows from 96% over
  320 ms, and leaves over 200 ms. It faded over 150 ms both ways, as Material's dialog does. This is every
  `openModal` dialog with no blur or scale of its own, and `confirm`.
- **A plain bottom sheet moves as the SDK's sheets do**: up over 320 ms and down over 200 ms on the SDK's curve
  (it was 250 ms on Material's), and a downward fling of 400 px a second closes it (it was 700). It is as wide as
  the screen unless the action sets `sheetWidth`, which a plain sheet now follows; it was never wider than 640.
  It still follows a finger, and closes when let go under half way.
- **A dialog's barrier and pull to refresh are called "Dismiss" and "Refresh"** to a screen reader in every app.
  In a Material app they were your app's Material localization. `CodelesslyConfig.labels` gives them, and the
  other words of the runtime's own chrome, in your language (see Added).

**Chrome**

The runtime's own chrome looked like Material's. It is drawn with the SDK's stock controls now, in the project's
theme (or a design system's), as the same control in a screen is.

- **Buttons.** The toast's action and close button, the confirm dialog's answers, the players' play buttons, a
  swiped row's Undo and a chat list's jump-to-latest button are the SDK's buttons with nothing of Material's over
  them: the theme's hover and press layers, and a focus ring when the keyboard is on one (it was a tint). Their
  colours, fonts, radii and the dialog's button height are still the feedback look's (`FeedbackTheme`, a
  toast's or a confirm's own style).
  - The toast's action is as wide as its label and padding (it was at least 48), and the close button's cross is
    the icon size of the SDK's 36 px button (16; it was 18).
  - The audio player's play button is the SDK's 44 px icon button in the theme's secondary text colour (it was
    40 px, in the primary colour). The video player's is the SDK's small floating button at 44 px: the primary
    colour, with its shadow.
  - A list's jump-to-latest button is the SDK's small floating button, 44 px (it was 48 px on a tonal surface).
- **The Undo bar** is the theme's inverse surface (the tooltip's colours), with the theme's panel radius and
  shadow and 13 px text. It was Material's dark grey snackbar.
- **The audio seek bar** is the SDK's slider, as an unstyled `slider` draws: its track, its thumb and its
  disabled look. It was a 3 px track with a taller played part and a 12 px thumb.
- **The loading spinner** is the SDK's spinner as an unstyled `circularProgressIndicator` draws it: a 24 px
  ring, its arc a steady 30% turning once every 900 ms, in the theme's primary colour. The loading screen
  (`CodelesslyLoadingScreen`), a paginated list's default loading footer and an audio player that is getting
  ready showed Material's `CircularProgressIndicator` (36 px on the loading screen, its arc growing and
  shrinking). A `loadingBuilder` of your own is unchanged.
- **Pull to refresh** shows the SDK's spinner on a 36 px disc in the theme's raised surface, with its hairline
  border and shadow. The arc fills from the top as the list is pulled, then turns while the list refreshes. It
  was Material's 40 px white disc and its arc with an arrowhead. The pull that brings it down, where it rests
  and how long it takes to leave are unchanged; `refreshColor`, `refreshBackgroundColor` and
  `refreshDisplacement` apply as before.
- **The line between a list's items** (`separator: divider`) is the SDK's divider: a `dividerThickness` of 0
  draws no line (it drew a hairline of one device pixel), and a line thicker than the gap between the items is
  centered on the gap (it grew out of one side). Any other line is unchanged.
- **The players' and the chat list's buttons show no tooltip.** Hovering (or holding) the video and audio play
  buttons and a list's jump-to-latest button showed "Play video", "Pause audio", "Jump to latest". They no longer
  do; a screen reader still reads those names.
- **The keyboard reaches the toast's, the Undo bar's and the players' buttons as it reaches a screen's controls.**
  They are in the SDK's own focus order now (Tab, Shift+Tab, Enter and Space), where they were stops of Flutter's.
  In the confirm dialog the focus still starts on the yes (on Cancel when it is destructive), Tab moves between
  the two, Enter presses, Escape cancels. A revealed swipe action is no longer a Tab stop of its own: the row's
  keys run its actions, as before. The audio seek bar takes the arrow keys, Page Up and Page Down, Home and End.

### Added

- **`CodelesslyConfig.pageTransitions`: the page transition of a project's screens.**
  `CodelesslyPageTransitions.platform` (the default) plays Android's fade forwards, iOS's and macOS's slide with
  its back swipe from the edge, the zoom on Windows and Linux, and none on the web. Each can be chosen by name on
  every platform (`fadeForwards`, `cupertino`, `zoom`, `none`). `CodelesslyPageTransitions.animated(...)`
  takes **any transition of the animation system**: a `RouteTransition`, with a preset (`sharedAxisX`,
  `fadeThrough`, `iosPush`, `circularReveal`...) or its own `enter` and `exit` poses, curves and durations,
  played as a `navigate` action's `routeTransition` is. A subclass of your own draws anything else. A
  `navigate` action's own `transition` or `routeTransition` still wins for that navigation.
- **`CodelesslyConfig.labels`: the words a screen reader hears for the runtime's own chrome** (`CodelesslyLabels`:
  a dialog's barrier, a toast's close button, pull to refresh, jump to latest, the players' buttons, the seek bar),
  English unless you give your own.
- **`surfaceRoles(tokens)`: the colours an unstyled control draws in** (`SurfaceRoles`: surface, onSurface,
  primary, muted, outline, hairline, error), from a project's theme tokens, for your own widgets.

### Fixed

- **The package is tested and documented for any app shell.** Its tests run under a plain `WidgetsApp` as well
  as a `MaterialApp`; the README and the quickstart have a `WidgetsApp` sample and say what the SDK needs from
  the app around it (a `Navigator`, and the Material icon font for icons); the example app is a plain
  `WidgetsApp`, with a `MaterialApp` variant in `example/lib/main_material.dart`.
- **A host app that is not a Material app can open dialogs and sheets, and show a reorderable list.** Under a
  plain `WidgetsApp` (no `MaterialLocalizations` above the SDK) an `openModal` (a dialog, a cover, a bottom
  sheet), a `confirm` and a list with `reorder` failed with "No MaterialLocalizations found". Each is a route or a
  list of the SDK's own now, the same in every app.

### Changed

- **No file of the package imports Flutter's Material or Cupertino library** (23 did). An app that does not use
  Material itself carries about 430 KB less of it (Android arm64: 104 KB of `flutter/src/material`, from
  432 KB; 16 KB of `flutter/src/cupertino`, from 47 KB; none of `material_color_utilities`, from 72 KB). What
  is left in such an app comes from the plugins the package depends on (`video_player`, `webview_flutter`,
  `in_app_purchase`), which import Material themselves. A Material app carries about 300 KB less.
  `docs/design/no-material.md` has the measurements.

## 39.0.0

Schema 3 is the only schema the SDK loads; a sheet's resting stop in a variable, a file picked without an upload,
the share panel and the page's address. Needs codelessly_api 39.0.0.

### Behaviour changes (read before upgrading)

**Schema 2 documents are refused**

- **Documents of schema 2 are no longer loaded.** Every loader (Firestore, HTTP, an asset bundle, memory) refuses
  a publish model, layout, component or bundle of any schema other than 3, or with no `"schema"`, with a
  `PublishLoadException` that names the schema it found and the one it reads: `The publish model of project [p1]
  is in schema 2; codelessly_api reads schema 3 only.`, `Layout [home] is in schema 2; ...`, `The bundle is in
  schema 2; ...`. A schema newer than 3 says the same and adds `Update codelessly_sdk.`
- **What to do with one: convert it with 38.0.0 before upgrading.** 38.0.0 is the last release that reads schema
  2: with it, load each publish model, layout, component and bundle (a bundled asset too) and save what `toJson`
  gives, which is schema 3 (codelessly_api's 39.0.0 entry says how). A project published again from the Codelessly
  Editor is schema 3 already. Then upgrade: nothing that is schema 2 is read any more, in memory or otherwise.
- **A `setValue` path of schema 2** (`loops[0].duration`, `drag.track.value`...) is no longer recognised and
  refused with a hint: it is a path like any other, and sets nothing the node reads.
- **The `clock` trigger is gone** (it was read as a `timer`); write `timer`.
- **A signature pad's `signLineOffset` and `showSignMark` are no longer read**: write `signLineBottom` and
  `signLineMark`.

**Sheets**

- **A notation `Sheet` with a stop over nine tenths rises to it** (`stops=[0.5,1]`: the whole window), since
  codelessly_api 39.0.0 makes the sheet as tall as its highest stop. It stopped at its half stop: the higher one
  was dropped.

### Added

- **The stop a bottom sheet rests at, in a variable** (`openModal`'s `stopVariable`; the notation's `Sheet#id
  stops=[0.5,1] stop=@name`). The sheet writes the stop (as `snapHeights` gives it: `0.5`, `1`) as it opens and
  when a drag, its handle or Alt and the arrows move it to another; setting the variable moves the open sheet to
  the nearest stop; a sheet opened while the variable holds one of its stops opens there; the variable is `0`
  once the sheet has closed. An app's own `ActionUi` binds it by implementing `SheetStopUi` (`openSheet`, given a
  `SheetStop` to read, write and listen to); without it the sheet opens as before and binds nothing.
- **`pickFile`** opens the platform's file chooser (the `file_selector` the SDK already uses; the browser's on the
  web) and gives the picked file's record as `${result}`: `{name, size, type, data}`, `data` a `data:` URL an
  image shows and a `cloudFiles` action uploads as its `source`. `accept`, `multiple`, `content` (`dataUrl`,
  `text`, `none`) and `maxSizeMB` are its fields; picking nothing ends the chain without an error. `Services`'
  `filePicker` (or the app shell's own picker) is asked; a `TypedFilePicker` is offered the accepted kinds
  (`PlatformFilePicker` is one), any other picker is asked for images or any file and what it gives is checked.
  `mimeTypeOfFileName`, `acceptedKinds` and `fileAccepted` are exported.
- **`share`** opens the device's share panel with a text, a link and a title, through `Services`' new `sharer`
  (`Sharer`). `PlatformSharer`, the default, is the browser's `navigator.share` on the web. On Android, iOS,
  macOS, Windows and Linux the SDK has no share panel of its own (it adds no plugin for one): give `Services(sharer:
  ...)` your app's (a few lines over a share plugin), or the action copies the link (with no link, the text) to
  the clipboard and `${result.copied}` is true, as it does in a browser without `navigator.share`.
  `${result.shared}` says the panel took it. `RecordingSharer` records shares in tests.
- **`screen.url`**: the address of the page as shown. In a browser, its URL; elsewhere the location the screen's
  route was opened with (`/trip/coast?day=2`, as `CodelesslyWidget.onGenerateRoute` names routes and as a link
  into the app opens them), or empty when it has none. A dialog or sheet has the address of the page it was opened
  from. In a `CodelesslyView` too.
- **Render tool: `--pick-file <path>`** is the file a `pickFile` action (or a `cloudFiles` upload) picks in a run,
  repeatable; without it nothing is picked, as when the chooser is closed. A `share` action copies its link there,
  listed under `copied to the clipboard`.

- **A graph, as a preview** (`package:codelessly_sdk/graph.dart`): `CodelesslyGraph` draws an interactive chart
  from a JSON spec and a list of rows, with no closures in the spec: panes of marks (lines, areas, bars, candles)
  over one x axis the person drives, transforms that work out further columns (`sma`, `ema`, `rsi`, `stddev`),
  price lines, session bands and markers. It pans, flicks, zooms by wheel and pinch, scales an axis by a drag,
  fits the y scale to the rows in view, shows a crosshair that snaps to the rows, follows new rows, and asks for
  older ones as the view reaches the first (`onNeedHistory`). Its viewport and cursor are state it gives the app
  (`onState`) and takes back (`view`). `GraphEngine` and `GraphSpec` are the same without a widget. It is drawn
  by a copy of the graphic package kept inside the SDK (MIT), and adds the `vector_math` dependency. This is a
  preview: the spec's shape and these classes may change in any release, and a Codelessly document cannot hold a
  graph yet.

### Desk

- **A `BoardColumn`'s cards are 8 apart**, as its description says: cards written under it touched. Cards made
  by an `each` go in a `Column w=fill gap=8` under the column, with the `each` in it (a gap does not reach into
  an `each` from outside it); Desk's guide says so.
- **The kanban example's cards drag between columns**: each column's cards are in a Column that takes a dropped
  card (`drop=cards onDrop={…}`) and each card is dragged (`drag=cards({k.key})`). Its pictures are rebuilt, with
  one of a card dropped on another column (`board@1440x900-light-dragged.png`), and the gallery's feedback page.

### Removed

- `tool/notation/notation.sh migrate` (and `migrate.dart`, `migrate_bind.dart`, `expand_all.dart --migrate`), which
  rewrote notation files from the grammar of 33 and earlier (`bind=name`, `key:value`, `-> actions`): rewrite such
  a file with 38.0.0's tool before upgrading. The notation still says `bind=` is not read, with the line as it is
  written now.

### Tools

- `tool/codelessly render` reports a document that is not of schema 3 as `schema_unsupported` (an error naming the
  schema it has) and does not render it. `notation print` refuses such a document with the same message.

## 38.0.0

Needs codelessly_api 38.0.0, whose entry lists what the notation now draws differently.

### Behaviour changes (read before upgrading)

**The notation's shorthand words**

- **`Heading`, `H1`–`H4`, `Title`, `Brand`, `Logo`, `Link`, `NavItem`, `NavSection`, `SidebarFooter`, `IconTile`,
  `Dots`, `ConfirmDialog`, `Shortcut`, `computed` and their other names are no longer the notation's** (see
  codelessly_api's 38.0.0 entry): `expand` says each as an unknown word, or a placeholder with `--open`, unless a
  definition gives it. A design system's component of one of these names is called as before: Desk's `NavItem`,
  `NavSection`, `Brand` and `MenuItem`, so Desk's and Cards' reference screens draw as they did. To keep writing
  them, read a dictionary that defines them (Added); the definitions, ready to copy, are in codelessly_api's
  notation reference (`docs/reference/notation/components.md`).

**Layout**

- **Squeezable texts side by side in a row keep their own widths while they fit**, and give way in proportion
  when they do not (CSS's `flex-shrink`), in a row that squeezes its children (`squeezeChildren`, the default). As
  flexible children of equal flex they took an equal share each, so a heading beside a short count wrapped at half
  the row with room to spare. Where they cannot fit even at their least, they give way below it, so what is
  beside them stays in the row, as before. Measured (a grid's row that hugs it), the row is as tall as the
  squeezed texts' lines. A row with `squeezeChildren: false` is unchanged.
- **A grid whose rows shrink-wrap (`shrinkWrapRows`) and that gives a `mainAxisExtent`** has rows at least that
  long (CSS's `grid-auto-rows: minmax(extent, auto)`); the extent was not read and rows were as short as their
  content (a timetable's slots 16 px high).

**Controls and charts**

- **An inline calendar given less height than its rows need** fits its six rows of days inside its box (down to
  20 px a row); its rows stayed 48 px and painted past the box.
- **A line chart draws a series written without a `kind` as a line** (`chartType: line`, `series: [{"field":
  "first"}]`); it was a bar, which a line chart does not draw, so the chart had no lines.
- **A ring filled to a value (`circularProgressIndicator` with a `value`) shows its track** when it names no
  `backgroundColor`: the theme's `track`, else a progress bar's tenth of grey. It drew the arc alone. A spinner
  (no value) is unchanged.

**Dialogs**

- **A confirm action's built-in dialog takes a design system's dialog**: the corner of `radii.dialog` (before
  `radii.popup`), and with a `dialogTitle` text style its title at that size, its message at `body`'s, its
  buttons at `sizes.control` and its cancel outlined in `secondaryBorder`. Desk's confirm drew the runtime's own
  18 / 15 / 44 px and a text cancel beside Desk's outlined buttons. A theme with no dialog of its own is unchanged
  but for `radii.dialog`.

**The vocabulary record**

- **A word read from a dictionary resolves as a `definition` whose `definedBy` and `origin` are the dictionary's
  folder name** (`words` for `--dictionary ../words`), not `design system`.

### Added

- **A design at a width.** A page written with the notation's `at <width>` blocks (codelessly_api's 38.0.0 entry)
  renders as it is, with no change here: each design shows at its widths. Across a width bound the text typed into
  a field is kept (both copies of the field bind the same variable); the focus and the caret are not (the copy
  shown is another field, and the hidden one loses the focus), and each copy of a scrolling list keeps its own
  scroll position. An action that names a copied field (`focus search`) reaches the copy that is shown.
- **Render tool: `--modals`** captures the screens only ever opened as a modal (an `openModal` names them, no
  `navigate` does), each alone, in a run that captures every screen. Without it each such screen is named in a
  `modal_screen_not_captured` info line, with how to capture it.
- **Dictionaries.** `tool/notation/notation.sh` (`prompt`, `expand`, `validate`, `print`) and `tool/codelessly
  notation` and `validate` read the folders of definitions `--dictionary <folder>` names (written again for each
  further folder), or, with none written, those `CODELESSLY_DICTIONARY` lists (separated as in `PATH`;
  `--no-dictionary` reads none); a site's `site.json` adds its own (`"dictionary": ["../words"]`, relative to
  it). A word is read from the first that defines it: the page's own `define`, the site's, the design system's,
  then the dictionaries in order. `prompt` lists their words, one line each as a line uses it; the MCP server's
  `codelessly_validate` takes `dictionary` (a list of folders).
- **The vocabulary record says where the meaning of a word is written**: `origin` is `base`, `code` (a word of
  the page's frames the expander writes out) or the name of the dictionary it was read from.

### Fixed

- A custom paint's color worked out to the name of a theme color (`stroke={props.ink}` with `ink="tealDot"`)
  draws in that color; it was transparent.
- No `value_not_computed` warning for a word such as `null` that is in the data a text reads (a site's
  variables, a component's parameters) though not in the page's document.

## 37.0.0

Needs codelessly_api 37.0.0, whose entry lists what the notation now draws differently.

### Behaviour changes (read before upgrading)

**Text fields**

- **A multi-line field with an action of its own** (`textInputAction` `send`, `done`…) takes Enter itself: Enter is
  the action and Shift+Enter a new line (while an IME composes, Enter stays the IME's). A text area with no action
  is unchanged.
- **Sending from a multi-line field keeps the focus.**
- **A box around a text field with a focused look of its own** (`focused.border=…`) is focused while the field has
  the focus, as CSS's `:focus-within`.
- **A field with no border keeps its border's radius for its fill.**
- **A hugging text field whose box has a height of its own** draws its text at that box's step of the control
  scale.

**Controls**

- **A date or time picker whose decoration names only its fill, border and corners keeps its icons.** A
  decoration's border with no corners takes the control radius.
- **A dropdown with no frame of its own (`underline: false`) has its value in the middle of its box.**
- **A switch given one side only** (`Toggle h=44`) draws the standard 36 × 20 track in the middle of its box.

**Layout**

- **A stack that does not scroll and has a `clipBehavior`** clips what is in it, its corners' radius too.
- **A list's copies that are hidden take no gap.**
- **A fill with a `maxWidth`, in a stack,** is as wide as the stack up to that.
- **Squeezable texts beside a child that fills keep their own width** and the filling child takes the room left,
  whatever order the row's boxes are applied in.

**Keys**

- **What is under an open overlay takes no key.** A page's `key` lines and a node's `onKeyDown` wait while a dialog,
  a sheet, a drawer or a menu is open; the overlay's own keys run. A page shortcut that was meant to act over its
  own dialog now needs to be written under the dialog.

**Themes and fonts**

- **A theme with no `surface` on a dark ground**: controls, menus, tooltips, pickers and dialogs take that ground
  as their surface and the theme's `ink` as their text. A light ground, and a theme that names its `surface`, are
  unchanged.
- **A site's theme family is one of its pages' fonts**: the family the theme names (`"fontFamily"`,
  `"titleFontFamily"`) is declared at each weight the pages' texts use, so an app fetches it with the page.
- **A theme font that loads after the first layout reaches the controls' own texts** (a checkbox's and a toggle's
  label, a field's hint).

**Render tool**

- **Fonts from Google Fonts.** A family that is neither among the tool's own faces, the `--fonts` directories nor
  the site's declared files is fetched from Google Fonts and kept in a cache (`CODELESSLY_FONT_CACHE`, else
  `.dart_tool/codelessly_google_fonts`). A family Google Fonts does not have is drawn in an open face, the same on
  every machine: Georgia in Gelasio, Times New Roman in Tinos, Arial and Helvetica in Arimo, Courier New in
  Cousine, another serif in Gelasio, a slab in Roboto Slab, a script in Dancing Script. `--no-google-fonts` (or
  `CODELESSLY_NO_GOOGLE_FONTS=1`) fetches nothing; then, or when a fetch fails, the family falls back to the
  machine's face of its class and the `font_fallback` warning says so. A render never fails for a font, and no
  font file is added to the package.
- **`placeholder_word`** says when a stand-in draws nothing and takes no room.
- **`--wait`**: `now()` and `nowMs()` move with the run's clock. `--now` still pins it.

**Desk**

- **Narrow forms**: `PageHeader` puts its actions under the title on a phone, `BulkBar` puts its actions on a
  second line, and `Breadcrumb` shows its last step below a desktop's width.
- **Avatars inside Desk's components are the sizes its design gives**: 20 on a `TaskCard`, 32 on a `ListRow`, 36 on
  a `PaneHeader` (they all drew at 28: the component's numeric `size` was not passed through).
- **Desk's rail is 64** (`sizes.rail`, was 60), and an app's `Sidebar` with no rule for other widths is a rail on a
  tablet and a drawer on a phone.

### Added

- **`design_systems/cards/TO-DESKTOP.md`**: taking a Cards screen to a desktop page on Desk, with two screens taken
  across. **`design_systems/NAMES.md`**: the parts Desk and Cards share under other names or shapes.
  `design_systems/desk/TO-MOBILE.md` says what now happens by itself.
- **Render driver**: `--tap "Text"` taps the line of an open menu, popover or dialog that shows that text; a step
  on a row of a list hidden at this size is skipped with a note.
- **`FormulaClock.source`** lets a host that runs time itself give the time formulas read.
- **Notation tools**: an overlay a site's component writes after its tree is on every page that calls it;
  `notation.sh prompt --open` says how a theme names its font.

### Fixed

- An accordion draws every child after its header.
- A ring (`circularProgressIndicator`) that fills its place draws.
- A control's label falls back for the symbols its font lacks (← → ↗ ⌘).
- A paint `paragraph` with `textAlign` and `maxWidth` is aligned across its `maxWidth`.
- A list that keeps its end in view, with a padding of its own, no longer fails.
- `scrollTo` from an overlay reaches the page under it.
- The render command gives no `page_not_written` warning for a page listed without its extension.

## 36.0.0

Needs codelessly_api 36.0.0.

### Behaviour changes (read before upgrading)

- **Tabs, segmented buttons and chips** take the theme's accent with nothing styled and are rounded rectangles at
  the control radius, not grey pills: the chosen one is the accent with the on-accent ink, the others the theme's
  ink at 6% (10% in the dark). A chip chosen from shows no check mark unless written.
- **Tab follows the order of the tree** (the document's lines), not the position on screen.
- **Custom paint**: a node's painter is drawn over the node's own fill and border and under its children; a filled
  node hid its painter whole.
- **A Splitter** is as long as the panes it divides and an 8 px hairline in a desktop window.
- **A text beside a Spacer keeps its own width**; a list is as thick as its thickest item; copies of an `each`
  across a row sit where the row says (they were centered).
- **A node that reacts only to the secondary button** takes no part in a primary press.
- **Render tool, output names**: diagnostics are `diagnostics[-screens][@sizes][-label].json`; a capture after
  `--navigate` is named after the screen it shows; `--outline` lists this run's files only. A full-page capture with
  a dialog, drawer or menu open is the window as it shows.
- **Notation tools**: `expand` saves a vocabulary record in the site's folder (`vocabulary.json`, `VOCABULARY.md`;
  `--no-record` for none); a components file that cannot be loaded and a formula that cannot be parsed fail the
  expand; a built-in word wins over a site's definition of its name.

### Added

- **Desk** (`design_systems/desk`): a desktop design system, written clean room: a theme (zinc neutrals, an indigo
  accent, Inter 13), 36 components, its guides (`README.md`, `DESIGN.md`, `TO-MOBILE.md`), galleries and three
  reference screens. A site re-accents it by naming `primary` alone.
- **The vocabulary loop**: `tool/codelessly validate` (and the MCP tool `codelessly_validate`) gives a site's
  issues and placeholder words as JSON; render reports each placeholder (`placeholder_word`) and a formula the
  engine cannot parse (`formula_invalid`) or that fails (`formula_failed`); `notation.sh vocabulary` harvests the
  records of many runs.
- **Sites in notation**: `expand <site folder>` writes the whole site (its pages, components, variables and
  theme); `site.json` lists pages by name or as records; a `designSystem` may be an absolute path.
- **Render driver**: `--state <label> <steps>` captures several states in one run; steps hold modifier keys
  (`--tap shift+row`); `--drag id=dx,dy,hold`; `--focus` on any focusable node; `#n` counts the copies shown; a
  component's node by the end of its path (`joinSeason/action`); named parts of built-in controls (`@increment`,
  `@decrement`, `@thumb`, `@option:<label>`); `--scroll x,y`.
- **Controls**: `semanticLabel` on a checkbox, switch, radio and slider; a field's own label takes the theme's
  `fieldLabel`.

### Fixed

- A list's item template is read at the screen's size (wrapped copies were 0 tall); the children slot shows a
  `slots.children` it is given; a nested list's parent tells its readers when the outer item changes.
- A grid whose rows hug measures an item with no intrinsic size by its laid-out length (it threw).
- `close; close` closes the overlay and the one under it; a tooltip's `${…}` is filled from its scope; `key j` does
  not fire on Shift+J; focus reaches a field inside a component.
- A list reordered by the keyboard with no Handle moves its row by Alt and the arrows.

## 35.0.1

Needs codelessly_api 35.0.0.

### Fixed

- **What a view reports of a UI that is right** (`UiSession.shownDiagnostics`), found by running every check over
  the showcase pages and the vocabulary corpus:
  - `component_empty` no longer names a block that draws with a painter (Cards' `Media`) or one that only wraps
    what is put in it (`WideScroll`).
  - `no_size` no longer names the rows an `if` leaves out under an `each`, a list with no items, or a text whose
    value is empty.
  - `value_not_computed` no longer names a value that is an empty text (`"Picked: {sel}"` before anything is
    picked), a value beside another with no text between them, or words the UI's own text or data has
    (`"ERROR null check failed"`).

## 35.0.0

Needs codelessly_api 35.0.0.

### Changed

- **Notation**: `tool/notation expand` takes `--nearest-colors`; a `UiSession` writes the notation's looks as theme
  names and leaves written colors as written.

### Removed

- **The strict validator is gone** (codelessly_api no longer has `package:codelessly_api/validate.dart`): `tool/codelessly validate`, `render.sh --validate-only` and the MCP server's `codelessly_validate` are removed, and a render reports only what it meets while rendering.

## 34.0.0

Needs codelessly_api 34.0.0.

### Breaking

- **The compact notation binds a variable with `@`, and codelessly_api reads only that** (its
  docs/design/13-compact-notation.md, section 3.1): `Slider @heat min=14 max=24` (bare, the control's value;
  `value=@heat` the same), `Column selectable selected=@picked`, `SortMenu @sort direction=@dir` (a block's
  further variable), `Slider @low @high` and `Calendar @arrival @departure` (a range), where 33 wrote `bind=heat`,
  `bind=picked`, `direction=dir`, `bind=low bindEnd=high`. On what only shows a value, 33's `bind={done/total}` is
  `value={done/total}`. A bound variable is declared: by a `state` line, a site's variable, a loop's item or a
  definition's parameter. `bind=`, `bind={…}` and `bindEnd=` are not read: each line that writes them is one issue
  that shows the line in the new form.
  **To migrate: `tool/notation/notation.sh migrate <file or folder>...`** (`--design-system <folder>` for the
  blocks the files call, else every design system here; `--site <site.json>` for a site's variables; `--check` to
  list what is left; `--from 32` for a file written before 33.0.0). It rewrites notation files and the notation
  in Markdown, Dart, Python, JSON and HTML, adds a `state` line at a screen's head for each variable it binds and
  nothing declares, and prints each line it changed. It cannot rewrite `bind=` assembled in code (a Python
  f-string, a Dart interpolation): `--check` names those lines, to rewrite by hand.
- **The showcase's sortable tables bind their header's direction** (`TableHeader @sort desc=@desc` in
  `examples/showcase/cards/dashboard`, `data_table`, `table_wide` and the desktop pages with a `TableHeader`): a
  second tap on a header flips `desc`, as the block's own documentation asks. 33 read `desc={desc}` as a value
  shown, and `migrate` leaves a value in braces as written.
- Everything in this repository written in the notation is rewritten with it: the examples (the showcase's cards,
  recorded answers and desktop pages, the playground's samples, the prompt app's screens and its bundle of Skip),
  `tool/values`, the benchmark's generated notation, the README and the docs; the showcase's site
  (`examples/showcase/site`) is expanded again. Changelog entries of earlier releases keep the form they were
  written in.

### Added

- **The built-in confirm dialog** shows a detail, its buttons' words and a destructive yes; its buttons are
  `confirmOk` and `confirmCancel` to the render tool, focus starts on the yes (on Cancel when it is destructive),
  and a menu that opened it stays out of sight behind it.
- **Cards**: `mark=` on `ListRow`, `ConversationRow`, `PostCard` and `CommandPalette` highlights what a search
  matched; `Banner` takes `live`; `InfiniteList` takes `hasMore`; the `Composer` sends on Enter and takes a new
  line on Shift+Enter.
- **The vocabulary tool** (`tool/notation/notation.sh vocabulary`) counts resolved, stand-in, never read and
  unknown words apart, lists the definitions that do less than they say, and `prompt --open` prints the glossary
  with signatures (`--glossary=names` for names alone).
- **The render tool** logs what `announce` and live regions said; a step whose node is not found names the nodes
  it may have meant; a tap on a block goes to its one tappable part; `--key` takes any printable character,
  F1 to F24 and `mod`; a sheet's handle is `<sheet id>/handle`; `--reload` restarts on the page shown, in the
  mode `--theme` gave.

### Fixed

- A bottom sheet with stops moves to its next stop when dragged anywhere, and its content scrolls at the top stop.
- `SwipeAction … removes` removes its row, and its revealed action takes a tap.
- A range slider's thumbs are Tab stops of their own with a focus ring, and an arrow between whole-number ends
  steps by at least 1.
- A press on a reorder handle focuses it, so Alt and the arrows move its row after a tap.
- Cards' `CanvasShell` hugs its content where nothing limits its height; `Rating` no longer warns of a bound
  root placement; `Segments` fits its labels at 390; a `TimePicker` reads a whole number as minutes since
  midnight.

## 33.1.1

Needs codelessly_api 33.1.1.

### Changed

- **A list beside its detail, written once in the notation, works on a phone** (codelessly_api's notation, design
  note 13 section 14.4): the list fills the screen, a tap on a row (Enter or Space on it) shows the detail with a
  back button at its top left, and the back button, Escape and the system back show the list again where it was
  left; the detail fades and slides in. `test/notation/list_detail_test.dart` drives it by pointer and keyboard in
  a session and the system back in a published app; a desktop keeps both side by side. The showcase inbox
  (`examples/showcase/desktop/tier5/app_inbox.txt`) is a list and its detail at 390; the ten showcase pages draw
  as before at 1440x900.

### Fixed

- **A control's label is centered on its glyphs** by the font's own ascent and descent from the baseline. A style with
  no line height of its own has its line rounded up to a whole pixel, and the label was centered on that box: up to
  half a pixel too high, a pixel once snapped (13 px over and 16 under "Send" in a 40 px button). Buttons, chips,
  dropdowns, menu rows, tabs and pickers share the label.

## 33.1.0

Needs codelessly_api 33.1.0.

Needs codelessly_api from its master branch (universal words, docs/design/21-universal-words.md).

### Added

- **`notation.sh prompt --open --design-system <folder>` names the design system's words: the glossary** (Review
  6, D29): one line with the names of its components and defined words the open prompt does not teach, and the
  instruction to use one as expected and define only what is in neither list. `--no-glossary` leaves it out (the
  prompt `corpus-define/d01` and `d02` were written with). With Cards: 3,664 characters (24,206 for a page at
  1280 against 20,542 without; 14,874 for a card at 390 against 11,202).
- **The vocabulary tool lists the named words used in a shape we do not take** (Review 6, D30): a section of
  `VOCABULARY.md` ranks, by answers, the parameters, flags, events and variants answers gave a component of the
  design system or a word it defines that it does not take (the glossary's bug list); the sections that were
  "on words we have" are now "on core words".
- **Cards' words take the shapes the self-defining answers agreed on** (the vocabulary loop's Review 5, D25;
  codelessly_api docs/design/20-defined-words.md section 10). From the harvest of `corpus-define/d01` and `d02`
  (111 answers), where three or more answers defined a word, or a word Cards already had: `Timeline` is first a
  list of dated records (`items=[] bind=at selected onPick`; `events=`, `steps=`, `entries=` and `current=`,
  `onSelect` are aliases; a bare `Timeline` is still it), its tracks and route meanings name `tracks=[]` and
  `stops=[]`; `Stepper#steps` (`steps=[] bind=step current done=[] orientation onPick`) is the steps indicator
  beside the `Stepper` component, the number control, read when a line fits it better; `Countdown#timer`
  (`"label" seconds=0 warnAt=0 format="m:ss" onWarn onEnd`; `warnBelow=`, `onDone` aliases); `ChatBubble` takes its
  text as a string and `role="user"`; `StarRating` is `Rating`, `Breadcrumbs` and `crumbs=` are `Breadcrumb`'s.
  Where the writers' definitions were labelled boxes because the thing needs a primitive, Cards has a stand-in in
  the agreed signature, its events declared and a `//` line saying what it does not do: `MapView` (and `Map`),
  `RouteMap`, `FloorPlan`, `SignaturePad`, `CameraView`, `PhotoPicker`, `Waveform`.
- **The shapes the glossary's answers wrote, taken** (the vocabulary loop's Review 6, D30; from
  `corpus-define/d03`): repaired components (`tool/repairs/`) `Banner icon= action= onAction` (and
  `actionLabel=`; `Banner.warning` is its tone, in the notation), `FileUploader accept=` (a text or a list, said in
  its hint) and `multiple`, `Rating max=` (its label no longer required); definitions `TimelineItem date= done=
  current=`, `AttachmentTile "name" "size" progress=` (its close button with `onRemove` alone), `FlightProgress
  value=`; aliases for a component's list under the name answers gave it (`ChipTabs`, `ChoiceChips`, `Combobox`,
  `SegmentedControl`, `StepIndicator items=`), `StatusBadge status=`, `StatCard caption=`, `ImageUpload accept=`,
  `CodeBlock lang= copy`. `test/tool/cards_shapes_test.dart` expands each line as an answer wrote it, with no word
  left unknown and a document that validates. d03's unknown words 40 to 14.
- **The vocabulary tool counts universal words** (`tool/notation/vocabulary_words.dart`, `tool/vocabulary/count.py`):
  a new resolution, `universal`, for a word every line understands read where the type has no word of that name, and
  for each word a stand-in of a type we do not have honours (the parser says which: Review 2, D6). A bare number in
  the text position is counted as a text. `vocabulary.json`'s words carry the files that used them (`in`), so
  `gaps.py` counts files again (it printed 0).
- **`examples/showcase/desktop/behaviours/universal.txt`**: the universal words on several kinds of line, rendered in
  light and dark.

### Fixed

- A box whose bound interaction state changes (`selected`, `disabled` from its binding) is re-applied even when its
  node is otherwise unchanged: a list's row that became selected kept its old press target (not announced selected)
  and did not show its state style until something else re-applied it.
- A node in its `disabled` state runs no pointer actions (before, it was only taken out of the focus order).

### Changed

- **`notation.sh vocabulary`: a word an answer defines holds for all of its screens** (the vocabulary loop's Review
  4, D20): `define Word …` blocks anywhere in an answer (models write them after the last screen) are read for every
  `### screen`, with codelessly_api's `parseNotation(…, definitions:)`; what is wrong in one is said once, on the
  screen that holds it. `tool/vocabulary/hoist.py`, the stopgap that copied them to the head of each screen, is
  removed. `notation.sh expand` reads a file's definitions wherever they are written.
- **`notation.sh prompt --open` asks for every invented word to be defined** after the last screen (Review 4, D19;
  codelessly_api's `notationDefinePreface`), so `batch.sh prepare` writes self-defining batches. `--no-define`
  gives the prompt the first corpus was written with, identical to `corpus/b09/prompt.txt`.
- **`notation.sh vocabulary`: overlays opened and never written** (Review 3, D17): codelessly_api now opens a
  placeholder sheet for them with the open vocabulary; the report counts them (`overlays` in `vocabulary.json`, a
  section in `VOCABULARY.md`, and the summary line) instead of as grammar issues.
- **`notation.sh vocabulary` harvests definitions** (Reviews 3 and 4, D15 and D22; `tool/notation/vocabulary_harvest.dart`):
  `VOCABULARY.md` gains "Words defined in more than one answer": for each such word, by how many answers defined it,
  every definition's signature and body side by side as fenced blocks, with which core words, components, universal
  words (review 2's list) and other definitions each body uses, and a note where the signatures disagree (different
  strings, a parameter some answers name and others do not, a parameter that may be one under two names: the same
  default, never in the same answer). Then "Words one answer defined that others used without a definition".
  `vocabulary.json` has both as `harvest` (`definedInMoreThanOne`, `wouldResolve`).
- `notation.sh vocabulary`: `go decks_and_mixer` reaches the screen `### Decks and Mixer` (its id is
  `decks-and-mixer`); it did not validate.

## 33.0.0

Needs codelessly_api 33.0.0.

### Breaking

- **The compact notation has a new grammar, and codelessly_api reads only it** (its docs/design/17 and 18):
  `Column gap=12`, `Input "Email" bind=email`, `selected={tab == "a"}`, `Button "Save" onTap={saved=true; toast
  "Saved"}`, `SiteNav … onNavigate={go {lower(result)}} onCta={go signup}`, where it was `gap:12`, `=email`,
  `selected:=tab=="a"`, `-> saved=true; toast "Saved"` and `onCta: go signup` on a line of its own. A file in the
  old grammar does not expand: each old line is an error that says what to write.
  **To migrate: `tool/notation/notation.sh migrate <file.txt> --design-system <folder>`** (also `--markdown`,
  `--dart` for notation inside those files; `--check`). It is a one-off tool with its own copy of how the old
  grammar split a line, to be deleted once the sites written before 2026-11-16 are migrated.
- Everything in this repository written in the notation is rewritten: 434 files (the showcase's recorded answers,
  the playground's samples, SSUI's targets, the prompt app's screens, `tool/values/reference`), the design systems'
  patterns, the line each component is taught by (Cards' through its generator), the prompt app's bundle of Skip,
  the README and the tests. Each rewritten file expands to the document master's parser gave for the file as it
  was: 868 expansions (as a card, and as a page with Cards) compared to the byte, and the same for the 217 pages
  of the twenty sites with Cards. The recorded answers as the models wrote them are in this repository's history
  (the parent of this change). Answers written with no vocabulary (`examples/showcase/natural-words/**/natural`,
  the `elicit` streams), recorded prompts and the recorded `.jsonl` streams are evidence of what was written and
  are left as they were: they no longer expand.

### Added

- **Every word an answer used, known or not** (`tool/notation/notation.sh vocabulary`; the vocabulary loop's
  journal, Review 1, D1): `vocabulary.json` has `words` (each type; per type each string position, parameter,
  flag and layout word, event and variant; each action verb, formula function and statement) with how each
  resolved (core, component, alias, definition, unknown), and `summary`; `VOCABULARY.md` opens with the table by
  kind and resolution and adds, for each word we have, what the answers gave it (and what a component or a defined
  word takes that nobody gave). `tool/vocabulary/count.py` counts all of them (the 30 answers of the first two
  batches: 1,580 words, where the old count says 508) and still diffs two runs, an old one too. The parser is
  unchanged: what it knew is read from the answer's line, what it did not from its record.
- **Cards defines words in the notation** (`design_systems/cards/vocabulary/*.txt`, codelessly_api
  docs/design/20-defined-words.md): 40 files, 46 meanings, for words the corpus reached for (`StickyNote`,
  `FlipCard` with `Front` and `Back`, `ChatBubble`, `Table` in three shapes, `Timeline` in three, `ColorPicker`,
  `RangeSlider bind=range`, `Countdown`…). `expand`, `vocabulary` and `prompt` load them with the design system;
  `prompt` lists their signatures in the taught mode only; `vocabulary --no-definitions` counts without them. On
  the corpus: lines that stand in 220 → 99, unknown types 98 → 54, words resolved 46.6% → 57.7%.

- **The vocabulary loop** (codelessly_api docs/design/19-open-vocabulary.md): the prompt teaches the grammar and a
  small core, the model writes any word it expects, and we count the words it reached for.
  - `tool/notation/notation.sh prompt --open`: the open-vocabulary prompt (no component list, no behaviour words).
  - `tool/notation/notation.sh expand <file.txt> --open [--vocabulary <file.json>] [--aliases <file.json>]`: a word
    the notation does not have stands in (a type) or is left out, and is recorded; `--vocabulary` writes the
    record. The aliases are codelessly_api's built-in table and the design system's `vocabulary.json`.
  - `tool/notation/notation.sh vocabulary <folder or files> [--design-system <folder>] [--aliases <file.json>]
    [--no-aliases] [--out <dir>] [--sites <dir>]` (`tool/notation/vocabulary.dart`): reads a corpus of answers
    (several screens to a file, each under a `### name` line), expands every screen open with Cards, and writes
    `vocabulary.json` and `VOCABULARY.md`: every word with the files and uses that reached for it and how it
    resolved (core, component, alias, unknown), its parameters, events and example lines; names that share a part
    side by side; the parameters, flags, events, verbs, variants and formula functions we do not have; the grammar
    issues by message; and what does not validate, each file checked as a site with formulas parsed as the
    renderer parses them. `--sites` writes each file as a site folder for `tool/render/render.sh`.
  - `design_systems/cards/vocabulary.json`: Cards' own aliases (`Tabs items=` is `tabs=`, `Rating … readonly` is
    `readOnly`).
  - `tool/vocabulary/corpus/2026-11-16-sonnet/`: the first corpus (the prompt, 20 app briefs, Sonnet's answers)
    with the tool's output: 105 screens, 4,657 lines; 81.3% a core word, 11.6% a Cards component, 3.1% an alias,
    4.0% a word we do not have (6.5% before the aliases; `no-aliases/` has that run).

- **Nineteen behaviours, folded from the `dsl5/*` branches** (their notation in the 33.0.0 grammar; an example page
  with all of them is `examples/showcase/desktop/behaviours/words.txt`):
  - **Confirm**: the built-in confirm opens with the focus on Cancel (`onTap={confirm "Remove it?" then {rows=[]}}`).
  - **A saved value** (`state draft="" saved`) that no longer has the shape or type of its declaration starts
    afresh, and its stored entry is removed.
  - **A one-time code** (`CodeInput "Code" bind=code length=6 digits`): a text field with `otpLength` is drawn as
    boxes, still one field, one Tab stop and one semantics node.
  - **A range slider** (`Slider bind=low bindEnd=high`): two thumbs that never cross; Space or Enter switches the
    thumb the keys move.
  - **A list that follows its end** (`each line in lines follow h=180`) shows a "Jump to latest" button, a Tab
    stop, once the reader scrolls away.
  - **Search**: the formulas `fuzzy`, `fuzzyScore`, `matchRanges`, `matchRuns`, `matchReason` (`each r in
    fuzzy(rows,q,x=>x.title)`, `Text "{r.title}" mark={q}`).
  - **Announcements**: the `announce` action (`onTap={announce "Saved"}`) and a live text (`Text "{n} results"
    live`).
  - **Overlays**: a bottom sheet with `snapHeights` rests at stops (`Sheet#filters stops=[0.5,0.9]`), dragged by
    its handle or moved with Alt+Up/Down; tests for a live `blockBack` (`Dialog#edit guard={name!=""}`).
  - **A splitter** (`Splitter bind=paneW min=200 max=640`): dragged, or moved by arrows, Page Up/Down, Home/End;
    Enter collapses and restores.
  - **A rating**: a slider with `trackShape: stars` (and `readOnly`); Cards' `Rating` block (`Rating "Your rating"
    bind=score half`).
  - **A tooltip** (`IconButton "close" tooltip="Close"`) shows on keyboard focus and a touch hold too, Escape hides
    it, and it names an icon-only button.
  - **A hover card** (`Link "About Mara" preview=bio`, `Popover#bio arrow`): opens on a rested pointer or a
    keyboard focus, stays while the pointer is on it; an anchored popover can draw an arrow.
  - **Shortcuts** (`key mod+k onPress={open search}`): a combination with Ctrl/Cmd or Alt runs while a field is
    typed in; `Text "Search" shortcut="mod+k"` shows Ctrl K or ⌘K.
  - **Reorder** (`each stop in trip reorder`, `Handle`): Alt+Up/Down from a row's handle moves it, Alt+Left/Right
    passes it to the next list of its group; moves are announced.
  - **Swipe actions** (`SwipeAction "Book" side=end onTap={…}`): Left/Right reveal a row's action, Enter or Space
    runs it, Escape hides it.
  - **`device.hover`, `device.pointer`**: live, from the mice connected (`if !device.hover`); the render tool gives
    a capture 1024 or wider a mouse.
  - **A number field** (`Input "Qty" bind=qty type=number min=1 max=12 step=1`) steps by Up/Down, Page Up/Down,
    Home/End; a click reaction with `repeat` repeats while held. Cards' Stepper, Counter, NumberInput and CartLine
    use both.
  - **A calendar in the page** (`Calendar bind=arrival bindEnd=departure disabledDates=[…] marks={…}`): the
    picker's month with a range, by pointer and keys; render tool: `--tap <calendar>@<yyyy-MM-dd>`.
  - **A table by keyboard** (`DataTable rows={orders} columns=[…] bind=row`): one Tab stop, sort from a header,
    arrows through rows and columns, Enter or Space selects.
- **`tool/notation/expand_all.dart`** with `compare_runs.dart`: many files expanded at once, as a card and as a
  page with Cards, and two such runs compared to the byte: the proof that a change to the parser, or a rewrite of
  the files, leaves the documents as they were.
- **The keyboard on plain nodes**: a node with a `click` reaction is a Tab stop. It shows the theme's focus ring
  (`focusBorder`, the node's corner radius) when the keyboard brings the focus, never for a pointer; Enter and Space
  run its click; its `focused` state applies; a screen reader gets one focusable button named by its text or
  `tooltip`. Skipped: `focusable: false`, `ignorePointer`, `disabled`, hidden nodes, a click whose `when` fails,
  and a node that is itself a control. Tab also skips controls under `ignorePointer` and scrolls the stop it lands
  on into view.
- **Modal overlays hold the keyboard**: a dialog, sheet, side sheet, popover, full-screen cover and the built-in
  confirm take the focus as they open (the first focusable when the keyboard opened them, else the overlay itself
  with no ring), keep Tab inside, close on Escape unless `barrierDismissible` is false or the canvas blocks back
  (`backPressed` runs), and give the focus back to what opened them; nested overlays unwind. Their route is named
  for assistive technology (the canvas's `semanticLabel`, a popover by its opener, else its first text).
  `ModalFocus` (internals) is the host for a route of your own.
- **`focusGroup`**: what is focusable inside a node is one Tab stop; the arrows of its axis, Home, End and (with
  `typeAhead`) a letter move inside. Cards' `MenuPopover` is one, so a notation `Menu` is driven as the kit's
  dropdown menu is; `MenuItem` shows the focused row as the hovered one.
- **Render command**: prints where the keyboard focus is after the steps (the node, whether its ring shows, whether
  it is in an overlay), lists it under `focus` in the diagnostics file, and marks it in `--dump-layout`.
- **docs/BEHAVIOR_CHECKLIST.md**: ten questions a control or design-system block answers, and
  `test/support/keyboard.dart`, the test helper that answers them.
- **Session views**: a `CodelesslyView` session's `closeModal` closes the modal the session opened (a menu row that
  chose left the menu open).
- **Pages at a tablet's and a phone's width**: with the notation's reflow (codelessly_api), a page written for a
  desktop renders without layout errors at 834 and 390 wide; `tool/notation/notation.sh expand` takes
  `--no-reflow`, and reads a site's variables from the `site.json` beside `--out` (or `--site`).
- **A menu's corner**: a popover is clipped to a theme's `radii.menu` where it names one (else `radii.popup`, a
  dialog's corner).
- **Cards**: blocks fixed for a phone (SiteNav with its own menu, Hero, PostCard, Details with `inlineOnPhone`,
  PlaceRow, Steps, Pager, ComparisonTable, PhotoGallery, CodeSample, Counter, Testimonial, SiteFooter, DocsNav,
  CommandPalette, FeatureCard, InputField, CallToAction), a new `BeforeAfter`, `radii.menu`, and menu items at
  the body size. `design_systems/cards/tool/repairs.py` keeps changes made to generated components across a
  rebuild (`--record`).
- **Cards, tabs**: Tabs, TabToggle, SegmentedControl, ChipTabs and BrowserTabs are Cards blocks, and with Segments
  they stay on one line and scroll where the options do not fit (never a second row): hover and pressed states,
  44 high tap areas on a phone, an edge fade, the chosen option brought into view. ChoiceChips keeps equal columns
  while the labels fit, else chips as wide as their labels that wrap. The patterns say which of Tabs, Segments
  and ChipTabs to write.
- **A photo viewer**: the notation's `Lightbox` renders as a viewer over the window (zoom by pinch, wheel and
  double tap, pan, a gallery that pages with thumbnails and a count); Cards' PhotoGallery takes
  `viewer="overlay"`, which leaves its grid in place for it. Render steps `--double-tap`, `--wheel` and `--pinch`
  (the CLI and the MCP tool) drive it; `examples/showcase/desktop/behaviours` has a gallery, a list of pictures
  and one picture.
- **Examples**: overlays, an app's sidebar drawer and a lightbox written in the notation
  (`examples/showcase/desktop/behaviours`).
- Render steps `--long-press <id>` (a `longPress` reaction, a context menu on touch), `--right-click <id>` (a
  `secondaryClick` reaction, a context menu on a desktop: `menu=<id>` in the notation) and `--reload` (the app is
  closed and started again on the same screen with what it kept on the device, so a variable marked `saved` can be
  seen surviving a reload within one run; each capture still starts with nothing stored). In the CLI, `render.sh`,
  the MCP tool's steps (`{"long-press": "id"}`, `{"right-click": "id"}`, `{"reload": true}`) and the README.

### Fixed

- A date or time field given only a label keeps its calendar and chevron, and shows the label as its hint.
- A borderless text field with a `contentPadding` that hugs its height centers its line in the room the kit's
  minimum height adds (it sat at the top: Cards' FilterBar showed its search text 4 px above the icon beside it).
- A page route opened from an overlay sized to its design fills the window.
- `tool/render/render.sh` runs under Git Bash on Windows (it gave Dart `/c/…` paths).
- A site's variables written by name in `site.json` (`"variables": {"cart": [], "plan": "pro"}`) or as records with
  no `type` work in the notation's expander (it threw a Dart cast error on the object form), the render command and
  the runtime: they are read by codelessly_api's manifest reader, each typed by its value, and a record that cannot
  be read is an `invalid_variable` error on `site.json` (the expander prints it as one line).
- The render command's `--full-page` capture of an app frame (`App` with a `Sidebar` beside a `Main` taller than the
  window) left the columns beside the scrolling pane unpainted below the first window (a black or transparent strip
  under the sidebar, and a `transparent_background` warning). The frame is right as written: the sidebar is as tall
  as the window and stays in view while `Main` scrolls. The capture now carries each side pane's own background (its
  fill and border, without its content) down to its bottom; the pane's content shows once, in the first window.
- A card dragged onto a drop target whose `drop` reaction takes it out of its list (a board's column) threw `Cannot
  hit test a render box that has never been laid out`, and the drop did nothing. Three causes: a layer added to the
  middle of a node's chain between frames (the dragged card's opacity) was hit tested by the next pointer event
  before it was laid out (a node whose own layers are not all laid out now takes no hit, as one whose first layer is
  not already did); the dragged copy of a component instance was built without the component registry, so it showed
  the component's defaults instead of the call's parameters, at another size (a flex overflow in the copy); and a
  `draggable` or `dropTarget` written on a component's call (`TaskCard … drag=task(c.id)` inside `each`) evaluated
  its data, key and conditions inside the component, where the list's `item` and the page's variables do not exist,
  so `result.data` was empty. They read in the caller's scope now, as the call's reactions do.
- The render command's `--drag <id>=<dx>,<dy>` over a node with `swipeLeft`, `swipeRight`, `swipeUp` or `swipeDown`
  reactions fired nothing: its pointer moves carried no times, so the release had no speed and no swipe was
  recognized (the renderer's trigger fires as before). The moves are now timed a frame apart: a drag by a distance
  is a swipe that way.
- A menu item that opens a dialog, a sheet or a screen (`MenuItem "Delete" onTap={open confirmDelete}`) left its
  menu drawn, dimmed, under the dialog until the dialog closed: its chain is "open the dialog, close the menu", and
  an `openModal` waits for its modal, so the close ran afterwards. A chain whose `openModal` (not a popover) is
  followed at once by a plain `closeModal`, run from a popover, now closes the popover first and then opens. A
  chain that only opens keeps its popover under what it opens, and Escape goes back to it, as before.
- The render command's `--key Enter` in a focused text field did nothing (`TextInput … onSubmitted={…}` never ran
  after `--type`): a field connected to the platform's text input leaves Enter to it, and the test harness's text
  input sent nothing. The blocks wire `onSubmitted` correctly and a device submits. The step now does what the
  platform does: it sends a one-line field its action key (its `submitted` reactions run) and types the new line
  into a multi-line one.
- Cards: `SortMenu bind=sort options=[…]` drew an open panel of options on first paint, over what was beside it:
  SSUI's SortMenu is the body of a menu, not a control. Under Cards it is a closed control, 36 tall: the page's
  dropdown showing the choice (its menu opens on a tap, Enter or Space; the arrows and Enter choose) and the arrow
  button that flips the direction beside it. A repair in `design_systems/cards/tool/repairs.py`, so a rebuild keeps
  it.
- `NumberInput bind=amount step=0.01 showStepper=true` over `state amount=0` saved 26 for a typed 25.50, and
  ArrowUp, ArrowDown and the stepper buttons did nothing: the notation declared the variable an integer, which
  rounds what the field sets. codelessly_api's notation now declares it a decimal (the field and the block were
  right); the value keeps the step's precision by typing, by the arrow keys and by the buttons.
- A site that overrides Cards' accent (`"theme": {"primary": …}`, `colors.accent`) no longer keeps Cards' blue in
  dark mode, in the selected `Sidebar` row and `ConversationRow`, in the info `Banner`, in links and focus rings:
  the site's theme is laid over the design system's with codelessly_api's `ThemeTokens.withSiteTheme` (the render
  command and `UiSession`), which makes what Cards makes from its accent from the site's. `"primary"` or `"colors"`
  written at the top of `site.json`, outside `"theme"`, is a `site_key_ignored` warning that says where it goes.
  Cards' DESIGN.md says how a site sets its accent, its fonts (`fontFamily` for the Inter styles; the display and
  mono styles one by one) and dark as its default (`"mode": "dark"`).
- Cards: `ReorderableList addable=false` is a fixed set of items whose order alone changes: it hid the + of the
  header and still drew the x that removes each row. The x goes with the +.
- A dialog whose content is taller than the window (a long `Dialog` body on a phone) ran off the screen, its last
  buttons out of reach, with a flex overflow: it is now laid out at the height it asks for and scrolls inside the
  window (a drag, a wheel; a step that taps one of its nodes brings the node into view). A dialog that fits is laid
  out as before.

## 32.0.0

Needs codelessly_api 32.0.0. No SDK API was removed or renamed; the major version follows the API's (the compact
notation's `Column center` reads differently: see its changelog).

### Added

- **`DesignPass`**: a design agent you supply restyles a session's UI in place, after a fast model has written
  it from plain parts. An answer that is rejected, or that changes what the UI says or does, is undone and asked
  for again; a kept pass is one undo step. See the guide, "The design pass".
- **`DesignPass(blocks: [...])`**: the agent may put the design system's blocks you name in place of plain
  nodes. `DesignPass.changedMeaning(before, after, blocks: ...)` accepts a removed node when a block carries its
  text, bindings and actions.
- **`OnDemandBlocks(store:)`**: called with a new block's files so the host can save them; a later session
  started from that folder has the block.
- **Markdown**: a text with `markdown` draws bold, italic, code, links, @mentions and lists without the markers;
  a text field with `markdown` styles what is typed as it goes, markers dimmed.
- **A text field's reactions read `${field.value}`, `${field.word}`, `${field.cursor}`,
  `${field.selectionStart}` and `${field.selectionEnd}`** (`field.word` is the word ending at the cursor).
- **`"render": "glyph"` on a Material icon** draws the font glyph exactly as Flutter's `Icon` draws `Icons.*`,
  and loads no SVG.
- **Designed defaults**: with a design system whose theme defines them, plain cards, badges, bar charts, popups,
  dialogs and chart series take its look, and a control's corner follows its height (`radii.controlXs` …
  `controlLarge`). The bundled look is unchanged.

### Changed

- **`editText` edits a field as typing does**: its changed reactions run, it is one undo step, and the field
  keeps the keyboard.
- **A node at opacity 0 takes no taps**, like a hidden one. A scrim waiting to fade in no longer swallows taps.

### Fixed

- A spinner holds still when the host's tickers are off (a design canvas) and paints in its own layer.
- A text field holds its gesture recognizers only while it is attached: detaching releases them, with the double-tap
  timer a tap leaves running, so a field removed from the tree (whose dispose may wait for a frame that never comes)
  leaves no timer behind.
- SVG text is drawn in one family: vector_graphics reads `font-family` as a single name, so the resolved list
  (`"DejaVu Sans, Lora"`) named a font nothing has. A named family is drawn, or, where the caller knows its fonts
  (`SvgFonts.isAvailable`, set by the render tool), the next family the list names or the site's font; a lacking
  family is still reported.

## 31.0.1

- **A text field with a limit shows its count again.** A `textField` with `maxLength` draws how much of the limit
  is used under the field ("0/280"), following the typing, as it did when the field was Flutter's `TextField`;
  31.0.0 drew a counter only when the design wrote `decoration.counterText`, which still replaces it (and written empty,
  `counterText: ""`, still means no counter). A hugging
  field with a limit is one caption line taller than in 31.0.0.

## 31.0.0

**Breaking: the library an app imports is smaller.** Thirty-five types that are the SDK's own machinery (bound
values and the tree's bindings, the viewport's boxes, route and transition internals, the session view's sources,
the managed-component resolver) are no longer exported from `package:codelessly_sdk/codelessly_sdk.dart`. They are
in `package:codelessly_sdk/internals.dart`, which promises no stability. None is named in the guide or used by the
examples, the tools or CodelesslySite; one CodelesslyEditor test named two (`ManagedComponentSource`,
`ManagedComponentResolver`) and now imports it. An app that used one adds that import. Moved:
`BackGuard`, `BoundNode`, `BoundSource`, `BoundValues`, `BoundVariable`, `CanvasBox`, `CanvasLocationMatch`,
`CanvasSizingScope`, `CanvasViewport`, `CodelesslyPageTransitionRoute`, `CodelesslyRouteTransitionRoute`,
`CodelesslyTranslucentRoute`, `ExpressionValues`, `FocusManagerKeyboard`, `FontRegistrationCache`,
`HitTestedWhereDrawn`, `InstanceBindings`, `ManagedComponentResolver`, `ManagedComponentSource`, `MapValueScope`,
`MemoryManagedComponentSource`, `NavigatorActionUi`, `NodeGestures`, `PopoverLayout`, `PublishAssetSource`,
`RenderNodeView`, `RouteDragDismiss`, `ScreenActionContext`, `ScreenIdentity`,
`SeeThroughZoomPageTransitionsBuilder`, `SessionValues`, `ThemedSource`, `TransitionPhysics`,
`TransitionSideView`, `TreeBindings`.

**Breaking for tests and hosts that look for `EditableText`.** A `textField` is a render object: there is no
`EditableText` widget under it. A test finds the field's `RenderEditable` in the render tree (or uses the render
tool's `--type`), and a host that asks "is someone typing?" by looking for a focused `EditableText` calls
`isTyping()`, now exported, which is true while one of the SDK's fields has the keyboard.

- **A model's answer in the notation, with a design system** (guide chapter 18): `UiSession(designSystem: ...)`,
  `notationInstructions({blocks})`, `applyNotation(text, {prelude})` (looks written as the design system's token
  names, so the same answer takes another theme or dark mode unchanged), and `addBlock(definition)`, which gives a
  running session a block designed after it began.
- **Blocks designed while a session runs** (guide chapter 18, `examples/on_demand_blocks`):
  `notationInstructions(askForBlocks: true)` has the model name a block where none fits; `UiSession.wantedBlocks`
  holds what it asked for; `OnDemandBlocks` takes each request to a designer the host supplies, keeps a design
  only when it is a component of that name, of node types the session has, calling no cycle, and passes the
  validator and the check the host gives,
  and adds it with `UiSession.addBlock`; `applyNotation(text, replace: true)` puts the card written again in
  place of the old one. `OnDemandBlocks.mostlyPlainParts` and `shownProblems()` are a host's two other signals.
- **`UiSession.shownDiagnostics()` reports `content_overflows`** (a warning): a child of a row or a column that
  reaches more than a pixel past its right or bottom edge, unless it is under a scroller or a transform.
- **`isTyping()`** is exported: whether one of the SDK's text fields has the keyboard.
- **Render tool**: `--design-system <folder>` renders one document with a design system's blocks and theme;
  `--dump-layout` writes the label a button or chip draws as its text.
- **`edgeFade`** on scrolling containers and page views: content fades out at an edge it continues past, by
  scroll position, on any background.
- **A block's children show as they arrive** in a streamed answer (a card frame filled line by line stayed empty
  until the view was rebuilt).
- **`UiSession.shownDiagnostics()` reports `value_not_computed`**: a text with a gap where a computed value came
  out as nothing.
- The render tool's `--dump-layout` carries the text each node shows. `tool/values/check.py` uses it to test the
  values a generated card shows after it is used.
- The `cards` design system (43 blocks for inline chat cards), the showcase, and blocks designed on demand
  (`examples/showcase/on-demand`).

- **A checkbox, radio or switch draws its `label`** beside the mark (8 px away, centered on it, the control hugging
  both); a tap anywhere on it toggles. A list tile no longer draws a hairline of its own: a list draws the dividers
  between its rows (`separator`).

**Tell the model when its valid UI shows nothing.** Final frames of recorded SSUI generations
(tool/stream/streams/live/2026-11-14-ssui) showed blank cards or cards missing their content while the summary's
final validation was clean. The causes, and what changed:

- `UiSession.shownDiagnostics()`: once a view has laid the UI out, what a reader would see wrong, as edit diagnostics
  a host adds to the stream's result (`result.withDiagnostics(session.shownDiagnostics())`): `empty_view` (no canvas
  root, or a canvas showing no text, icon, image or control, with why), `list_empty` (data that is not a list, no item
  template, or empty while the list it reads is not, with the lambda to write), `empty_label`,
  `expression_not_evaluated`, `text_no_color` (also a transparent color), `component_empty`, and `no_size`. Views
  register the check with `attachShownProbe`. The text checks are shared with the render command
  (`paragraphIssues`). The chat example adds them to every reply's result; replays report them in `metrics.json`
  (`shownDiagnostics`).
- A bound value that names a theme color or text style resolves against the theme: the reservation card's day
  labels were bound to `{'from': 'caption', 'color': 'onPrimary'}` and drew transparent (empty day buttons).
- The formula parser runs without Flutter (`formula_time.dart` holds `ClockTick` and the pinned time;
  `FormulaClock.pinned` forwards to it), and `FormulaEvaluator.report` is what `ValidateOptions.formulas` takes.
  The chat example's sessions and the recorder (`record_check.dart`, Dart VM) now check formulas with it, and the
  recorder reports references unresolved at the end of a stream (`unresolvedReferences`), so the formula errors reach
  the model.
- A formula that does not parse because it is written as JavaScript (`x.toFixed(2)`, `s.trim().toUpperCase()`,
  `list.map(...)`, `function (s) { return ... }`) says what to write instead (`fixed(x, 2)`, `upper(trim(s))`,
  `map(list, x => ...)`, an arrow lambda): a recorded order summary failed three turns on 'Unexpected "(" at 38'.
- `tool/stream/live_summary.py` names each cell's final frame (its last retry's replay) and what that frame shows
  wrong: the frames read as blank were often a first turn whose retry had fixed it.
- The chat example's prompts are regenerated (the design system's scales as the binding to write).

- **Tab bars, navigation bars and the app bar as render objects (Milestone 3, WS-F).** `tabBar`, `tabs`,
  `navigationBar`, `bottomNavigationBar` and `appBar` no longer host Material's `TabBar`, `NavigationBar`,
  `BottomNavigationBar`, `BottomAppBar`, `AppBar` or a `Scaffold` (render/controls/{tab_bar,navigation_bar,app_bar}.dart).
  With nothing styled a tab bar is SSUI's Tabs (36 high when it hugs, pixel-identical to the component), a navigation
  bar SSUI's tab bar (about 61 high when it hugs), the app bar SSUI's top bar (44). The indicator moves between items
  over 150 ms; Left/Right/Home/End move the keyboard, Enter/Space pick; tabs scroll when they overflow; picking fires
  `changed` with the index, written back to a bound `initialIndex` / `selectedIndex`. Size changes: a hugging tab bar
  is 36 (was Material's tab height), a hugging or unsized navigation bar about 61 (was its design size), an
  unsized control of these types hugs instead of being 0 × 0; fixed sizes are kept. A canvas's app bar and bottom
  bar grow by the view's safe area (read from the view, not MediaQuery).
- **Date and time pickers are render objects (Milestone 3, workstream G).** `datePicker`, `timePicker` and
  `dateTimeInput` draw SSUI's select field (28 high when they hug; calendar or clock icon, value, chevron) and open in
  the root's overlay layer: a popover under the field on a screen 600 or wider, else a bottom sheet; a tap outside or
  Escape closes it. Dates in SSUI's calendar (month and year navigation, the range, today ringed, arrows, Page Up/Down,
  Home/End, Enter), times in hour/minute (and AM/PM) columns; month and day names and the first weekday are the
  platform locale's (intl, no Material localizations); today follows the formulas' clock (`--now`). An empty picker
  shows its hint or "Select date" instead of today's date. No `showDatePicker`/`showTimePicker` and no Material
  dialog: the picker islands in `widgets/inputs.dart` are gone. Size changes: an unstyled hugging picker is 28 high; a `dateTimeInput` takes its node's size (the island ignored
  it: the pickers sample's parity golden is re-pinned to the nodes' own 300 × 56).
- The `dropdown` is a render object (`render/controls/dropdown.dart`, Milestone 3 WS-B): SSUI's Select on the field
  frame (28 high when it hugs, `primaryBackground`, hairline, radius 7, Lucide chevron in `tertiaryText` turned over
  while open, the value optically centered) opening its menu (`render/controls/menu.dart`) as an entry of the root's
  overlay layer: under the field or above it when there is no room, at least its width (120 at least), 240 high at
  most and scrolling, SSUI's surface (`level3`, hairline, 4 px inset, 28 px rows, the selected row tinted with a
  check). A press outside or Escape closes it and the field keeps the focus; Enter, Space and the arrows open it,
  arrows, Home/End, Page Up/Down and type-ahead move, Enter and Space choose (`changed`, written back). Screen readers
  get a button with its value and expanded state and the rows as buttons. No Material arrow, card, route, ripple or
  elevation. The popup layer (`ControlPopup`: barrier, placement, dismissal) is for dialogs and sheets to reuse.
  Matches SSUI's own Select to 0.77 % (light) and 0.73 % (dark) of the pixels (`test/controls/ssui_select_reference_test.dart`).
  A dropdown that hugs its height is 28 high (was 48; `isDense` 24: the `samples-inputs` parity goldens re-pinned), and
  one that hugs its width is as wide as its widest item plus the chevron and padding; `isDense` and `isExpanded` no longer change its size; `elevation` maps to SSUI's shadow levels.

**A list that filtered to nothing, explained.** A recorded SSUI data table (data_table@claude-sonnet-5-5) showed
"No results" over twelve defined invoices: its `filtered` variable was `filter(invoices, (statusF == 'All' || status ==
statusF) && contains(lower(cust), lower(search)))`, a condition without its item (computed once, outside the list,
and matching no item). The formula engine is right; nothing told the model.

- `textField` is a render object (Milestone 3, WS-A): SSUI's field frame (`render/controls/field_frame.dart`: label
  above, never floating; hint in the text's metrics; helper and error below in the theme's `error`, a named role
  included; border, focus and disabled from tokens; 240 × 28 when it hugs) around `RenderEditable`, edited without
  `EditableText` (`render/controls/editable.dart`: text input connection with IME composition, keyboard and pointer
  selection, clipboard, undo/redo, obscuring, `maxLength`, autofill per form, semantics). Tab reaches it from
  render-object controls. `TextFieldHandle.controller` is now the field's `FieldEditor` and `focusNode` its
  `ControlFocusNode`; the text field island is gone from `widgets/inputs.dart`.
- Milestone 3, kit follow-up and workstreams C and I: every render-object control's state changes (hover, press,
  focus, selected, disabled) ease over SSUI's 150 ms (`durations.control`, ease-out) on its own ticker; a control
  node with no layout hugs (a column of zero-prop buttons lays out on the scale); buttons take `loading` (SSUI's
  spinner in the icon's place, presses ignored, busy to screen readers); chips (`chip`, `actionChip`, `choiceChip`,
  `filterChip`, `inputChip`) and `badge` are render objects in SSUI's look (render/controls/chips.dart; the check
  mark's room kept, an input chip's x fires `deleted`), 0.00 % from soft_saas_ui's own; `circularProgressIndicator`
  and `activityIndicator` are render objects on their own ticker (render/controls/spinner.dart) and no file imports
  Cupertino. Parity goldens re-pinned for the new look: samples-material/chips and fab_badge.
- `UiSession.applyStream` reports, when the stream ends, the references it accepted as warnings while the stream ran
  and that never arrived (codelessly_api's `unresolvedReferences`): an `unknown_name` in a computed variable's
  formula or a binding is an error in the result, with the lambda to write when the name is a field of a list's
  records. The warnings it replaces are dropped.
- `tool/stream/replay.sh --dump-document` writes `document.json` (the document when the stream ended) and
  `state.json` (`UiSession.values`).
- Tests: the reference's filter, sort and page example works as it says (`test/lists/filter_sort_page_example_test.dart`);
  the recording's end-of-stream errors (`test/session/ui_session_list_formula_test.dart`).
- A session without a design system draws its gauges and charts in its theme: the colors they leave unset
  (indicator_theme.dart) come from the theme the tree reads from its component registry, and only a session with a
  design system had one, so a plain session's (`UiSession(theme:)`) were always the neutral set. Every session's view
  now has a registry (empty without a design system), so a site, a session with a design system and a plain session
  take the same path (`test/session/session_indicator_theme_test.dart`). With no theme they are the neutral ink and
  greys, as before.

- **Toggles, slider and segmented button are render objects** (Milestone 3, WS-E). `checkbox`, `switch`, `radio`
  (`render/controls/toggles.dart`), `slider` (`slider.dart`) and `segmentedButton` (`segmented.dart`) draw with no
  Material widget; their islands (`widgets/inputs.dart`, `inputs_toggle.dart`, `slider_paint.dart`, the slider
  shapes in `inputs_shapes.dart`) are gone. With nothing styled each is SSUI's control: a 16 px checkbox and radio,
  a 36 × 20 switch whose thumb eases over 150 ms, a 200 × 28 slider with a 6 px rail and a ringed 14 px thumb (no
  shadow), and SSUI's segmented well with each label measured centered in its segment. Values write back through
  `changed` and follow their bindings; tristate checkboxes; radio groups with arrow keys; slider drag, tap, arrows,
  Page Up/Down and Home/End, its value indicator in the root's overlay and its custom paint between its parts;
  segmented tap and arrow keys, single and multi select; checked, toggled, slider (increase/decrease) and
  per-segment semantics. Size changes: hugging toggles and segmented buttons were 0 × 0 or Material-sized and are
  now SSUI's; a sized one keeps the islands' proportions (checkbox box 18/40, radio ring 18/32, switch track 52/59
  of the node). Looks dropped as Material-only: the off thumb shrinking on a plain switch, the segmented check mark
  (a set `selectedIcon` still shows), the slider thumb's shadow and default tick dots. Matched against
  soft_saas_ui's own controls (`ssui-toggles-*.png`) within 0.6 % (toggles), 0.1 % (sliders), 0 % (segmented).

- **Milestone 3 begins: buttons are render objects** (codelessly_api `docs/design/11-no-widgets.md`).
  `filledButton`, `elevatedButton`, `outlinedButton`, `textButton`, `iconButton` and `floatingActionButton` are drawn
  by `RenderButton` (`lib/src/render/controls/buttons.dart`) with no Material widget in their path. With nothing
  styled each is SSUI's button: filled = primary, tonal = tertiary, elevated, outlined = outline, text = ghost, icon
  button = SSUI's ghost icon button, a floating action button = primary with SSUI's floating shadow. A hugging button
  is 28 px high (SSUI's compact); a sized one takes the padding, font, icon size and radius of the nearest step of
  the control scale (24/28/32/36/44). Hover and press are SSUI's faint overlays, focus its 1.5 px ring (keyboard
  only), disabled 50 % opacity; a bound `selected` draws SSUI's active tint with primary ink. Every `ButtonStyle`
  field, the node's padding and its `states` patches still apply. The zero-prop page matches SSUI's own widgets to
  0.06 % of the pixels (`test/controls/ssui_reference_test.dart`; renders in
  `design_systems/ssui/examples/renders/m3`).
- **List tiles, accordions and expansion tiles are render objects** (Milestone 3, workstream D).
  `listTile` is `RenderListTile`, `accordion` and `expansionTile` are `RenderExpansion`
  (`lib/src/render/controls/{tile,expansion}.dart`); the `ListTile`, `ExpansionTile` and the accordion's Material
  toggle button are gone. With nothing styled a list tile is SSUI's ListRow (36 high, 28 dense, 12 × 6 padding, 10
  between its slots, no divider of its own (a list draws them: `separator`), `activeTint` when selected) and an accordion is SSUI's
  Accordion (a `tertiaryBackground` header panel, 1 px `primaryBorder`, radius 8, SSUI's chevron turning down as it
  opens, the content in a `primaryBackground` panel); an expansion tile's header is its `tile` slot's slots laid out
  as a list tile, with the chevron and `primaryBorder` hairlines while open. The slots and content are nodes laid out
  by the tree. The whole header is the tap target (it was a 48 px button over the header's end); Tab focuses it with
  SSUI's ring, Enter and Space toggle it; the content opens and closes over SSUI's 150 ms ease on the tree's ticker,
  clipped while it moves; screen readers hear a button, expanded or collapsed. A toggle fires the node's `click`, then
  `changed` with the new state; a list tile with a `click` reaction takes focus and the hand cursor. On a design
  canvas an expansion tile is drawn as it is (it was a placeholder). Zero-prop pages match SSUI's own Accordion and
  its ListRow to 0.00 % of the pixels (`test/controls/tile_reference_test.dart`). Size changes: a hugging list tile
  takes its content's size (it was its design size, often 0 × 0); a hugging accordion's header is 46 px high (SSUI's). Parity goldens re-pinned
  (`samples-collections/controls`, the accordion page): the header child sits 16 px inside SSUI's 1 px border and is
  as wide as the room beside the chevron (row `rc17` 300×64 at (20, 38) → 238×64 at (37, 33), its text `t18` with
  it), the content starts under the 46 px header in a 16 px panel (`r20` y 102 → 127), and the collapsed one's header
  child moves the same way (`r22` (20, 303) → (37, 273)). The `listTile` layout test now expects its slots centered on
  the tile (36 in a 72 px tile), not on Material's 56 px row.
- **Size changes of buttons** (parity goldens): a hugging button is 28 high (Material's was 40); the icon beside a
  label is SSUI's (14–18) with a 6 px gap (Material's 18 and 8), so labeled buttons with an icon are 2 px narrower.
  `samples-material/buttons`: `elev_hug` 186×39 → 184×38.6, `filled_hug` 184 → 182 wide, `text_icon` 118 → 116
  wide. The `static` set goes from 99.06 % to 98.84 % of rects within 1 px: six filled buttons of one fixture 2 px
  narrower (one squeezed by its column from 40 to 37.3 high) and the 43 rects beside them that move with them.
- The control kit (`lib/src/render/controls`): `RenderControl` (states, tap, hover and cursor, focus, activation,
  semantics, a 44 × 44 touch target by hit testing only), `ControlLabel` (one line, glyphs centered), `ControlTokens`
  (SSUI's tokens bundled as data, `ssui_defaults.g.dart`, written by `tool/controls/bundle_ssui.dart` and checked
  against `design_systems/ssui/design_system.json`, the document's theme over them, for the screen's brightness and
  backdrop), `ControlFocusNode`/`ControlFocusScope` (Tab and Shift-Tab in reading order, Enter, Numpad Enter and
  Space activate, Escape, `autofocus`), and the root `RenderControlRoot` with an overlay layer.
- `NodeView` is the adapter: its render object (`RenderNodeView`) is now a `RenderControlRoot`; it feeds key events
  from `FocusManager`'s early handlers (or `HardwareKeyboard` when nothing has Flutter's focus) and bridges the two
  focuses. A document of buttons lays out, paints, hit-tests and takes the keyboard with no `MaterialApp`,
  `WidgetsApp`, `Theme` or `Overlay` above it (`test/controls/root_test.dart`); `attachRoot` shows a root in a view
  with no widget at all (`test/controls/direct_attach_test.dart`).
- The `tooltip` behavior (declared, never drawn before) shows SSUI's tooltip in the root's overlay layer after the
  theme's `durations.tooltipDelay` of hovering, and names the node to screen readers.
- `RenderTree.theme` and `RenderTree.dark`: the theme and brightness controls draw with (`CodelesslyWidget` sets the
  mode).
- Theme roles that name a theme color (`"primary": "forest"`) now reach controls, dialogs and toasts (they drew
  black or white).
- `test/architecture_test.dart` keeps a ratchet of the files that may import `material.dart`, `cupertino.dart` or
  `widgets.dart` (60 at the start); it only shrinks, and the render-object controls are never on it. The look guard
  measures labels and fonts of render-object controls too (`LabeledControl`).
- Island controls not yet moved (chips, fields, toggles, pickers, tabs, bars, tiles) are unchanged and still draw
  their neutral look.

**What ten sites built as data (brief 3) ran into.**

- Text inside an SVG image is drawn in the site's fonts: a generic family (`sans-serif`, `monospace`) and text with
  no family take the theme's `fontFamily`, a named family is asked for as a text style's is with the theme's font as
  its fallback, and the picture is recorded once they load (in the render command it was drawn as solid blocks).
  The render command names the SVG in `font_fallback` when a family is not had.
- `navigate` evaluates a `to` (and `base`) built by a binding (`${item.to}`): it threw "no such screen".
- A canvas opened as a modal takes the size its media rules give it at the screen's width (the patch was ignored).
- A `lineChart` with no `axisLabelStyle` color draws its tick labels and axis title in the axis color (they were
  white).
- `gridView.fillGaps` (CSS `grid-auto-flow: dense`).
- `VariableAnimator.anyPlaying`: whether a number variable's timeline plays anywhere.
- Render command:
  - every run first prints the SDK and API versions, commits and paths it uses; Flutter is looked for in the usual
    install places too, and when none is found the message says to set `FLUTTER=/path/to/flutter/bin/flutter` and
    that the tool and reference are on `master`;
  - a step on a component's node (by its path) hidden at a size is skipped there, and a skip is its own warning,
    `step_skipped`, not `interaction_failed`;
  - `--hover` at several sizes no longer crashes the harness (Flutter's mouse tracker assertion);
  - full-page captures draw an open dropdown menu or toast once, in the first window, and a page whose content
    changes height once it scrolls (a header compacting on scroll) is stitched without a doubled line at a seam;
  - `--type` names the one node with a text field among nodes sharing an id;
  - a page `site.json` lists but not written yet is one `page_not_written` warning per file, not `unknown_screen`
    errors;
  - counters animated in a load reaction (one after another) are captured where they end;
  - image paths are relative to the site's folder in every document, components included (the README said the
    document's), and a path written from a component's folder is reported with the path to write;
  - a variable font declared once counts as having every weight of its `wght` axis (no `font_fallback`);
  - a flex overflow names the list copy that overflows and says what its content needs and what to change.
- Skipped tests for the controls engineer: invalid form fields vanish when the theme's `error` role names a theme
  color (`test/tool/form_named_error_role_test.dart`); an empty `datePicker` shows today's date
  (`test/tool/date_picker_empty_test.dart`).

**Generative UI with a design system, recorded and replayed.**

- `UiSession(designSystem:)` allows the design system's components under the session's trust profile
  (`TrustProfile.withComponents`): with the default `TrustProfile.agent` every call to one was
  `capability_not_allowed`, so a model's design-system UI never applied.
- A session's theme names (`"color": "primaryBackground"`, `"style": "sectionTitle"`) resolve in its own nodes in
  light mode: `ThemedSource` started with no names and was only given the theme when the mode changed, so they
  resolved in dark only (components' names did resolve).
- A component call that streams in after its parent shows (a pending child that arrives as a call, or a set that
  changes a node's type to one) renders as its definition: its parent places its children again
  (`NodeBox._becameCall`). It drew as the empty box of an unknown type.
- The stream replay (`tool/stream/replay.sh`) replays a recording with the design system its meta names (or
  `--design-system`), in light or `--theme dark`, and reports `designSystem` (component calls rendered and not,
  core controls the design system replaces) in `metrics.json`. `examples/stream_chat/tool/record.dart
  --design-system ssui` records with one (prompt, `ui_docs`, per-op validation and retries), `record_all.sh` gains
  `--design-system <id>` and `--only ssui`, and the live summary has the design system per cell and its components
  against the raw controls it replaces.

**Fixes.**

- Gauges, charts and barcodes drawn with the theme's colors (the ones they leave unset, `indicator_theme.dart`)
  repaint when the theme changes at run time (`setThemeMode`, the platform's brightness under `system`): the box
  notes it depends on the theme (`RenderTree.dependOnTheme`) and a theme change (`ComponentRegistry.theme`,
  `themeChanged`) re-applies it. Before, only nodes naming theme colors re-applied, so an unstyled gauge kept the
  old mode's colors.
- The render command with no `--screen` no longer renders a canvas only ever opened as a modal as a screen of its
  own, whether the `openModal` is on a page or inside a component (the site's or its design system's).
- An image whose path a binding builds (`"bind": {"decoration.fills[0].image.url": "images/${id}.jpg"}`), relative
  to the site, is read from the site's files when it is drawn: the app's tree reads site images through
  `SiteImageLoader` (the loader's file URL, else its bytes), and a raster image whose URL has no scheme is fetched by
  the tree's loader instead of `NetworkImage`. Literal paths were already resolved when the layout loads.
- A theme's `fontFamily` is the default family of every text, as it is the controls' (Flutter: the `DefaultTextStyle`
  an app's theme gives): a text node with no family (and no `defaultTextStyle` above it naming one) is drawn in it,
  in a site (`CodelesslyWidget`) and in a session (`CodelesslyView`). `RenderTree.textDefault` holds it under every
  node's inherited default text style. Before, controls took the theme's font and text nodes the platform's. No
  parity golden or render test changed.
- The render command waits for its own font fetches still in flight before its runtime checks: a family asked for by
  name late (named by a binding, so no layout lists it, its file slow to read) was measured in the fallback, so
  `text_clipped` was reported for text the PNG drew in the real font. `DirectoryFontFetcher.debugLatency` simulates a
  slow source in tests.
- A `dateTimeInput`, `datePicker` or `timePicker` whose width hugs takes its content's width (`IntrinsicWidth`), as a
  `textField` and a `dropdown` already did: in a wrapping row it took the row's whole width, and in a plain row it
  failed (an unbounded `InputDecorator`). A picker's field reads its constraints only when its height fills.

## 30.1.0

**No special cases left** (with codelessly_api's unreleased removal of the last 21 one-look fields, each now a
general mechanism; its CHANGELOG has the table). The renderer no longer reads them:

| Removed | Drawn now by | SDK |
|---|---|---|
| text `countUp`, `countUpDuration`, `countUpCurve`, `countUpOnShow` | a transition and an animation of `props.text` | `RenderCountUpParagraph` (count_up.dart) is gone: a transition or track on a text prop counts the number in it (`RenderAnimations`, `isTextPath`); an animated text re-applies instead of retexting in place, so its player sees each change |
| slider ruler ticks, marker, `activeTrackStartOpacity`, `thumbGripColor` | the slider's `customPaint` | a slider draws its node's custom paint between its parts (slider_paint.dart): `painter` over the track and under the thumb, `foregroundPainter` over the thumb, reading `size` and `slider` (`value`, `min`, `max`, `trackRect`, `thumbCenter`); `RenderCustomPaintLayer.drawnByContent` and `drawFor`. The ruler track draws its strip and fill, the marked track (`fillFromEnd`) its fill, the rectangular thumb its body and border |
| slider `deriveOverlayColorFromThumb` | nothing (it was never read) | — |
| text field `highlightStart`, `highlightEnd`, `highlightStyle` | the field's `runs` | `HighlightTextController.runs`: every run, merged in order over the field's style, as a text node's runs |
| table `selectedRowEdgeColor`, `selectedRowEdgeWidth` | the cell template's `selected` state style | both table renderers draw no edge |
| date/time input `displayFormat` | `format` | formatted with `format` only |

test/migration/special_fields_test.dart draws what the migration makes of a node that used each and matches what
the previous renderer drew from the same node (goldens and recorded texts taken with it): identical; a count, frame
for frame; the slider's fade within one level but for 12 anti-aliased pixels at the track's rounded end (the fade is
now the inactive color laid over the active track). A `ruler` track in a document already at schema 3 draws no
ticks of its own: they are custom paint ops (the migration writes them for a schema-2 document).

- **Radio group: arrow keys move the choice.** Each radio is its own island with its own `RadioGroup`, which saw
  one radio: right and down now choose the next radio of the group in reading order, left and up the previous,
  wrapping at the ends, the focus moving with the choice, as Flutter's `RadioGroup` does.
- **Forms: fields a list repeats inside a form belong to it.** A field published its form's state to its own list
  item's instance, so the form saw only fields in its own instance, and a form a list repeats validated every
  item's fields. A field's form instance is now its instance with the items of lists inside the form left behind:
  each form instance validates and publishes its own fields; `validate` checks the instance of the form around the
  node whose reaction runs it (`FormRegistry.formInstanceOf`, `anyInstance`).
- **A box that hugs both ways and keeps an aspect ratio sizes as `AspectRatio` does** (the widest it may be, else
  the tallest). It took no size while its intrinsic height said its width over the ratio, so in a grid row that
  shrink-wraps it drew nothing in the room the row made for it.

**A site looks like itself: theme mode, declared fonts, local images** (with codelessly_api's unreleased

**Unstyled controls that are not Material's, and design systems as data** (with codelessly_api's unreleased
additions).

- **Shapes.** Without a theme radius, buttons, chips and segmented buttons have a 6 px radius (no stadium);
  dialogs, menus and pickers 8 px with a hairline. A field with no border of its own is outlined (the theme's radius,
  else 6), padded 12, its label above it (always visible) and its hint inside; no underline, no floating label.
  Dropdowns draw the same outline; date and time pickers are plain fields of their node's size (they grew past it
  before) with a calendar or clock icon. Switches have one thumb size and no outline; check boxes a 4 px radius;
  tabs a square underline; a chip is as wide as its content, so its check mark never cuts its label.
- **Controls fit their node.** No 48 px tap-target margin or platform density: a 28 or 32 px node shows the whole
  control, its label centered (segmented buttons take the node's height; fields of a set height center their line;
  pagination centers its buttons). Hugging buttons and chips lose the margin (48 to 35-40 px).
- **Colors from the theme.** Tab bars, pagination, gauges, charts, barcodes and signature pads take the colors
  they leave unset from the theme of what they are drawn on (`indicator_theme.dart`).
- **The guard** (`test/app/no_material_look_test.dart`) also asserts no stadium button, no underline-only field and
  no cut chip label, and measures every labeled control's label centered within 1 px at its default height and
  32 px, in Barlow and Roboto, light and dark.
- **Generated UI with a design system or a theme.** `UiSession(designSystem:, theme:)`: the design system's
  components are node types of its catalog, its tokens (with the app's theme over them) the theme `CodelesslyView`
  resolves named colors and text styles against, reads as `${theme.*}` and draws controls with. A themeless
  session's field text is in the same family as a text node beside it; the stream replay gives its session the
  render command's default family.
- **The render command** reads `site.json`'s `designSystem` (`design_system_missing` when it cannot).
- **`design_systems/ssui`**: Soft SaaS UI as data: its tokens, DESIGN.md, PATTERNS.md, 23 components drawn from
  core nodes (four wrap a styled text field, dropdown or slider), a gallery and three inline cards with raw-control
  counterparts, and their renders.

**Earlier in this release: a site looks like itself: theme mode, declared fonts, local images** (with codelessly_api's unreleased
additions).

- **Theme mode.** `Codelessly.themeMode`, `themeModeChoice` and `setThemeMode(mode, persist:)`: the site's
  `ThemeMode` (a choice over the theme's own `mode`, kept in local storage under `codelessly.themeMode` when
  persisted, so a reload starts in it). Every screen follows it at once: named colors, named text styles, the
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

### Earlier in 30.1.0

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
  is labeled in ink or paper, whichever reads on it; a button's `style.textStyle.color` is its label color when
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
- **Behavior changes:** a track with no value is drawn at its minimum (the `drag_misc` parity golden moves
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
  seam, interaction, slots and events as any component's. **Behavior change:** the island path for plugin
  widgets (`_HostedRecipe`, a fixed-size fit box) is gone; `hostedPluginFeature` returns no recipes.
- Per instance: `setValue` / `setVariant` inside a component instance set that instance's node
  (`RenderTree.setInstanceValue`); slot content inside a list of the definition shows once per item, in the
  caller's scope (`SlotContent`); an instance's scopes are released when it leaves the tree
  (`InstanceBindings.releaseInstance`); `persist` on a component variable is kept per instance path
  (`NodeBinder.persistComponentVariable`, `PersistedVariable.attach(key:)`); a changed declaration decodes the
  loaded layouts that call it again. **Behavior change (bug fix):** set value inside an instance changed the
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
- Icon `size`: the glyph at that size, centered in the node's box; a hugging icon takes it.
- Actions naming a node from inside a component instance (`scrollTo`, `animate`, `focus`, `editText`) act on that
  instance's node. **Behavior change (bug fix):** they acted on every instance's (or none).
- A node written `visible: false` whose media rule binds `visible` collapses when hidden.
- `RenderFitBox.designWidthUsed` / `designHeightUsed`: a fill laid out with no room took its design size.
- Render command: `fill_fallback` (a fill whose size came from its design number, naming the parent and the fix);
  diagnostics find a node's parent in its own document and name component nodes by path (no more false
  `layout_overflow` when a page and a component share an id); `--full-page` captures the whole page while the
  window keeps its size (**behavior change:** `screen.height` and anything pinned to the window's top and bottom
  are no longer stretched to the page; page content is unchanged), and `--dump-layout` reports boxes where the PNG
  draws them; `--unfocus`, `--key`; `--compare` (side-by-side and diff images, bands, height difference); of a
  font package's subset files the one with Latin text's characters is served; the site manifest's theme is
  validated, published and its fonts loaded.

**Authoring fixes from the second direct-authoring experiment (cycle 2)**
