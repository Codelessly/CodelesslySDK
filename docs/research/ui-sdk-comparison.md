# Vercel Labs UI SDK and Codelessly: a comparison

Written 2026-11-16. Read-only research: nothing was installed, and no repository was changed.

**How to read this.** "Fact" means read at the cited source on 2026-11-16. "Inference" is marked as such. UI SDK
sources are the repository `github.com/vercel-labs/ui` at `main` (read through the GitHub API) and `ui-sdk.dev`.
Codelessly sources are the local checkouts under `C:/Users/searc/Development/CodelesslyEditor/`.

## 0. Sources reached, and the secondhand claims

Both primary sources were reachable: the repository (tree of 8,626 paths, not truncated) and the site (`/`,
`/llms.txt`, `/docs/agents/llms.txt`, `/docs/core/llms.txt`).

| Claim as given | Verdict | What the source says |
|---|---|---|
| Announced around 2026-11-13 | Close | Launch post is dated 2026-11-12 (`apps/docs/content/docs/core/changelog/introducing-ui-sdk.mdx`). Repo created 2026-10-26; first npm publish 2026-11-12. |
| At 0.1.0-beta.1 | Different (moved on) | `packages/core/package.json` says `0.1.0-beta.5`; releases beta.3 to beta.5 were all cut on 2026-11-15. npm `latest` tag is `0.1.0-beta.3`, `beta` tag is `0.1.0-beta.5`. |
| 6 npm packages | Confirmed | `packages/`: `core`, `react`, `solid`, `svelte`, `vue`, `web`. |
| 50+ behaviors | Confirmed as their wording; the count depends on what is counted | Launch post: "We built more than 50 of them." The "All Behaviors" index (`apps/docs/content/docs/core/behaviors/index.mdx`) lists 134 helpers, many of them small functions (`dragThreshold`, `labelOf`), not `create*` behaviors. |
| 51 component modules | Confirmed | `packages/core/src/components/` has 51 directories. |
| `createRovingFocus`, `createTypeahead`, `createPopup`, `createSelection`, `createReorder`, `createResize`, `createViewport`, `createVirtualizer`, `createFocusRecovery` | Confirmed | All named on the home page or the behaviors index; source files exist under `packages/core/src/foundation/` (`focus/roving-focus.ts`, `text/typeahead.ts`, `popups/create-popup.ts`, `drag-and-drop/reorder.ts`, `direct-manipulation/resize.ts`, `canvas/viewport.ts`, `lists/virtualizer.ts`, `focus/focus-recovery.ts`). |
| `definePrimitive` (state, API, slots), rendered with `createParts` | Confirmed | README, launch post, `AGENTS.md`. Also takes `name`, `options`, and an optional `agent` key. |
| Docs group behaviors into 10 categories, "Focus and Keys" to "Canvas" | Partly | There are 10 behavior guide pages (`core/behaviors/`: canvas, direct-manipulation, drag-and-drop, focus, lists, motion, popups, preferences, selection, trees). The index page itself has 16 top-level headings, from "Focus and Keys" to "Values and Testing"; "Canvas" is the 11th. |
| Prebuilt Select, Combobox, Date Picker, Menu, Tree, Color Picker | Confirmed | All six are directories in `packages/core/src/components/` and have React adapters in `packages/react/src/`. |
| Benchmark: 69% fewer tool calls, 41 s to 16 s, 1 task, 3 runs, "agent bridge" | Different numbers | `benchmarks/agent/README.md` and `docs/agents/index.mdx`: React 17 to 7 tool calls (59% fewer), 53 s to 31 s (41% faster), tokens 291.7k to 69.5k (76% fewer), cost $0.139 to $0.044 (68% cheaper). One task, medians of three runs, Sonnet through Claude Code, run on 2026-11-15. I could not find "69%" or "16 s" anywhere; "41" matches the "41% faster" figure and "68%" the cost figure, so the secondhand numbers look garbled. |
| `ui-sdk` agent skill and an llms.txt | Confirmed | `packages/core/skills/ui-sdk/SKILL.md` plus seven reference files; `ui-sdk.dev/llms.txt` and one per docs section; each npm package also ships its docs as Markdown with its own `docs/llms.txt` (per the skill file). |

## 1. What UI SDK is

**One line (fact, `AGENTS.md`):** "a TypeScript library of UI behaviors for building interfaces. It isn't a
component library. It's the layer underneath one."

### Packages and architecture

| Layer | Where | What it holds |
|---|---|---|
| Kernel | `packages/core/src/foundation/kernel/` | `definePrimitive`, store, change handling (`change.ts`, `draft.ts`, `undo-stack.ts`), parts and attrs, roles |
| Behaviors | `packages/core/src/foundation/*` (20 folders) | focus, selection, popups, drag-and-drop, direct-manipulation, lists (listbox engine, virtualizer, tree collection), motion, canvas, forms, text, number, date, color, image, shortcuts, platform (announce, layers, position), preferences, storage |
| Components | `packages/core/src/components/` (51) | Each component's primitive, framework-free |
| Page level | `packages/core/src/page/` | `agent`, `history`, `observe`, `overlays`, `shortcuts` |
| Testing | `packages/core/src/testing/` | `checkPattern`, `mount`, `checkServer`, direction checks |
| Adapters | `packages/{react,vue,svelte,solid,web}` | `createParts` plus a thin file per component (React: 85 source files) |

Principles they state (`AGENTS.md`): zero runtime dependencies; works under SSR and before hydration; right to
left without a provider; popups without portals; "one shape across components and frameworks, so a model writes
them correctly in few tokens."

### How a behavior is defined and composed

A primitive is one object: `name`, `options`, `state`, `api` (where behaviors are called), `slots` (the parts, each
with attributes, event handlers and a `present` condition). From the launch post:

```ts
const share = definePrimitive({
  name: "share",
  options: { defaultOpen: "boolean" },
  state: (options) => popupState(options),
  api: (context) => createPopup(context, { preset: popoverPreset }),
  slots: (slot) => ({ trigger: popupTrigger(slot), content: popupContent(slot) }),
})
// React: const parts = createParts(share, { trigger: "button", content: "div" })
```

`createParts` returns `Root`, `Trigger`, `Content` components in each framework; the Web Components adapter
registers custom elements instead. Values are "default or controlled" (`defaultValue`, or `value` with
`onValueChange(value, details)` where `details` carries `reason`, `source` and `cancel()`), per the skill file.

### Accessibility

- ARIA attributes, roles, focus movement and keyboard maps come from the behaviors, not from the author.
- The skill tells agents never to hand-write roles next to an installed package: "A `div` with `role="listbox"` ...
  is almost always a bug" (`packages/core/skills/ui-sdk/SKILL.md`).
- `checkPattern(root, "tabs")` checks roles, names, states, part references and keyboard interactions for 15
  WAI-ARIA patterns, deliberately stricter than the APG in places (`core/testing.mdx`).
- Their own test suite runs axe, ARIA snapshots, a virtual screen reader (`@guidepup/virtual-screen-reader`) with
  a spoken-phrase log, right to left, SSR and leak checks per component (`tests/README.md`).

### Styling

Unstyled. Every part gets `data-slot`; state is exposed as data attributes (`data-open`, `data-pressed`) and CSS
variables; styled with CSS or Tailwind variants (`core/kernel/style-a-component.mdx`). An optional default look
ships as `@ui-sdk/core/web.css`. There is no design token system, no theme object and no design system beyond that
stylesheet (inference from the docs tree: the only theming guide is `guides/dark-mode.mdx`).

### Agent onboarding

| Piece | Source | What it does |
|---|---|---|
| Skill `ui-sdk` | `packages/core/skills/ui-sdk/SKILL.md`; install command in `docs/agents/skills.mdx` | Two paths (compose shipped components; build a missing one from behaviors), then "make it agent-ready" and "test it". Ends with a done checklist: typecheck, write and run tests, report each command with its exit code. Also ships inside the npm package so it matches the installed version. |
| Docs in the package | Skill file | `node_modules/@ui-sdk/<framework>/docs/llms.txt` as the index, one Markdown page per component. `core.md` is "over 300 KB", to be searched by heading, not read. |
| `llms.txt` | `ui-sdk.dev/llms.txt`, plus `/docs/<section>/llms.txt` | Index of indexes. `/docs/core/llms.txt` is about 390,000 characters. |
| `AGENTS.md` / `CLAUDE.md` | Repo root | For contributors' agents, not for users. The repo also has contributor skills (`.agents/skills/ui-sdk-write-code`, `-write-docs`, `-unslop`, `-expert-review`) and per-framework "expert" agents. |
| Agent bridge | `packages/core/src/page/agent`, `docs/agents/` | `createAgent()` on a running page exposes `snapshot()` (components, state, available actions), `act()` (for example `setValue` by label or ref), `query()` (a Select's options without opening it), `subscribe()`. Changes pass through the component's API with `source: "agent"` and can be cancelled; an `allow` callback gates actions; `data-agent-hidden`, `data-agent-secret`, `data-agent-confirm` control exposure. Can be registered with a browser through WebMCP. History and undo (`createHistory`, `stageChanges`) are marked experimental. |

### Prebuilt

51 component modules in core: accordion, autocomplete, avatar, button, calendar, carousel, checkbox, collapsible,
color-picker, combobox, command, date-input, date-picker, dialog (and alert-dialog), drawer, field, file-input,
hover-card, image-cropper, input, label, listbox, menu, menubar, meter, navigation-menu, number-input, otp-input,
pagination, password-input, popover, progress, radio, rating, resizable, scroll-area, segmented-control, select,
separator, slider, switch, tabs, timeline, toast, toggle, token-input, toolbar, tooltip, tree, trigger-menu,
waterfall.

### Maturity

| | Fact |
|---|---|
| Version | `0.1.0-beta.5`; README: beta, APIs "may change before general availability", under Vercel's beta terms |
| Age | Repo created 2026-10-26; 526 commits on `main`; last push 2026-11-16 |
| License | Apache-2.0 |
| Tests | 1,009 test or spec files: 365 Playwright specs in `tests/specs`, 221 unit tests in `packages/core/test`, 55 to 85 per adapter, 63 docs smoke tests. Size budgets (`size-budget.json`), perf and leak specs. |
| Issues | 84 open, 62 closed (GitHub search API); 8 open pull requests |
| Attention | About 5,100 stars and 165 forks in four days |

Three betas in one day suggests the API is still moving (inference).

### What the benchmark measured

Fact (`benchmarks/agent/README.md`): an agent **operating** a finished project-settings screen (three tabs, 24
member rows with menus, a confirm dialog, an accordion of switches), asked to make six changes and save. It
compares browser tools modelled on Playwright MCP (accessibility-tree snapshot, click, type) against the three
bridge tools (`snapshot`, `query`, `act`).

Their own control row is the important one: the UI SDK screen driven with browser tools costs the same as Base UI
(17 calls, 294k tokens, 56 s). They say so: "The difference comes from the agent tools."

So the benchmark says nothing about agents **building** UI with the library, and nothing about the behaviors. It
measures a semantic action API against DOM driving, on one task, three runs, one model, self-reported, with every
run correct. The home page's "more than twice as fast at less than half the cost" is this same result. I found no
published measurement of authoring speed, token cost or first-try correctness.

## 2. What Codelessly is

**One line (fact, `CodelesslyAPI/docs/design/12-agent-first-flutter.md` section 2):** "an agent-first UI framework
on Flutter's rendering pipeline", where the UI is a data document and Flutter's widget layer is replaced.

| Layer | Where | What it holds |
|---|---|---|
| Document | `CodelesslyAPI`, schema 3; entry `docs/reference/STARTER.md` | A flat node map (`roots`, `nodes`, `variables`, `conditions`, `scripts`, `breakpoints`). About 90 node types, 44 action types, bindings and formulas, `media` rules, components with parameters, slots and events, sites with `site.json`. Reference is generated from declarations; "every example here is checked by a test". |
| Levels | `docs/design/12-agent-first-flutter.md` section 3 | Six closed levels, 0 core to 5 feature layers; the validator can run at a level. |
| Notation (the DSL) | `CodelesslyAPI/lib/src/core/notation/` (`notation.dart` 196 KB, `reflow.dart`, `page_words.dart`, `prompt.dart` 27.6 KB, `print.dart`); design in `docs/design/13-compact-notation.md` | One node per indented line: `Type.variant#id "text" key:value =binding -> action`. Expands, line by line as it streams, to the same document. Accepts the forms models actually write. |
| Renderer | `CodelesslySDK/lib/src/render/` | Render objects directly. Its own controls in `render/controls/` (buttons, text field and editable, dropdown, menu, pickers, calendar, time dial, slider, toggles, chips, segmented, tab bar, tiles, expansion, app and navigation bars), its own focus scope (`focus.dart`), overlay layer (`overlay.dart`), flex/wrap/grid layout (`render/layout/`). Default look is SSUI, generated from tokens (`ssui_defaults.g.dart`). |
| Design systems as data | `CodelesslySDK/design_systems/ssui` (160 component documents), `design_systems/cards` (225), each with `design_system.json`, `DESIGN.md`, `PATTERNS.md` | Components are documents; themes are tokens; a notation line calls a component by name. |
| Check loop | `CodelesslySDK/tool/codelessly` (one entry point), `tool/render`, `tool/notation`, `tool/cli/mcp_server.py` | `docs`, `validate`, `render`, `outline`, `states`, `sheet`, `notation prompt/expand/apply`, `serve`, and all of it as an MCP server. Render takes scripted steps (`--tap`, `--hover`, `--focus`, `--key`, `--type`, `--set`, `--scroll`, `--drag`, `--navigate`), sizes, `--theme`, `--compare`, `--dump-layout`; output is PNGs plus `diagnostics.json` with a code and JSON pointer per problem. |
| Measured runs | `CodelesslySDK/examples/showcase/`, `docs/design/13` sections 10 to 14, `docs/projects/2026-11-milestone-1/` | See the table below. |

Measured (fact, `13-compact-notation.md`):

| | `ui_apply` JSON ops | Notation | A2UI v1.0 |
|---|---|---|---|
| Instructions | 26,033 tokens | 2,379 | 21,169 |
| Output per card, median | 3,300 | 935 | 1,612 |
| Output per node | 137 | 27.7 | 84.5 |
| Time to complete, median | 15.1 s | 5.4 s | 7.8 s |
| Valid on first answer | | 26 of 34 | 23 of 34 |

Responsive reflow (section 14): ten pages written for desktop only went from 74 render errors at 390 wide to 0;
seven test-5 sites (50 pages) from 130 errors at 390 to 2, with 49 of 50 desktop captures byte-identical.

Maturity (fact): `codelessly_api` and `codelessly_sdk` at 32.0.0; a BSD-style license (2023); 237 test files in
the SDK and 68 in the API; one keyboard test (`CodelesslySDK/test/actions/keyboard_test.dart`) and no file named
for semantics, focus or accessibility among the SDK's tests.

## 3. Comparison

| Dimension | UI SDK | Codelessly |
|---|---|---|
| Where the abstraction lives | Behaviors as TypeScript functions, composed in code into a primitive, rendered by a framework adapter | UI as a data document, written through a notation, expanded and drawn by one renderer |
| What the agent writes | A `definePrimitive` (for a new component), a `createParts` file, then JSX or templates, then CSS or Tailwind, then tests | Notation lines (or JSON document, or edit ops); no styling when a design system is given |
| Tokens and steps | Not published for authoring. Skill tells the agent to read docs, typecheck, write tests, run them | Published: 935 output tokens and 5.4 s per card, 2,379-token prompt; one expand-and-render call |
| Unit of reuse | A behavior (`createRovingFocus`) | A node type, or a component document in a design system |
| Platforms | Web: React, Vue, Svelte, Solid, Web Components; SSR | Flutter: iOS, Android, web, desktop, one renderer |
| Accessibility | First-class: ARIA from behaviors, `checkPattern`, axe, virtual screen reader, RTL | Present in the built-in controls; thin for composed components and generic nodes (section 4) |
| Keyboard | Roving focus, grid focus, spatial focus, typeahead, focus recovery, shortcuts as shared behaviors | Hand-written per control; shared part is Tab order, Enter/Space, Escape (`focus.dart`) |
| Theming and design systems | None beyond `data-*` hooks and an optional `web.css`; "you bring the styles" | Tokens, named colors and text styles, light and dark, design systems as data with DESIGN.md and PATTERNS.md |
| Responsiveness | Not addressed; left to the author's CSS. One page on mobile (`core/mobile.mdx`), sheets and drawers adapt | `media` rules in the document; automatic reflow in the notation; render at three sizes |
| State and data | Component state only (default or controlled); app state is the framework's | Variables, formulas, bindings, conditions, actions, API calls, storage, auth, scripts in the document |
| Verification loop | Typecheck, vitest with `mount`, `checkPattern`, `checkServer`; a real browser for color | Strict validation with codes and pointers, headless PNGs at sizes, scripted interaction, outline as text, pixel compare |
| What the loop can see | Behavior and semantics; not appearance (jsdom "can't see color") | Appearance and layout; not semantics or focus order |
| Runtime inspection by an agent | The agent bridge: `snapshot`, `query`, `act`, `subscribe`, permissions, WebMCP | None at run time. Authoring-time only: `outline`, `--dump-layout`, `ui_read` |
| Editing by a non-coder | No. The artifact is source code | Yes. The artifact is data the Codelessly editor opens; round trip to notation is designed (printer listed as not built in section 10) |
| Runtime delivery | Ships as code in the app's bundle | Ships as data; a published document updates a running app (server-driven UI); streams as it is written |
| Maturity and ecosystem | Four days public, beta.5, 1,009 test files, 5k stars, Vercel distribution, npm and five frameworks | Version 32, in-house, 305 test files, design systems of 160 and 225 components, a visual editor, no public agent distribution found |

### Discussion

**They are less similar than the launch language suggests.** Both say "for agents" and both hold that an agent
should compose tested parts instead of regenerating them. But UI SDK abstracts **interaction behavior** and
leaves layout, look, state and delivery to the agent's ordinary code. Codelessly abstracts **the whole UI** into
data and leaves almost nothing to code. UI SDK's answer to "what should an agent not rewrite each time" is focus
and ARIA. Codelessly's answer is everything.

**The overlap is the control layer.** Codelessly's `render/controls/` is doing by hand, per control, what UI SDK
factored into shared behaviors. `menu.dart` has arrows, Home/End, page keys, type-ahead, Escape and focus return;
`calendar.dart`, `slider.dart`, `segmented.dart`, `toggles.dart`, `kit_bars.dart`, `time_dial.dart` each carry
their own key map and their own semantics block. That works for a closed catalog. It does not extend to a
component a design system or an agent composes from boxes.

**The verification loops are complementary, almost exactly.** UI SDK can prove a tab list has the right roles and
arrow keys but cannot see that it is ugly or overflows at 390 px. Codelessly can prove a page renders with no
layout error at three sizes and looks right, but has no check that a screen reader or a keyboard user can operate
it.

**The agent bridge is the part closest to home, and Codelessly is better placed to build it.** The bridge needs a
typed model of components, state and actions; UI SDK had to add an `agent` key to primitives to get one. A
Codelessly document already is that model: nodes with ids, variables, declared actions. (Inference.)

**Token economics point opposite ways.** UI SDK optimizes "one shape everywhere" so a model writes the API
correctly, but the agent still writes a framework app, and the skill adds tests and a typecheck to every task.
Codelessly has measured numbers for authoring; UI SDK has none. Their only measurement is of operating a UI.

## 4. Codelessly's strengths and gaps

### Strengths

1. **Measured authoring cost.** Prompt, output tokens, time and first-try validity are recorded against A2UI and
   against Codelessly's own JSON ops (`13-compact-notation.md` sections 10 and 11). UI SDK publishes nothing
   comparable for building.
2. **Scope.** Layout, theme, state, data, navigation, responsiveness and delivery are in one document. UI SDK
   covers none of those.
3. **A loop that sees pixels.** `tool/codelessly render` with scripted states and sizes. Their skill has to tell
   the agent to check contrast "in a real browser".
4. **Design systems as data.** 160 and 225 components with DESIGN.md and PATTERNS.md, callable from one notation
   line. UI SDK has an optional stylesheet.
5. **Data, not code.** Editable in a visual editor, streamable, publishable to a running app, on mobile and
   desktop as well as web.
6. **Responsive by construction.** Reflow from one desktop-written page, with error counts before and after.

### Gaps relative to UI SDK

Checked in `CodelesslySDK/lib/src/render/` and `lib/src/runtime/`.

| Area | What exists (file) | What is missing |
|---|---|---|
| Focus model | `controls/focus.dart`: `ControlFocusNode`, `ControlFocusScope`, Tab and Shift-Tab in reading order with wrap, Enter/Space activate, Escape drops focus, keyboard-only focus ring | No nested scopes or focus trap; no restore when the focused node is removed (their `createFocusRecovery`); no grid or spatial movement as a shared piece |
| Roving focus | Per control: arrows in `segmented.dart`, `toggles.dart` (radio), `kit_bars.dart` (tabs, with Home/End), `calendar.dart` (grid, page keys) | No shared roving-focus behavior; a composed group of nodes cannot get "one Tab stop, arrows inside" |
| Typeahead | `controls/menu.dart` (`typeAhead`, line 600), used by menus and dropdowns | Only there; not available to a list, tree or grid |
| Clickable generic nodes | `runtime/actions/wiring.dart` `RenderReactions`: a node with a `click` reaction is a semantic button with `onTap` | It joins no `ControlFocusScope`, so it is not a Tab stop and has no Enter/Space. A hand-built button (the STARTER recommends "a `row` with a fill ... and a `click` reaction" for full control) is not keyboard-operable. This is the most important gap, because the notation and design systems produce many such nodes. (Fact for the missing focus node: no `ControlFocusNode` in `wiring.dart`. Not run-tested.) |
| Semantics authoring | Controls set `isButton`, `isSlider`, `isChecked`, `isToggled`, `isSelected`, `isTextField`, `isHeader`, tab roles, live regions for tooltip and slider value | The document has no label, role, heading level or alt text on a node. The only `semanticLabel` in the reference is for charts. An icon-only button, an image and a heading have no accessible name or role an author can set |
| Design system components | SSUI ships `Tree`, `FileTree`, `Combobox`, `CommandPalette`, `ColorInput`, `ReorderableList`, `ResizableRow`, `ContextMenu`, `Dialog` as documents | None of those ten files contains a `keyDown` reaction; one component across both design systems does. A document-built tree has no arrow keys, expand/collapse keys or tree roles |
| Dismissal | `menu.dart` `ControlPopup`: barrier, press outside, Escape, `onDismiss` returns focus; `kit_pickers.dart` sets `scopesRoute` and `namesRoute`; modals go through Flutter's `PopupRoute` (`app/ui/presentation_route.dart`) | Layered dismissal (Escape closes only the top of a menu-over-dialog), focus trap inside a document modal and focus return after it are not verified here; the notation's own notes list overlay gaps (section 14.2 "Not done") |
| Virtualized lists | `widgets/collections_data_list.dart` ("built lazily in slivers"), `collections_table.dart` ("builds only" what shows) | Keyboard movement to rows not yet built (their `createGridFocus` handles "cells that aren't rendered yet") is not addressed |
| Drag and drop, reorder | `draggable`, `dropTarget`, `reorder`, `reorderHandle` in the document; `widgets/collections_reorder.dart` (a `ReorderableListView` island with a `Semantics` wrapper) | No keyboard reorder or spoken reorder messages as a document feature; transfer between lists by keyboard; tree reorder |
| Resize | SSUI `ResizableRow`; `track` behavior with arrow, page, Home/End keys and `isSlider` (`drag_track.dart` lines 893, 1097) | No splitter node with the window-splitter pattern |
| Tree, color picker, combobox | Only as design system documents; `dropdown` is the nearest built-in | No built-in node for any of the three; no `aria-activedescendant` equivalent for a text field driving a list |
| Tests of behavior | `test/actions/keyboard_test.dart` | No per-control keyboard, semantics, screen reader or RTL suite; nothing like `checkPattern` |
| Agent distribution | `.claude/skills/codelessly-render/SKILL.md` in this workspace; `tool/codelessly mcp`; `docs.py` search | No public skill install, no `llms.txt`, no docs shipped inside a package |
| Run-time agent access | None | No equivalent of `snapshot` / `act` on a running app |

In fairness to Codelessly: the built-in controls are considerably better than "no accessibility". Menus, sliders,
calendars, tabs, segmented controls, radios and the time dial have real key maps and semantics. The gap is that
this quality stops at the edge of the built-in catalog, and nothing checks it.

## 5. What to take, and what not to copy

### Worth adopting

| Idea | Why | Where it lands |
|---|---|---|
| A behavior vocabulary in the document | Lets a composed component get keyboard and semantics without script. A few declarative behaviors cover most of it: `focusable`, `rovingFocus` (on a container: one Tab stop, arrows, Home/End, orientation), `typeahead`, `dismissible` layer, `focusTrap`, `selection` (single, multi, range) | New behavior keys beside `draggable`, `track`, `dismissible` (documented in `CodelesslyAPI/docs/reference/interaction.md`); implemented once in `CodelesslySDK/lib/src/render/controls/focus.dart` and `runtime/actions/wiring.dart`; then `segmented.dart`, `toggles.dart`, `kit_bars.dart`, `menu.dart` call the shared code instead of their own |
| Make clickable nodes Tab stops | Closes the largest single gap cheaply | `RenderReactions` in `wiring.dart` owns a `ControlFocusNode` when it has a `click` trigger; `onActivate` fires the click; focus ring from tokens |
| Semantics fields on a node | Names for icon buttons, alt text for image fills, heading levels, landmarks | A `semantics` object on the node (`label`, `role`, `heading`, `hidden`) in the API; notation words `label:"..."` and `Heading level:n` writing it; validator codes such as `unnamed_control` for an icon button with no label |
| A pattern checker | The piece of their design most worth copying: one function that checks roles, names, states and keys for a named pattern | `tool/codelessly render --check-a11y`, reading Flutter's semantics tree after layout and driving `--key`; new diagnostic codes in `diagnostics.json`; a per-control test suite under `CodelesslySDK/test/` |
| Semantics in the outline | Lets an agent see what a screen reader would, as text, next to the boxes | `tool/cli/outline.py` and `--dump-layout`: add role, label, focusable, Tab order index per node |
| An agent bridge for a running app | Codelessly already has ids, variables and typed actions; the bridge is a thin layer. Their permission model (`hidden`, `secret`, `confirm`, `source: "agent"`, cancellable changes) is a sound template | A `CodelesslyAgent` in `CodelesslySDK/lib/src/session/` exposing snapshot (screens, nodes with values, available reactions), query (a list's or dropdown's items) and act (fire a trigger, set a variable); the same over `tool/cli/mcp_server.py` for the headless harness, which already has `--tap`, `--type`, `--set` |
| `llms.txt` and versioned docs | The generated reference already exists; an index is nearly free. Their rule "prefer the installed copy: it matches the version" is right | `tool/reference/generate.dart` also writes `docs/reference/llms.txt`; ship `docs/reference/` in the published `codelessly_api` package |
| An installable skill with a done checklist | Their skill ends in "typecheck, test, report each command with its exit code". Codelessly's equivalent is "expand, render at three sizes, zero diagnostics, look at the sheet" | Promote `.claude/skills/codelessly-render/SKILL.md` to a published skill beside `tool/codelessly`, with one reference file per level |
| Their benchmark's control row | Running their own screen through the baseline tools separates the library's effect from the tool's. Good method | Apply to milestone runs: the same brief in notation, in JSON ops, and in code, same model and harness (partly done in section 11 of design 13) |
| "Don't hand-roll what we ship" as a validator rule | They enforce it in prose; Codelessly can enforce it in the validator | A warning when a `row` with a `click` and a single text duplicates a `Button`, or when a design system has the component being rebuilt from boxes |

### Not to copy

| Their choice | Why not |
|---|---|
| Behaviors as code the agent composes | It is their product and the opposite of UI as data. Adopt the vocabulary as declarative keys; do not expose a `definePrimitive` |
| Unstyled by default | Codelessly's measured advantage is that a zero-prop control already looks finished (design 12 section 3.1) |
| Five framework adapters | Their cost of being a web library. One renderer is Codelessly's simplification |
| 300 KB+ of docs the agent must search | Their `core.md` is "over 300 KB" and `/docs/core/llms.txt` about 390,000 characters. Codelessly's 2,379-token prompt and levelled reference is the better position; keep it |
| "Every task gets tests" written by the agent | Reasonable for code. For data, validation and rendering should be the test, run by the tool, not authored per task |
| The headline benchmark framing | "Twice as fast at less than half the cost" describes the bridge, on one task. Report Codelessly's numbers with the same care they took in the README, not the home page |
| 134 helpers as the public surface | Many are small functions. A dozen declarative behaviors is enough to close the gaps listed above |

## 6. Open questions and what was not verified

- **Authoring cost with UI SDK.** No published numbers. A fair test would give one of the milestone briefs to an
  agent with the `ui-sdk` skill and to one with the notation, same model, and compare tokens, time and defects.
- **Whether the behaviors hold up in use.** 84 open issues in four days; I did not read them. Their content would
  show where the behaviors break.
- **The "more than 50 behaviors" count.** I did not count `create*` exports in `packages/core/src/index.ts`; the
  134 figure is rows in the docs index, a different thing.
- **The skill's reference files** (`build-interface.md`, `create-component.md`, `agent-ready.md`, `testing.md`,
  `patterns.md`, `styles.md`, `web-components.md`) were listed, not read.
- **The benchmark was not run.** Numbers are theirs. `harness/task.mjs` (the prompt) was not read.
- **Codelessly modal focus.** Whether a document modal traps focus, closes on Escape and returns focus was not
  traced through `presentation_route.dart` and `presenter.dart`, and nothing was run.
- **Generic node focus.** The claim that a clickable `row` is not a Tab stop rests on reading `wiring.dart` and
  `focus.dart`, not on running the app with a keyboard or a screen reader.
- **Flutter web semantics.** How the SDK's render-object semantics reach a browser's accessibility tree (and so
  browser agents and WebMCP) was not examined. It matters if the agent bridge idea is pursued for web.
- **Codelessly's notation printer.** Section 10 of design 13 lists it as not built on 2026-11-14; `print.dart`
  exists now. Its state was not checked.
- **The `codelessly-editor` MCP server** failed to connect in this session, so nothing was checked in the editor.
- **WebMCP** is taken from their docs as described; the browser support it depends on was not checked.

## Sources

UI SDK (all read 2026-11-16):

- https://github.com/vercel-labs/ui (README, `AGENTS.md`, tree)
- https://github.com/vercel-labs/ui/blob/main/benchmarks/agent/README.md
- https://github.com/vercel-labs/ui/blob/main/packages/core/skills/ui-sdk/SKILL.md
- https://github.com/vercel-labs/ui/blob/main/packages/core/package.json
- https://github.com/vercel-labs/ui/blob/main/apps/docs/content/docs/core/behaviors/index.mdx
- https://github.com/vercel-labs/ui/blob/main/apps/docs/content/docs/core/changelog/introducing-ui-sdk.mdx
- https://github.com/vercel-labs/ui/blob/main/apps/docs/content/docs/core/testing.mdx
- https://github.com/vercel-labs/ui/blob/main/apps/docs/content/docs/core/kernel/style-a-component.mdx
- https://github.com/vercel-labs/ui/blob/main/apps/docs/content/docs/agents/index.mdx and `agents/skills.mdx`
- https://github.com/vercel-labs/ui/blob/main/tests/README.md
- https://ui-sdk.dev , https://ui-sdk.dev/llms.txt , https://ui-sdk.dev/docs/agents/llms.txt , https://ui-sdk.dev/docs/core/llms.txt

Codelessly (local, under `C:/Users/searc/Development/CodelesslyEditor/`):

- `CodelesslyAPI/docs/reference/STARTER.md`, `forms.md`
- `CodelesslyAPI/docs/design/12-agent-first-flutter.md`, `13-compact-notation.md`
- `CodelesslyAPI/lib/src/core/notation/`
- `CodelesslySDK/lib/src/render/controls/` (`focus.dart`, `overlay.dart`, `menu.dart`, and the others named above)
- `CodelesslySDK/lib/src/runtime/actions/wiring.dart`, `lib/src/widgets/collections*.dart`, `lib/src/app/ui/presentation_route.dart`
- `CodelesslySDK/design_systems/ssui`, `design_systems/cards` (`DESIGN.md`, `PATTERNS.md`)
- `CodelesslySDK/tool/codelessly`, `tool/render/README.md`, `tool/cli/mcp_server.py`
- `CodelesslySDK/examples/showcase/NOTES.md`
- `docs/projects/2026-11-milestone-1/README.md`
