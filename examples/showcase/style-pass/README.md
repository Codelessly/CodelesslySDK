# The design pass

A card a model wrote from plain parts, restyled in place by a design agent's edit operations. The
architecture, what the agent is given and the checks are in codelessly_api
`docs/design/16-the-design-pass.md`; the tool is `examples/showcase/tool/style_pass.py`.

Each folder: `before.json` (the card as composed), `ops.json` (the operations kept), `after.json`,
`summary.json` (seconds and tokens per round), `compare.png` (before, after in light, after in dark).

| Card | Operations | First answer | Rounds |
|---|---|---|---|
| `flights` | 23 | 29.0 s | 2 |
| `approval` | 36 | 27.5 s | 2 |
| `carousel` | 27 | 21.7 s | 2 |

Composer: Sonnet. Design agent: Opus. Design system: Cards.
