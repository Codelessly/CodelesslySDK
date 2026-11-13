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
