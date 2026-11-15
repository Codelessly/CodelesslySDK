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

## Seven more areas (`areas/`)

Ten requests each for forms, charts and tables, navigation and overlays, lists and gestures, media and drawing,
full phone pages (390) and full desktop website pages (1280): `requests.json`, Sonnet's answer in its own words
(`natural/`), its answer with the notation prompt after the fixes below (`notation/`), and what the notation and
the renderer reported, on the first answers (`issues-first.txt`, `render-first.txt`) and now (`issues.txt`,
`render.txt`). Over the 70 requests: notation issues 15 to 9, render errors 51 to 18.

What the first answers showed, and what was changed for it:

| Seen | How often | Now |
|---|---|---|
| `Column center` meant its children centered side to side; it was read as gathered at the column's middle, and a hand-built tab bar drew no icons | 105 lines in the recorded answers; 5 of 10 phone pages | `center` is across the page and `middle` down it on a Row, a Column and a Stack |
| A page written as several top-level sections (header, content, footer) was "a second root" | 131 lines in the desktop answers | They stack in a column that becomes the root |
| `Avatar` | 27 lines unprompted in three areas | `Avatar "Maya Reyes" size:40` (initials, or `src:` a picture); a design system's own Avatar comes first |
| `type:password` opened a keyboard and showed the password | 3 forms | `password` hides it; `multiline` is a text area |
| A line chart with `series`, `labels`, `area`; a pie or donut | 5 chart answers | `LineChart labels:[…] series:[…]`, `AreaChart`, `Donut values:[…] labels:[…]` |
| Guessed props in a JSON tail (`{"props": {"margin": …, "decoration": …, "multiline": true}}`) passed the notation and failed at render | 9 nodes in media, more elsewhere | Read as the key they are (margin, radius, fill, gradient, multiline…) or named at the line and left out |
| `Stack end bottom` for a floating button; `Text "4" center` | 3 answers | A Stack places with left, right, top, bottom; a Text aligns with center, right; `strike` |
| `color:` and `size:` on an IconButton (a star rating) | 6 nodes | Read as the icon's color and size |
| A gradient | 4 answers | `gradient:["#…","#…"]` |
| `selected:=room=='Living Room'` broke at the space | 1 answer | Single quotes hold spaces in an expression |
| Table columns as fixed-width texts wider than the card | 2 tables | A row's fixed text widths become shares when they add up to more than the canvas |
| `max-width` on a page's content | 22 lines unprompted | `maxw:720` |

Still open, by how often the model asked: links and hover (desktop, 109 and 52 lines); a dialog, a bottom sheet
and a drawer as elements (the notation has `if` over a Stack; `openModal` needs a second canvas); a table as an
element; legends and axes for charts; a sparkline or line chart whose values follow state; a list reordered by
drag with a handle; pull to refresh; a map; shapes other than a rounded box; a number that counts up. Network
images are blank in these renders because the render tool does not fetch them.
