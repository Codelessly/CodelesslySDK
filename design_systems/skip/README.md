# Skip

A consumer fitness design system for the Skip jump rope app: a brand layer over SSUI's controls, plus screen
blocks and drawn illustrations. See DESIGN.md (the look and the tokens) and PATTERNS.md (how blocks compose).

Built by `python3 design_systems/skip/tool/build.py` (do not edit the generated files by hand):

| File | What it is |
|---|---|
| `tool/tokens.py` | The token sets: default, pink, athlete (colors, radii, shadows, the display type scale) |
| `tool/blocks.py` | The 19 blocks: Screen, TopBar, HeroSession, StreakFlame, ProgressGoal, WeekStrip, SectionTitle, SessionRow, ChartCard, StatTrio, RecordCard, EmptyState, Illustration, SessionBar, SessionDial, TapPad, SessionControls, BigButton, SessionSummary |
| `tool/art.py` | The illustrations (hero, streak, empty, record, cheer; adult and kid) as customPaint draw lists colored by tokens |
| `tool/build.py` | Runs `design_systems/tool/new_design_system.py` on `tool/brands/skip.json` (SSUI's 159 components, rebranded), merges the tokens, writes the blocks first in the component list, and writes `themes/*.json` |
| `themes/pink.json`, `themes/athlete.json` | Whole token sets as theme overrides for a site's `theme` |

`EmptyState` here replaces SSUI's component of the same name.
