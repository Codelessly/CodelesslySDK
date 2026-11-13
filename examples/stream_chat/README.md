# Generative UI chat

A minimal chat whose replies carry inline UI: each reply is a `UiSession` shown by `CodelesslyView`, filling in as
the model's `ui_apply` tool call streams. Tapping in the UI (choosing a flight, confirming) is the user's next turn;
a follow-up ("Sort them by price.", "Make it dark.") edits the same UI with a few ops instead of regenerating it,
and the reply says how many output tokens that took.

## Setup

The example builds against the `codelessly_api` the SDK is developed with (it does not compile against the hosted
24.0.0). Point it at the sibling checkout once (it writes the git-ignored `pubspec_overrides.yaml`):

```sh
tool/use_local_api.sh            # or: tool/use_local_api.sh path/to/CodelesslyAPI, or CODELESSLY_API=...
flutter pub get
tool/check.sh                    # what CI runs: the override, analyze with no issue, the offline tests
```

```sh
flutter run                                                   # recorded streams, offline
flutter run --dart-define=ANTHROPIC_API_KEY=<key> \
            --dart-define=MODEL=claude-sonnet-5-5              # live (default model: claude-haiku-5-5)
```

| File | |
|---|---|
| `lib/main.dart` | The chat screen. |
| `lib/src/sources.dart` | `StreamSource`, `RecordedStreamSource` (plays `assets/streams/*.jsonl` at their recorded pace), `LlmStreamSource` (live, compact prompt). |
| `lib/src/llm.dart` | The live request (pure Dart, shared with the record command): Anthropic's Messages API through `anthropic_sdk_dart`, the tools with `eager_input_streaming`, the `input_json_delta` text of the `ui_apply` call fed straight to `UiSession.applyStream`; `UiModel.turn` answers `ui_docs` and `ui_read` calls before the `ui_apply` call of the same turn; the briefs. |
| `assets/system_prompt.md` | The **full** system prompt (`dart run tool/system_prompt.dart`: the op rules, the node and action types, and codelessly_api's base in its file form, `docs/reference/STARTER.md`): 48,833 characters. |
| `tool/record.dart` | Records one real generation, its retries and its follow-up in the replay format. |
| `tool/record_all.sh` | The live matrix: records, replays and writes one summary table. |

## Prompts

`PromptVariant.compact` (the default, `--prompt compact`) sends codelessly_api's **base** in its runtime form,
`runtimeStarter()` (`docs/reference/RUNTIME_STARTER.md`), generated at run time from the same template and
declarations as the base an agent reads as a file (`STARTER.md`): the answering rules, the document and the node
map, layout, decoration and text, the theme, one table of the base node types (the button family, `textField`,
`checkbox`, `switch`, `radio`, `slider`, `dropdown`, `segmentedButton`, `listView`, `gridView` included) and one
of which types take children or slots, variables, bindings and reactions, media rules, the rules that are easy to
get wrong, the ops and two examples that apply cleanly, and the index: a task table and the pages, each entry a
`ui_docs` topic. `ui_docs`, the third tool, answers with the reference's pages, one section at a time (a page's
"When to use", minimal example and pitfalls; a section by its anchor; any node type, action, trigger or behavior
by name). 43,343 characters of prompt and 2,126 of tools, against 48,833 and 8,369 for `--prompt full`. Without a
tokenizer here: ≈ 12,400 tokens at 3.5 characters per token; ≈ 18,300 at the 2.37 characters per token the API
counted for the earlier full prompt. The record command counts both with the API when it runs
(`systemPromptAndToolsTokens`).

App briefs (`form_builder`, `sudoku`, `basketball`, `kanban`, `habits`, `memory`) get `TrustProfile.agentApps`
with `--scripts on` (the default): the document's own sandboxed scripts (the `scripts` op, `runScript`,
`script.name(...)`; capabilities `variables.read`, `variables.write`, `clock`), and a base prompt that says when to
prefer a script. `--scripts off` keeps `TrustProfile.agent`.

Supported models (`MODEL`, `--model`): `claude-haiku-5-5` (default: fast inline answers; thinking off, so the tool
choice is forced to `any`: a turn cannot end without a tool call), `claude-sonnet-5-5` (thinking off between tools),
`claude-opus-5-5` and `claude-fable-5-2` (adaptive thinking; it cannot be turned off). Sonnet 5.5, Opus 5.5 and
Fable 5.2 reject a forced tool choice, so they get `auto`, and a turn that ends with text only is nudged once
("Answer with the ui_apply tool call now"). Effort is low for all.

## Recording real streams

```sh
ANTHROPIC_API_KEY=<key> dart run tool/record.dart --ui flights --model claude-haiku-5-5 \
    --out ../../tool/stream/streams/live/flights@claude-haiku-5-5.jsonl --followup [--prompt compact|full] [--retries 2]
../../tool/stream/replay.sh ../../tool/stream/streams/live/flights@claude-haiku-5-5.jsonl --out ../../tool/stream/out/live/flights-haiku
```

It saves the exact `ui_apply` input deltas with their arrival times (`{"tMs", "delta"}` lines after a `{"meta"}`
line with usage, the lookups made first, and how the ops fared). Then **the retry protocol**: the ops are applied
as a session applies them (strict validation, the end of the stream, the lints of a finished UI: a button with no
label, text in its background's colour, characters Roboto cannot draw); while anything is rejected, pending or
linted, the tool result (`EditResult.toModelJson()`: rev, the ids that applied, every rejected op with code, path,
expected and suggestion, pending ids, and `next`: fix by patching the document as it is, same ids, never start
over) goes back and the retry is recorded (`.retry.jsonl`, `.retry2.jsonl`...), at most `--retries` times (2;
apps 3). A retry that rebuilds under a new root or canvas is answered with `start_over`. With `--followup` it then
sends the brief's follow-up edit (`.followup.jsonl`). `.summary.json` has the numbers. The key is read from the
environment only: nothing writes it, and the files hold no request headers. Without the key the command exits
with status 2 and says so.

## The live matrix

```sh
ANTHROPIC_API_KEY=<key> tool/record_all.sh                 # everything; --repeats 2 per card and page cell
ANTHROPIC_API_KEY=<key> tool/record_all.sh --only apps --app-repeats 2
tool/record_all.sh --dry-run                                # the cells and commands, no request
```

Cells: the two cards (flights, weather) on `claude-haiku-5-5`, `claude-sonnet-5-5` and `claude-opus-5-5`, each
with `--prompt compact` and `--prompt full` and the follow-up; the two page briefs on haiku and sonnet (compact);
the six app briefs on sonnet and opus (compact, scripts on; `--app-repeats`, default 1), haiku once each, and
sudoku and basketball once with scripts off. Recordings go to `../../tool/stream/streams/live/<date>/`, replays
(video, contact sheet, metrics, and for apps the scripted "works when used" interaction of
`tool/stream/interactions/<ui>.json`) to `../../tool/stream/out/live/<date>/`, and one table to
`summary.md` / `summary.json` there: per cell the time to first token, first paint and first text, complete,
output tokens and tokens/s, ops written / applied / rejected / recovered from malformed input, lookups, retries,
final diagnostics, scripts, works when used, follow-up tokens and time, and input tokens (uncached, cache read,
cache write). The script applies `tool/use_local_api.sh`, builds QuickJS for the replays' scripts
(`tool/build_quickjs.sh` of the SDK) and skips cells already recorded, so it can be resumed.
