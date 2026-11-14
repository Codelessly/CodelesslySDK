# A2UI answers on A2UI's own renderer

Draws each recorded A2UI v1.0 answer (`tool/stream/streams/live/<run>/*.a2ui.jsonl`, the retry's when there was
one) with A2UI's own web renderer: `@a2ui/web_core`'s v1.0 message processor and basic catalog under
`@a2ui/lit`'s `<a2ui-surface>`, release 0.15.0, default styles. It is the other half of the head to head: the
same answers are drawn by CodelesslySDK through `parseA2ui`.

    npm install
    npm run bundle
    node shoot.js ../../../../tool/stream/streams/live/2026-11-14-a2ui-1 shots

`shots/<cell>.png` is the surface at 390 wide; `shots/results.json` says, per answer, what the processor refused
as written (`asWrittenErrors`), which keys were renamed for a second try (`renamed`) and what it refused then
(`errors`). The published v1.0 schemas spell a component's `@checks` and `@accessibility` with an `@`; release
0.15.0 reads `checks` and `accessibility`, so an answer that follows the schemas is refused until they are
renamed. Both counts are reported.

Playwright comes from the machine (`require('playwright')`); nothing here calls a model.
