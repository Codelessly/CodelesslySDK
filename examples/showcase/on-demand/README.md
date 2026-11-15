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

Each folder holds the block's brief, the block as designed, the designer's card, the rounds side by side and the
timings. `poll/fast-model-card.*` is the card a fast model then wrote with the new block in 2.3 s, before and
after a vote.

Not shown yet: a judge other than the author of this experiment; the loop inside a live session; what a request
gets while its block is being made.
