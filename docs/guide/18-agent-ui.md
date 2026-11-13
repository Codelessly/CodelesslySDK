# 18. UI an agent builds and edits: `UiSession` and `CodelesslyView`

A model can answer with UI instead of text: it calls a `ui_apply` tool whose input is a list of edit operations on a
Codelessly document (codelessly_api guide §20 and chapter 11), and the SDK renders the document natively **while the
tool call streams**, then keeps it live: its variables, bindings, conditions and reactions run, and what the user
does in it goes back to the model. A follow-up ("make it dark", "sort by price") is a few more ops on the same
document, not a new answer.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';

final session = UiSession(); // the core catalog, TrustProfile.agent, catalogCheck

// The model's ui_apply input, as the API streams it (input_json_delta text):
final result = await session.applyStream(toolInputDeltas);
sendToolResult(result.toModelJson());              // rejected ops with codes, dangling ids

session.events.listen((e) => sendUserTurn(e.toModelMessage())); // a tap the UI routes to the model

// In the chat:
CodelesslyView(session: session);
```

## `UiSession`

| | |
|---|---|
| `UiSession({document, catalog = Catalog.core, profile = TrustProfile.agent, check = catalogCheck, arrivalFade, holdEmptyContainers = true})` | A document an agent writes. `check: strictEditCheck()` (from `package:codelessly_api/validate.dart`) runs the strict validator on each op's nodes. |
| `apply(ops, {author, baseRev, atomic})` | One batch (a list of `EditOp`s or the tool input JSON): one revision, one undo step. Returns the `EditResult`. |
| `applyStream(deltas, {author, baseRev, map, onOp})` | A streamed tool input: each op applies the moment its text is complete; one revision and one undo step for the whole stream; ids still pending at the end are `dangling_child` errors in the result. `map` rewrites each op first (asset URLs to a CDN); `onOp` reports each op. |
| `outline()`, `read(input)` | What a model reads (the `ui_read` tool). |
| `tools` | The two tools (`ui_apply`, `ui_read`) for the session's catalog restricted by its profile. |
| `describeForModel({starter})` | The node and action types the model may use, after a starter guide. |
| `events` | `UiEvent`s: `event`, `value` (evaluated), `source` (the node id), `rev`; `toModelMessage()`. |
| `undo({author})`, `redo({author})` | The last batch's inverse ops, applied atomically and checked like any batch. |
| `rev`, `revision`, `streaming`, `changes`, `pending`, `document` | State, as values and listenables. |

It is a `NodeSource`: an op notifies only the nodes it changed, so the render tree re-applies only their boxes.
Measured in the tests: a patch re-applies one box; a node arriving under a parent that already listed it re-applies
only its own box. Placing a node under a parent that did not list it changes the parent's child list, which
re-applies the parent and its children (each child's slot holds its parent node) — the streaming order (a node
lists its children when it is set) avoids that.

## How a streaming UI renders

* Nothing paints until a root canvas has content.
* A child listed before its node arrives takes no room (it is hidden as a binding hides a node, so a row's spacing
  skips it), or the size a `set` op gave it in `placeholders` (a neutral box, `placeholderColor`).
* A container none of whose children shows yet (each pending, or waiting the same way) waits for its first
  (`holdEmptyContainers`), so no empty bordered shells flash while a stream runs.
* An op applies whole: no half-written text or value is ever shown.
* `arrivalFade: Duration(milliseconds: 180)` fades each arriving node in (an `enter` animation from opacity 0). Off
  by default.
* Images load as they do anywhere: a fixed-size image box keeps its size while the bytes arrive, so nothing moves.

## `CodelesslyView`

`CodelesslyView(session: session, canvas: 'home', imageLoader: ..., data: {...}, handlers: {...})` shows the
session's canvas and follows it as ops apply. A canvas whose height hugs its content (`"height": {"hug": 400}`)
is as tall as its content in an unbounded parent (a chat message in a list); otherwise it fills the space it is
given. Media rules follow the width it is shown at.

It runs the document with the core runtime alone (`CoreActions`, no feature library): a `vars` op updates the
bindings that read the variable at once; `navigate` shows another of the session's canvases in the view (`pop`
goes back); modals and toasts show over the app's `Navigator`. A `componentEvent` outside any component (the
document is the agent's, not a component) is delivered to `session.events`, and so is an `emitEvent` when the
catalog has it:

```json
{"trigger": {"type": "click"},
 "actions": [{"type": "componentEvent", "event": "confirmFlight", "value": {"flight": "${selected}"}}]}
```

## The trust profile

An agent's document is untrusted input. `TrustProfile.agent` (the default) allows the core's node types and local
actions (variables, values, in-document navigation, modals, toasts, scrolling, focus, animation,
`componentEvent`): no `runScript`, no `callFunction`, no links, no feature library's node or action types, at
most 1500 nodes, 40 levels, 4000 characters of text and 2000 ops per call. An op that uses anything else is
rejected with `capability_not_allowed` (or `limit_exceeded`), the path and what is allowed; the model reads it in
the tool result and resends. Widen it for an app: `TrustProfile.agent.copyWith(linkHosts: {'example.com'},
actions: {...TrustProfile.agentActions, 'openLink'})`.

`UiSession` and `CodelesslyView` import the model through `package:codelessly_api/core.dart` only and no feature of
either package (`test/core_only_import_test.dart` proves it): a renderer-only app can host agent UI.

## Seeing it: the replay command and the chat example

`tool/stream/replay.sh <stream.jsonl> --out <dir>` replays a recorded stream headless on a virtual clock and writes
a video, a contact sheet and metrics (time to first paint, first section, complete; boxes re-applied per op). See
`tool/stream/README.md`, with the four demo UIs at three output rates in `tool/stream/out/`.

`examples/stream_chat` is a chat whose replies carry inline UI that fills in as the stream arrives, offline from
recorded streams or live against a model (`--dart-define=ANTHROPIC_API_KEY=...`).
