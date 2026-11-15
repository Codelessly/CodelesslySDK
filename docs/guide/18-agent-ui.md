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

## A model that writes the notation, with a design system

The shortest path from a model's answer to a designed card: the model writes the compact notation (a few lines of
text, no tool call), and the session's design system supplies the look and the ready-made blocks.

```dart
import 'package:codelessly_api/codelessly_api.dart' show DesignSystem;
import 'package:codelessly_sdk/codelessly_sdk.dart';

// A design system is a folder (design_system.json, components/, DESIGN.md, PATTERNS.md). Load it through a
// function that reads one of its files by its path in the folder: from disk, from assets, from a server.
final cards = await DesignSystem.load((ref) => rootBundle.loadString('assets/design_systems/cards/$ref'));

final session = UiSession(designSystem: cards);

// 1. What the model is told: the notation, and the blocks it may call. Name the blocks to keep it short.
final system = session.notationInstructions(blocks: {'ChatCard', 'Details', 'OptionList', 'ActionButton', 'Receipt'});

// 2. The model's answer, as it streams (a Stream<String> of text deltas), is applied line by line.
final result = await session.applyNotation(answerDeltas); // or Stream.value(wholeAnswer)

// 3. In the chat. No canvas is named: the view shows the session's first canvas.
CodelesslyView(session: session);
```

| | |
|---|---|
| `UiSession(designSystem: ds, theme: ...)` | The session's blocks and looks are the design system's; `theme` is laid over its tokens. |
| `notationInstructions({blocks})` | The system prompt: the notation's grammar, the design system's blocks (all of them, or the ones named), and how its pieces go together (its PATTERNS.md "In brief"). |
| `applyNotation(text, {options, prelude, author, onOp})` | Applies a streamed answer: each line becomes nodes the moment it is complete, one revision and one undo step for the whole answer. Returns the `EditResult`. |
| `prelude` | Notation the host puts before the answer: state that must be right and is not the model's to write (`state cart=[...]`, a clock). |
| `addBlock(definition)` | Adds a block (a component document) to the session's design system while it runs, or replaces the one of that type: the next `notationInstructions()` lists it, the next answer may call it, and a view already on screen draws it. For a block designed after the session began because none fitted a request. |
| `notationInstructions(askForBlocks: true)`, `wantedBlocks` | The model is told to name a block where none fits (`Wanted "PollResults" "each option with its share"`, the part built from plain types under it). The part shows as written; what was asked for is in `wantedBlocks` after the answer. |
| `applyNotation(text, replace: true)` | The answer takes the place of the UI the session holds, in one revision: a card written again once its block exists. Without it a session that has a UI refuses a second one. |
| `notationIssues` | What the notation could not read in the last answer, by line and column: send these back to the model for a second try. |

What to know:

* The answer is drawn on a canvas named `screen`. A view with no `canvas` shows it; pass `canvas:` only when the
  session holds several.
* A block that takes children (a card frame) shows each child as its line arrives. The view is not rebuilt and
  needs no key that changes.
* Events a card emits (`-> emit confirm order`) arrive on `session.events`, as with any session.
* Looks are written as the design system's token names, so the same answer shown under another design system
  with the same names, or in dark mode, takes that look with nothing rewritten.
* A block read from a file is decoded with the catalog:
  `LayoutDocument.fromJson(json, catalog: standardCatalog)`. To use it in another session, call `addBlock` there
  too: a block belongs to the session it was added to until it is stored in the design system's folder.
* `applyStream` (below) is the other path: a model that calls the `ui_apply` tool with edit operations. It can
  change a UI already on screen node by node; the notation writes a whole card.

### Blocks designed while the session runs

`OnDemandBlocks` takes what the answers ask for to a designer you supply (a stronger model, a service, a lookup in
a library), checks what comes back, and adds it to the session:

```dart
final blocks = OnDemandBlocks(
  session,
  design: (wanted, session, notes) => myService.design(wanted.name, wanted.purpose, notes), // a component document, or null
  check: (wanted, definition) => myRenderCheck(definition), // your own gate: problems, none to pass
  // Keeps the block for the sessions that follow: the files that hold it in the design system's folder (its
  // definition, and the manifest that now lists it), written wherever you keep the design system.
  store: (files) async {
    for (final e in files.entries) {
      await (File('$folder/${e.key}')..createSync(recursive: true)).writeAsString(e.value);
    }
  },
);

final system = session.notationInstructions(askForBlocks: true);
await session.applyNotation(firstAnswer);        // the card shows now, the wanted part from plain types
final outcomes = await blocks.designWanted();    // minutes, in the background
if (outcomes.any((o) => o.added)) {
  // The next answer calls the block by name. To swap the card on screen, ask the model again and:
  await session.applyNotation(secondAnswer, replace: true);
}
```

A design is kept only when it is a component of the name asked for, made of node types the session has, calls
no cycle, and passes `validate` and `check`. Give `validate` the strict validator of
`package:codelessly_api/validate.dart` (the session's own code is the core only, so it is the host's to pass;
the class's comment has the four lines). A refused design is asked for again
with the problems as `notes`, up to `maxTries`. A block already being designed is not asked for twice. Designing
one takes a strong model two to four minutes (`examples/showcase/on-demand`); composing with it afterwards
costs nothing extra.

### The design pass: fast first, then designed

A card written from plain parts shows within seconds and looks generic. `DesignPass` takes it to a design agent
you supply (a stronger model), which answers with edit operations that restyle the card where it stands. The
card is not written again: its texts, state, bindings and actions stay.

```dart
await session.applyNotation(answerStream);            // the plain card shows now
final pass = DesignPass(
  session,
  design: (request) async {
    // request.instructions is the system message, built from the session and its design system: the role,
    // what must not change, DESIGN.md, the theme's names, the edit operations and the card's nodes.
    // Show the model the card as a picture too when you can. On a later round, request.problems says what
    // the last answer was refused for. Return its text, {"ops": [...]}, or the list.
    return await myModel(system: request.instructions, problems: request.problems);
  },
  check: () async {
    await WidgetsBinding.instance.endOfFrame;         // let the view lay it out
    return [for (final d in session.shownDiagnostics()) d.message];
  },
);
final outcome = await pass.run(request: 'three flights to choose from');
```

* An answer is applied as one batch by the author `DesignPass.author`. It is refused, undone and asked for again
  (up to `maxRounds`, 2) when an operation is rejected, when it changed what the card says or does (a text, a
  label, an action, a data binding, a variable, a node that showed content: `DesignPass.changedMeaning`), or when
  your `check` reports a problem. With no answer that passes, the plain card stays.
* A kept pass is one undo step: `session.undo(author: DesignPass.author)` puts the plain card back.
* The session needs a design system with a `DESIGN.md` and a theme that names its colors, text styles, radii and
  shadows. It needs no blocks beyond one to show the agent how a node is written.
* `pass.instructions()` returns the system message alone, to read or to send yourself.

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
session's canvas and follows it as ops apply; with no `canvas`, or one the session does not have, it shows the
session's first canvas. A canvas whose height hugs its content (`"height": {"hug": 400}`)
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
