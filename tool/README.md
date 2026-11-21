# The SDK's tools

Codelessly UIs are data: a JSON layout document (codelessly_api's `docs/reference/STARTER.md` describes it) that
this SDK renders straight to render objects. Because the renderer runs headless under `flutter test`, a document
can be checked and *seen* in a few seconds, without building or launching an app, an editor or a browser. These
tools are that loop, for the agents (and people) who write documents. Everything below runs from a fresh checkout
with Flutter installed; `codelessly_api` comes from the `CodelesslyAPI` checkout beside this one when there is one.

## Start here: `tool/codelessly`

One entry point for the authoring loop. `tool/codelessly help` lists the commands; each has `--help`.

```
                    ┌────────── fix what it reports ─────────┐
                    v                                        │
 docs ──> write JSON (or a nested tree ─> flatten) ──> render --outline ──> look at the PNGs / sheet
 (look up                                              (problems per node,     │
  a section)                                            boxes, texts)          v
                                                                 states: every state, compared
                                                                 with its reference, worst first
```

| Command | What it does | When |
|---|---|---|
| `doctor [--warm]` | Says what the toolkit finds: Flutter, the API checkout, the reference, the compiled commands, QuickJS. `--warm` compiles the render harness and renders a document, so the first render is fast and the check is real. Its exit status is 0 when rendering works, 1 when it does not (no Flutter, or the document did not render); the reference (docs and the notation need it) and QuickJS (only documents with scripts need it: `build_quickjs.sh` builds it) are said on their lines and do not fail it. | Once per machine or session; when a command can't find something. |
| `docs [query]` | The API reference from the shell: no query lists the pages; an anchor (`forms-validation-and-an-error-state`), a name (`row`, `navigate`, `textField`) or words (`sticky header`) print the best section and other matches. `--starter` prints the base's path. | Before writing a feature you haven't used. |
| `flatten <tree.json>` | A nested node tree, trees per breakpoint (`{"trees": {"mobile": ..., "desktop": ...}}`, as the editor's `layouts.createResponsive` takes them) or a document with nested children, to a flat layout document. `key` names a node; `"@key"` elsewhere becomes its id. | You (or a generator) write screens as nested trees; render them headless before installing them in the editor. |
| `render <doc \| site>... --out <dir>` | Publishes as the editor would, renders every screen at each size (`--sizes`, default phone, tablet, desktop) with `CodelesslyWidget`, after optional steps (`--tap`, `--type`, `--navigate`, `--hover`, `--drag`, `--set`, `--now`...), and reports what only rendering shows (overflow, clipped text, failed taps, missing fonts and images). `--outline` prints every capture's outline; `--sheet` writes `<out>/sheet.png`; `--compare` diffs against reference screenshots. All other options: [render/README.md](render/README.md). | Every time you want to see the result or check an interaction. |
| `outline <out> <doc \| site>...` | What a render drew, as text: each node's type, id, box and text, indented as the tree, with its problems. Zero-size nodes are marked. | Read before the PNG: most layout mistakes show as numbers. |
| `states <states.json>` | Renders every state a manifest lists (screen, steps, sizes, reference), compares each with its reference, writes `summary.md`/`summary.json` worst first and one `sheet.png`. Exit 1 when a state has errors or matches its reference less than `minMatch`. `--only <name>` picks the state of that name alone (a name no state has: every state whose name contains it); `--outline` (also in the manifest's or a state's `args`) writes each state's outline. A step's key is a render option without `--`, or the same in camel case (`longPress`). | Recreating an app screen by screen; checking a whole site after a change. |
| `sheet <png \| dir>... --out <png>` | Captures on one labelled image, one row per state, narrowest size first. | Showing a model (or a person) many captures at once. |
| `notation prompt|expand|print|apply`\|expand\|apply` | The compact authoring notation ([notation/notation.sh](notation/notation.sh)): the prompt a model gets, a notation text expanded to a document, a document printed back as the notation, ops applied to a document. A file in a site's folder is expanded with the site's components (its `components/*.txt` and those `site.json` lists), variables and theme; `notation expand <site folder>` expands the whole site, components first (also `tool/codelessly expand <site folder>`; each of these commands by its own name). A `.txt` that `site.json` lists is never written over: its JSON goes beside it, and the expand says to list that. `--dictionary <folder>` (or `CODELESSLY_DICTIONARY`, or a site's `"dictionary"`) reads a folder of definitions after the site's own. | Generating UI with a model in the notation instead of JSON. |
| `replay <stream.jsonl> --out <dir>` | A recorded `ui_apply` stream replayed headless: video, contact sheet, metrics ([stream/README.md](stream/README.md)). | Working on streaming generative UI. |
| `serve [--stop\|--status]` | Keeps the renderer running in the background ([render/serve.sh](render/serve.sh)), so every `render` and `states` run on this checkout skips Flutter's start: about 1 s a run instead of about 6. It serves the code it started with; after a change to the SDK or the API it is stopped and runs go the usual way until it is started again. Stops after 30 idle minutes. | Any session that will render more than a few times. The MCP server starts it by itself. |
| `mcp` | All of the above as an MCP server on stdio: `codelessly_docs`, `codelessly_render` (report, outline and PNGs in one answer), `codelessly_flatten`, `codelessly_states`. | Giving any MCP client (Claude Code, an IDE agent, your own) the render loop as tool calls. |

Register the MCP server with a client, e.g. a project's `.mcp.json`:

```json
{"mcpServers": {"codelessly": {"command": "/path/to/CodelesslySDK/tool/codelessly", "args": ["mcp"]}}}
```

A typical session:

```sh
tool/codelessly doctor --warm
tool/codelessly serve                                  # keep the renderer up: a render costs its drawing
tool/codelessly docs                                   # what's where
tool/codelessly docs "a row that becomes a column"     # the section for a need
tool/codelessly render site/ --out out/ --outline      # problems, boxes, texts; PNGs in out/
tool/codelessly render site/ --out out/ --screen contact --tap submit --label errors --outline
tool/codelessly states states.json                     # every state vs its reference: out/states/summary.md
```

Speed: with `serve` running, a render costs its drawing: about a third of a second for a page at one size, under
three seconds for six pages at three sizes; `expand` of a six-page site takes about a third of a second too.
Without the server a render first starts Flutter (about 5 seconds once the harness is compiled; the first after an
SDK change takes 20 to 60 seconds, `doctor --warm` does it up front). The commands are compiled once per change of
their sources (`tool/cli`, and the notation's with `codelessly_api`'s `lib/`: ten to twenty seconds, said as it
happens). `--timings` on `render` or a notation command (or `CODELESSLY_TIMINGS=1`) prints each phase's
milliseconds on stderr. Runs on one checkout take turns (a lock in `build/`, or the server's queue); use git
worktrees for runs in parallel.

## Every tool here

### The authoring loop (for agents)

| Path | What | Docs |
|---|---|---|
| `codelessly` | The entry point above. | this file |
| `cli/` | The entry point's commands, in Dart: `codelessly.dart` (the dispatcher) and `src/` (`docs`, `flatten`, `outline`, `states`, `render_cmd` (render with `--outline`/`--sheet`, and `sheet`), `mcp`). `tool/codelessly` compiles them to `build/codelessly_cli` when they change (about 3 s, once); they need nothing but Flutter's Dart. `test/tool/cli_test.dart` tests them. | each file's header |
| `lib/env.sh` | Shared by every launcher: finds Flutter, points the SDK at the sibling `codelessly_api` (a `pubspec_overrides.yaml` marked as written by the tools), resolves dependencies when stale, the per-checkout lock. | its header |
| `render/` | The render command: `render.sh` (launcher), `serve.sh` (the render server), `render_harness.dart` (the `flutter test` entry, one run or the server's loop), `src/` (arguments, site loading, publishing, fonts, rendering, steps, checks, compare). | [render/README.md](render/README.md), codelessly_api `docs/reference/render.md` |
| `notation/` | The compact notation's tools: `prompt.dart`, `expand.dart`, `print.dart`, `apply.dart`, launched by `notation.sh`. | `notation.sh` header |

### Measuring generative UI (research)

| Path | What | Docs |
|---|---|---|
| `stream/` | Streaming: `make_streams.dart` (synthetic streams), `replay.sh`/`replay_harness.dart` (replay), `run_all.sh`, `compose.py` (video), `summary.py`, `live_summary.py`, `arms_sheet.py`/`arms_table.py` (head-to-head of recording arms), `interactions/` (scripted interactions), `ui/` and `streams/` (fixtures). | [stream/README.md](stream/README.md) |
| `values/` | Are a generated card's values right after it is used: `check.py` renders recordings, drives each case's steps and reads the texts; `elicit.py`/`tally.py`/`reexpand.py` study how models write state. Cases in `cases.json`, `on_demand_cases.json`. | [values/README.md](values/README.md), `CASES.md` |
| `../examples/stream_chat/tool/` | Recording live model streams (`record.dart`, `record_all.sh`, the notation and A2UI arms). | that folder |
| `../design_systems/tool/new_design_system.py` | Scaffolds a design system folder. | [design_systems/README.md](../design_systems/README.md) |

### Maintaining the SDK (generators, fixtures)

| Path | What |
|---|---|
| `build_quickjs.sh` | Builds the QuickJS library the SDK's scripts run on under `flutter test` (renders run documents' scripts with it when present). |
| `controls/bundle_ssui.dart` | Bundles SSUI's tokens as the unstyled controls' defaults (`ssui_defaults.g.dart`). |
| `reference/extract_formulas.sh` | Writes the formula function table codelessly_api's reference generator reads. |
| `gen_material_icon_codepoints.dart`, `gen_material_icon_versions.py`, `generate_directional_icons.py`, `export_cupertino_svg.py` | Icon tables and glyphs, regenerated after a Flutter or font upgrade. |
| `render_docs_images.sh` | The developer guide's images. |
| `media_fixture.cjs`, `verify_embedded_player.cjs` | Local media transport and the embedded player's browser test. |

## Related tools elsewhere

- **codelessly_api** (`CodelesslyAPI/`): `tool/reference/generate.dart` generates `docs/reference` (the base, the
  pages, `index.json`, `catalog.json`, `document.schema.json`, the `ui_apply`/`ui_read` tool schemas) from the
  declarations; `tool/name_conformance.dart` checks names.
- **The editor** (`CodelesslyEditor/`): the editor MCP server (`packages/codelessly_editor_mcp`, with `ed.mjs` and
  `bridge.mjs` for shells) drives a live editor: projects, pages, publishing. Its `docs/ai_tools.md` inventories
  every tool across the repositories, including the reference-app parity workflow.
