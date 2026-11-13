## Unreleased

**UI an agent builds and edits, rendered while it streams (codelessly_api docs/design/08, phase 4)**

- `UiSession`: a document changed only by edit ops (codelessly_api's `applyOps`), a `NodeSource` over it, so an op
  re-applies only the boxes it changed. `apply` (one batch, one revision, one undo step), `applyStream` (a
  `ui_apply` tool call's raw text deltas; each op applies the moment it is complete; dangling ids reported at the
  end; `map`, `onOp`), `outline`, `read`, `tools`, `describeForModel`, `events` (`UiEvent`), `undo`/`redo`,
  `rev`/`revision`, `streaming`, `changes`, `pending`. The trust profile defaults to `TrustProfile.agent`; the
  check to the core's `catalogCheck` (pass `strictEditCheck()` for the strict validator).
- Progressive rendering: a pending child takes no room (or the size an op's `placeholders` gave it); a container
  none of whose children shows yet waits for its first (`holdEmptyContainers`); optional `arrivalFade`.
- `CodelesslyView(session:)`: the session's canvas with the core runtime alone (`CoreActions`); `vars` ops update
  bindings live; `componentEvent` outside a component (and `emitEvent`) reaches `session.events` with the node id
  and the evaluated payload; `navigate` switches between the session's canvases; media rules follow the view's
  width.
- New layer `lib/src/session` (architecture test); the core-only test proves its import closure reaches no feature.
- `tool/stream`: the replay command (`replay.sh`: a recorded stream through `applyStream` on a virtual clock, at
  phone and desktop sizes, to a video with an overlay, a contact sheet and metrics), `make_streams.dart`
  (synthetic streams of the four demo UIs at 60, 150 and 400 tokens/s, and two follow-up edits),
  `run_all.sh`; the outputs in `tool/stream/out/`.
- `examples/stream_chat`: a chat whose replies carry inline UI that fills in as the stream arrives, from recorded
  streams (`RecordedStreamSource`, with a widget test) or live (`LlmStreamSource`, Anthropic's Messages API through
  `anthropic_sdk_dart`, eager tool input streaming; the example's dependency only); `tool/record.dart` records a
  real generation (timed deltas, usage, one retry with the diagnostics, a follow-up edit).

**Sections and components by reference (codelessly_api docs/design/06, phase 1)**

- A call node (a node whose `type` is a component's) renders as its definition's nodes, each an ordinary box of
  the screen's render tree keyed by (node id, `ComponentInstance`), as list items are: lists of components, lists
  inside components and components inside components compose. `ComponentRegistry` (the definitions, by type;
  `define` replaces one in place, re-applying only the nodes that changed in every instance; `missing` lists calls
  rendered without one), `RegisteredComponent`, `InstanceSource`, `componentInstanceOf`, `componentPath`,
  `kMaxComponentDepth` (a cycle stops at 32 nested instances, as an empty box).
- `RenderTree(components:)`, `RenderTree.sourceOf`, `isInstanceRoot`, `pathOf`, `boxAtPath` (`plans/card1/cta`,
  `faq/fq#1`); `boxOf(callId)` finds the call's box (its definition root's). `NodeBox.source` and
  `NodeBuilder.source`: the document a box's node is in (recipes and render objects pass it to the binder instead
  of `tree.source`).
- `NodeBinder(projectScope:)`: a definition reads `${props.x}` (the call's parameters, bound in the caller's scope),
  its own variables (one set per instance), the project's variables and the runtime's scopes, never the caller's
  variables; a `variable` parameter reads and writes the caller's variable; conditions per definition.
  `ComponentScopes`, `ComponentProps`, `AmbientScope`, `ReferenceScope`, `referencedVariable`.
- `componentEvent` runs the call's `{"type": "event", "event": key}` reactions in the caller's scope with the payload
  as `${result}` (`fireComponentEvent`).
- `Codelessly(components:)` / `Codelessly.fromBundle(components:)`: the project's definitions, in memory; layouts
  decode with their catalog. Loading them from a publish is not done yet.
- Render command: a directory with `site.json` (or `components/`) is a site of pages and components;
  `--component <Type>` (`--props`, `--slots`) renders one component alone; steps name nodes inside instances by
  path; `component_missing`. Example: `examples/relay-pricing`, the m05 Relay pricing page split into sections,
  rendering pixel-identical to the original.

**Authoring fixes from the first direct-authoring experiment (cycle 1)**

- Renders the API's new `flex` node (Flutter `Flex`) with the row/column render object, its main axis from
  `props.direction` (bound or patched: a direction change re-lays the same child boxes).
- Applies a node's `media` rules (CSS media queries) for the screen's size before interaction states, bindings and
  conditions; a resize re-applies only the nodes whose holding rules changed (and their parents). Rows, columns
  and flex nodes lay their children out by `layout.order` (CSS order).
- A wrapping row/column/flex reads `layout.basis` (CSS flex-basis): lines are broken by the basis and filling
  children grow by `flex` to share their line (shrinking to a line narrower than the basis). Tests assert the
  rects CSS gives for `flex: 1 1 280px` at several widths.
- `gridView.minCrossAxisExtent`: auto-fit columns (CSS `repeat(auto-fit, minmax(min, 1fr))`).
- A node hidden by a media rule (or an interaction state's patch) takes no room, as one hidden by a binding does;
  one hidden in its own data (`"visible": false`) with no media rule about `visible` keeps its room, as before.
- **Bug fix (behaviour change):** a collapsed (hidden) child no longer takes a slot in `spaceBetween` /
  `spaceAround` / `spaceEvenly`: the shown children are spread as the Flutter Row without it would spread them (it
  already took no `spacing`). Tests compare every `MainAxisAlignment` with the real Row.
- **Bug fix (behaviour change):** a canvas's `appBar`, `bottomNavigationBar` and `floatingActionButton` slots are
  drawn, where Flutter's Scaffold puts them (they validated and drew nothing). A canvas with only a body lays out
  exactly as before. Tests compare with a real Scaffold.
- **Bug fix (behaviour change):** a `spacer` with no size along its row's or column's main axis is Flutter's
  `Spacer()`: it takes the free space by its `layout.flex` (it was 0 long and did nothing). A spacer with a size
  there is unchanged. Tests compare with Flutter's Spacer in a Row and a Column.
- **Bug fix (behaviour change):** `crossAxisAlignment: stretch` on a wrapping row/column/flex stretches each child to
  its line's thickest (CSS `align-items: stretch`; equal-height cards per line); it acted as `start`.
- Render command: a step may name a node by its `name` (the same name on each breakpoint canvas of a screen
  reaches whichever is shown); steps for nodes on another breakpoint's canvas are summarised in one warning per
  size instead of one per step.
- **Bug fix:** a text whose `props.runs` is bound shows its evaluated text, styled by the bound runs (it showed
  the formula's source: written runs split the template, bound runs are computed for the shown text).
- `IconSources.codepointOf`: a host's MaterialIcons codepoint table, so a Material icon named without a codepoint
  (a bound name) draws from the font offline. `NodeBox.capturePaintShift` (render command only).
- Render command (`tool/render`): `--tap`/`--hover` aim at a point a hit test proves reaches the node (a narrow
  text or icon in a wide slot, a node with a margin), scroll a node under an overlay to the middle of its scroll
  view, and report a tap that would land on another node (`interaction_failed`, naming it) or on nothing that
  reacts (`tap_no_reaction`); `--focus <id>` and `--type <id>=<text>` produce form states by real input;
  `--label` writes `diagnostics-<label>.json`; `--full-page` measures the page's own scroll view only and draws
  window-fixed content in the first window; every `render_exception` names its node and sub-pixel (< 0.01 px)
  flex overflows are not errors; new warnings `missing_glyph`, `icon_not_drawn`, `expression_not_evaluated`,
  `path_overflow`. Fixtures under `test/tool/fixtures/authoring`.
