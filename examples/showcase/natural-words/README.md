# The words a model reaches for

Sixteen requests for cards that need a gauge, a dial, a ring, a sparkline or motion (`requests.py`), answered
by claude-sonnet-5-5 three times on 2026-11-15:

| Folder | The model was given |
|---|---|
| `natural/` | No vocabulary: "a compact indented outline, use the names you find most natural" |
| `before/` | The notation prompt as it stood (no word for a gauge, a ring, a sparkline or motion) |
| `after/` | The notation prompt after those words were added |

What it wrote unprompted: `gauge`, `dial`, `Ring`, `Sparkline`, `needle`, `arc`; for motion `animate:`,
`Animation type:… trigger:on-appear`, `duration:`, `easing:`, `delay:`; `draggable:`, `swipe:`. With the old
prompt it built a gauge from boxes or a bare number, used `CircularProgressIndicator` for a ring, and left
motion out or approximated it with a timer. Two of sixteen answers did not expand (`Stack center middle`).

Added to the notation for it (CodelesslyAPI `notation.dart`, one line each in the prompt): `Gauge` and `Dial`
(a clean arc with its figure inside, `limit:`, `unit:`), `Ring`, `Sparkline`, `animate:<word>` with
`duration:`, `delay:` and `stagger:`, `swipe:left -> …`, a `Stack` that centers, a slider's `step:`, an `every`
whose actions are on the next line, `stagger:` on an `each` line.

After: 16 of 16 answers expand with no issue and use the new words where the request calls for them (lines written: 2 Gauge, 2 Ring, 3 Sparkline, 10 animate, 1 stagger:, 1 swipe:left; see `after/`). Judged blind against `before/` with `judge.py` (`judge.json`, 32 judgments): after
above before in 20, mean 6.47 against 5.81. The cards it lost are a different draw of content from the model,
and one capture taken while a requested skeleton state showed. Motion does not show in a still picture: whether
the animations play as written was not checked on a device.

Still not in the notation: a value that counts up (`animate` on a number), a card that flips, a list reordered
by drag (`drag:` exists for moving between groups), a sparkline whose values follow state
(`Sparkline values:=s.trend` expands to a binding the line chart does not take).
