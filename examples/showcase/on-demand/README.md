# Blocks designed on demand

The experiment for the gap between ready-made blocks and new design (codelessly_api
`docs/design/15-the-middle-and-generated-apps.md` §4.8 to §4.11): when no block of a design system fits a
request, a designer that can see its own renders adds one, and from then on the fast path composes it like any
other block.

`../tool/design_block.py` is the loop. With a model:

    ANTHROPIC_API_KEY=... python3 examples/showcase/tool/design_block.py --name PollResults \
        --brief-file on-demand/poll/block-brief.txt --card-file heldout/briefs/poll.txt --out <dir> --rounds 2

With a person or an agent as the designer, given exactly what the model is given:

    python3 examples/showcase/tool/design_block.py brief --name PollResults --out <dir>
    python3 examples/showcase/tool/design_block.py check --name PollResults --out <dir> --block <file.json> --card <file.txt>

`brief` writes the instructions word for word (the system's principles, its theme names, three of its blocks as
written, the notation). `check` is one round: it validates the block and the card, renders the block alone from
its first preview and the card as it first appears, light and dark, and lists every problem reported. The design
system is copied to `<dir>/ds`; only the copy changes.

| Run | Rounds | To first block | Total | Problems by round | What came out |
|---|---|---|---|---|---|
| `poll/` (PollResults) | 3 | 84 s | 251 s | 0, 0, 0 | Share bars, the leader in the accent, the voter's choice, the total; right in light and dark. Round 3 changed almost nothing. |
| `player/` (NowPlaying) | 2 | 164 s | 271 s | 3, 0 | Drawn art, track and artist, progress with times, a transport row. Round 1's card wired the block's events in a way the notation does not read; round 2 fixed it. |
| `stock/` (StockQuote) | 2 | 87 s | 173 s | 0, 2 | The price as the leading figure, change chip, a sparkline on the engine's `lineChart` node, open, high, low, volume. Round 1 is the one kept: round 2's card wrote `enabled:=false`, which the notation then read as a variable (fixed since). |
| `habit/` (HabitStreak) | 3 | 98 s | 233 s | 10, 4, 0 | The streak as the leading figure with a flame, the week as marks (done, missed, today, ahead), the best streak, a check-in. Run on the changed harness; the outside run of this block on the old one was cut off at the output limit in round 1. |

The brief names every node type the engine has and carries the chart nodes in full. Before it did, a standalone
run of this same block had the model draw the chart point by point until it hit its output limit and produced
nothing.

Six outside runs of the loop with a model (branch `codex/on-demand-six-runs`, on the harness before the changes
below; five blocks on the larger model, one repeated on the smaller) were judged by the agent that ran them: three
of six final cards it would ship (stock quote, cinema seats, the smaller model's habit streak). What went wrong in
the others was the loop's, not the idea's: three first answers were cut off at the output limit, and a forced
third round made a block worse as often as better. Since then the limit is doubled, the brief asks for a block
under about 12,000 characters and names the engine's node types (so a chart is a node, not a drawing), and the
designer may answer SHIP to keep the round it has; `summary.json` says which round is final.

Each folder holds the block's brief, the block as designed, the designer's card, the rounds side by side and the
timings. `poll/fast-model-card.*` is the card a fast model then wrote with the new block in 2.3 s, before and
after a vote.

Not shown yet: a judge other than the author of this experiment; the loop inside a live session; what a request
gets while its block is being made.

## A block with behavior, checked by using it (seat-map)

`seat-map/` is one run on the harness after the outside runs of 2026-11-15, whose most-hit finding was that the
check saw only a block's first state. The designer (Opus, three rounds, 480 seconds, 35 problems in round one and
none after) ended its answer with `use.json`: tap an occupied seat, tap 7C and 7D, press Continue; expect "7C, 7D
are held"; forbid "1A", "Tap a seat" and "Continue". The check drove the card and tested the texts
(`used.png` is the card after the steps). `light.png`, `dark.png` and `narrow.png` (320 wide) are the card as
it first appears.

