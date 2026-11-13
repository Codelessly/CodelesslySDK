# Streaming generative UI: the replay command

A model's `ui_apply` tool call arrives as text deltas; `UiSession.applyStream` applies each edit op the moment its
text is complete, so the UI assembles while the answer streams. These tools make that visible and measured,
headless, from recorded streams.

```sh
dart run tool/stream/make_streams.dart                      # the synthetic streams (tool/stream/streams)
tool/stream/replay.sh tool/stream/streams/flights@150tps.jsonl --out out/flights   # one stream
tool/stream/run_all.sh                                      # every stream into tool/stream/out + summary.md
```

`replay.sh <stream.jsonl> --out <dir> [--sizes 390x844,1440x900] [--fonts dir]... [--frame-ms n | --frames n]
[--no-video]` replays the stream through `UiSession.applyStream` (the core catalog, `TrustProfile.agent`, the strict
validator on each op) on a virtual clock, at each size, and writes `<dir>/<size>/`:

| File | |
|---|---|
| `video.mp4` | The UI assembling (10 fps, the stream's time compressed to about 18 s), with a strip: elapsed time, tokens received (and a bar), nodes in the document, the source. Desktop sizes are scaled to 960 wide. |
| `contact.png` | Frames at 5, 15, 30, 50, 75 and 100% of the time to complete, with the metrics in the title. |
| `metrics.json` | Below. |
| `frames.json` | The timeline: per frame its time, tokens and nodes. |

Fonts are read from `--fonts` directories (default: the reference apps' font files at `../references`); a family no
file has is drawn with Roboto. Before an op applies, the harness does what the render command does offline
(`UiSession.applyStream(map:)`): local image paths become data URLs, text with no family gets Roboto (the test
environment has no platform font), icon names get their codepoints. Chat cards (`"kind": "card"`) are shown in a
chat column under the user's request; pages fill the window, and the page's scroll view follows the newest node
as a reader's eye would.

## Stream files

JSON lines: `{"meta": {...}}`, then one `{"tMs": 1234, "delta": "..."}` per delta (ms from the request). `meta` has
`ui`, `kind` (`card` or `page`), `source` (`synthetic` or `live`), `outputTokens`, and for a follow-up edit `base`
(the stream(s) that built the UI it edits) and `followup` (the instruction).

* **Synthetic** (`make_streams.dart`): each UI in `ui/` written as the ops a model would stream top-down
  (`opsFromDocument`: roots, the canvas and its state variables, then each section complete before the next, a
  large data variable just before the first node that reads it), as compact JSON one op per line, cut into deltas
  of 1 to 4 tokens at 60, 150 and 400 tokens/s, after a 500 ms time to first token. Tokens are estimated at 4
  characters each.
* **Live** (`examples/stream_chat/tool/record.dart`): a real generation's exact deltas and arrival times, with the
  API's usage. None are committed: the environment this was built in could not run them (see that README).

The UIs (`ui/`): `restaurant_menu.json` (147 nodes) and `saas_pricing.json` (196 nodes), pages written by AI agents
in the m05 authoring experiment (copied unchanged; `ui/assets` are the restaurant's images); `flights.json` (43
nodes: a flight-options card with a selectable list, a total and a confirm button that reports the choice) and
`weather.json` (54 nodes: a forecast card with a rain-alert button), written for this demo from the STARTER alone, as
a model would in a chat reply. `followups/` holds the two edits: "Sort them by price." (one `move` op) and "Make it
dark." (five `patch` ops).

## Metrics

| Key | Meaning |
|---|---|
| `ttftMs` | Time to the first token (synthetic: 500 ms; live: the API's first content event). |
| `timeToFirstPaintMs` | When the canvas first shows content (a canvas whose children have not arrived waits for them). |
| `timeToFirstSectionMs` | When the first section (a child of the page's main container, three or more nodes) is complete. |
| `timeToCompleteMs` | When the last op applied. |
| `opsApplied`, `opsRejected`, `rejections` | The stream's result: rejected ops with their codes (`EditResult.toModelJson()`). |
| `reappliedBoxesPerOp` | Boxes the render tree applied after each op (`NodeBox.debugApplyCounts`, the frame pumped after every delta that completed an op): min, median, 90th percentile, max. New boxes count: an op that brings a list's data applies its items. |
| `pumpsOverBudget16ms` | Frames whose build, layout and paint took more than 16.7 ms of real time in the headless pump (not a device measurement). |
| `renderExceptions` | Flutter errors (overflows above 0.01 px included) during the replay: none in any run. |

All runs (`tool/stream/out/summary.md`, written by `run_all.sh`):

| Stream | Size | Source | TTFT ms | First paint ms | First section ms | Complete ms | Output tokens | Ops applied / rejected | Re-applied boxes per op (min/med/p90/max) | Pumps > 16.7 ms | Render errors |
|---|---|---|---|---|---|---|---|---|---|---|---|
| flights@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 2653 | 3720 | 19328 | 2825~ | 45 / 0 | 0/0/6/9 | 0 of 1310 | 0 |
| flights@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 2653 | 3720 | 19328 | 2825~ | 45 / 0 | 0/0/6/9 | 10 of 1310 | 0 |
| flights@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 1300 | 1708 | 7561 | 2825~ | 45 / 0 | 0/0/6/9 | 2 of 1275 | 0 |
| flights@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 1300 | 1708 | 7561 | 2825~ | 45 / 0 | 0/0/6/9 | 15 of 1275 | 0 |
| flights@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 5833 | 8533 | 47571 | 2825~ | 45 / 0 | 0/0/6/9 | 2 of 1326 | 0 |
| flights@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 5833 | 8533 | 47571 | 2825~ | 45 / 0 | 0/0/6/9 | 9 of 1326 | 0 |
| flights_sort@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 607 | 607 | 608 | 17~ | 1 / 0 | 4/4/4/4 | 1 of 31 | 0 |
| flights_sort@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 607 | 607 | 608 | 17~ | 1 / 0 | 4/4/4/4 | 2 of 31 | 0 |
| restaurant_menu@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 4747 | 10087 | 86100 | 12840~ | 149 / 1 | 0/2/8/114 | 23 of 5354 | 0 |
| restaurant_menu@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 4747 | 10087 | 86100 | 12840~ | 149 / 1 | 0/1/7/113 | 30 of 5354 | 0 |
| restaurant_menu@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 2090 | 4098 | 32600 | 12840~ | 149 / 1 | 0/2/8/114 | 23 of 5292 | 0 |
| restaurant_menu@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 2090 | 4098 | 32600 | 12840~ | 149 / 1 | 0/1/7/113 | 34 of 5292 | 0 |
| restaurant_menu@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 11100 | 24483 | 214500 | 12840~ | 149 / 1 | 0/2/8/114 | 21 of 5280 | 0 |
| restaurant_menu@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 11100 | 24483 | 214500 | 12840~ | 149 / 1 | 0/1/7/113 | 31 of 5280 | 0 |
| saas_pricing@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 5133 | 9627 | 101527 | 15154~ | 202 / 0 | 0/1/15/51 | 31 of 6272 | 0 |
| saas_pricing@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 5133 | 9627 | 101527 | 15154~ | 202 / 0 | 0/1/14/51 | 57 of 6272 | 0 |
| saas_pricing@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 2240 | 3925 | 38385 | 15154~ | 202 / 0 | 0/1/15/51 | 38 of 6214 | 0 |
| saas_pricing@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 2240 | 3925 | 38385 | 15154~ | 202 / 0 | 0/1/14/51 | 59 of 6214 | 0 |
| saas_pricing@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 12100 | 23350 | 253067 | 15154~ | 202 / 0 | 0/1/15/51 | 39 of 6244 | 0 |
| saas_pricing@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 12100 | 23350 | 253067 | 15154~ | 202 / 0 | 0/1/14/51 | 52 of 6244 | 0 |
| weather@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 2580 | 3620 | 18445 | 2692~ | 55 / 0 | 0/2/6/13 | 3 of 1251 | 0 |
| weather@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 2580 | 3620 | 18445 | 2692~ | 55 / 0 | 0/2/6/13 | 8 of 1251 | 0 |
| weather@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 1278 | 1670 | 7229 | 2692~ | 55 / 0 | 0/2/6/13 | 1 of 1206 | 0 |
| weather@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 1278 | 1670 | 7229 | 2692~ | 55 / 0 | 0/2/6/13 | 6 of 1206 | 0 |
| weather@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 5717 | 8283 | 45363 | 2692~ | 55 / 0 | 0/2/6/13 | 2 of 1267 | 0 |
| weather@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 5717 | 8283 | 45363 | 2692~ | 55 / 0 | 0/2/6/13 | 7 of 1267 | 0 |
| weather_dark@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 973 | 973 | 1538 | 156~ | 5 / 0 | 1/3/7/7 | 1 of 100 | 0 |
| weather_dark@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 973 | 973 | 1538 | 156~ | 5 / 0 | 1/3/7/7 | 3 of 100 | 0 |

~ estimated (characters / 4). Times are on the replay's virtual clock from the request: the stream file's delta times.

## How it looks, honestly

* **Cards** assemble top-down with no empty shells: the canvas waits for content, a container waits for its first
  child, a pending child takes no room. Each option row appears whole enough to read (its radio, then its times,
  then its price). The weather card's hourly strip is `spaceBetween`, so its five columns re-space as each arrives
  (a small horizontal shift, four times).
* **Pages** paint their header within 2.1 to 12 s depending on the rate (a few hundred tokens in), and every later
  section grows the page downward; the follow-scroll keeps the newest content in view. Before the hero's dark
  background arrives, the header sits on the page's cream background for a moment (the band arrives with its
  section). The restaurant's menu list shows "0 items" until its data variable (8 KB) arrives right before the
  list, then all items at once (the op that re-applies 113 boxes).
* **Full pages are long answers**: 12.8k and 15.2k output tokens, 33 to 253 s from first token to complete.
  Streaming makes the first section readable within 4 to 24 s; the total is what the format costs (doc 08 §4).
* **Edits are small**: the follow-ups are 17 and 156 tokens against 2,825 and 2,692 to regenerate the cards.
* One op of the restaurant page is rejected by the agent profile (a `print` action, a feature of the data library):
  the stream goes on and the result tells the model which op, why, and what is allowed.
