# UI SDK behavior inventory, compared with Codelessly

Date: 2026-11-16. Read-only research; nothing was installed, run or changed in any repository.

## 0. Summary

- **Their primary sources were reached.** Repo `github.com/vercel-labs/ui` at commit `6efa592053` (2026-11-16), `@ui-sdk/core` 0.1.0-beta.5; site `ui-sdk.dev` (docs navigation, `llms.txt`); the skill file `packages/core/skills/ui-sdk/SKILL.md`.
- **Real counts.**
  - The "All Behaviors" docs page lists **134 helpers** in 15 headings (plus a 16th, "Values and Testing", with no helpers). The secondhand "50+ behaviors" is the launch post's own phrase ("We built more than 50 of them"); the count depends on whether small helpers (`reorderMessage`, `popupArrow`) are counted.
  - The docs sidebar group "Behaviors" has **10 category pages**, from "Focus and Keys" to "Canvas" (confirmed). Those 10 pages hold 91 of the 134 helpers; the other 43 are under Text, Platform, Changes and History, Building Blocks and Agents.
  - `packages/core/src/components/` has **51 component modules** (confirmed). The React docs have **55 component pages**: the 51 plus Alert Dialog, Textarea, Time Input and Preferences (which live inside other modules).
  - The secondhand names were all confirmed: `createRovingFocus`, `createTypeahead`, `createPopup`, `createSelection`, `createReorder`, `createResize`, `createViewport`, `createVirtualizer`, `createFocusRecovery`; Select, Combobox, Date Picker, Menu, Tree, Color Picker.
- **Comparison totals** (70 behavior rows, sub-helpers grouped under their behavior, plus 55 component rows = 125):

| Status | Behaviors | Components | Total |
|---|---|---|---|
| HAVE | 17 | 26 | 43 |
| MODEL ONLY | 11 | 1 | 12 |
| DESIGN SYSTEM ONLY | 1 | 9 | 10 |
| PARTIAL | 16 | 10 | 26 |
| IN PROGRESS | 0 | 1 | 1 |
| MISSING | 20 | 8 | 28 |
| NOT APPLICABLE | 5 | 0 | 5 |

- **The one finding that matters most.** Codelessly's own controls (button, dropdown, slider, tab bar, segmented button, radio, calendar, time dial, text field) are keyboard-driven and described to screen readers; that part is in good shape. The gap is everything **composed**: a node with a click reaction (`Box onTap={action}`, and so the design-system blocks built from boxes: a link, a sidebar line, a menu row, a card tile) is announced as a button but is **not in the Tab order and does not answer Enter or Space**, because only kit controls and `track` create a focus node (`CodelesslySDK/lib/src/render/controls/kit.dart:34`, `render/drag_track.dart:1053`; the click semantics are at `runtime/actions/wiring.dart:613-621`). The overlays the notation writes (Dialog, Sheet, Drawer, Menu, Popover) open and dismiss, but nothing was found that moves focus into them, keeps Tab inside, or returns focus to the opener. Their library's core idea (one shared behavior fixes many controls) applies directly: four shared behaviors (focusable press target, roving group with type-ahead, modal focus scope, listbox highlight) would close most of the PARTIAL rows.

**How statuses were checked.** Codelessly claims were checked by reading the reference pages and the renderer source (file and line given). Nothing was run, so "HAVE" for keyboard handling means "the key handler and the semantics flags are in the code", not "tested with a screen reader". Where a claim was not read in code it says "not checked".

---

## 1. Their inventory

### 1.1 Sources

| What | Where | Used for |
|---|---|---|
| All Behaviors index | `apps/docs/content/docs/core/behaviors/index.mdx` (= ui-sdk.dev/docs/core/behaviors) | the 134 helpers, their headings and one-line descriptions (quoted in the tables below) |
| Category pages | `apps/docs/content/docs/core/behaviors/{focus,selection,drag-and-drop,direct-manipulation,lists,trees,motion,popups,preferences,canvas}.mdx` | keyboard, pointer and ARIA contracts (section headings and demo captions) |
| Category order | `apps/docs/content/docs/core/behaviors/meta.json` | the 10 categories |
| Docs sidebar | ui-sdk.dev/docs | groups: Overview, Core, Utilities (Text, Numbers, Dates, Colors, Images, Storage, Platform, Mobile), Behaviors (10), Tools (Observe, Testing) |
| Source tree | GitHub tree API, `packages/core/src/{foundation,components,page}` | module lists; 51 component directories |
| Launch post | `apps/docs/content/docs/core/changelog/introducing-ui-sdk.mdx`, dated 2026-11-12 | "more than 50" behaviors, "more than 50 ready-made components" |
| Skill | `packages/core/skills/ui-sdk/SKILL.md`, `references/build-interface.md`, `references/patterns.md` | the "need → component" table; what they tell agents |
| llms.txt | ui-sdk.dev/llms.txt | index of per-framework docs (Core, Agents, Guides, React, Vue, Svelte, Solid, Web Components) |

Packages: `@ui-sdk/core`, `@ui-sdk/react`, `@ui-sdk/vue`, `@ui-sdk/svelte`, `@ui-sdk/solid`, `@ui-sdk/web`. Beta.

What their pages tell an agent to do (reported, not followed): the Get Started page gives a setup prompt that installs `@ui-sdk/core` and a framework package and adds notes to AGENTS.md; the README suggests `npx skills@latest add vercel-labs/ui --skill ui-sdk`; the skill says to read the installed docs, not compiled JS, and "Don't hand-roll what we ship" (a `div` with `role="listbox"`, `"menu"`, `"dialog"`, `"tablist"`... next to their package "is almost always a bug").

### 1.2 Behaviors (the 134 helpers, as they group them)

Contract column: from the category page's text and demo captions.

**Focus and Keys (9)**

| Helper | What it does (their words) | Contract |
|---|---|---|
| `createRovingFocus` | Gives a group one Tab stop and moves focus with the arrow keys. | Tab enters and leaves the group; Left/Right or Up/Down, Home, End; optional wrap; arrows follow text direction; disabled items stay focusable (`aria-disabled`); remembers last item; custom `move` for any layout or a ring |
| `createGridFocus` | Moves focus by row and column, including cells that aren't rendered yet. | `role="grid"`/`row`; arrows; Home/End row ends, Ctrl/Cmd+Home/End grid corners; skips disabled cells; Shift reported for range; works with virtualized rows |
| `byCell` | Updates only the cell focus leaves and the cell it lands on. | performance helper |
| `spatialMove` | Chooses the next item from its position on screen. | arrows by geometry (Left is left on screen even in RTL) |
| `nearestInDirection` | Finds the nearest item in a direction without moving focus. | query only |
| `createTypeahead` | Finds an item as someone types its name. | printable keys build a buffer, match by label |
| `createFocusRecovery` | Restores focus when the focused item is removed. | focus goes to a neighbor or a fallback |
| `keepFocus` | Preserves focus through a change that moves an element. | e.g. a task moved between lists keeps focus |
| `inputHints` | Picks the on-screen keyboard and autofill for a kind of field. | `inputmode`, `autocomplete`, etc. |

**Text (7 + Search Matching 3)**

| Helper | What it does |
|---|---|
| `createInputHistory` | Brings back earlier entries with ArrowUp and ArrowDown, like a terminal. |
| `isTypeaheadKey` | Checks whether a key can be used for typeahead. |
| `labelOf` | Reads an element's label for matching typed text. |
| `isComposing` | Checks whether an input event is part of text that's still being composed (IME). |
| `pageLocale`, `userLocale`, `toLocale` | The page's language, the browser's, and tag conversion for `Intl`. |
| `fuzzyScore` | Scores how well a piece of text matches what someone typed. |
| `matchRanges`, `matchSegments` | Where the typed text appears; split into matched and unmatched pieces to render (highlighting). |

**Selection (7)**

| Helper | What it does | Contract |
|---|---|---|
| `createSelection` | Tracks selected items, including multiple selections and ranges. | click/Space choose or toggle; Shift-click and Shift+arrows extend from an anchor; Ctrl/Cmd-click toggles one; select all; unselectable items; `aria-selected`, `aria-multiselectable` |
| `createLasso` | Selects items touched by a rectangle drawn with the pointer. | drag from empty space; Shift adds; Escape cancels |
| `createCellRange` | Selects a rectangular range of grid cells. | drag or Shift+arrows; Shift+Space rows, Ctrl+Space columns, Escape clears; `aria-selected`, `data-range-edge` |
| `byCellRange`, `cellRangeMessage` | Partial updates; default announcements. | |
| `cellsToText`, `textToCells` | Copy and paste of cell blocks as text. | |

**Drag and Drop (12)**

| Helper | What it does | Contract |
|---|---|---|
| `bindDrag` | Tracks a pointer drag with capture, thresholds, and cancellation. | Escape during a drag restores; keyboard Left/Right on a divider; pointer lock for unbounded drags |
| `dragThreshold` | Sets the standard drag threshold to 3 pixels. | |
| `createReorder` | Reorders a list or grid with the pointer or keyboard. | Space/Enter picks up, arrows move, Space/Enter drops, Escape cancels; grids; several items at once; pinned items; move from code |
| `createTreeReorder` | Reorders and nests tree items with their descendants. | Up/Down place, Left/Right change level; depth limits |
| `createTransfer` | Moves items within or between lists. | Left/Right change list, Up/Down place; rules (limits, locked items): a board |
| `bindDragPreview` | Shows a copy of the dragged element above the page. | |
| `createAutoScroll` | Scrolls a container when a drag approaches its edge. | |
| `settleDraft` | Keeps a draft visible while a controlled value catches up. | |
| `reorderMessage`, `treeReorderMessage`, `transferMessage` | Default screen-reader announcements. | |
| `subtreeEnd` | Finds the first row index after a subtree. | |

**Dragging and Resizing (13)**

| Helper | What it does | Contract |
|---|---|---|
| `createMove` | Moves freely positioned objects with the pointer or keyboard. | drag; Alt+arrow nudges, Shift ×10; Escape puts it back; groups; zoom-aware |
| `createResize` | Resizes boxes from their edges and corners. | handles; arrows on a focused handle, Shift larger; aspect lock; Escape cancels |
| `createSwipeActions` | Reveals actions behind a row and supports full-swipe actions. | swipe; keyboard Left reaches the action, Escape closes; drag to dismiss |
| `bindHold` | Runs an action once a press is held, and can repeat it while held. | hold to confirm; hold Space from the keyboard |
| `bindRepeat` | Steps once when a button is pressed, and keeps stepping while held. | |
| `createArea` | Picks a value along two axes, such as a point on a pad. | drag; arrows on the thumb, Shift larger |
| `createSpans` | Draws, moves, and resizes ranges on tracks. | bookings on a timeline, calendar events; snapping; no overlap |
| `stackSpans`, `isSpanFree` | Lanes for overlapping ranges; overlap check. | |
| `createPreview` | Tracks a value being tried before it is chosen. | press and slide, hover, arrows preview; Enter chooses, Escape clears |
| `moveMessage`, `resizeMessage`, `spansMessage` | Default announcements. | |

**Lists (5)**

| Helper | What it does | Contract |
|---|---|---|
| `createListbox` | Highlights options with the arrow keys, and filters them as someone types. | real focus or `focus: "virtual"` with `aria-activedescendant`; arrows, PageUp/PageDown; `onEnd` to load more |
| `createVirtualizer` | Calculates which rows to render and where to place them. | fixed or measured heights, horizontal, jump to index, load more, `aria-setsize`/`aria-posinset`; keeps browser find-in-page working over unrendered rows |
| `createStickToBottom` | Follows new content while preserving the reader's place when they scroll up. | `role="log"` |
| `bindScrollPicker` | Picks the option at the center of a scrolling list, like a wheel. | scroll, flick, drag; Up/Down/Home/End; stays a listbox |
| `createInlineEdit` | Manages editing, committing, and canceling a value in place. | Enter or F2 or double-click starts; Enter saves, Escape cancels, Tab saves and moves on; typing a letter starts a replacement; focus restored |

**Trees (6)**

| Helper | What it does |
|---|---|
| `createTreeCollection` | Looks up parents, children, levels, and visible nodes. |
| `treeDataNodes`, `treeFromPaths` | Nested items, or file paths, into tree nodes. |
| `visibleTreeRows` | Flattens open branches into rows with parent, level, and index data. |
| `treeCheckedStates`, `toggleTreeChecked` | Checked, unchecked and mixed states across a tree; the next value on toggle. |

**Transitions and Gestures (6 + Gesture Calculations 5)**

| Helper | What it does |
|---|---|
| `bindPanel` | Coordinates panel height, transitions, and focus when opening or closing. |
| `hiddenAttrs`, `bindFindable`, `supportsHiddenUntilFound` | Hidden content the browser's find-in-page can reveal. |
| `animateIn`, `animateOut` | Enter and exit states for CSS animations; exit completes before removal. |
| `createVelocityTracker`, `projectDistance`, `solveSpring`, `rubberBand` | Velocity from pointer positions, throw distance, spring solver, edge resistance. |
| `sectorOf` | Converts a stroke's direction into a sector, such as a radial menu item. |

**Popups and Layers (16)**

| Helper | What it does | Contract |
|---|---|---|
| `createPopup` | Manages opening, closing, positioning, and focus using a popup preset. | presets: popover, dialog, tooltip, hover card. Opens next to its trigger; closes on Escape or an outside press; "puts focus back where it was"; `dismissible: false`, `onDismissAttempt` with the reason |
| `popupState`, `popupTrigger`, `popupContent`, `popupClose`, `popupSlots` | State and the standard parts. | |
| `popupTitle`, `popupDescription` | Connects a visible title and description to the popup's accessible name. | `aria-labelledby`, `aria-describedby` |
| `popupArrow` | An arrow that follows the popup's placement. | |
| `popupBackdrop` | A backdrop behind a modal popup. | |
| `popupViewport` | A full-screen container for a popup sheet. | sheet modules in source: drag, scroll snap, safe area |
| `position` | Places an element beside an anchor and updates its placement. | side, align, offsets, collision padding, arrow |
| `bindLayer` | Registers a floating element for Escape and outside-press dismissal. | Escape goes to the topmost layer; nested popups count as inside their parent |
| `bindPersistentLayer` | Keeps an element usable across layers, including modal popups. | e.g. toasts over a modal |
| `isDismissal` | Identifies a dismissal reason. | |
| `supportsTopLayer` | Browser top-layer check. | |

Also: popup controllers open existing popups from code and wait for a result.

**Preferences (6 + Storage 3)**

| Helper | What it does |
|---|---|
| `createPreference` | Holds a choice from a list, notifies subscribers, and can save it between visits. |
| `createColorScheme`, `colorSchemeOf`, `preferencesScript` | Light, dark or the browser's scheme; reading it on the server; applying before first paint. |
| `createPointerKind`, `pointerKindOf` | Whether the main pointer is a finger or a mouse, and whether it can hover. |
| `createLocalStorage`, `createSessionStorage`, `createCookieStorage` | Persisted values. |

**Canvas (3)**

| Helper | What it does | Contract |
|---|---|---|
| `createViewport` | Pans and zooms a canvas and converts between screen and canvas coordinates. | drag or scroll to pan; pinch or Ctrl/Cmd+scroll to zoom; `+`, `−`, `0`; fit, reveal the focused item; find-in-page pans to matches |
| `createConnect` | Tracks connections between ports with the pointer or keyboard. | drag port to port; or press C, arrows choose, Enter connects, Escape cancels |
| `connectMessage` | Default announcements. | |

**Outside the 10 category pages (43 helpers)**

| Heading | Helpers |
|---|---|
| Platform (6 + Mobile 2) | `announce`, `prepareAnnouncements` (live regions); `isRTL`; `matchesShortcut`, `formatShortcut`, `ariaKeyshortcuts`; `bindViewport`, `bindAvoidKeyboard` |
| Changes and History (7 + 3) | `createChange`, `createCommit`, `dispatch`, `createUndoStack`, `createController`, `sourceOf`, `isFocusFromKeyboard`; `observe`, `elementOf`, `withSource` |
| Building Blocks (9) | `definePrimitive`, `idPart`, `elements`, `openAttrs`, `checkedAttrs`, `css`, `live`, `selects`, `direct` |
| Agents (3 + History 3) | `createAgent`, `agentTools`, `registerTools` (WebMCP); `createHistory`, `describeEntry`, `stageChanges` |

Source modules in `packages/core/src/foundation/` with no helper in the index (seen in the tree, not read): `disclosure`, `forms` (form, field control, files, text-field, toggle-control), `gauge`, `shortcuts` (create-shortcuts), `motion/snap-points`, `popups/sheet-*`, `popups/hover`, `platform/scrollbar`, `text/text-editor`, `text/caret`, `image/crop`, `number/*`, `date/*`, `color/*`.

### 1.3 Component modules (51 in `packages/core/src/components/`)

accordion, autocomplete, avatar, button, calendar, carousel, checkbox (+ checkbox-group), collapsible, color-picker, combobox, command, date-input (+ time-input), date-picker, dialog (+ alert-dialog), drawer, field (+ field-set), file-input, hover-card, image-cropper, input, label, listbox, menu, menubar, meter, navigation-menu, number-input, otp-input, pagination, password-input, popover, progress, radio, rating, resizable, scroll-area, segmented-control, select, separator, slider, switch, tabs, timeline, toast, toggle (+ toggle-group), token-input, toolbar, tooltip, tree, trigger-menu, waterfall.

Docs pages add: alert-dialog, textarea, time-input, preferences (55 pages).

Which behaviors each composes is **not stated per component** in the pages read; the file names show some of it (`select-keyboard.ts`, `combobox-keyboard.ts`, `navigation-menu-focus.ts`, `carousel-keyboard.ts`, `toast/swipe.ts`, `lists/listbox-popup.ts`). Their skill's "The person needs to → Use" table (`references/build-interface.md`) is the best one-line statement of what each is for and is used in section 2.2. It also names two things they deliberately do **not** ship as components: a seat-style grid (build on `createGridFocus`) and reorder/kanban (build on `createReorder`/`createTransfer`).

---

## 2. The comparison

Paths: `API/` = `C:/Users/searc/Development/CodelesslyEditor/CodelesslyAPI/`, `SDK/` = `.../CodelesslySDK/`, `ref/` = `API/docs/reference/`, `ctl/` = `SDK/lib/src/render/controls/`. "Prompt" = `API/lib/src/core/notation/prompt.dart`. "Cards X" = `SDK/design_systems/cards/components/X.json`.

Priority: **H** common on real pages or blocks keyboard/screen-reader use; **M** regular in apps; **L** specialist.

### 2.1 Behaviors

| # | Their item | What it does | Status | Where in Codelessly, or what is missing | Pri |
|---|---|---|---|---|---|
| B1 | `createRovingFocus` | one Tab stop, arrows inside a group | PARTIAL | Each kit control has its own: tab bar and navigation bars Left/Right/Home/End (`ctl/kit_bars.dart:353-356`), segmented button (`ctl/segmented.dart:266`), radio group (`ctl/toggles.dart:271`), menu rows (`ctl/menu.dart:634-646`). No shared behavior and none for composed groups: a toolbar of icon buttons, a sidebar of NavItem lines, ChoiceChips are each separate Tab stops or not focusable at all (see B-note below). No RTL mirroring checked. | H |
| B2 | `createGridFocus`, `byCell` | row and column focus | PARTIAL | Calendar grid only: arrows, PageUp/PageDown, Home/End (`ctl/calendar.dart:200-247`). `tableView` and `gridView` have no cell or row focus (`SDK/lib/src/widgets/collections_table.dart`: no key handling). | M |
| B3 | `spatialMove`, `nearestInDirection` | arrow keys by geometry | MISSING | Tab order is by geometry (reading order, `ctl/focus.dart:225-238`) but arrows are not. | L |
| B4 | `createTypeahead` (+ `isTypeaheadKey`, `labelOf`) | jump to an item by typing | PARTIAL | Only inside the kit menu, so only an open `dropdown` (`ctl/menu.dart:595-611`, 700 ms buffer, repeated letter cycles). Not on lists, trees, tabs or design-system menus. | M |
| B5 | `createFocusRecovery` | focus moves to a neighbor when the focused item is removed | MISSING | A removed focused node drops focus to nothing (`ctl/focus.dart:170-173`). Deleting a row from the keyboard loses your place. | M |
| B6 | `keepFocus` | focus follows an element that moves | MISSING | Not found; not checked whether a list re-key keeps the same render object. | L |
| B7 | `inputHints` | keyboard type and autofill | HAVE | `textField.keyboardType`, `textInputAction`, `autofillHints`, `textCapitalization` (`ref/forms.md#node-textField`); notation `Input type=number` (email, phone), `password` (prompt line 237, 242). `autofillHints` is not taught. | - |
| B8 | `createInputHistory` | Up/Down recall earlier entries | MISSING | A canvas `keyDown` reaction does not run while a text field has focus (`ref/interaction.md#interaction-keys`), so it cannot be composed either. Chat prompts would use it. | L |
| B9 | `isComposing` | IME composition | HAVE | The field editor keeps the composing range and passes IME keys through (`ctl/editable.dart:6,155-164`; `ControlKeyResult.passThrough`, `ctl/focus.dart:60-64`). | - |
| B10 | `pageLocale`, `userLocale`, `toLocale` | locale lookup | PARTIAL | `SDK/lib/src/widgets/picker_locale.dart` exists for pickers; `formatDate`, `money` formulas. A page-level locale variable: not checked. | L |
| B11 | `fuzzyScore`, `matchRanges`, `matchSegments` | ranked search and match highlighting | MISSING | Formulas have `contains`, `startsWith`, `filter`, `sortBy` (prompt `notationFunctions`); no fuzzy score and no way to highlight the matched part of a label. | M |
| B12 | `createSelection` | single, multi, range, select all | PARTIAL | Single: a variable plus the `selected` state (`ref/interaction.md#behavior-states`); multi: a list variable with `contains/append/without`; `tableView.selectedRow` (single). A click's `${result}` carries `meta`, `shift`, `alt` (`SDK/lib/src/runtime/actions/wiring.dart:630-640`) so a range could be hand-built, but there is no anchor, range, select-all or `multiselectable` semantics, and no keyboard selection. | M |
| B13 | `createLasso` | rectangle selection | MISSING | | L |
| B14 | `createCellRange` (+ `byCellRange`, `cellRangeMessage`, `cellsToText`, `textToCells`) | spreadsheet ranges, copy and paste | MISSING | | L |
| B15 | `bindDrag`, `dragThreshold` | raw pointer drag | MODEL ONLY | `drag`, `dragStart`, `dragEnd` triggers; `pan` (`ref/interaction.md#behavior-pan`). Notation has `drag:`/`drop:` for drag and drop and `swipe:`, no word for a raw drag. Escape to cancel a drag: not checked. | L |
| B16 | `createReorder` (+ `reorderMessage`) | reorder by pointer or keyboard | MODEL ONLY | `listView.reorder` + `reorderHandle` + `reorder` trigger (`ref/lists.md#type-ListReorder`); the renderer has keyboard moves, screen-reader custom actions "Move up/down" and an announcement "Moved to 3 of 12" (`SDK/lib/src/widgets/collections_reorder.dart:400-438`). Notation: the prompt only points at the lists page ("reorderable lists: lists", written as `node {…}`); Cards `ReorderableList` is a block. Several items at once: missing. Grid reorder: not checked. | M |
| B17 | `createTreeReorder` (+ `subtreeEnd`, `treeReorderMessage`) | reorder and nest in a tree | MISSING | | L |
| B18 | `createTransfer` (+ `transferMessage`) | move between lists (a board) | PARTIAL | Pointer: `ListReorder.group` across lists, `draggable`/`dropTarget` with `acceptIf` and `slotWhenRefused` (`ref/interaction.md#behavior-dropTarget`); notation `drag:todo(card.id)` / `drop:todo -> …`. Keyboard move between lists: not found. | M |
| B19 | `bindDragPreview` | a floating copy while dragging | HAVE | `DragSource.feedback`, ghost, rotation, elevation (`ref/interaction.md#type-DragSource`); default feedback with the notation's `drag:`. Cards `ReorderGhost`. | - |
| B20 | `createAutoScroll` | scroll near an edge while dragging | MODEL ONLY | `listView.dragEdgeScroll` (`ref/lists.md#node-listView`). Its default and behavior outside lists: not checked. | L |
| B21 | `settleDraft` | reconcile a draft with a controlled value | NOT APPLICABLE | A framework state concern; Codelessly variables are the one store. | - |
| B22 | `createMove` (+ `moveMessage`) | free 2D move, pointer or keyboard | PARTIAL | Pointer: `pan` with `xVariable`/`yVariable`, bounds, snap. No keyboard nudge, no group move, no announcements. | L |
| B23 | `createResize` (+ `resizeMessage`) | resize from edges and corners | PARTIAL | `transformGesture.handles` (`TransformHandles`, fields not read); Cards `ResizableRow` (width in a variable). Keyboard resize, aspect lock, Escape cancel: not found. | M |
| B24 | `createSwipeActions` | actions behind a row, full swipe | MODEL ONLY | `listView.swipeActions` + `swipeAction` trigger, `dismissible` (`ref/lists.md#type-SwipeActions`, `SDK/lib/src/widgets/collections_swipe.dart`). Notation has only `swipe:left -> …`. Keyboard reach of the actions: not checked. | M |
| B25 | `bindHold` | press and hold | MODEL ONLY | `hold` trigger with `holdMs` (`ref/interaction.md#trigger-hold`). Parses as a trigger in the notation; not taught. Holding Space from the keyboard: no. | L |
| B26 | `bindRepeat` | repeat while held | MISSING | `keyDown` has `repeat`; a held pointer does not repeat. Cards `Stepper`, `Counter`, `NumberInput` would use it. | L |
| B27 | `createArea` | a point on a 2D pad | PARTIAL | `track` is one value; `pan` with two variables approximates it by pointer. No keyboard, no semantics. | L |
| B28 | `createSpans`, `stackSpans`, `isSpanFree`, `spansMessage` | ranges on tracks (bookings, calendar events) | MISSING | | L |
| B29 | `createPreview` | try a value before choosing | MISSING | Hand-built with `cursorEnter`/`cursorExit` setting a variable; no press-and-slide, no keyboard preview. | L |
| B30 | `createListbox` | highlight with arrows, filter while typing, virtual focus | PARTIAL | The kit menu under `dropdown` highlights with arrows, Home/End, PageUp/PageDown, Enter/Space (`ctl/menu.dart:627-646`). There is no searchable list where focus stays in the field and arrows move a highlight: Cards `Combobox`, `CommandPalette`, `DropdownMultiselect` draw it, and since composed rows have no focus and `keyDown` does not run in a field, arrow keys there very likely do nothing (not run). | H |
| B31 | `createVirtualizer` | render only what is in view | HAVE | `listView`/`gridView` build lazily with `itemExtent`, `cacheExtent` (`SDK/lib/src/widgets/collections_data_list.dart:430-439`); `tableView` builds the cells on screen (`collections_table.dart:197`); `pagination` loads more. Whether the notation's `each` in a plain Column is lazy: not checked. Browser find-in-page over the list: not applicable (see B38). | - |
| B32 | `createStickToBottom` | follow new content | MODEL ONLY | `listView.stickToEnd`; Cards `ScrollToBottomFAB`. No notation word. | M |
| B33 | `bindScrollPicker` | a wheel you scroll to pick | MISSING | `listView.itemSnapping` could be the base; no wheel control. The time picker is a dial. | L |
| B34 | `createInlineEdit` | rename in place | MISSING | Hand-built: `doubleTap` swaps a Text for an Input, `submitted` saves. Escape to cancel and focus restore are not available to a document. | M |
| B35 | `createTreeCollection` (+ `treeDataNodes`, `treeFromPaths`, `visibleTreeRows`) | a tree's shape and visible rows | DESIGN SYSTEM ONLY | Cards `Tree`, `FileTree`, `HierarchicalPicker`, `NestedTaskLedger`, `DocsNav`: the author gives each row its depth. No tree model, no Left/Right expand and collapse, no tree semantics. `expansionTile` nests but is not a tree. | M |
| B36 | `treeCheckedStates`, `toggleTreeChecked` | tri-state checks down a tree | MISSING | | L |
| B37 | `bindPanel` | open/close a panel with a height transition | HAVE | `accordion`, `expansionTile` (kit control, expanded state in semantics: `ctl/expansion.dart:679-680`); notation `Accordion`; `if` + `animate:`; Cards `FaqItem`, `Disclosure`, `TextExpandable`. | - |
| B38 | `hiddenAttrs`, `bindFindable`, `supportsHiddenUntilFound` | browser find-in-page reveals hidden content | NOT APPLICABLE | A DOM feature (`hidden="until-found"`). Flutter paints to a canvas, so Ctrl+F does not search a Codelessly page at all; that is a platform gap, noted in section 6. | - |
| B39 | `animateIn`, `animateOut` | enter and exit animation | HAVE | `animations`, `transitions`, `motion` (`ref/animation.md`); notation `animate:fade` etc. with `duration`, `delay`, `stagger`. Exit-before-removal: not checked. | - |
| B40 | `createVelocityTracker`, `projectDistance`, `solveSpring`, `rubberBand` | throw, spring, edge resistance | MODEL ONLY | `GesturePhysics`, `Spring`, `resistance`, `overscroll` on `pan`, `dismissible`, `track`, `transformGesture`; `SDK/lib/src/render/physics.dart`. Internal to those behaviors; nothing to add to the notation. | - |
| B41 | `sectorOf` | direction to a sector (radial menu) | MISSING | | L |
| B42 | `createPopup` + parts + presets | open, close, place, **focus in and back** | PARTIAL | Open/close: `openModal` (`dialog`, `bottomSheet`, `adaptive`, `sideSheet`, `fullScreen`, `popover`, `banner`), `closeModal` with a result (`ref/navigation.md#action-openModal`); notation `Dialog#id`, `Sheet#id`, `Drawer#id`, `Menu#id`, `Popover#id`, `Lightbox#id` with `open`/`close` (`API/lib/src/core/notation/page_words.dart:126-230`, prompt lines 131-138). Outside press: `barrierDismissible`. Escape: the routes are Flutter `PopupRoute`/`showDialog` (`SDK/lib/src/app/ui/presentation_route.dart:25`, `app/navigator_ui.dart:344-414`), which dismiss on Escape; not run. **Missing or not found:** focus moving into the overlay, Tab kept inside it, focus returning to the opener. The controls' focus is a separate `ControlFocusScope` per root with no route awareness; "Tab from nowhere is taken by the first scope with somewhere to go" (`ctl/focus.dart:251-262`), which may be the page behind. Not run. | H |
| B43 | `popupTitle`, `popupDescription` | the popup's accessible name | PARTIAL | `scopesRoute: true` on the route (`presentation_route.dart:105`) but `namesRoute` only on the built-in confirm dialog (`app/ui/confirm_dialog.dart:560-561`); a notation `Dialog#id "Title"` does not name its route. | M |
| B44 | `popupArrow` | an arrow toward the anchor | MISSING | Not found on popovers or the tooltip bubble (`ctl/overlay.dart:24-26`). | L |
| B45 | `popupBackdrop` | scrim | HAVE | `barrierColor`, `barrierBlur`. | - |
| B46 | `popupViewport`, sheet | a sheet that drags | HAVE | `bottomSheet` with `showDragHandle`, `maxHeightFactor`, `RouteDismiss` drag to close; notation `Sheet#id`. Detents (half, full): not on modal sheets. | - |
| B47 | `position` | anchor, side, align, flip | HAVE | `anchor` (`trigger`, `pointer`, `node`), `placement`, `anchorGap`, `anchorOffset`, `anchorReserve`; `AnchoredPlacement` flips and keeps 8 px inside (`ctl/menu.dart:46-51`); notation `Menu#more end`, `above`, `menu:<id>` at the pointer. | - |
| B48 | `bindLayer` | a layer stack: Escape closes the top one | HAVE | The navigator's route stack; the kit's `ControlPopup` closes on Escape and outside press (`ctl/menu.dart:253-258,364`). A kit dropdown inside a modal: not checked. | - |
| B49 | `bindPersistentLayer` | something stays usable over a modal (toasts) | PARTIAL | Toasts are drawn over routes (`SDK/lib/src/app/ui/toast.dart`); whether they take presses while a modal is open: not checked. | L |
| B50 | `isDismissal`, `dismissible: false`, `onDismissAttempt` | block or observe dismissal | MODEL ONLY | `barrierDismissible: false`; `blockBack` + `backPressed` for unsaved changes (`ref/navigation.md#trigger-backPressed`). The reason is not exposed. No notation word. | L |
| B51 | `supportsTopLayer` | browser check | NOT APPLICABLE | DOM. | - |
| B52 | popup controllers | open from code, await a result | HAVE | `openModal` → `closeModal.result` as `${result}`; `confirm`. | - |
| B53 | `createPreference` | a saved choice | MODEL ONLY | Variables + `setStorage` / the `storage` scope (`SDK/lib/src/app/persisted_variables.dart`); the notation has site-wide variables in `site.json` but no word to persist one. | M |
| B54 | `createColorScheme` (+ `colorSchemeOf`, `preferencesScript`) | light, dark, system | HAVE | `setThemeMode`, the `theme` scope; Cards `ThemeToggle`. The server-side helpers are not applicable. | - |
| B55 | `createPointerKind`, `pointerKindOf` | finger or mouse, can it hover | PARTIAL | Handled inside behaviors (`DragStart.auto`; "hovered never happens on touch" is a documented pitfall) but not readable by a document, so a hover-only affordance cannot fall back by itself. Not checked for a hidden variable. | M |
| B56 | `createLocalStorage`, `createSessionStorage`, `createCookieStorage` | persisted values | MODEL ONLY | `setStorage` (`StorageOperation`). Cookie: not applicable. | L |
| B57 | `createViewport` | pan and zoom a canvas | MODEL ONLY | `transformGesture` (`target: content`, wheel and pinch zoom, double tap, bounds, two-way pose variables) + `controlTransform` (`reset`, `scaleBy`, `animateTo`) (`ref/interaction.md#behavior-transformGesture`). No notation word; no `+`/`−`/`0` keys; no "reveal the focused item". Cards `CanvasShell`, `MapPanel`. The image viewer on `dsl5/viewer` builds on this (in progress). | M |
| B58 | `createConnect`, `connectMessage` | connect ports (node editors) | MISSING | | L |
| B59 | `announce`, `prepareAnnouncements` | screen-reader announcements | PARTIAL | Built in for toasts (`toast.dart:504`), banners (`app/presenter.dart:561`) and reorder (`collections_reorder.dart:422`). No `announce` action and no live-region flag a document can set ("3 results", "Added to cart" without a toast). | M |
| B60 | `isRTL` | text direction | HAVE | `textDirection` behavior, RTL pattern (`ref/layout.md#layout-rtl`). Arrow-key mirroring inside controls under RTL: not checked. | - |
| B61 | `matchesShortcut`, `formatShortcut`, `ariaKeyshortcuts` (+ `shortcuts` module) | global shortcuts, shown per platform | PARTIAL | Canvas `keyDown` with a key combination and `when` (`ref/interaction.md#interaction-trigger-fields`). It does not run while a text field has focus; a shortcut label is not formatted per platform (⌘K vs Ctrl+K); no shortcut semantics. Not taught in the prompt. | M |
| B62 | `bindViewport`, `bindAvoidKeyboard` | the visual viewport and the on-screen keyboard | HAVE | Flutter's own keyboard insets; `keyboardDismissBehavior` on lists. Not checked on a device. | - |
| B63 | `createChange`, `createCommit`, `dispatch` | change vs final value | HAVE | `changed` / `changeEnd` / `submitted` / `editingComplete` triggers. Cancelling a change from a handler: no. | - |
| B64 | `createUndoStack` | undo and redo | MISSING | Only inside a text field (`ctl/editable.dart:559-562`) and a list's undo bar after a swipe delete (`collections_data_list.dart:807`). No undo over variables. | L |
| B65 | `createController` | call a component's methods from outside | HAVE | `controlTrack`, `controlDismissible`, `controlTransform`, `paginate`, `scrollTo`, `focus`, `editText`, `animate` actions. | - |
| B66 | `sourceOf`, `isFocusFromKeyboard` | input modality; focus ring only from the keyboard | HAVE | `showsHighlight` (`ctl/focus.dart:115-117`). Not readable by a document. | - |
| B67 | `observe`, `elementOf`, `withSource` | watch every component change | NOT APPLICABLE | Their components are code; Codelessly's state is already data, and `emit` / `componentEvent` reach the host. | - |
| B68 | `definePrimitive`, `idPart`, `elements`, `openAttrs`, `checkedAttrs`, `css`, `live`, `selects`, `direct` | their component kernel | NOT APPLICABLE | The counterpart is the document model, components (`ref/components.md`) and design systems as data. | - |
| B69 | `createAgent`, `agentTools`, `registerTools` | an agent reads and operates the live page | MISSING | The render command drives a page from outside (`--tap`, `--type`, `--key`), and `ui_tools.json` covers authoring; an in-page bridge (snapshot, act, query, permissions, WebMCP) was not found. Not checked beyond a file search. Strategic rather than a page behavior. | L |
| B70 | `createHistory`, `describeEntry`, `stageChanges` | record who changed what; try and revert | MISSING | | L |

**B-note (applies to B1, B4, B30, B35 and most component rows).** In the renderer a focus node is created in exactly two places: the kit control base (`ctl/kit.dart:34`) and `track` (`render/drag_track.dart:1053`). A node with a `click` reaction gets button semantics and an `onTap` for screen readers (`runtime/actions/wiring.dart:613-621`) but no focus node, so it is skipped by Tab and ignores Enter and Space. How each Cards block is built (kit button inside, or boxes with reactions) was not read block by block; any block built from boxes inherits this.

### 2.2 Components

| # | Their component | What it is for | Status | Where in Codelessly, or what is missing | Pri |
|---|---|---|---|---|---|
| C1 | Accordion | show and hide sections | HAVE | `accordion`, `expansionTile`; notation `Accordion`; Cards `FaqItem`. Arrow keys between headers: no (optional in APG). | - |
| C2 | Alert Dialog | confirm before an action | MODEL ONLY | `confirm` action with `destructive`, names its route (`confirm_dialog.dart:560`). The word "confirm" does not occur in `notation.dart`, `page_words.dart` or the prompt. | H |
| C3 | Autocomplete | free text with suggestions | MISSING | No suggestion list under a field. | M |
| C4 | Avatar | image with a fallback | HAVE | notation `Avatar "Maya Reyes"` / `src:`. | - |
| C5 | Button | run an action | HAVE | kit buttons: focus, Enter/Space, `isButton` (`ctl/buttons.dart:732`). | - |
| C6 | Calendar | pick dates from a month grid | PARTIAL | The month grid exists inside `datePicker` with full keys (`ctl/calendar.dart`). Not available as an inline node; no range selection; Cards `DayPicker` is a strip of days. | M |
| C7 | Carousel | page through slides | HAVE | `pageView`; notation `Pages bind=page peek=` + `Dots`; Cards `Carousel`, `PageDots`. Arrow keys, loop, autoplay pause on hover: not checked. | - |
| C8 | Checkbox (+ group) | independent options | HAVE | kit toggle, `isChecked` (`ctl/toggles.dart:622-637`). Mixed state: not checked. | - |
| C9 | Collapsible | show and hide one section | HAVE | as C1; Cards `TextExpandable`, `Disclosure`. | - |
| C10 | Color Picker | pick a color | PARTIAL | Cards `ColorInput` is a hex field with a swatch. No area, hue or alpha picker (their `createArea`). | L |
| C11 | Combobox | search a list and choose | DESIGN SYSTEM ONLY | Cards `Combobox`, `DropdownMultiselect`. Arrow-key highlight while typing: see B30. | H |
| C12 | Command | search and run commands | DESIGN SYSTEM ONLY | Cards `CommandPalette`. Same keyboard question; no global shortcut to open it from a field (B61). | M |
| C13 | Date Input | type a date | HAVE | `dateTimeInput` (`mode`, `format`, `min`, `max`); notation `DatePicker`. Segment-by-segment typing with arrows: not checked. | - |
| C14 | Date Picker | a date with a calendar | HAVE | `datePicker`, drawn by the renderer in the project theme (`ctl/pickers.dart`, `ctl/calendar.dart`; merged from `dsl5/datepicker`). Escape and Tab close it (`pickers.dart:737-741`). | - |
| C15 | Dialog | a focused task over the page | PARTIAL | Opens, dismisses, returns a result (B42). Focus in, Tab trap, focus return, accessible name: not found (B42, B43). | H |
| C16 | Drawer | a panel from an edge | PARTIAL | notation `Drawer#id`, `Sheet#id`; an App's Sidebar becomes a drawer on a phone. Same focus gaps as C15. | H |
| C17 | Field (+ Label) | label, description, errors | HAVE | `InputDecoration` label, helper, error; `form`, `validate`; Cards `Field`. Whether a Cards `Field` label is tied to a non-text child for screen readers: not checked. | - |
| C18 | File Input | choose, drop or paste files | PARTIAL | `cloudFiles` picks through the host; Cards `FileUploader`, `ImageUpload` fire `onPick`. Dropping files from the desktop and paste: not found. | M |
| C19 | Hover Card | preview a link on hover or focus | MISSING | No hover-open popover with open and close delays that stays open while the pointer travels to it. | L |
| C20 | Image Cropper | crop an image | MISSING | `transformGesture` could be the base. | L |
| C21 | Input | text | HAVE | kit text field with its own editor (selection, clipboard, undo, IME). | - |
| C22 | Label | name a control | HAVE | decoration label; Cards `TextInputLabel`. Pressing a label to focus its control: not checked. | - |
| C23 | Listbox | choose from an always-visible list | DESIGN SYSTEM ONLY | Cards `OptionList`, `SelectableListRow`, `Checklist`; `listTile.selected`. No arrows, type-ahead or listbox semantics. | M |
| C24 | Menu | actions from a button or a right click | PARTIAL | notation `Menu#id` with `MenuItem` lines, closes after a choice; `menu:<id>` on right click or long press at the pointer. The rows are Cards `MenuItem` blocks in a popover canvas, not the kit's `RenderMenu`, so the arrows, Home/End and type-ahead that the dropdown has are not there; no menu roles; no submenus, checkbox or radio items. | H |
| C25 | Menubar | an application menu bar | MISSING | | L |
| C26 | Meter | a measurement in a range | HAVE | `gaugeMeter`, `radialGauge`; notation `Gauge`, `Ring`. | - |
| C27 | Navigation Menu | site links in panels that open from triggers | PARTIAL | `Nav` + `Link`, `SiteNav`, and the phone menu the reflow adds (`page_words.dart:280-286`). Panels under a trigger (a mega menu) with hover intent and arrows: missing. | M |
| C28 | Number Input | a number you type or step | DESIGN SYSTEM ONLY | Cards `NumberInput`, `Stepper`, `Counter`; `textField.keyboardType`. Up/Down to step, hold to repeat (B26), locale formatting: not found. | M |
| C29 | OTP Input | a one-time code | MISSING | Cards `AuthInput` not read. | M |
| C30 | Pagination | page through results | HAVE | `pagination` node with button semantics (`widgets/collections_pagination.dart:589-609`), `paginate`; Cards `Pager`, `LoadMore`. | - |
| C31 | Password Input | a password | HAVE | notation `Input "Password" password`. A show/hide toggle: not checked. | - |
| C32 | Popover | a panel beside its trigger | PARTIAL | notation `Popover#id`; placement HAVE (B47); focus gaps as C15. | H |
| C33 | Progress | progress of a task | HAVE | `progressBar`, `circularProgressIndicator`; notation `Progress`. | - |
| C34 | Radio | one of a few | HAVE | `radio` + `radioGroup`, arrows move the choice (`ctl/toggles.dart:271`). | - |
| C35 | Rating | pick a score | MISSING | Hand-built from icons with clicks: no keyboard, no slider semantics. Common on product and review pages. | M |
| C36 | Resizable | resizable panels | DESIGN SYSTEM ONLY | Cards `ResizableRow`. Keyboard resize, collapse, saved layout: not checked. | M |
| C37 | Scroll Area | styled scrollbars, edge indicators, follow-to-end | PARTIAL | `listView.stickToEnd`; `pageView.edgeFade`. Styled scrollbars and edge shadows on any scroller: not checked. | L |
| C38 | Segmented Control | one of a compact row | HAVE | `segmentedButton` with arrows (`ctl/segmented.dart:266-288`); notation `SegmentedButton`. | - |
| C39 | Select | choose from a popup list | HAVE | `dropdown`: Up/Down opens, menu keys and type-ahead, Escape, Tab closes (`ctl/dropdown.dart:468-485`), `isButton` + value (`:613-619`). Several values: only Cards `DropdownMultiselect`. | - |
| C40 | Separator | divide content | HAVE | `divider`. | - |
| C41 | Slider | a number by dragging | HAVE | arrows, PageUp/PageDown, Home/End (`ctl/slider.dart:255-269`), `isSlider`. A two-thumb range: missing. | - |
| C42 | Switch | on or off | HAVE | notation `Toggle`. | - |
| C43 | Tabs | switch between panels | IN PROGRESS | `tabs`, `tabBar` nodes: arrows, Home/End, tab role and selected state, `isScrollable` (`ctl/kit_bars.dart:353`, `ctl/tab_bar.dart:262`). No notation word (not in `notationTypes` or the prompt's taught set); Cards `Tabs`, `TabOverflowScroll`, `ChipTabs` are blocks. Branch `dsl5/tabs` (worktree `wt-tabs`, 24 uncommitted files in the SDK) is restyling and scrolling them. Tab-panel association: not checked. | H |
| C44 | Timeline | dated events with arrow keys between them | DESIGN SYSTEM ONLY | Cards `HistoryTimeline`, `Steps`, `DateTimelineAxis`. No keys. | L |
| C45 | Toast | notifications | HAVE | `showToast` with an action and close, live region; notation `toast "Saved"`. Swipe to dismiss, stacking, pause on hover: not checked. | - |
| C46 | Toggle (+ group) | a pressed button or group | HAVE | `filterChip`, `choiceChip`, `segmentedButton`; a button's `selected` state. | - |
| C47 | Token Input | text mixed with tokens | DESIGN SYSTEM ONLY | Cards `ExtensionChipsInput` (type and add, a chip with an x); `inputChip` deletes on Backspace/Delete (`ctl/chips.dart:473`). Tokens inline in running text: missing. | L |
| C48 | Toolbar | one Tab stop for a row of tools | DESIGN SYSTEM ONLY | Cards `Toolbar`, `RichTextToolbar`, `PaneToolbar`. No roving focus (B1). | M |
| C49 | Tooltip | name a control or add a hint | PARTIAL | `tooltip` behavior; read by screen readers; notation `tooltip:"…"` parses (`notation.dart:2375`) but the prompt does not teach it. Shown on hover only (`ctl/overlay.dart:119-123`), not on keyboard focus; no Escape. | M |
| C50 | Tree | browse a hierarchy | DESIGN SYSTEM ONLY | as B35. | M |
| C51 | Trigger Menu | suggestions at the caret for @, / or # | MISSING | | L |
| C52 | Waterfall | request timings on a time axis | MISSING | Charts cover bars; not this. | L |
| C53 | Textarea | several lines | HAVE | `Input "Note" multiline`; `minLines`, `maxLines`. | - |
| C54 | Time Input | a time | HAVE | `timePicker` (dial with arrows, digits, A/P: `ctl/time_dial.dart:134-182`), `dateTimeInput`. | - |
| C55 | Preferences | theme and other saved choices | HAVE | `setThemeMode`, Cards `ThemeToggle` (B54). | - |

---

## 3. The reverse list: what Codelessly has that their list does not

Their library stops at behavior; these are outside its scope, so the lists are complementary rather than competing.

| Codelessly has | Where |
|---|---|
| Responsive reflow by default (Grid drops columns, rows stack or wrap, tables keep leading columns, Nav and Sidebar collapse to a menu), `hide:`/`show:` per size, media rules, a canvas per breakpoint | `API/lib/src/core/notation/reflow.dart`, prompt lines 125-129, `ref/layout.md#layout-responsive-design` |
| Page frames: Page, Nav, Section, Footer, App, Sidebar, Main, Pane | `page_words.dart` |
| Sticky, floating, measure | `ref/layout.md#behavior-sticky` |
| Scroll to a node or an anchor (`scroll pricing`, `href:"#pricing"`), scroll progress, viewport triggers (`enterViewport`, `visibleFraction`) | `ref/layout.md#action-scrollTo`, `ref/interaction.md` |
| Screens, routes with params and paths, route transitions and presets, swipe back, drag to dismiss, hero flights, back blocking | `ref/navigation.md` |
| Charts and gauges (bar, line, area, donut, plot, sparkline, radial gauge) | `ref/charts.md` |
| Data: bindings, formulas, variables, conditions, scripts, `callApi`, cloud data, pagination controllers, pull to refresh, sections | `ref/state.md`, `ref/data.md`, `ref/lists.md` |
| Forms end to end: validation, `submitForm`, auth, paywall | `ref/forms.md`, `ref/auth.md`, `ref/commerce.md` |
| Animation presets and behaviors: motion, keyframes, transitions, shimmer, reveal, typewriter, particles, flip, tilt, view progress | `ref/animation.md` |
| Design systems as data: theming, tokens, 200+ Cards components, SSUI | `SDK/design_systems/` |
| Media: video, embedded video, audio, web view, speech, sound, print, screenshot, download; signature pad; barcode | `ref/media.md`, catalog node types |
| A value along any path (`track`: line, arc, SVG path: knobs and dials) with keys and physics | `ref/interaction.md#behavior-track` |
| Haptics, clipboard, open link, timers (`every`), frame ticker | `ref/interaction.md`, `ref/triggers.md` |
| Image viewer and gallery with zoom (IN PROGRESS, `dsl5/viewer`, worktree `wt-viewer`: `navigator_ui.dart`, Cards `PhotoGallery` modified, uncommitted) | `wt-viewer` |

They ship none of: layout, routing, data, charts, theming, media.

---

## 4. The gap list, ranked and grouped

Every MISSING, PARTIAL and MODEL ONLY row, grouped. "Built in": R = renderer control, M = document model, N = notation word, D = design system block, P = prompt. Size: S / M / L.

### 4.1 Four shared behaviors (their core idea) and what each would fix

| Shared behavior | Fixes rows | Our controls and blocks that benefit | Built in | Size |
|---|---|---|---|---|
| **S1. Focusable press target**: any node with a click reaction joins the focus order, shows the focus ring from the keyboard, runs on Enter/Space | B-note; part of B1, C24, C23, C48, C50, C11, C12, C27 | Every Cards block built from boxes: Link, NavItem, MenuItem, ListRow, SelectableListRow, card tiles, Breadcrumb, Pager, FaqItem, Disclosure, ChoiceChips, OptionList, Tree rows, IconBox buttons | R (`RenderReactions` in `runtime/actions/wiring.dart` joins `ControlFocusScope`) | M |
| **S2. Roving group with type-ahead**: a container declares "one Tab stop; arrows move inside; Home/End; optional wrap; type a letter to jump", with a role | B1, B4, C23, C24, C48, C50 (with expand/collapse keys), C44, C27, part of B2 | Menu#id and ContextMenu, Toolbar and RichTextToolbar, Sidebar and DocsNav lines, Cards Tabs / ChipTabs / SegmentedControl / ChoiceChips, OptionList, Tree and FileTree, HistoryTimeline. The kit already has four private copies to unify (tab bar, segmented, radio, menu) | M (a node behavior such as `focusGroup`) + R + N (implied by Menu, Toolbar, Sidebar words) | M |
| **S3. Modal focus scope**: opening an overlay moves focus into it, Tab stays inside, closing returns focus to the opener; the overlay is named by its title; Escape closes the top layer | B42, B43, C15, C16, C32, C24, C2, B5 (same machinery restores focus) | Dialog, Sheet, Drawer, Menu, Popover, Lightbox, confirm, the phone nav menu, the date and time picker popups | R (`app/navigator_ui.dart`, `presentation_route.dart`, `ctl/focus.dart`) | M |
| **S4. Listbox highlight with a field**: focus stays in the text field; Up/Down move a highlight over the options; Enter chooses; Escape closes; the option list filters as you type; highlighted option is announced | B30, B11, C11, C12, C3, C51, part of C39 (multi) | Cards Combobox, DropdownMultiselect, MultiSelectDropdown, CommandPalette, SearchBar with suggestions, ModelSelectMenu, ProjectSelector, WorkspaceSwitcher, HierarchicalPicker | R (reuse `RenderMenu`, `ctl/menu.dart`) + M (a `dropdown` that is searchable and multi, or a `combobox` node) + N | L |

### 4.2 Focus and keyboard

| Gap | What a user or an agent would notice | Built in | Size |
|---|---|---|---|
| S1 focusable press targets | Tab skips links, sidebar lines, menu rows and card tiles; a keyboard user cannot activate them | R | M |
| S2 roving group, type-ahead (B1, B4) | a toolbar takes ten Tabs to cross; typing a letter in a menu does nothing | M, R, N | M |
| Focus recovery (B5) | delete a row from the keyboard and focus is gone; the next Tab starts from the top | R | S |
| Grid focus (B2) | arrows do nothing in a table or a grid of cards | R, M | M |
| Shortcuts (B61) | Ctrl+K cannot open a palette while typing; a shortcut hint shows "Ctrl" on a Mac; the notation cannot write a shortcut | M (run in fields for modifier combos), N (`key:"mod+k" -> …`), P | S |
| Announcements (B59) | a filter changes the result count and a screen reader hears nothing | M (`announce` action or `live` on a node), N | S |
| Tooltip on focus (C49) | an icon-only button has no visible name for a keyboard user | R; P to teach `tooltip:` | S |
| Input history (B8), spatial focus (B3), keep focus (B6) | specialist | R | S each |

### 4.3 Selection

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| Selection model (B12) | no Shift-click range, no select all, no "3 selected" bar without hand-written formulas; a multi-select list is not announced as one | M (a `selection` on list, grid and table with a list variable), R, N | M |
| Table rows: sort, select, keys (B2, B12) | a data table is read-only by keyboard | R, M | M |
| Lasso (B13), cell ranges and copy/paste (B14), tree checks (B36) | specialist: canvases, spreadsheets, file pickers | R | M to L |

### 4.4 Popups and dismissal

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| S3 modal focus scope (B42, B43, C15, C16, C32) | after opening a dialog, Tab walks the page behind it; closing leaves focus nowhere; a screen reader is not told a dialog named "Join the waitlist" opened | R | M |
| Menu keyboard (C24) | a Menu written in the notation opens but cannot be driven by arrows; the dropdown can, so the two feel different | R (S2, or render Menu#id with `RenderMenu`), N | M |
| Confirm has no word (C2) | an agent writes a hand-made confirm dialog, or none, for "Delete?" | N (`confirm "Delete this?" -> …`), P | S |
| Submenus, checkbox and radio menu items (C24) | no nested menu | D, N | M |
| Hover card (C19), popup arrow (B44) | no link preview; popovers have no pointer | R, M | S to M |
| Dismissal reason and "don't dismiss" in the notation (B50) | a form in a dialog closes on an outside tap and loses input | N (`Dialog#id … sticky` or `dismiss:false`), P | S |
| Detents on sheets (B46) | no half-height sheet | M, R | S |

### 4.5 Lists and virtualization

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| S4 listbox with a field (B30, C11, C12, C3) | a combobox or command palette that needs the mouse | R, M, N | L |
| Fuzzy match and highlight (B11) | search results are substring-only and cannot bold the match | M (formulas `fuzzy(list, q, x => x.name)`, text runs for matches) | S |
| Stick to end has no word (B32) | a chat or log does not follow new lines unless written as JSON | N (`List follow` or `Column scroll follow`), P | S |
| Inline edit (B34) | rename in place needs a hand-built swap and cannot cancel with Escape | D or M (`editable` on a Text), R | M |
| Wheel picker (B33) | no iOS-style wheel | R, D | M |
| Find in page (B38) | Ctrl+F finds nothing on a Codelessly page | platform; see 6 | L |

### 4.6 Drag, reorder, resize

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| Reorder has no word (B16) | an agent does not reach the (already keyboard-capable) reorder; it writes up/down buttons | N (`each row in rows reorder`, `Handle`), P | S |
| Swipe actions have no word (B24) | no "swipe to delete" from the notation | N (`swipe-actions:` or a line under `each`), P | S |
| Keyboard move between lists (B18) | a board works by mouse only | R | M |
| Resize (B23, C36) | a split pane's divider cannot be moved from the keyboard, does not collapse, forgets its size | R (a splitter control), D | M |
| Repeat while held (B26), hold in the notation (B25) | a stepper needs a click per step | R, N | S |
| Tree reorder (B17), spans (B28), 2D pad (B27), free move by keyboard (B22), preview (B29), raw drag word (B15), auto-scroll default (B20) | specialist | R, M | M each |

### 4.7 Inputs

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| OTP input (C29) | a sign-in code page is six hand-wired fields | R or D, N | S |
| Rating (C35) | stars that cannot be set by keyboard and are not announced | D on `track`/slider semantics, N | S |
| Number input (C28) | Up/Down do not step; holding the button does not repeat | R (keys on the field), D | S |
| Range slider (C41 note) | no two-thumb price filter | R, M | M |
| Autocomplete (C3), token input (C47), trigger menu (C51) | no suggestions under a field, no @mentions | S4 first | M to L |
| Inline calendar and date range (C6) | a booking page cannot show a month or pick check-in to check-out | M (a `calendar` node reusing `ctl/calendar.dart`), N | M |
| Color picker (C10), image cropper (C20), file drop and paste (C18) | specialist editors, uploads | R, D | M each |

### 4.8 Navigation

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| Tabs (C43) | IN PROGRESS on `dsl5/tabs`; when it lands, check it against S2 and add the notation word | R, N, P | - |
| Navigation menu panels (C27) | no mega menu; on desktop a Nav is links only | D, N, S2 + hover intent | M |
| Menubar (C25) | app menu bars | D on S2 | M |
| Tree (C50, B35) | a file tree that cannot be walked by arrows or collapsed with Left | M (tree data → rows), R (S2 + Left/Right), N | M |

### 4.9 Preferences, canvas, platform

| Gap | What is noticed | Built in | Size |
|---|---|---|---|
| Persist a value from the notation (B53, B56) | a theme choice or a dismissed banner comes back after reload | N (`state theme="light" saved`), P | S |
| Pointer kind readable (B55) | hover-only menus on a touch laptop; no way to write "if it can hover" | M (a `${device.hover}` value), N | S |
| Viewport word and keys (B57) | pan and zoom needs JSON; no +/−/0 | N (`zoom` on a Box), R | S; the viewer branch may cover it |
| Connections (B58), radial sector (B41), undo over variables (B64), agent bridge (B69, B70) | node editors, radial menus, undo, agents operating a live page | R, M | L each |

---

## 5. Proposed order of work

### 5.1 The ten to close first

| # | Gap | Why first |
|---|---|---|
| 1 | **S1: nodes with a click reaction take focus and Enter/Space** | Largest reach for the least work: every page has links, nav lines and tiles, and every block built from boxes becomes keyboard-usable at once. Without it nothing below it is reachable by keyboard. |
| 2 | **S3: overlays move focus in, keep Tab inside, return it on close, and are named by their title** | Dialog, Sheet, Drawer, Menu, Popover and Lightbox were just added to the notation and are on most of the twenty sites; this is the classic accessibility failure of modals. One change in the route and focus code fixes all six. |
| 3 | **Menu keyboard: `Menu#id` driven by arrows, Home/End, type-ahead, Escape** | Menus are on every app page. The kit's `RenderMenu` already does all of it for the dropdown; either render notation menus with it or get it through S2. |
| 4 | **S2: one roving-focus group behavior (with type-ahead), and move the four private copies onto it** | Unlocks Toolbar, Sidebar, Cards tabs and chips, OptionList, Tree, Timeline; ends the pattern of each control re-implementing arrows. |
| 5 | **Tabs: finish `dsl5/tabs`, give it a notation word, check it against S2** | Already in progress; tabs are among the most frequent page controls and currently have no word. |
| 6 | **Words for what the model already has: `confirm`, list `reorder`, swipe actions, stick to end, persisted state, `tooltip:` taught; tooltip also on keyboard focus** | Six MODEL ONLY rows closed by notation and prompt work alone (small each); the renderer side exists and reorder is already keyboard-capable and announced. |
| 7 | **S4: a searchable listbox (combobox), then command palette and multi-select on it** | Search-and-pick is on most app pages (filters, assignees, command palettes) and today needs the mouse. Large, so after the cheap wins. |
| 8 | **Selection model on list, grid and table (multi, range, select all) plus row and cell focus in `tableView`** | Data tables are the center of dashboard pages; bulk actions need it. |
| 9 | **Small missing inputs: OTP, rating, number stepping with hold-repeat, range slider; then an inline calendar with a range** | Each is small, each appears on common pages (sign-in, reviews, cart, price filter, booking). |
| 10 | **Announcements and shortcuts: an `announce` action or live region, focus recovery after a removal, `key:` shortcuts that work from a field and print per platform** | Completes screen-reader and keyboard coverage for dynamic pages; all small. |

Deferred on purpose (specialist, low page frequency): lasso, cell ranges, spans, connections, radial sector, tree reorder, image cropper, waterfall, menubar, trigger menu, undo stack, agent bridge.

### 5.2 A standing checklist

Keep one file, for example `CodelesslySDK/docs/BEHAVIOR_CHECKLIST.md`, seeded from section 2 of this report, and require a filled copy for every new or changed control or design-system block. Per control, answer yes / no / not applicable with a file reference:

1. **Reachable**: is it in the Tab order? One Tab stop for a group?
2. **Operable**: Enter/Space; arrows, Home/End, PageUp/PageDown where it has items; type-ahead where items have labels; Escape where it opens something.
3. **Focus**: ring from the keyboard only; where does focus go when it opens, closes, or the focused item is removed?
4. **Named and described**: role, label, value, state (selected, checked, expanded, disabled) in semantics; changes announced.
5. **Dismissal**: outside press, Escape, back button; can it be blocked; nested layers.
6. **Pointer kinds**: works without hover; touch target size; long press or right click equivalents.
7. **Text direction**: arrows and placement under RTL.
8. **Phone**: reflow, on-screen keyboard, sheet instead of popover.
9. **Reachable from the notation**: a word or a key, and a line in the prompt; otherwise the status is MODEL ONLY.
10. **Which shared behavior it uses** (S1 to S4, selection, reorder, popup placement), so nothing re-implements keys.

Make it enforceable: a test helper that, for a control under test, presses Tab, the arrows, Enter and Escape and reads the semantics tree (their `@ui-sdk/core/testing` does exactly this for their components: "testing keyboard, focus, ARIA, server rendering and right to left"), and a line in the design system's block lint that fails a block with a click reaction and no focus. Re-run this comparison when their list changes; their index page is a single file (`apps/docs/content/docs/core/behaviors/index.mdx`), so a diff of it is the watch.

---

## 6. What could not be verified

- **Nothing was run.** Every Codelessly status comes from reading docs and source. In particular: Escape on modal routes, where Tab goes with a modal open, and whether focus returns on close are inferred from the code (B42); they need a five-minute manual test before work is planned on them.
- **Design-system blocks were not read one by one.** Their `widget.doc` lines were read (about 100 of the 218 Cards components); whether a given block is built on a kit control (focusable) or on boxes with reactions (not focusable) was not checked per block. SSUI components were listed, not read.
- **Their per-component behavior composition** is not stated in the pages read; the component rows use their one-line descriptions and file names. Their component docs (55 pages) and the keyboard tables inside them were not read in full; only titles and descriptions for ten of them.
- **Their category pages** were read for headings and demo captions, not line by line; API reference option tables were skipped.
- **Their `foundation/` modules with no index entry** (`disclosure`, `forms`, `gauge`, `shortcuts`, `snap-points`, sheet and hover presets, `scrollbar`, `text-editor`, `caret`) are listed from the tree only.
- **Codelessly items marked "not checked" in the tables**: RTL arrow mirroring; `each` laziness; exit animations; toast swipe and stacking; carousel keys; checkbox mixed state; password show/hide; label press; `TransformHandles` fields; `dragEdgeScroll` default; date input segment typing; page locale; a dropdown inside a modal; toasts over a modal; Cards `AuthInput`; scrollbar styling; grid reorder.
- **Browser find-in-page and DOM-level accessibility on the web build** (what Flutter's semantics tree exposes to a browser's screen reader, and that Ctrl+F does not search canvas text) were not tested; they affect how far any of the above reaches web users.
- **Work in progress** was judged from `git status` in the worktrees only: `wt-tabs` (SDK: 24 files changed, uncommitted), `wt-viewer` (API 4, SDK 9, uncommitted); `wt-datepicker` and `wt-behaviours` are clean and their branches appear merged (main has "date fields" and the overlay words).
- The `codelessly-editor` MCP server failed to connect in this session; it was not needed for this read-only research.
