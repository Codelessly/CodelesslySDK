## Unreleased

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
