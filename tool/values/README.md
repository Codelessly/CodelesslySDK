# Are the values right?

`check.py` answers, without a person looking at pictures, whether a generated card shows the right values after
it is used: it renders a recorded answer, drives the steps of a case, reads the texts on screen (the render
tool's `--dump-layout`, which carries each text node's `text`) and tests them against what the case expects.
It is the measure for work on how values, variables and state are written (codelessly_api design 12 §12, design
15 §4.10): a parser test passing says a spelling is read; this says the card is right.

    python3 tool/values/check.py tool/values/on_demand_cases.json <recordings dir> --design-system <folder> [--model ...]

`on_demand_cases.json`: the ten requests of the outside on-demand test (five polls, five players), each with the
interaction and the numbers its request implies (a vote for the first option, then every share and the total).

| Recordings | Model | Right |
|---|---|---|
| The outside run (branch `on-demand-model-comparison`) | Sonnet | 9 of 10 |
| The outside run | Haiku | 3 of 10 |
| `2026-11-15-ondemand-haiku-2`, after the notation changes of that day | Haiku | 7 of 10 |

The outside agent, judging by eye, counted 8 and 1 for the first two: it also failed cards whose drawn picture
was not the one asked for and whose two time labels disagreed, which a text check cannot see. What it reads is
what a person reads as numbers and labels; what it cannot judge is a picture, a color, or whether a control that
changed nothing should have.
