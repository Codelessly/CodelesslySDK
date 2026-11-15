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
