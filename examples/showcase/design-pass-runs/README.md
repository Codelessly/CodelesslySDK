# Recorded design passes

The inputs and results of the design passes run on 2026-11-15 (CodelesslyAPI `docs/design/16-the-design-pass.md`),
kept so that what the pass changes can be counted and moved into defaults.

| Folder | What |
|---|---|
| `inline-cards/` | 17 chat cards a Sonnet composer wrote from plain parts |
| `mobile-pages/` | 6 phone pages (four written by hand, two real generated app screens) |
| `mobile-app-screens/` | 8 full phone screens Sonnet wrote from one-paragraph briefs (`ui.txt` is its notation) |
| `desktop-screens/` | 7 screens at 1280 wide (five by Sonnet, two by hand) |

Each case: `before.json` (the UI the pass was given, expanded with `design_systems/cards --named` as the
defaults stood then), `ops.json` (the operations kept), `summary.json` (rounds, seconds, tokens, problems),
`request.txt` where there was one. `judge.json` in a set is the blind judging of three versions (SSUI
defaults, designed defaults, defaults plus the pass).

    python3 examples/showcase/tool/pass_ops.py              # what recurs across the 38 passes
    python3 examples/showcase/tool/pass_ops.py --styles     # text restyles
    tool/notation/notation.sh apply <before.json> <ops.json> --design-system design_systems/cards --out after.json

Added in the second session (design 16 section 10, "Cycles"):

| Folder or file | What |
|---|---|
| `inline-cards/*/ui.txt` | The 17 cards' notation as recorded (`tool/stream/streams/live/2026-11-14-notation-5`). The notation now expands a badge and a grid to other nodes than `before.json` has, so the recorded `ops.json` apply to `before.json`, not to a fresh expansion, for 12 of the 17 |
| `block-pictures/` | Each own block's first preview rendered alone (`style_pass.py block-pictures`), for `--block-pictures` |
| `run10-blocks/` | Run 10's six briefs passed again with `--blocks` (`-b`) and with block pictures too (`-bp`): the operations kept, the summary, the result in light and dark |
| `cycles/` | The blind judgments of each change tried (`judge-*.json`: what was compared, who judged, each ranking and score) |
| `mobile-app-screens/judge-text-styles.json` | The text styles before and after, judged together |

    # the same UIs several ways, side by side, and packed for blind judging
    python3 examples/showcase/tool/ways.py render --set examples/showcase/design-pass-runs/mobile-app-screens --out /tmp/w \
        --dark --variant ssui= --variant designed=design_systems/cards --variant pass=design_systems/cards+ops
    python3 examples/showcase/tool/ways.py sheet --out /tmp/w/sheet.png --col SSUI=/tmp/w/ssui --col designed=/tmp/w/designed --col pass=/tmp/w/pass
    python3 examples/showcase/tool/ways.py pack --out /tmp/w/blind --col ssui=/tmp/w/ssui --col designed=/tmp/w/designed --col pass=/tmp/w/pass
    python3 examples/showcase/tool/ways.py tally --out /tmp/w/blind
